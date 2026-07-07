-- Faceless AI — Supabase Database Schema
-- Run this in the Supabase SQL Editor

-- ═══════════════════════════════════════════
-- 1. Profiles Table (extends auth.users)
-- ═══════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  credits_remaining INTEGER DEFAULT 10,
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'unlimited')),
  total_videos_created INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ═══════════════════════════════════════════
-- 2. Projects Table
-- ═══════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  tone TEXT DEFAULT 'inspirational',
  status TEXT DEFAULT 'draft' CHECK (status IN (
    'draft', 'scripting', 'fetching', 'rendering', 'completed', 'failed'
  )),

  -- Input
  user_media_url TEXT,
  product_name TEXT NOT NULL DEFAULT '',
  product_description TEXT NOT NULL DEFAULT '',

  -- Generated
  script_json JSONB,
  render_spec_json JSONB,

  -- Output
  video_url TEXT,
  thumbnail_url TEXT,
  duration_sec INTEGER,

  -- Progress
  render_progress INTEGER DEFAULT 0,
  error_message TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-update timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER projects_updated_at
  BEFORE UPDATE ON public.projects
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- ═══════════════════════════════════════════
-- 3. Row Level Security (RLS)
-- ═══════════════════════════════════════════

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

-- Profiles: users can only read/update their own
CREATE POLICY "Users read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Projects: users can CRUD their own
CREATE POLICY "Users read own projects"
  ON public.projects FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own projects"
  ON public.projects FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own projects"
  ON public.projects FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own projects"
  ON public.projects FOR DELETE
  USING (auth.uid() = user_id);

-- Service role can update any project (for render worker callbacks)
CREATE POLICY "Service role updates projects"
  ON public.projects FOR UPDATE
  USING (auth.role() = 'service_role');

-- ═══════════════════════════════════════════
-- 4. Realtime
-- ═══════════════════════════════════════════

ALTER PUBLICATION supabase_realtime ADD TABLE public.projects;

-- ═══════════════════════════════════════════
-- 5. Storage Buckets
-- ═══════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public)
VALUES ('uploads', 'uploads', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('renders', 'renders', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('raw_media', 'raw_media', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: users upload to their own folder
CREATE POLICY "Users upload to own folder uploads"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'uploads' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users upload to own folder raw_media"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'raw_media' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Public read uploads"
  ON storage.objects FOR SELECT
  USING (bucket_id IN ('uploads', 'renders', 'raw_media'));

-- ═══════════════════════════════════════════
-- 6. Indexes
-- ═══════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_projects_user_id ON public.projects(user_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON public.projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_created_at ON public.projects(created_at DESC);

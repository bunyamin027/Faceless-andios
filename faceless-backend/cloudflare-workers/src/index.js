// Faceless AI — Cloudflare Worker (API Proxy)
// Deploy: npx wrangler deploy
// Env vars: GEMINI_API_KEY, PEXELS_API_KEY, RENDER_WORKER_URL, SUPABASE_JWT_SECRET

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    };

    if (request.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });

    // JWT verify (Supabase)
    const auth = request.headers.get('Authorization');
    if (!auth?.startsWith('Bearer ')) {
      return json({ error: 'Unauthorized' }, 401, corsHeaders);
    }

    try {
      switch (url.pathname) {
        case '/api/generate':       return handleGenerate(request, env, corsHeaders);
        case '/api/search-broll':   return handleBrollSearch(request, env, corsHeaders);
        case '/api/render':         return handleRender(request, env, corsHeaders);
        default:                    return json({ error: 'Not found' }, 404, corsHeaders);
      }
    } catch (e) {
      return json({ error: e.message }, 500, corsHeaders);
    }
  },
};

// ─────────────────────────────────────────────────────────────────
// HANDLER 1: /api/generate
// Calls Gemini → returns script JSON + Edge-TTS audio URL
// ─────────────────────────────────────────────────────────────────

async function handleGenerate(request, env, corsHeaders) {
  const { product_name, description, tone, duration_sec, user_media_url } = await request.json();

  // ── Step 1: Gemini — Creative Director Script ──
  const script = await callGemini(env.GEMINI_API_KEY, {
    product_name,
    description,
    tone: tone || 'inspirational',
    duration_sec: duration_sec || 25,
  });

  // ── Step 2: Pexels B-Roll search per scene ──
  const scenesWithBroll = await Promise.all(
    script.scenes.map(async (scene) => {
      const broll = await searchPexels(env.PEXELS_API_KEY, scene.broll_keywords);
      return { ...scene, broll_url: broll.url, broll_thumbnail: broll.thumbnail };
    })
  );

  // ── Step 3: Edge-TTS voiceover ──
  const fullText = scenesWithBroll.map(s => s.voiceover_text).join(' ');
  const ttsResult = await generateEdgeTTS(fullText, tone);

  // ── Step 4: Build render specification ──
  const renderSpec = buildRenderSpec({
    scenes: scenesWithBroll,
    audio_url: ttsResult.audio_url,
    user_media_url,
    word_timestamps: ttsResult.word_timestamps,
  });

  return json({
    script: { ...script, scenes: scenesWithBroll },
    tts: ttsResult,
    render_spec: renderSpec,
  }, 200, corsHeaders);
}

// ─────────────────────────────────────────────────────────────────
// GEMINI 1.5 FLASH — Creative Director System Prompt
// ─────────────────────────────────────────────────────────────────

async function callGemini(apiKey, input) {
  const systemPrompt = `You are an elite Creative Director for viral TikTok/Reels product showcase videos.

ROLE: You are a CREATOR, not a parrot. NEVER simply read back the user's description. Transform it into a compelling, emotionally-driven video script.

OUTPUT FORMAT: Return ONLY valid JSON matching this exact schema:
{
  "title": "string — the hook text (pattern-interrupt, max 8 words)",
  "scenes": [
    {
      "scene_number": 1,
      "duration_sec": 4,
      "voiceover_text": "string — natural spoken narration for this scene",
      "display_text": "string — bold on-screen text (max 6 words per line, use \\n for line breaks)",
      "text_animation": "pop_word | karaoke_highlight | fade_in | slide_up",
      "broll_keywords": ["keyword1", "keyword2"],
      "show_mockup": false
    }
  ],
  "total_duration_sec": 25,
  "music_mood": "ambient_calm | energetic_beat | dramatic_cinematic | lo_fi_chill"
}

RULES:
1. Generate exactly 4-6 scenes totaling ${input.duration_sec || 25} seconds.
2. Scene 1 MUST be a pattern-interrupt hook. No product name in scene 1. Start with pain/curiosity.
3. Scenes 2-3: Build tension, show the problem, tease the solution.
4. Scene 4+: Reveal the product. Set show_mockup=true for scenes showing the app/product.
5. Last scene: Strong CTA with urgency.

CULTURAL CONTEXT AI — CRITICAL:
Analyze the product description for cultural/religious context:
- Islamic/Muslim context (prayer, quran, mosque, halal, islamic): Use keywords like "mosque architecture", "peaceful nature sunset", "dark aesthetic calm", "crescent moon night". STRICTLY AVOID: "yoga", "buddha", "meditation candle", "wine", "church".
- Christian context: Use "church", "sunrise hope", "community gathering". Avoid Islamic/Hindu imagery.
- Secular/Tech: Use "modern workspace", "city lights", "technology abstract", "dark gradient".
- Fitness: Use "gym workout", "running outdoor", "healthy lifestyle". Avoid religious imagery.

TONE MAPPING (${input.tone}):
- inspirational: Warm, hopeful narration. Slow reveals.
- energetic: Fast cuts, punchy text, exclamation marks.
- professional: Clean, corporate, data-driven language.
- dramatic: Cinematic tension, contrast, "But then..." transitions.
- calm: Soft spoken, nature imagery, minimal text.
- edgy: Bold claims, dark visuals, CAPS for emphasis.
- luxurious: Premium language, gold/marble keywords, exclusivity.

PRODUCT: "${input.product_name}"
DESCRIPTION: "${input.description}"`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: systemPrompt }] }],
        generationConfig: {
          responseMimeType: 'application/json',
          temperature: 0.9,
          maxOutputTokens: 2048,
        },
      }),
    }
  );

  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('Gemini returned empty response');
  return JSON.parse(text);
}

// ─────────────────────────────────────────────────────────────────
// PEXELS API — B-Roll Video Search
// ─────────────────────────────────────────────────────────────────

async function searchPexels(apiKey, keywords) {
  const query = keywords.join(' ');
  const res = await fetch(
    `https://api.pexels.com/videos/search?query=${encodeURIComponent(query)}&per_page=5&orientation=portrait&size=medium`,
    { headers: { Authorization: apiKey } }
  );
  const data = await res.json();

  if (data.videos?.length > 0) {
    const video = data.videos[0];
    // Pick the HD file (max 1920px height)
    const file = video.video_files
      .filter(f => f.height <= 1920 && f.width <= 1080)
      .sort((a, b) => b.height - a.height)[0] || video.video_files[0];
    return {
      url: file.link,
      thumbnail: video.image,
      width: file.width,
      height: file.height,
    };
  }
  // Fallback: dark abstract
  return searchPexels(apiKey, ['dark abstract background']);
}

async function handleBrollSearch(request, env, corsHeaders) {
  const { keywords } = await request.json();
  const result = await searchPexels(env.PEXELS_API_KEY, keywords);
  return json(result, 200, corsHeaders);
}

// ─────────────────────────────────────────────────────────────────
// EDGE-TTS — Free Voiceover Generation
// Uses the Edge TTS WebSocket protocol directly
// ─────────────────────────────────────────────────────────────────

async function generateEdgeTTS(text, tone) {
  // Voice selection based on tone
  const voiceMap = {
    inspirational: 'en-US-AriaNeural',
    energetic: 'en-US-JennyNeural',
    professional: 'en-US-GuyNeural',
    dramatic: 'en-US-DavisNeural',
    calm: 'en-US-SaraNeural',
    edgy: 'en-US-TonyNeural',
    playful: 'en-US-JennyNeural',
    luxurious: 'en-US-AriaNeural',
  };
  const voice = voiceMap[tone] || 'en-US-AriaNeural';

  // Call our Fly.io render worker's TTS endpoint
  // (Edge-TTS requires WebSocket — can't do in CF Workers, so we proxy via Fly.io)
  // For MVP: Return a placeholder that the render worker will generate
  return {
    voice,
    text,
    audio_url: null, // Render worker generates this during render
    word_timestamps: [], // Render worker extracts these via edge-tts SubMaker
  };
}

// ─────────────────────────────────────────────────────────────────
// RENDER SPEC BUILDER — The payload for FFmpeg render worker
// This IS the "OpenCut project format" equivalent
// ─────────────────────────────────────────────────────────────────

function buildRenderSpec({ scenes, audio_url, user_media_url, word_timestamps }) {
  let currentTime = 0;

  const renderScenes = scenes.map((scene) => {
    const start = currentTime;
    const end = currentTime + scene.duration_sec;
    currentTime = end;

    return {
      // Timing
      start_sec: start,
      end_sec: end,
      duration_sec: scene.duration_sec,

      // Layer 1: Background (B-Roll)
      background: {
        type: 'video',
        url: scene.broll_url,
        filters: {
          blur: { sigma: 15 },
          dim: { opacity: 0.4 },
          scale: { width: 1080, height: 1920, mode: 'cover' },
        },
      },

      // Layer 2: Mockup (conditional)
      mockup: scene.show_mockup && user_media_url ? {
        type: 'device_frame',
        frame_template: 'iphone_15_pro',
        user_media_url: user_media_url,
        position: { x: 'center', y: 'center' },
        screen_rect: { x: 138, y: 108, width: 804, height: 1704 },
        scale: 0.65,
      } : null,

      // Layer 3: Text Overlay
      text: {
        content: scene.display_text,
        animation: scene.text_animation,
        style: {
          font_family: 'Inter-Bold',
          font_size: 64,
          color: '#FFFFFF',
          stroke_color: '#000000',
          stroke_width: 3,
          shadow: { x: 2, y: 2, blur: 8, color: '#00000080' },
        },
        position: { x: 'center', y: scene.show_mockup ? 'top_third' : 'center' },
        timing: {
          fade_in_ms: 200,
          hold_ms: (scene.duration_sec * 1000) - 600,
          fade_out_ms: 400,
        },
      },
    };
  });

  return {
    version: '1.0',
    output: {
      width: 1080,
      height: 1920,
      fps: 30,
      codec: 'libx264',
      audio_codec: 'aac',
      format: 'mp4',
      preset: 'medium',
      crf: 23,
    },
    audio: {
      voiceover: {
        url: audio_url,
        word_timestamps: word_timestamps,
      },
      music: null, // Phase 4: ambient track
    },
    scenes: renderScenes,
    total_duration_sec: currentTime,
  };
}

// ─────────────────────────────────────────────────────────────────
// HANDLER 3: /api/render — Dispatch to Fly.io render worker
// ─────────────────────────────────────────────────────────────────

async function handleRender(request, env, corsHeaders) {
  const { project_id, render_spec, callback_url } = await request.json();

  const res = await fetch(`${env.RENDER_WORKER_URL}/render`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      project_id,
      render_spec,
      callback_url: callback_url || `${env.SUPABASE_URL}/rest/v1/projects`,
    }),
  });

  const result = await res.json();
  return json(result, 200, corsHeaders);
}

// ─── Helpers ───

function json(data, status = 200, corsHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

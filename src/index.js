// Faceless AI — Cloudflare Worker (Optimized MVP)
// Deploy: npx wrangler deploy
// Env vars: GEMINI_API_KEY, PEXELS_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_KEY

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405);
    }

    const url = new URL(request.url);

    try {
      switch (url.pathname) {
        case '/api/generate':
          return await handleGenerate(request, env);
        case '/api/render':
          return await handleRender(request, env);
        case '/api/search-broll':
          return await handleBrollSearch(request, env);
        default:
          return jsonResponse({ error: 'Endpoint not found' }, 404);
      }
    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({ error: error.message || 'Internal server error' }, 500);
    }
  },
};

// ─────────────────────────────────────────────────────────────────
// HANDLER 1: /api/generate
// Gemini script → Pexels B-Roll → return script + best video URL
// ─────────────────────────────────────────────────────────────────

async function handleGenerate(request, env) {
  const body = await request.json();
  const { product_name, description, tone, duration_sec, user_media_url } = body;

  if (!product_name || !description) {
    return jsonResponse({ error: 'Missing required fields: product_name, description' }, 400);
  }

  // ── Step 1: Gemini — Generate script ──
  let script;
  try {
    script = await callGemini(env.GEMINI_API_KEY, {
      product_name,
      description,
      tone: tone || 'inspirational',
      duration_sec: duration_sec || 25,
    });
  } catch (e) {
    console.error('Gemini error:', e);
    return jsonResponse({ error: `Script generation failed: ${e.message}` }, 500);
  }

  // ── Step 2: Pexels B-Roll search per scene ──
  let scenesWithBroll;
  try {
    scenesWithBroll = await Promise.all(
      (script.scenes || []).map(async (scene) => {
        const broll = await searchPexels(env.PEXELS_API_KEY, scene.broll_keywords || []);
        return {
          ...scene,
          broll_url: broll.url,
          broll_thumbnail: broll.thumbnail,
        };
      })
    );
  } catch (e) {
    console.error('Pexels error:', e);
    // Continue with script even if Pexels fails
    scenesWithBroll = script.scenes || [];
  }

  // ── Step 3: Pick the best B-Roll video as the main video ──
  const bestVideo = scenesWithBroll.find(s => s.broll_url) || {};

  // ── Step 4: Build render spec (simplified for MVP) ──
  const renderSpec = {
    version: '1.0',
    video_url: bestVideo.broll_url || null,
    thumbnail_url: bestVideo.broll_thumbnail || null,
    output: {
      width: 1080,
      height: 1920,
      fps: 30,
      format: 'mp4',
    },
    scenes: scenesWithBroll.map((scene, i) => ({
      scene_number: scene.scene_number || i + 1,
      start_sec: scenesWithBroll.slice(0, i).reduce((sum, s) => sum + (s.duration_sec || 5), 0),
      end_sec: scenesWithBroll.slice(0, i + 1).reduce((sum, s) => sum + (s.duration_sec || 5), 0),
      duration_sec: scene.duration_sec || 5,
      broll_url: scene.broll_url,
      broll_thumbnail: scene.broll_thumbnail,
      display_text: scene.display_text,
      voiceover_text: scene.voiceover_text,
    })),
    total_duration_sec: script.total_duration_sec || 25,
  };

  return jsonResponse({
    script: {
      ...script,
      scenes: scenesWithBroll,
    },
    render_spec: renderSpec,
    // Direct video URL for MVP (skip FFmpeg render)
    video_url: bestVideo.broll_url || null,
    thumbnail_url: bestVideo.broll_thumbnail || null,
  });
}

// ─────────────────────────────────────────────────────────────────
// HANDLER 2: /api/render
// MVP: Skip FFmpeg, directly mark project as completed with Pexels video
// ─────────────────────────────────────────────────────────────────

async function handleRender(request, env) {
  const { project_id, render_spec } = await request.json();

  if (!project_id) {
    return jsonResponse({ error: 'Missing project_id' }, 400);
  }

  // Extract the best video URL from render_spec
  const videoUrl = render_spec?.video_url ||
    render_spec?.scenes?.find(s => s.broll_url)?.broll_url ||
    null;

  const thumbnailUrl = render_spec?.thumbnail_url ||
    render_spec?.scenes?.find(s => s.broll_thumbnail)?.broll_thumbnail ||
    null;

  if (!videoUrl) {
    // Update project as failed
    await updateProject(env, project_id, {
      status: 'failed',
      render_progress: 0,
      error_message: 'No video could be found for your product. Please try with a different description.',
    });
    return jsonResponse({ status: 'failed', error: 'No video URL available' });
  }

  // Directly mark project as completed (skip FFmpeg render)
  await updateProject(env, project_id, {
    status: 'completed',
    render_progress: 100,
    video_url: videoUrl,
    thumbnail_url: thumbnailUrl,
  });

  return jsonResponse({
    status: 'completed',
    job_id: project_id,
    video_url: videoUrl,
  });
}

// ─────────────────────────────────────────────────────────────────
// HANDLER 3: /api/search-broll — Standalone B-Roll search
// ─────────────────────────────────────────────────────────────────

async function handleBrollSearch(request, env) {
  const { keywords } = await request.json();
  const result = await searchPexels(env.PEXELS_API_KEY, keywords || []);
  return jsonResponse(result);
}

// ─────────────────────────────────────────────────────────────────
// GEMINI 1.5 FLASH — Creative Director
// ─────────────────────────────────────────────────────────────────

async function callGemini(apiKey, input) {
  if (!apiKey || apiKey === 'placeholder_key_add_via_dashboard') {
    throw new Error('GEMINI_API_KEY not configured. Add it via Cloudflare Dashboard.');
  }

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

B-ROLL KEYWORDS RULES — CRITICAL:
- Each scene MUST have 2-3 specific, searchable keywords for Pexels video search
- Use concrete visual terms: "city skyline night", "person typing laptop", "sunrise mountains"
- AVOID abstract terms that won't find videos: "transformation", "potential", "synergy"
- First scene keywords should be the most visually striking

PRODUCT: "${input.product_name}"
DESCRIPTION: "${input.description}"`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
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

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API returned ${res.status}: ${errText.slice(0, 200)}`);
  }

  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    const finishReason = data.candidates?.[0]?.finishReason;
    throw new Error(`Gemini returned empty response. Finish reason: ${finishReason || 'unknown'}`);
  }

  try {
    return JSON.parse(text);
  } catch (e) {
    // Try to extract JSON from markdown code blocks
    const cleanText = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
    try {
      return JSON.parse(cleanText);
    } catch (e2) {
      throw new Error(`Failed to parse Gemini response as JSON: ${text.slice(0, 200)}`);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// PEXELS API — B-Roll Video Search
// ─────────────────────────────────────────────────────────────────

async function searchPexels(apiKey, keywords) {
  if (!apiKey || apiKey === 'placeholder_key_add_via_dashboard') {
    // Return a fallback instead of crashing
    console.warn('PEXELS_API_KEY not configured');
    return { url: null, thumbnail: null };
  }

  if (!keywords || keywords.length === 0) {
    return { url: null, thumbnail: null };
  }

  const query = keywords.join(' ');

  try {
    const res = await fetch(
      `https://api.pexels.com/videos/search?query=${encodeURIComponent(query)}&per_page=5&orientation=portrait&size=medium`,
      { headers: { Authorization: apiKey } }
    );

    if (!res.ok) {
      console.error(`Pexels API returned ${res.status}`);
      return { url: null, thumbnail: null };
    }

    const data = await res.json();

    if (data.videos?.length > 0) {
      const video = data.videos[0];
      // Pick the best HD file (portrait, max 1920px height)
      const file = video.video_files
        .filter(f => f.height <= 1920 && f.width <= 1080)
        .sort((a, b) => b.height - a.height)[0] || video.video_files[0];

      return {
        url: file?.link || null,
        thumbnail: video.image || null,
        width: file?.width,
        height: file?.height,
      };
    }

    // Fallback: try a generic search if specific keywords fail
    if (!keywords.includes('dark abstract background')) {
      return searchPexels(apiKey, ['dark abstract background']);
    }

    return { url: null, thumbnail: null };
  } catch (e) {
    console.error('Pexels search error:', e);
    return { url: null, thumbnail: null };
  }
}

// ─────────────────────────────────────────────────────────────────
// SUPABASE — Direct project update
// ─────────────────────────────────────────────────────────────────

async function updateProject(env, projectId, updates) {
  const supabaseUrl = env.SUPABASE_URL;
  const serviceKey = env.SUPABASE_SERVICE_KEY;

  if (!supabaseUrl || !serviceKey ||
      supabaseUrl === 'placeholder_url_add_via_dashboard' ||
      serviceKey === 'placeholder_key_add_via_dashboard') {
    console.warn('Supabase credentials not configured, skipping project update');
    return;
  }

  // Normalize URL in case user included /rest/v1/ or trailing slash
  const baseUrl = supabaseUrl.replace(/\/rest\/v1\/?$/, '').replace(/\/$/, '');

  try {
    const res = await fetch(
      `${baseUrl}/rest/v1/projects?id=eq.${projectId}`,
      {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'apikey': serviceKey,
          'Authorization': `Bearer ${serviceKey}`,
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          ...updates,
          updated_at: new Date().toISOString(),
        }),
      }
    );

    if (!res.ok) {
      console.error(`Supabase update failed: ${res.status} ${await res.text()}`);
    }
  } catch (e) {
    console.error('Supabase update error:', e);
  }
}

// ─── Helpers ───

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}

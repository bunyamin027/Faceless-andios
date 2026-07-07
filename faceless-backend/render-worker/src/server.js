// Faceless AI — FFmpeg Render Worker (Fly.io)
// Consumes the render_spec JSON and produces MP4 via FFmpeg filter_complex
// Deploy: flyctl deploy

import express from 'express';
import { execSync, spawn } from 'child_process';
import { writeFileSync, mkdirSync, existsSync, unlinkSync } from 'fs';
import { join } from 'path';
import { randomUUID } from 'crypto';

const app = express();
app.use(express.json({ limit: '50mb' }));

const WORK_DIR = '/tmp/renders';

app.post('/render', async (req, res) => {
  const { project_id, render_spec, callback_url } = req.body;
  const jobId = project_id || randomUUID();
  const jobDir = join(WORK_DIR, jobId);

  try {
    mkdirSync(jobDir, { recursive: true });
    res.json({ status: 'accepted', job_id: jobId });

    // Run async — don't block response
    processRender(jobId, jobDir, render_spec, callback_url).catch(err => {
      console.error(`[${jobId}] FATAL:`, err);
      reportProgress(callback_url, project_id, 'failed', 0, err.message);
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─────────────────────────────────────────────────────────────────
// RENDER PIPELINE
// ─────────────────────────────────────────────────────────────────

async function processRender(jobId, jobDir, spec, callbackUrl) {
  const log = (msg) => console.log(`[${jobId}] ${msg}`);

  // ── Step 1: Generate TTS audio via edge-tts CLI ──
  log('Generating voiceover...');
  await reportProgress(callbackUrl, jobId, 'rendering', 10);

  const voText = spec.audio?.voiceover?.text ||
    spec.scenes.map(s => s.text?.content?.replace(/\\n/g, ' ')).join('. ');
  const voice = spec.audio?.voiceover?.voice || 'en-US-AriaNeural';
  const audioPath = join(jobDir, 'voiceover.mp3');
  const srtPath = join(jobDir, 'subs.srt');

  execSync(
    `edge-tts --voice "${voice}" --text "${voText.replace(/"/g, '\\"')}" ` +
    `--write-media "${audioPath}" --write-subtitles "${srtPath}"`,
    { timeout: 30000 }
  );

  // ── Step 2: Download assets ──
  log('Downloading B-Roll assets...');
  await reportProgress(callbackUrl, jobId, 'rendering', 25);

  const scenePaths = [];
  for (let i = 0; i < spec.scenes.length; i++) {
    const scene = spec.scenes[i];
    const brollPath = join(jobDir, `broll_${i}.mp4`);
    if (scene.background?.url) {
      execSync(`curl -sL -o "${brollPath}" "${scene.background.url}"`, { timeout: 60000 });
    }
    scenePaths.push({ index: i, broll: brollPath, scene });
  }

  // Download user media if any scene uses mockup
  let userMediaPath = null;
  const mockupScene = spec.scenes.find(s => s.mockup);
  if (mockupScene?.mockup?.user_media_url) {
    userMediaPath = join(jobDir, 'user_media.mp4');
    execSync(`curl -sL -o "${userMediaPath}" "${mockupScene.mockup.user_media_url}"`, { timeout: 60000 });
  }

  // ── Step 3: Render each scene as a clip ──
  log('Rendering scene clips...');
  await reportProgress(callbackUrl, jobId, 'rendering', 40);

  const clipPaths = [];
  for (const { index, broll, scene } of scenePaths) {
    const clipPath = join(jobDir, `clip_${index}.mp4`);
    const ffmpegCmd = buildSceneFFmpeg(scene, broll, userMediaPath, clipPath, jobDir);
    log(`Scene ${index}: ${ffmpegCmd.slice(0, 120)}...`);
    execSync(ffmpegCmd, { timeout: 120000 });
    clipPaths.push(clipPath);
    await reportProgress(callbackUrl, jobId, 'rendering', 40 + Math.round((index + 1) / scenePaths.length * 30));
  }

  // ── Step 4: Concat all clips ──
  log('Concatenating clips...');
  await reportProgress(callbackUrl, jobId, 'rendering', 75);

  const concatFile = join(jobDir, 'concat.txt');
  writeFileSync(concatFile, clipPaths.map(p => `file '${p}'`).join('\n'));
  const concatPath = join(jobDir, 'concat.mp4');
  execSync(
    `ffmpeg -y -f concat -safe 0 -i "${concatFile}" -c copy "${concatPath}"`,
    { timeout: 60000 }
  );

  // ── Step 5: Mux with voiceover audio ──
  log('Muxing audio...');
  await reportProgress(callbackUrl, jobId, 'rendering', 85);

  const finalPath = join(jobDir, 'final.mp4');
  execSync(
    `ffmpeg -y -i "${concatPath}" -i "${audioPath}" ` +
    `-map 0:v -map 1:a -c:v copy -c:a aac -shortest "${finalPath}"`,
    { timeout: 60000 }
  );

  // ── Step 6: Upload to Supabase Storage ──
  log('Uploading final video...');
  await reportProgress(callbackUrl, jobId, 'rendering', 95);

  // TODO: Upload to Supabase Storage bucket via REST API
  // For now, serve the file locally
  const videoUrl = `https://faceless-render.fly.dev/output/${jobId}/final.mp4`;

  await reportProgress(callbackUrl, jobId, 'completed', 100, null, videoUrl);
  log('DONE ✓');
}

// ─────────────────────────────────────────────────────────────────
// FFMPEG FILTER_COMPLEX BUILDER
// This converts our render_spec scene → FFmpeg command
// ─────────────────────────────────────────────────────────────────

function buildSceneFFmpeg(scene, brollPath, userMediaPath, outputPath, jobDir) {
  const dur = scene.duration_sec;
  const w = 1080, h = 1920;

  let inputs = `-i "${brollPath}"`;
  let filterChain = [];
  let inputIndex = 0;

  // ── LAYER 1: B-Roll (blurred + dimmed) ──
  const blur = scene.background?.filters?.blur?.sigma || 15;
  const dim = scene.background?.filters?.dim?.opacity || 0.4;
  filterChain.push(
    `[${inputIndex}:v]` +
    `scale=${w}:${h}:force_original_aspect_ratio=increase,` +
    `crop=${w}:${h},` +
    `gblur=sigma=${blur},` +
    `colorbalance=rs=-${(1-dim).toFixed(1)}:gs=-${(1-dim).toFixed(1)}:bs=-${(1-dim).toFixed(1)},` +
    `setpts=PTS-STARTPTS,` +
    `trim=duration=${dur}` +
    `[bg]`
  );

  let lastLayer = '[bg]';

  // ── LAYER 2: Device Mockup (if present) ──
  if (scene.mockup && userMediaPath) {
    inputIndex++;
    inputs += ` -i "${userMediaPath}"`;

    const sr = scene.mockup.screen_rect || { x: 138, y: 108, width: 804, height: 1704 };
    const mockScale = scene.mockup.scale || 0.65;
    const screenW = Math.round(sr.width * mockScale);
    const screenH = Math.round(sr.height * mockScale);

    // Scale user media to fit inside mockup screen area
    filterChain.push(
      `[${inputIndex}:v]` +
      `scale=${screenW}:${screenH}:force_original_aspect_ratio=decrease,` +
      `pad=${screenW}:${screenH}:(ow-iw)/2:(oh-ih)/2:black,` +
      `setpts=PTS-STARTPTS,` +
      `trim=duration=${dur}` +
      `[media]`
    );

    // Add rounded corners + phone frame effect
    const ox = Math.round((w - screenW) / 2);
    const oy = Math.round((h - screenH) / 2);

    // Overlay media on background
    filterChain.push(
      `${lastLayer}[media]overlay=${ox}:${oy}:shortest=1[mockup_base]`
    );

    // Draw phone bezel (rounded rect border)
    filterChain.push(
      `[mockup_base]drawbox=x=${ox-4}:y=${oy-4}:w=${screenW+8}:h=${screenH+8}:` +
      `color=0x333333@0.8:t=4[with_mockup]`
    );

    lastLayer = '[with_mockup]';
  }

  // ── LAYER 3: Animated Text ──
  if (scene.text?.content) {
    const text = scene.text.content.replace(/'/g, "'\\''").replace(/\n/g, '\\n');
    const fontSize = scene.text.style?.font_size || 64;
    const fadeIn = (scene.text.timing?.fade_in_ms || 200) / 1000;
    const fadeOut = (scene.text.timing?.fade_out_ms || 400) / 1000;

    // Position mapping
    let yExpr;
    const pos = scene.text.position?.y || 'center';
    switch (pos) {
      case 'top_third':   yExpr = 'h*0.2'; break;
      case 'bottom_third': yExpr = 'h*0.75'; break;
      default:            yExpr = '(h-text_h)/2'; break;
    }

    // Text animation via alpha expression
    const alphaExpr = scene.text.animation === 'pop_word'
      ? `if(lt(t,${fadeIn}),t/${fadeIn},if(gt(t,${dur-fadeOut}),(${dur}-t)/${fadeOut},1))`
      : `if(lt(t,${fadeIn}),t/${fadeIn},1)`;

    filterChain.push(
      `${lastLayer}drawtext=` +
      `text='${text}':` +
      `fontfile='/app/fonts/Inter-Bold.ttf':` +
      `fontsize=${fontSize}:` +
      `fontcolor=white:` +
      `borderw=3:bordercolor=black:` +
      `shadowx=2:shadowy=2:shadowcolor=black@0.5:` +
      `x=(w-text_w)/2:y=${yExpr}:` +
      `alpha='${alphaExpr}'` +
      `[final]`
    );
    lastLayer = '[final]';
  } else {
    // No text — rename last layer
    filterChain.push(`${lastLayer}null[final]`);
    lastLayer = '[final]';
  }

  return (
    `ffmpeg -y ${inputs} ` +
    `-filter_complex "${filterChain.join('; ')}" ` +
    `-map "${lastLayer}" -t ${dur} ` +
    `-c:v libx264 -preset medium -crf 23 -an ` +
    `"${outputPath}"`
  );
}

// ─── Progress Reporting → Supabase ───

async function reportProgress(callbackUrl, projectId, status, progress, error, videoUrl) {
  if (!callbackUrl) return;
  try {
    await fetch(`${callbackUrl}?id=eq.${projectId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'apikey': process.env.SUPABASE_SERVICE_KEY || '',
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_KEY || ''}`,
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify({
        status,
        render_progress: progress,
        ...(error && { error_message: error }),
        ...(videoUrl && { video_url: videoUrl }),
        updated_at: new Date().toISOString(),
      }),
    });
  } catch (e) {
    console.error('Progress report failed:', e.message);
  }
}

// ─── Static file serving for rendered videos ───
app.use('/output', express.static(WORK_DIR));

app.listen(8080, () => console.log('Render worker listening on :8080'));

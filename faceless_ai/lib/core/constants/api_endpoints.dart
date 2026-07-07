import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Faceless AI — API Endpoints
/// All Cloudflare Worker proxy URLs centralized here
class ApiEndpoints {
  ApiEndpoints._();

  // ── Base URL (Cloudflare Worker) ──
  static String get baseUrl => dotenv.env['CLOUDFLARE_WORKER_URL'] ?? '';

  // ── Unified Generate (Gemini + Pexels + TTS → render_spec) ──
  static String get generateScript => '$baseUrl/api/generate';

  // ── B-Roll Search (standalone) ──
  static String get searchBroll => '$baseUrl/api/search-broll';

  // ── Render Dispatch (→ Fly.io) ──
  static String get triggerRender => '$baseUrl/api/render';
}

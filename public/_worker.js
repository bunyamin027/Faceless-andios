const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    try {
      const url = new URL(request.url);

      if (url.pathname === '/api/generate') {
        const body = await request.json();
        const { product_name, description, tone, duration_sec, user_media_url } = body;

        if (!product_name || !description) {
          return new Response(JSON.stringify({ error: 'Missing required fields' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        // Gemini API URL
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${env.GEMINI_API_KEY}`;

        // System prompt defining the exact JSON output format
        const systemInstruction = `
          You are an expert AI video director. Your task is to generate a JSON blueprint for a viral TikTok/Reels style product showcase video.
          Return ONLY a raw JSON object (no markdown, no backticks).
          The JSON must follow this exact structure:
          {
            "script": {
              "scenes": [
                {
                  "text": "The voiceover text for this scene",
                  "duration": 5.0,
                  "visual": "Description of the visual for this scene"
                }
              ]
            },
            "render_spec": {
              "broll_query": "high quality search query for background video",
              "visual_layers": [
                {
                  "type": "blur_background",
                  "intensity": "high"
                },
                {
                  "type": "device_mockup",
                  "source": "user_media" 
                },
                {
                  "type": "animated_text",
                  "style": "neon"
                }
              ]
            }
          }
        `;

        const geminiPayload = {
          contents: [
            {
              role: 'user',
              parts: [
                { text: systemInstruction },
                { text: `Product: ${product_name}\nDescription: ${description}\nTone: ${tone || 'inspirational'}\nTarget Duration: ${duration_sec || 25}s\nHas User Media: ${!!user_media_url}` }
              ]
            }
          ]
        };

        const geminiResponse = await fetch(geminiUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(geminiPayload),
        });

        if (!geminiResponse.ok) {
          const err = await geminiResponse.text();
          throw new Error(`Gemini API Error: ${err}`);
        }

        const geminiData = await geminiResponse.json();
        const rawText = geminiData.candidates[0].content.parts[0].text;
        
        // Strip markdown formatting if Gemini accidentally includes it
        const cleanJsonString = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
        const finalJson = JSON.parse(cleanJsonString);

        return new Response(JSON.stringify(finalJson), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response(JSON.stringify({ error: 'Endpoint not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });

    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  },
};

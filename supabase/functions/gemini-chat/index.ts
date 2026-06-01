import { corsHeaders, preflight } from '../_shared/cors.ts';
import {
  AuthError,
  jsonError,
  jsonOk,
  rejectOversizedBody,
  requireAuth,
} from '../_shared/auth.ts';

const MAX_MESSAGE_CHARS = 1200;
const GEMINI_MODEL = 'gemini-2.0-flash';

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  const options = preflight(req);
  if (options) return options;

  const oversized = rejectOversizedBody(req, cors, 32 * 1024);
  if (oversized) return oversized;

  try {
    const ctx = await requireAuth(req, 'user');
    const apiKey = Deno.env.get('GEMINI_API_KEY')?.trim() ?? '';
    if (!apiKey) {
      return jsonError(
        503,
        'المساعد الذكي غير متاح حاليًا. لم يتم تجهيز الخدمة بعد.',
        cors,
      );
    }

    const rate = await ctx.serviceClient.rpc('consume_rate_limit', {
      _bucket: 'gemini_chat_user',
      _key: ctx.userId,
      _limit: 40,
      _window: '1 hour',
    });
    if (rate.error || !rate.data) {
      return jsonError(
        429,
        'عدد الرسائل كبير جدًا حاليًا. جرّب بعد شوية.',
        cors,
      );
    }

    const body = await req.json().catch(() => null);
    const message = typeof body?.message === 'string' ? body.message.trim() : '';
    if (!message) {
      return jsonError(400, 'اكتب سؤالك الأول.', cors);
    }
    if (message.length > MAX_MESSAGE_CHARS) {
      return jsonError(400, 'السؤال طويل جدًا. حاول تختصره شوية.', cors);
    }

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          system_instruction: {
            parts: [
              {
                text:
                  'You are Rafiq assistant. Reply in warm Egyptian Arabic. ' +
                  'Help users discover places, activities, tourism, culture, ' +
                  'restaurants, and local experiences in Egypt. Keep answers ' +
                  'clear, safe, and practical. Do not invent booking or ' +
                  'pricing facts. If unsure, say so briefly.',
              },
            ],
          },
          contents: [
            {
              role: 'user',
              parts: [{ text: message }],
            },
          ],
          generationConfig: {
            temperature: 0.7,
            topP: 0.9,
            maxOutputTokens: 600,
          },
        }),
      },
    );

    const geminiJson = await geminiRes.json().catch(() => null);
    if (!geminiRes.ok) {
      console.error('[gemini-chat] upstream error', geminiJson);
      return jsonError(
        502,
        'المساعد الذكي مشغول حاليًا. جرّب مرة ثانية بعد قليل.',
        cors,
      );
    }

    const reply =
      geminiJson?.candidates?.[0]?.content?.parts
        ?.map((part: { text?: string }) => part.text ?? '')
        ?.join('\n')
        ?.trim() ?? '';

    if (!reply) {
      return jsonError(
        502,
        'المساعد الذكي لم يرجّع ردًا واضحًا هذه المرة. جرّب سؤالًا آخر.',
        cors,
      );
    }

    return jsonOk({ reply }, cors);
  } catch (error) {
    if (error instanceof AuthError) {
      return jsonError(error.status, 'غير مصرح باستخدام هذه الخدمة.', cors);
    }

    console.error('[gemini-chat] unexpected error', error);
    return jsonError(
      500,
      'حدثت مشكلة مؤقتة أثناء تجهيز الرد. جرّب مرة أخرى.',
      cors,
    );
  }
});

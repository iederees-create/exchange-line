import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { validatePayload } from './validate-payload.js';
export { validatePayload };

const defaultOrigins = ['https://shafeeqahfrancis-gif.github.io', 'https://iederees-create.github.io'];
const extraOrigins = (Deno.env.get('ALLOWED_ORIGINS') || '').split(',').map((v) => v.trim()).filter(Boolean);
const allowedSet = [...new Set([...defaultOrigins, ...extraOrigins])];

function cors(origin: string | null) {
  const ok = origin && allowedSet.includes(origin);
  return {
    'access-control-allow-origin': ok ? origin! : '',
    'access-control-allow-headers': 'authorization,apikey,content-type',
    'access-control-allow-methods': 'POST,OPTIONS',
    vary: 'Origin',
  };
}

async function hashRateKey(ip: string) {
  const secret = Deno.env.get('RATE_LIMIT_SECRET') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`sf-enquiry:${ip}`));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  const origin = req.headers.get('origin');
  const headers = { ...cors(origin), 'content-type': 'application/json' };
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers });
  if (req.method !== 'POST' || !origin || !allowedSet.includes(origin)) {
    return new Response(JSON.stringify({ error: 'Request not allowed.' }), { status: 403, headers });
  }
  try {
    const payload = validatePayload(await req.json());
    const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for')?.split(',')[0].trim() || 'unknown';
    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !serviceKey) throw new Error('server_config');
    const supabase = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const rateKey = await hashRateKey(ip);
    const { data, error } = await supabase.rpc('submit_sf_enquiry_transaction', { p_payload: payload, p_rate_key: rateKey });
    if (error) {
      if (error.message.includes('rate_limited')) {
        return new Response(JSON.stringify({ error: 'Too many attempts. Please wait and try again.' }), { status: 429, headers });
      }
      throw error;
    }
    return new Response(JSON.stringify({ submission_id: data.submission_id, summary: data.summary }), { status: 201, headers });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({
      error: error instanceof Error && error.message === 'invalid_field'
        ? 'Please check the highlighted information and try again.'
        : 'We could not save this request. Please try again.',
    }), { status: 400, headers });
  }
});

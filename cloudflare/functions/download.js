// /download — one short link for posters and slides. A Mac or a PC gets its build straight
// away; a phone or anything else lands on the download section to read about it.
import { platformOf } from './_lib.js';

export function onRequest({ request }) {
  const os = platformOf(request);
  const to = new URL(os ? `/dl/${os}` : '/#download', request.url);
  return new Response(null, { status: 302, headers: { Location: to.href, 'Cache-Control': 'no-store', Vary: 'User-Agent, Sec-CH-UA-Platform' } });
}

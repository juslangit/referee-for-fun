// /dl/mac, /dl/win               → the latest build
// /dl/v0.3.0/mac, /dl/v0.3.0/win → a particular one
// Counts the download in KV, then sends the browser on to the file on GitHub Releases.
import { releases, asset, EXT } from '../_lib.js';

export async function onRequest(ctx) {
  const parts = [].concat(ctx.params.path || []);
  const os = parts[parts.length - 1];
  const tag = parts.length > 1 ? parts[0] : null;
  if (!EXT[os] || parts.length > 2) return Response.redirect(new URL('/#download', ctx.request.url), 302);

  let rels;
  try { rels = await releases(ctx); } catch {
    // GitHub unreachable: the stable "latest" URL still works for the newest build
    if (!tag) return Response.redirect(`https://github.com/juslangit/referee-for-fun/releases/latest/download/Referee.For.Fun${EXT[os]}`, 302);
    return Response.redirect('https://github.com/juslangit/referee-for-fun/releases', 302);
  }
  const rel = tag ? rels.find((r) => r.tag_name === tag) : rels[0];
  const a = rel && asset(rel, os);
  if (!a) return new Response('No such build', { status: 404 });

  if (ctx.env.DOWNLOADS) ctx.waitUntil(count(ctx.env.DOWNLOADS, rel.tag_name, os, ctx.request));
  return new Response(null, { status: 302, headers: { Location: a.browser_download_url, 'Cache-Control': 'no-store' } });
}

async function count(kv, tag, os, request) {
  if (/bot|crawl|spider|preview|curl|wget/i.test(request.headers.get('User-Agent') || '')) return;
  const bump = async (k) => kv.put(k, String((parseInt(await kv.get(k), 10) || 0) + 1));
  await Promise.all([bump('total'), bump(`os:${os}`), bump(`tag:${tag}:${os}`)]);
}

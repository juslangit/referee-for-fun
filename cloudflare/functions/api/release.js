// /api/release — the release list the page shows, trimmed, plus how many times the game
// has been downloaded (GitHub's own count across every build, which includes the ones
// started from this site, since /dl/ hands over to GitHub).
import { releases } from '../_lib.js';

export async function onRequest(ctx) {
  let rels;
  try { rels = await releases(ctx); } catch {
    return Response.json({ error: 'github unavailable' }, { status: 502 });
  }
  let downloads = 0;
  const out = rels.map((r) => ({
    tag: r.tag_name, name: r.name, body: r.body, published: r.published_at, url: r.html_url,
    assets: (r.assets || []).filter((a) => /\.(dmg|exe)$/.test(a.name)).map((a) => {
      downloads += a.download_count || 0;
      return { name: a.name, size: a.size, sha256: (a.digest || '').replace(/^sha256:/, '') || null, downloads: a.download_count };
    }),
  }));
  const site = ctx.env.DOWNLOADS ? parseInt(await ctx.env.DOWNLOADS.get('total'), 10) || 0 : null;
  return Response.json({ downloads, fromSite: site, releases: out }, {
    headers: { 'Cache-Control': 'public, max-age=120' },
  });
}

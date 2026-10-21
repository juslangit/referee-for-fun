// Shared by the Pages Functions: the release list from GitHub, cached at the edge so
// visitors never hit GitHub's 60-requests-an-hour limit for anonymous callers.
const REPO = 'juslangit/referee-for-fun';
const TTL = 300; // seconds

export async function releases(ctx) {
  const cache = caches.default;
  const key = new Request('https://cache.internal/referee-for-fun/releases');
  let hit = await cache.match(key);
  if (hit) return hit.json();
  const r = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=30`, {
    headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'referee-for-fun-site' },
  });
  if (!r.ok) throw new Error(`github ${r.status}`);
  const rels = (await r.json()).filter((x) => !x.draft);
  ctx.waitUntil(cache.put(key, new Response(JSON.stringify(rels), {
    headers: { 'Content-Type': 'application/json', 'Cache-Control': `max-age=${TTL}` },
  })));
  return rels;
}

export const EXT = { mac: '.dmg', win: '.exe' };

export function asset(rel, os) {
  return (rel.assets || []).find((a) => a.name.endsWith(EXT[os]));
}

// Which desktop the visitor is on, from the request headers. null for phones, Linux, bots.
export function platformOf(request) {
  const hint = (request.headers.get('Sec-CH-UA-Platform') || '').replace(/"/g, '');
  const ua = request.headers.get('User-Agent') || '';
  if (/iPhone|iPad|Android/i.test(ua)) return null;
  if (hint === 'macOS' || /Macintosh|Mac OS X/i.test(ua)) return 'mac';
  if (hint === 'Windows' || /Windows/i.test(ua)) return 'win';
  return null;
}

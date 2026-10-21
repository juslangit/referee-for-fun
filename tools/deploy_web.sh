#!/usr/bin/env bash
# Publishes web/ to Cloudflare Pages (https://referee-for-fun.pages.dev), with the
# Pages Functions in cloudflare/functions (download counter, /download, /api/release).
# Needs CLOUDFLARE_API_TOKEN, read from ~/.claude/.env when it is not already set.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f "$HOME/.claude/.env" ]; then
  set -a; . "$HOME/.claude/.env"; set +a
fi
export CLOUDFLARE_ACCOUNT_ID=863c8569b09cb26bbcb75f90f23a26e5
# wrangler looks for ./functions in the folder it runs from
cd cloudflare
npx -y wrangler@4 pages deploy ../web --project-name referee-for-fun --branch main --commit-dirty=true "$@"

#!/usr/bin/env bash
set -euo pipefail

# Publishes a generated CyberDigest artifact to Onecode24/cyber-news as a PR.
# Usage: publish_digest.sh <content_file> [title]

CONTENT_FILE="${1:?usage: publish_digest.sh <content_file> [title]}"
TITLE="${2:-CyberDigest $(date +%Y-%m-%d)}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GH_REPO="Onecode24/cyber-news"
TOKEN_FILE="${GH_TOKEN_FILE:-$HOME/.config/cyberdigest/gh_token}"

[ -f "$CONTENT_FILE" ] || { echo "content file not found: $CONTENT_FILE" >&2; exit 1; }
[ -f "$TOKEN_FILE" ] || { echo "GitHub token file not found: $TOKEN_FILE" >&2; exit 1; }

TOKEN="$(cat "$TOKEN_FILE")"
SLUG="$(date +%Y-%m-%d-%H%M)"
BRANCH="digest/${SLUG}"
EXT="${CONTENT_FILE##*.}"
DEST="digests/${SLUG}.${EXT}"

cd "$REPO_DIR"
git fetch origin main
git checkout -B "$BRANCH" origin/main

mkdir -p digests
cp "$CONTENT_FILE" "$DEST"
git add "$DEST"
git commit -m "Add ${TITLE}"
git push origin "$BRANCH"

PR_BODY="Automated CyberDigest artifact published on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
PAYLOAD="$(python3 -c "
import json, sys
print(json.dumps({'title': sys.argv[1], 'head': sys.argv[2], 'base': 'main', 'body': sys.argv[3]}))
" "$TITLE" "$BRANCH" "$PR_BODY")"

RESPONSE="$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GH_REPO}/pulls" \
  -d "$PAYLOAD")"

PR_URL="$(echo "$RESPONSE" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('html_url') or ('ERROR: ' + json.dumps(d)))
")"

git checkout main >/dev/null 2>&1

echo "$PR_URL"

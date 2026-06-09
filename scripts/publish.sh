#!/usr/bin/env bash
# Initialize git (if needed) and push to GitHub + Codeberg.
# Usage:
#   GITHUB_PAT=ghp_xxx CODEBERG_PAT=xxx ./scripts/publish.sh
#   GITHUB_USER=Cubiczan CODEBERG_USER=cubiczan REPO=swarmfi-monad ./scripts/publish.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GITHUB_USER="${GITHUB_USER:-Cubiczan}"
CODEBERG_USER="${CODEBERG_USER:-cubiczan}"
REPO="${REPO:-swarmfi-monad}"

if [[ ! -d .git ]] || [[ ! -f .git/HEAD ]]; then
  echo "==> Initializing git repository..."
  rm -rf .git 2>/dev/null || true
  git init -b main
fi

if [[ -z "$(git config user.name 2>/dev/null || true)" ]]; then
  echo "Set git user.name / user.email before committing, e.g.:"
  echo "  git config user.name 'Your Name'"
  echo "  git config user.email 'you@example.com'"
fi

echo "==> Staging files (secrets excluded via .gitignore)..."
git add -A
git status

if ! git diff --cached --quiet; then
  git commit -m "$(cat <<'EOF'
Publish SwarmFi on Monad — contracts, dashboard, docs, and demo video.

Port of SwarmFi to Monad EVM with Foundry contracts, Next.js dashboard,
testnet deployment, seed script, screenshots, and walkthrough video.
EOF
)"
else
  echo "==> Nothing new to commit."
fi

if [[ -n "${GITHUB_PAT:-}" ]]; then
  REMOTE="https://${GITHUB_USER}:${GITHUB_PAT}@github.com/${GITHUB_USER}/${REPO}.git"
  git remote remove github 2>/dev/null || true
  git remote add github "$REMOTE"
  echo "==> Pushing to GitHub..."
  git push -u github main
  echo "    https://github.com/${GITHUB_USER}/${REPO}"
fi

if [[ -n "${CODEBERG_PAT:-}" ]]; then
  REMOTE="https://${CODEBERG_USER}:${CODEBERG_PAT}@codeberg.org/${CODEBERG_USER}/${REPO}.git"
  git remote remove codeberg 2>/dev/null || true
  git remote add codeberg "$REMOTE"
  echo "==> Pushing to Codeberg..."
  git push -u codeberg main
  echo "    https://codeberg.org/${CODEBERG_USER}/${REPO}"
fi

if [[ -z "${GITHUB_PAT:-}" && -z "${CODEBERG_PAT:-}" ]]; then
  echo ""
  echo "No PATs set. To push:"
  echo "  GITHUB_PAT=ghp_xxx CODEBERG_PAT=xxx ./scripts/publish.sh"
  echo ""
  echo "Create empty repos first:"
  echo "  https://github.com/new  → ${REPO}"
  echo "  https://codeberg.org/repo/create → ${REPO}"
fi

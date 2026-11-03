#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
worktree="$(pwd)"
main_checkout="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "setup-worktree: pnpm is not installed" >&2
  exit 1
fi

for sibling in account-av apps-av; do
  target="$worktree/../$sibling"
  if [ -e "$target" ]; then
    continue
  fi
  source="$main_checkout/../$sibling"
  if [ ! -d "$source" ]; then
    echo "setup-worktree: $sibling is missing beside $main_checkout" >&2
    exit 1
  fi
  ln -s "$source" "$target"
done

pnpm install --frozen-lockfile --reporter=silent

echo "setup-worktree: ready in $worktree"

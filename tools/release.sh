#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Night City Roguelite - publish a version
# -----------------------------------------------------------------------------
# Usage (from the repo root):
#
#   tools/release.sh v0.0.16 "Short title" notes.md
#
#   notes.md  the version's changelog entry (markdown, no heading).
#
# Adds "## <tag> - <title> (<date>)" and the notes to the top of CHANGELOG.md,
# commits everything as "<tag>: <title>" and pushes to main. The Release
# workflow (.github/workflows/release.yml -> tools/publish-releases.sh) then
# tags that commit, builds the ZIP and publishes the GitHub release, marked
# latest, so .../releases/latest/download/NightCityRoguelite.zip serves it.
#
# The commit message format "vX.Y.Z: title" is what marks a version commit;
# without a shell, a commit made on github.com with that message (and the
# CHANGELOG.md entry) publishes the release the same way.
#
# Write the version's CHANGELOG.md notes before running it.
# -----------------------------------------------------------------------------
set -euo pipefail

tag="${1:?usage: tools/release.sh <tag> <title> <notes.md>}"
title="${2:?missing title}"
notes="${3:?missing notes file}"
date="$(date +%Y-%m-%d)"
cd "$(git rev-parse --show-toplevel)"

if ! printf '%s' "$tag" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Tag must look like v0.0.16." >&2
  exit 1
fi
if git log --format='%s' | grep -q "^$tag: "; then
  echo "$tag already has a version commit." >&2
  exit 1
fi

# The new entry goes right under the changelog's intro (its first 4 lines).
entry="$(mktemp)"
{ printf '## %s - %s (%s)\n\n' "$tag" "$title" "$date"; cat "$notes"; printf '\n\n'; } > "$entry"
{ head -n 4 CHANGELOG.md; printf '\n'; cat "$entry"; tail -n +6 CHANGELOG.md; } > CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md
rm -f "$entry"

git add -A
git commit -m "$tag: $title"
git push origin HEAD
echo "Pushed $tag. The Release workflow publishes it in a minute or two."

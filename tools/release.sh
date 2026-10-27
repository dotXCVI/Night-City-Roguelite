#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Night City Roguelite - publish a version
# -----------------------------------------------------------------------------
# Usage (from the repo root, with the GitHub CLI signed in):
#
#   tools/release.sh v0.0.16 "Short title" notes.md
#
#   notes.md  the version's changelog entry (markdown, no heading). It is
#             added to the top of CHANGELOG.md and used as the release notes.
#
# What it does:
#   1. adds "## <tag> - <title> (<date>)" + the notes to CHANGELOG.md;
#   2. commits everything, tags the commit, pushes branch and tag;
#   3. builds the ZIP (README, TESTING, DEVELOPER_NOTES, CHANGELOG, r6, archive,
#      source) and publishes a GitHub release with it attached twice:
#        NightCityRoguelite.zip          - same name every release, so
#          https://github.com/<owner>/<repo>/releases/latest/download/NightCityRoguelite.zip
#          always downloads the newest build;
#        NightCityRoguelite-<tag>.zip    - the versioned copy.
#
# Bump the version in README.md (title and status line) before running it.
# Never mark a release as a pre-release: "latest" skips pre-releases.
# -----------------------------------------------------------------------------
set -euo pipefail

tag="${1:?usage: tools/release.sh <tag> <title> <notes.md>}"
title="${2:?missing title}"
notes="${3:?missing notes file}"
date="$(date +%Y-%m-%d)"
root="$(git rev-parse --show-toplevel)"
cd "$root"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag $tag already exists." >&2
  exit 1
fi

# 1. Changelog: the new entry goes right under the file's intro (first 4 lines).
entry="$(mktemp)"
{ printf '## %s - %s (%s)\n\n' "$tag" "$title" "$date"; cat "$notes"; printf '\n\n'; } > "$entry"
{ head -n 4 CHANGELOG.md; cat "$entry"; tail -n +5 CHANGELOG.md; } > CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md
rm -f "$entry"

# 2. Commit, tag, push.
git add -A
git commit -m "$tag: $title"
git tag -a "$tag" -m "$tag - $title"
git push origin HEAD
git push origin "$tag"

# 3. ZIP and release.
out="$(mktemp -d)"
zip -qr "$out/NightCityRoguelite-$tag.zip" README.md TESTING.md DEVELOPER_NOTES.md CHANGELOG.md r6 archive source -x '*__pycache__*'
cp "$out/NightCityRoguelite-$tag.zip" "$out/NightCityRoguelite.zip"
gh release create "$tag" "$out/NightCityRoguelite.zip" "$out/NightCityRoguelite-$tag.zip" \
  --title "$tag - $title" --notes-file "$notes" --latest
rm -rf "$out"
echo "Published $tag."

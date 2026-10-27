#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Night City Roguelite - publish missing releases (run by the Release workflow)
# -----------------------------------------------------------------------------
# For every commit on the current branch whose message starts with
# "vX.Y.Z: <title>", oldest first, creates the tag and GitHub release if it
# doesn't exist yet. The ZIP is built from that commit's own files; the notes
# are that version's section of the commit's CHANGELOG.md. Needs GH_TOKEN.
# -----------------------------------------------------------------------------
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

newest="$(git log --format='%s' | grep -oE '^v[0-9]+\.[0-9]+\.[0-9]+(:| )' | tr -d ': ' | sort -V | tail -n 1)"

git log --reverse --format='%H %s' | while read -r sha subject; do
  tag="$(printf '%s' "$subject" | grep -oE '^v[0-9]+\.[0-9]+\.[0-9]+' || true)"
  if [ -z "$tag" ]; then
    continue
  fi
  if gh release view "$tag" >/dev/null 2>&1; then
    continue
  fi
  title="${subject#"$tag": }"

  # The commit's files.
  rm -rf "$work/tree" && mkdir -p "$work/tree"
  git archive "$sha" | tar -x -C "$work/tree"

  # Release notes: this version's CHANGELOG.md section.
  notes="$work/notes.md"
  if [ -f "$work/tree/CHANGELOG.md" ]; then
    awk -v tag="$tag" '
      $0 ~ "^## " tag " " { on = 1; next }
      on && /^## / { exit }
      on { print }
    ' "$work/tree/CHANGELOG.md" > "$notes"
  fi
  if [ ! -s "$notes" ]; then
    printf '%s\n' "$title" > "$notes"
  fi

  # The ZIP: whatever of the mod's files this version had.
  rm -f "$work"/*.zip
  (
    cd "$work/tree"
    files=()
    for f in README.md LICENSE TESTING.md DEVELOPER_NOTES.md CHANGELOG.md docs r6 archive source tools; do
      if [ -e "$f" ]; then files+=("$f"); fi
    done
    zip -qr "$work/NightCityRoguelite-$tag.zip" "${files[@]}" -x '*__pycache__*'
  )
  cp "$work/NightCityRoguelite-$tag.zip" "$work/NightCityRoguelite.zip"

  latest="--latest=false"
  if [ "$tag" = "$newest" ]; then
    latest="--latest"
  fi
  gh release create "$tag" "$work/NightCityRoguelite.zip" "$work/NightCityRoguelite-$tag.zip" \
    --target "$sha" --title "$tag - $title" --notes-file "$notes" "$latest"
  echo "Published $tag ($sha)."
done

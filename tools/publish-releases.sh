#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Night City Roguelite - publish missing releases (run by the Release workflow)
# -----------------------------------------------------------------------------
# For every commit on the current branch whose message starts with
# "vX.Y.Z: <title>", oldest first, creates the tag and GitHub release if it
# doesn't exist yet. The ZIP is built from that commit's own files; the notes
# are that version's section of the commit's CHANGELOG.md. Needs GH_TOKEN.
#
# A commit whose message starts with "vX.Y.Z update: <what>" refreshes a
# published version instead: the tag moves to that commit and the release
# gets its ZIP and notes, and its title from the version commit. Only an
# update newer than what the tag points at is applied, so each one runs once.
#
# Any other message - "v0.0.20 notes", say - is an ordinary commit.
# -----------------------------------------------------------------------------
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

newest="$(git log --format='%s' | grep -oE '^v[0-9]+\.[0-9]+\.[0-9]+(:| update:)' | grep -oE '^v[0-9.]+' | sort -V | tail -n 1)"

# Builds $work/notes.md and the two ZIPs from a commit's files.
build() {
  local sha="$1" tag="$2" title="$3"

  # The commit's files.
  rm -rf "$work/tree" && mkdir -p "$work/tree"
  git archive "$sha" | tar -x -C "$work/tree"
  # The build knows its version (RLConfig.ModVersion, "dev" in the source).
  config="$work/tree/r6/scripts/NightCityRoguelite/Core/Config.reds"
  if [ -f "$config" ]; then
    sed -i "s/ModVersion() -> String = \"dev\"/ModVersion() -> String = \"$tag\"/" "$config"
  fi

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
}

git log --reverse --format='%H %s' | while read -r sha subject; do
  tag="$(printf '%s' "$subject" | grep -oE '^v[0-9]+\.[0-9]+\.[0-9]+(:| update:)' | grep -oE '^v[0-9.]+' || true)"
  if [ -z "$tag" ]; then
    continue
  fi

  if [[ "$subject" == "$tag update:"* ]]; then
    tagged="$(git rev-list -n 1 "$tag" 2>/dev/null || true)"
    if [ -z "$tagged" ] || [ "$tagged" = "$sha" ] || ! git merge-base --is-ancestor "$tagged" "$sha"; then
      continue
    fi
    build "$sha" "$tag" "${subject#"$tag update: "}"
    git tag -f "$tag" "$sha"
    git push -f origin "refs/tags/$tag"
    gh release upload "$tag" "$work/NightCityRoguelite.zip" "$work/NightCityRoguelite-$tag.zip" --clobber
    version_title="$(git log --format='%s' | grep -m 1 "^$tag: " | sed "s/^$tag: //" || true)"
    if [ -n "$version_title" ]; then
      gh release edit "$tag" --notes-file "$work/notes.md" --title "$tag - $version_title"
    else
      gh release edit "$tag" --notes-file "$work/notes.md"
    fi
    echo "Updated $tag ($sha)."
    continue
  fi

  if gh release view "$tag" >/dev/null 2>&1; then
    continue
  fi
  title="${subject#"$tag": }"
  build "$sha" "$tag" "$title"

  latest="--latest=false"
  if [ "$tag" = "$newest" ]; then
    latest="--latest"
  fi
  gh release create "$tag" "$work/NightCityRoguelite.zip" "$work/NightCityRoguelite-$tag.zip" \
    --target "$sha" --title "$tag - $title" --notes-file "$notes" "$latest"
  echo "Published $tag ($sha)."
done

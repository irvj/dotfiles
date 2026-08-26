#!/bin/bash
set -e

SKILLS_DIR="$HOME/.local/share/opencode/skills"
SKILL_DIR="$SKILLS_DIR/frontend-design"
RAW_BASE="https://raw.githubusercontent.com/anthropics/skills/main/skills/frontend-design"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/frontend-design"
curl -fsSL "$RAW_BASE/SKILL.md" -o "$TMP_DIR/frontend-design/SKILL.md"
curl -fsSL "$RAW_BASE/LICENSE.txt" -o "$TMP_DIR/frontend-design/LICENSE.txt"

if [[ -f "$SKILL_DIR/SKILL.md" ]] && cmp -s "$TMP_DIR/frontend-design/SKILL.md" "$SKILL_DIR/SKILL.md" && \
  [[ -f "$SKILL_DIR/LICENSE.txt" ]] && cmp -s "$TMP_DIR/frontend-design/LICENSE.txt" "$SKILL_DIR/LICENSE.txt"; then
  echo "frontend-design skill up to date"
  exit 0
fi

mkdir -p "$SKILLS_DIR"
rm -rf "$SKILL_DIR"
mv "$TMP_DIR/frontend-design" "$SKILL_DIR"
echo "frontend-design skill updated"

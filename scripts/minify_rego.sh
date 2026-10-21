#!/usr/bin/env bash
#
# minify_rego.sh — strip comments, blank lines, and trailing whitespace from
# .rego files before they are packaged into an OPA bundle.
#
# OPA `# METADATA` annotation blocks (used to mark rule entrypoints, e.g.
# `# entrypoint: true`) are semantically significant to `opa build` and are
# preserved verbatim, along with every `#`-prefixed line that immediately
# follows the block header. All other full-line comments are stripped.
#
# Inline comments (code followed by `# ...` on the same line) are
# intentionally left alone — `#` can appear inside Rego string literals and
# cannot be safely stripped without a real parser.
#
# Usage: minify_rego.sh <file.rego> [<file.rego> ...]
# Each file is rewritten in place.

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $(basename "$0") <file.rego> [<file.rego> ...]" >&2
  exit 1
fi

for file in "$@"; do
  tmp="$(mktemp)"
  awk '
    BEGIN { in_meta = 0 }
    {
      line = $0

      # Once inside a METADATA block, keep every comment line verbatim.
      # The block ends at the first line that is not a comment.
      if (in_meta) {
        if (line ~ /^[[:space:]]*#/) {
          print line
          next
        }
        in_meta = 0
      }

      # Detect the start of a METADATA annotation block.
      if (line ~ /^[[:space:]]*# METADATA[[:space:]]*$/) {
        in_meta = 1
        print line
        next
      }

      # Strip full-line comments (not part of a METADATA block).
      if (line ~ /^[[:space:]]*#/) {
        next
      }

      # Strip blank / whitespace-only lines.
      if (line ~ /^[[:space:]]*$/) {
        next
      }

      # Strip trailing whitespace from the remaining line.
      sub(/[[:space:]]+$/, "", line)
      print line
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
done

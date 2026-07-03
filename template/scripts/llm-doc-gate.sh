#!/usr/bin/env sh
# ─────────────────────────────────────────────────────────────────────────
# llm-doc-gate.sh — Layer 2 doc governance (RECONSTRUCTED, not verbatim)
#
# NOTE ON PROVENANCE: DOC-GOVERNANCE-TEMPLATE.md's "Layer 2" section does not
# ship a script — it describes one by reference to an external "kuchnie kit"
# that is not in this repo. This file reconstructs that gate from the R1–R5
# spec stated in the governance doc. Treat it as a starting point, not a
# drop-in verbatim copy: the model-call step (marked TODO) must be wired to
# whichever LLM CLI you use.
#
# Run manually (weekly is the recommended cadence); wire to pre-push only
# after two weeks of useful verdicts. It never blocks a commit on its own.
#
# Usage:  sh scripts/llm-doc-gate.sh [BASE_REF]
#   BASE_REF defaults to HEAD — reviews docs changed since that ref.
# ─────────────────────────────────────────────────────────────────────────
set -eu
HERE=$(dirname "$0")
CONF="$HERE/governance.conf"
BASE="${1:-HEAD}"

# Current name list is prepended so the model sees DEAD_NAMES etc. (R3).
CONF_TEXT=""
[ -f "$CONF" ] && CONF_TEXT=$(cat "$CONF")

# Collect changed Markdown docs to review.
DOCS=$(git diff --name-only --diff-filter=ACMR "$BASE" -- '*.md' || true)
[ -z "$DOCS" ] && { echo "llm-doc-gate: no changed docs since $BASE — nothing to review."; exit 0; }

SYSTEM_PROMPT=$(cat <<'EOF'
You are a documentation governance reviewer. Review the supplied Markdown
docs against these rules and report every violation with file, line, and a
one-line fix. Be terse; silence on a rule means it passed.

(R1) No duplicate docs: two documents must not be the current source of
     truth for the same component or decision. Flag overlaps.
(R2) Evidence tags: factual claims about repo state must carry VERIFIED /
     INFERRED / UNVERIFIED, not bare assertion or hedged prose.
(R3) Docs must not describe components by retired names (see the
     governance.conf DEAD_NAMES list prepended below) as if current.
(R4) No mixed-purpose docs: each doc is one Diátaxis type (tutorial,
     how-to, reference, or explanation) — flag hybrids.
(R5) No scattered status claims: component status/type lives in the typed
     README header, not restated (and left to rot) across other docs.
EOF
)

# Assemble the payload the model reviews: conf + each doc's content.
PAYLOAD=$(
  printf '%s\n\n' "=== governance.conf (current name list) ==="
  printf '%s\n\n' "$CONF_TEXT"
  for f in $DOCS; do
    printf '=== %s ===\n' "$f"
    git show ":$f" 2>/dev/null || cat "$f" 2>/dev/null || true
    printf '\n\n'
  done
)

# ── LLM CLI invocation ──────────────────────────────────────────────────
# Primary path uses Simon Willison's `llm` CLI. `-s/--system` plus piping the
# prompt on stdin is the documented pattern — VERIFIED against
# https://llm.datasette.io usage docs (2026-07): e.g. `git diff | llm -s '...'`.
# For a different CLI the system-prompt flag differs and is the one remaining
# TODO — adapt the line below. For Claude Code, note it is:
#   printf '%s' "$PAYLOAD" | claude -p --append-system-prompt "$SYSTEM_PROMPT"
# (plain `claude -p "$SYSTEM_PROMPT"` would send it as the USER prompt).
# Until a CLI is present, this prints what WOULD be sent and exits 0 (advisory).
if command -v llm >/dev/null 2>&1; then
  printf '%s' "$PAYLOAD" | llm --system "$SYSTEM_PROMPT"
else
  echo "llm-doc-gate: no LLM CLI wired yet (see TODO in $0)." >&2
  echo "Would review these docs against R1–R5:" >&2
  printf '  %s\n' $DOCS >&2
fi
exit 0

#!/usr/bin/env sh
set -eu
. "$(dirname "$0")/governance.conf"
fail=0; say() { printf '%s\n' "$*" >&2; }
STAGED=$(git diff --cached --name-only --diff-filter=ACMR)
[ -z "$STAGED" ] && exit 0

# ── 1: dead names in added lines (skipped while DEAD_NAMES empty) ──
if [ -n "$DEAD_NAMES" ]; then
  for f in $STAGED; do
    echo "$f" | grep -Eq "$EXEMPT_PATHS" && continue
    case "$f" in *.md|*.py|*.ts|*.js|*.toml|*.json|*.yaml|*.yml) ;; *) continue ;; esac
    hits=$(git diff --cached -U0 -- "$f" | grep -E '^\+' | grep -Ev '^\+\+\+' \
           | grep -En "$DEAD_NAMES" || true)
    [ -n "$hits" ] && { say "✗ retired name added in $f:"; say "$hits"; fail=1; }
  done
fi

# ── 2: ADR immutability ─────────────────────────────────────────────
if [ "${ADR_AMEND:-0}" != "1" ]; then
  mods=$(git diff --cached --name-only --diff-filter=M \
         | grep -E '(^|/)adr/[0-9]{3}-' || true)
  [ -n "$mods" ] && { say "✗ accepted ADR modified — supersede instead:";
    say "$mods"; say "  conscious amend: ADR_AMEND=1 git commit ..."; fail=1; }
fi

# ── 3: new-doc three-question gate ──────────────────────────────────
news=$(git diff --cached --name-only --diff-filter=A | grep '\.md$' || true)
for f in $news; do
  echo "$f" | grep -Eq "$EXEMPT_PATHS" && continue
  echo "$f" | grep -Eq "$GATE_EXEMPT_NAMES" && continue
  ok=1
  for k in 'Reader:' 'Enables:' 'Update-trigger:'; do
    git show ":$f" | head -15 | grep -q "$k" || ok=0
  done
  [ $ok -eq 1 ] || { say "✗ new doc $f lacks header:";
    say "  > Reader: <who> | Enables: <what> | Update-trigger: <event>";
    say "  Can't answer all three? Don't write the doc."; fail=1; }
done

# ── 4: typed READMEs keep their header ──────────────────────────────
for f in $STAGED; do
  for r in $TYPED_READMES; do
    [ "$f" = "$r" ] || continue
    git show ":$f" | head -8 | grep -q '> Type:' \
      || { say "✗ $f lost its '> Type: ...' header"; fail=1; }
  done
done

[ $fail -eq 0 ] || { say ""; say "governance checks failed."; exit 1; }
exit 0

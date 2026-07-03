# DOC-GOVERNANCE TEMPLATE — project-agnostic version

> Reader: any new project's first agent session | Enables: installing
> doc-governance without inheriting another project's specifics |
> Update-trigger: a gate design changes in the source project

Reusable across projects. Everything project-specific lives in ONE config
block. Companion files (copy alongside this into any new repo):
AGENT-CHARTER.md + AGENT-CHARTER-APPENDIX-A.md — they seed AGENTS.md.

═══════════════════════════════════════════════════════════════════════════
DAY-1 RECIPE FOR A NEW PROJECT (staged — install gates when triggers fire)
═══════════════════════════════════════════════════════════════════════════

Day 1 (repo init):
  - AGENTS.md seeded from the charter's core rules: evidence protocol,
    new-doc three-question gate, new-component ADR gate, review contract,
    diagram labels. (Copy charter §1, §2, §4, §6 + Appendix A.9 — trim to
    one page; a rulebook nobody reads is doc creep.)
  - Every component README starts with the Type header:
    `> Type: <A–F> | Status: active | Role: <one line> | ADRs: —`
  - docs/adr/ folder + ADR template. Empty is fine; the folder existing
    is what makes "write an ADR" a 5-minute act instead of a project.

First multi-session work OR first teammate:
  - Install Layer 1 pre-commit hook (below) with checks 2–4 enabled.
    Check 1 (dead names) stays EMPTY until your first rename happens.

First rename/restructure:
  - Add the old names to DEAD_NAMES in the config block. This is the
    moment check 1 earns its existence.

First month of real doc volume:
  - Start running the Layer 2 LLM gate manually, weekly. Wire to
    pre-push only after two weeks of useful verdicts.

Every freeze / quarter:
  - Trust audit + re-stamp (charter freshness ritual).

═══════════════════════════════════════════════════════════════════════════
CONFIG — the ONLY part you edit per project
═══════════════════════════════════════════════════════════════════════════

File: scripts/governance.conf
------------------------------------------------------------------
# Regex of retired names (empty until your first rename):
DEAD_NAMES=''
# e.g. DEAD_NAMES='old-svc-name|legacy_pkg|projectx-poc'

# Space-separated README paths that must keep the '> Type:' header:
TYPED_READMES='README.md'
# e.g. TYPED_READMES='api/README.md core/README.md ui/README.md'

# Regex of paths where historical names / headerless docs are fine:
EXEMPT_PATHS='^(docs/archive/|attic/|docs/adr/|.*/docs/archive/|CHANGELOG)'

# Filenames exempt from the three-question header (format-governed):
GATE_EXEMPT_NAMES='(^|/)(README|RESUME|MIGRATION-STATUS|AGENTS|CONTRIBUTING|LICENSE)\.md$'
------------------------------------------------------------------

═══════════════════════════════════════════════════════════════════════════
LAYER 1 — pre-commit (identical logic to the kuchnie kit, config-driven)
═══════════════════════════════════════════════════════════════════════════

File: .husky/pre-commit   (or .git/hooks/pre-commit if no husky)
------------------------------------------------------------------
#!/usr/bin/env sh
sh scripts/check-governance.sh || exit 1
------------------------------------------------------------------

File: scripts/check-governance.sh
------------------------------------------------------------------
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
------------------------------------------------------------------

═══════════════════════════════════════════════════════════════════════════
LAYER 2 — LLM gate (portable as-is; rules R1–R5 are generic)
═══════════════════════════════════════════════════════════════════════════

Same script as the kuchnie kit's scripts/llm-doc-gate.sh with ONE edit:
in the system prompt, replace rule R3's hardcoded names with:
  "(R3) docs must not describe components by retired names (see
   scripts/governance.conf DEAD_NAMES) as current"
and prepend the conf file's contents to the piped input so the model
sees the current name list. Everything else — duplicate-doc detection
(R1), evidence tags (R2), mixed-purpose docs (R4), scattered status
claims (R5) — is already project-agnostic.

═══════════════════════════════════════════════════════════════════════════
NEW-PROJECT BOOTSTRAP PROMPT (paste to an agent in the fresh repo)
═══════════════════════════════════════════════════════════════════════════

"This is a new repo. Set up doc governance from
docs/DOC-GOVERNANCE-TEMPLATE.md:# DOC-GOVERNANCE TEMPLATE — project-agnostic version

> Reader: any new project's first agent session | Enables: installing
> doc-governance without inheriting another project's specifics |
> Update-trigger: a gate design changes in the source project

Reusable across projects. Everything project-specific lives in ONE config
block. Companion files (copy alongside this into any new repo):
AGENT-CHARTER.md + AGENT-CHARTER-APPENDIX-A.md — they seed AGENTS.md.

═══════════════════════════════════════════════════════════════════════════
DAY-1 RECIPE FOR A NEW PROJECT (staged — install gates when triggers fire)
═══════════════════════════════════════════════════════════════════════════

Day 1 (repo init):
  - AGENTS.md seeded from the charter's core rules: evidence protocol,
    new-doc three-question gate, new-component ADR gate, review contract,
    diagram labels. (Copy charter §1, §2, §4, §6 + Appendix A.9 — trim to
    one page; a rulebook nobody reads is doc creep.)
  - Every component README starts with the Type header:
    `> Type: <A–F> | Status: active | Role: <one line> | ADRs: —`
  - docs/adr/ folder + ADR template. Empty is fine; the folder existing
    is what makes "write an ADR" a 5-minute act instead of a project.

First multi-session work OR first teammate:
  - Install Layer 1 pre-commit hook (below) with checks 2–4 enabled.
    Check 1 (dead names) stays EMPTY until your first rename happens.

First rename/restructure:
  - Add the old names to DEAD_NAMES in the config block. This is the
    moment check 1 earns its existence.

First month of real doc volume:
  - Start running the Layer 2 LLM gate manually, weekly. Wire to
    pre-push only after two weeks of useful verdicts.

Every freeze / quarter:
  - Trust audit + re-stamp (charter freshness ritual).

═══════════════════════════════════════════════════════════════════════════
CONFIG — the ONLY part you edit per project
═══════════════════════════════════════════════════════════════════════════

File: scripts/governance.conf
------------------------------------------------------------------
# Regex of retired names (empty until your first rename):
DEAD_NAMES=''
# e.g. DEAD_NAMES='old-svc-name|legacy_pkg|projectx-poc'

# Space-separated README paths that must keep the '> Type:' header:
TYPED_READMES='README.md'
# e.g. TYPED_READMES='api/README.md core/README.md ui/README.md'

# Regex of paths where historical names / headerless docs are fine:
EXEMPT_PATHS='^(docs/archive/|attic/|docs/adr/|.*/docs/archive/|CHANGELOG)'

# Filenames exempt from the three-question header (format-governed):
GATE_EXEMPT_NAMES='(^|/)(README|RESUME|MIGRATION-STATUS|AGENTS|CONTRIBUTING|LICENSE)\.md$'
------------------------------------------------------------------

═══════════════════════════════════════════════════════════════════════════
LAYER 1 — pre-commit (identical logic to the kuchnie kit, config-driven)
═══════════════════════════════════════════════════════════════════════════

File: .husky/pre-commit   (or .git/hooks/pre-commit if no husky)
------------------------------------------------------------------
#!/usr/bin/env sh
sh scripts/check-governance.sh || exit 1
------------------------------------------------------------------

File: scripts/check-governance.sh
------------------------------------------------------------------
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
------------------------------------------------------------------

═══════════════════════════════════════════════════════════════════════════
LAYER 2 — LLM gate (portable as-is; rules R1–R5 are generic)
═══════════════════════════════════════════════════════════════════════════

Same script as the kuchnie kit's scripts/llm-doc-gate.sh with ONE edit:
in the system prompt, replace rule R3's hardcoded names with:
  "(R3) docs must not describe components by retired names (see
   scripts/governance.conf DEAD_NAMES) as current"
and prepend the conf file's contents to the piped input so the model
sees the current name list. Everything else — duplicate-doc detection
(R1), evidence tags (R2), mixed-purpose docs (R4), scattered status
claims (R5) — is already project-agnostic.

═══════════════════════════════════════════════════════════════════════════
NEW-PROJECT BOOTSTRAP PROMPT (paste to an agent in the fresh repo)
═══════════════════════════════════════════════════════════════════════════

"This is a new repo. Set up doc governance from
docs/DOC-GOVERNANCE-TEMPLATE.md: (1) create AGENTS.md seeded from
AGENT-CHARTER.md §1/§2/§4/§6 + Appendix A.9, trimmed to ~one page;
(2) add the Type header to README.md; (3) create docs/adr/ with a
template and README stating the numbering + supersede-don't-edit policy;
(4) create scripts/governance.conf with DEAD_NAMES empty and the
paths adjusted to this repo; (5) install checks 2–4 via the pre-commit
hook; (6) test: try committing a headerless scratch.md and confirm
refusal, then remove it. One commit per step." (1) create AGENTS.md seeded from
AGENT-CHARTER.md §1/§2/§4/§6 + Appendix A.9, trimmed to ~one page;
(2) add the Type header to README.md; (3) create docs/adr/ with a
template and README stating the numbering + supersede-don't-edit policy;
(4) create scripts/governance.conf with DEAD_NAMES empty and the
paths adjusted to this repo; (5) install checks 2–4 via the pre-commit
hook; (6) test: try committing a headerless scratch.md and confirm
refusal, then remove it. One commit per step."

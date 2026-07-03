# project-template — a Copier template for doc-governed repos

A [Copier](https://copier.readthedocs.io) template that scaffolds a new
project already wired for **documentation & scope discipline**: an evidence
protocol, component-type profiles, a three-question gate on new docs, and a
pre-commit hook that enforces the cheap parts automatically.

It exists so a fresh repo starts with governance baked in — and can **pull in
improvements later** as the template evolves, instead of copy-pasting rules
that immediately rot.

## Scaffold a new project

```sh
uvx copier copy --trust gh:m1981/project-template my-app
```

`--trust` is required: the template runs setup `_tasks` (git init, install the
hook, and a self-test). Copier will not run tasks without it.

Prefer a specific released version (recommended — it's what update tracks):

```sh
uvx copier copy --trust --vcs-ref v1.0.0 gh:m1981/project-template my-app
```

Non-interactive (CI, scripts): add `--defaults` to accept defaults for any
question you don't pass with `-d key=value`.

## What it asks

| Question | Meaning |
|----------|---------|
| `project_name` | kebab-case name; becomes the directory / repo name |
| `description` | one-line description |
| `project_type` | component type **A–F** (charter Appendix A): A library, B CLI, C backend API, D full-stack, E data pipeline, F host-bound plugin |
| `role_line` | one-line role for the README type header (defaults to the description) |
| `install_hooks` | install the pre-commit governance hook now? (default yes) |
| `enable_llm_gate` | include the optional manual LLM doc-gate script? (default no) |
| `python_package` | snake_case package name — asked only for types A, C, E |

## What you get

```
my-app/
├── README.md              # type header: > Type: <A–F> | Status | Role | ADRs
├── AGENTS.md              # binding rules, seeded from the charter + your type's profile
├── CHANGELOG.md           # Keep-a-Changelog skeleton
├── .gitignore
├── .copier-answers.yml    # records answers + template version → powers updates
├── docs/
│   ├── AGENT-CHARTER.md            # full charter (self-contained copy)
│   ├── AGENT-CHARTER-APPENDIX-A.md
│   ├── DOC-GOVERNANCE-TEMPLATE.md
│   └── adr/               # README (numbering + supersede policy) + 000-template.md
└── scripts/
    ├── check-governance.sh   # Layer 1 pre-commit checks
    ├── governance.conf       # the only per-project config block
    ├── pre-commit            # 2-line hook shim
    └── llm-doc-gate.sh       # only if enable_llm_gate=true
```

On scaffold the template initializes git, installs the hook (if chosen), and
runs a **fence self-test**: it tries to commit a headerless `scratch.md` and
confirms the governance hook blocks it (`OK: governance hook blocked …`).

## Pulling in template improvements later

Because `.copier-answers.yml` records your answers and the template version,
an existing project can pull later governance improvements:

```sh
cd my-app
uvx copier update --trust
```

Copier re-applies the template at the newer version, keeping your answers and
merging changes (conflicts surface as `.rej` files). Update runs against
released tags, so **tag your template versions** — a project updates from the
version it recorded to the latest tag.

## Zero-tooling fallback

Don't want Copier at all? This repo also works as a GitHub **“Template
repository.”** Enable it in *Settings → General → Template repository*, then
click **“Use this template.”** You get the file tree without the questionnaire,
`_tasks`, or the update path — you fill in the placeholders by hand.

## Layout of this repo

- `copier.yml` — the questionnaire and tasks.
- `template/` — everything that gets scaffolded (Copier's `_subdirectory`).
- `AGENT-CHARTER.md`, `AGENT-CHARTER-APPENDIX-A.md`,
  `DOC-GOVERNANCE-TEMPLATE.md` — the canonical governance sources at repo
  root. They're **copied** into `template/docs/` so generated projects never
  depend on this starter repo existing.

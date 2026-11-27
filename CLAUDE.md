## Instructions for Claude Code

- Respond in the user's language.
- When the user omits the year from a date (e.g., "March 5"), interpret it as the current year. Determine the year dynamically at runtime and always verify when writing dates.

# Kaizen-CLI Repository

This is the Kaizen-CLI open source project — a knowledge-accumulating workflow framework for Claude Code.

## Project Structure

- `docs/` — Methodology documentation (CONCEPT, DESIGN_PRINCIPLES, QUICKSTART, CUSTOMIZATION)
- `docs/internal/` — Development-only documents (.gitignore, not published). Includes PLAN_KAIZEN_CLI_OSS.md
- `framework/` — Copy-and-use template set (templates/, .claude/commands/, .claude/skills/, .claude/agents/, bin/)
- `examples/` — Domain-specific examples (data-analysis, web-development)
- `tests/` — Shell tests and the static lint of distributed files (`bash tests/run_all.sh`; also run by CI on Ubuntu and macOS)

## Language Policy

- Templates (user-facing): English and Japanese (per-registry language selection)
- Commands, skills: Description/heading in English, body in Japanese
- Documentation (docs/): Bilingual (English + Japanese)
- README: English (README.md) + Japanese (README.ja.md)

## Key Constraints

Rules that prevent bugs or design violations. For design rationale, see [DESIGN_PRINCIPLES.md](./docs/DESIGN_PRINCIPLES.md).

- **Read-only repository**: This repo is distribution-only. Never write user data here. Users' knowledge lives in `$KAIZEN_KNOWLEDGE_DIR`.
- **kaizen- prefix**: All commands and skills use `kaizen-` prefix to avoid name collisions with user's existing commands/skills.
- **Knowledge-only accumulation**: `reflect-learning` writes only to `knowledge/` files. Skills are static and not modified by the reflect process. A proposal that is not written at once (a script, a mandatory step, a lesson that recurred although it was already written) is handed to `/kaizen-update-docs` as an entry for `docs/NEXT_STEPS.md`; reflect itself never writes `docs/`.
- **Symlink + Glob workaround**: Claude Code's Glob tool cannot follow symlinks. Use Read/Grep instead of Glob for `knowledge/` access.
- **framework/bin/ for mechanical processing**: Mechanical steps (environment validation, registry listing, etc.) are extracted into shell scripts under `framework/bin/`. Skills call these scripts and parse structured output.
- **Knowledge commits name their files**: A command or skill that commits to `knowledge/` calls `framework/bin/kaizen-knowledge-commit.sh` with the files it changed. Never write `git add -A` or a `git commit` without paths into a command or skill body — the knowledge repository is shared by every project and session.
- **`knowledge/projects/` is derived**: Only `framework/bin/kaizen-registry.sh` writes there (`register` copies a project's docs, `sync-index` regenerates `INDEX.md`). Never instruct a hand edit of an INDEX row or a manual copy of a mirror.
- **One search for "is it already written"**: A step that asks whether something is already in `knowledge/` calls `framework/bin/kaizen-search-knowledge.sh` and points at `.claude/skills/kaizen-reflect-learning/CRITERIA.md` for how to read a zero. Never write a `grep -r` recipe for `knowledge/` into a command, skill, or agent body — a search that does not follow the symlink and a search that failed both print nothing, the same as "not written". Enforced by `tests/test_search_knowledge.sh`.
- **One reader for the `docs/LEARNINGS.md` markers**: The promotion candidate lines and the inventory lines are read by `framework/bin/kaizen-learnings-inventory.sh`, by the label at the start of a list item outside code fences. Never write a `grep` recipe for a label into a command, skill, or agent body — it also hits the example in the entry format and every sentence that mentions the word. Do not add an H3 heading that is not an entry to the LEARNINGS templates: the registry and the auditor count `### ` headings as entries. Enforced by `tests/test_learnings_inventory.sh` and `tests/test_reflect_structure.sh`.
- **Subagents do not read the main flow**: A workflow that needs a file only its subagents read is a skill directory (`SKILL.md` = main agent's flow, a supporting file such as `CRITERIA.md` = what the subagents read). Never point an agent definition at `SKILL.md`, and write section references into the supporting file as `` `path § Heading` `` so they can be checked. Routing belongs to the main flow as well: the words for where a finding goes (要熟考, NEXT_STEPS) stay out of `CRITERIA.md` and the agent definitions, because a subagent that reads the routing judges toward it. Enforced for reflect-learning by `tests/test_reflect_structure.sh`.
- **No runtime dependencies**: Pure Claude Code skills/commands/knowledge files — no npm, pip, or binary installs. python3 is an optional dependency (standard library only): a script that needs it lives in `framework/bin/`, and its callers print a note and skip the step when python3 is absent.
- **No positional variables in command/skill bodies**: Claude Code rewrites `$0`, `$1`, … in a command or `SKILL.md` body when it is invoked with arguments. Receive arguments via `$ARGUMENTS` only, and move shell snippets that need positional variables (e.g. awk field references) into `framework/bin/` scripts. Enforced by `tests/lint_framework.sh` (run from `tests/run_all.sh`), together with frontmatter validity, the `kaizen-` prefix, and the file-size limits.

## Conventions

- Commit messages: Conventional Commits format
- File size: Keep Markdown that Claude reads (knowledge, skills, commands, agents, templates, docs) under 800 lines — it is loaded into context in full. Scripts and tests are executed, not read whole: 1,500 lines is a soft ceiling that flags accretion, not a reason to split a single-file tool.
- SSOT: Each piece of information lives in exactly one place

## Reference Documentation

### Project Information
- **[docs/PROJECT_SUMMARY.md](./docs/PROJECT_SUMMARY.md)** — Project overview, purpose, and tech stack

### Design & Architecture
- **[docs/DESIGN_PRINCIPLES.md](./docs/DESIGN_PRINCIPLES.md)** — Architecture decisions and knowledge management patterns

### Knowledge Base
- **[knowledge/meta/INDEX.md](./knowledge/meta/INDEX.md)** — Find documents by what you want to do

### Kaizen-CLI Workflow
- `/kaizen-suggest-next` — Get suggestions for next steps
- `/kaizen-reflect-learning` — Record learnings to knowledge files
- `/kaizen-update-docs` — Update project documents (including PROJECT_SUMMARY sync)
- `/kaizen-unregister-project` — Remove a project from the registry
- `/kaizen-audit-knowledge` — Audit knowledge files for redundancy/quality and surface cross-project lessons ready for promotion to shared `knowledge/`

## Instructions for Claude Code

- Respond in the user's language.
- When the user omits the year from a date (e.g., "March 5"), interpret it as the current year. Determine the year dynamically at runtime and always verify when writing dates.

# Kaizen-CLI Repository

This is the Kaizen-CLI open source project — a knowledge-accumulating workflow framework for Claude Code.

## Project Structure

- `docs/` — Methodology documentation (CONCEPT, DESIGN_PRINCIPLES, QUICKSTART, CUSTOMIZATION)
- `docs/internal/` — Development-only documents (.gitignore, not published). Includes PLAN_KAIZEN_CLI_OSS.md
- `framework/` — Copy-and-use template set (templates/, .claude/commands/, .claude/skills/, bin/)
- `examples/` — Domain-specific examples (data-analysis, web-development)

## Language Policy

- Templates (user-facing): English and Japanese (per-registry language selection)
- Commands, skills: Description/heading in English, body in Japanese
- Documentation (docs/): Bilingual (English + Japanese)
- README: English (README.md) + Japanese (README.ja.md)

## Key Constraints

Rules that prevent bugs or design violations. For design rationale, see [DESIGN_PRINCIPLES.md](./docs/DESIGN_PRINCIPLES.md).

- **Read-only repository**: This repo is distribution-only. Never write user data here. Users' knowledge lives in `$KAIZEN_KNOWLEDGE_DIR`.
- **kaizen- prefix**: All commands and skills use `kaizen-` prefix to avoid name collisions with user's existing commands/skills.
- **Knowledge-only accumulation**: `reflect-learning` writes only to `knowledge/` files. Skills are static and not modified by the reflect process.
- **Symlink + Glob workaround**: Claude Code's Glob tool cannot follow symlinks. Use Read/Grep instead of Glob for `knowledge/` access.
- **framework/bin/ for mechanical processing**: Mechanical steps (environment validation, registry listing, etc.) are extracted into shell scripts under `framework/bin/`. Skills call these scripts and parse structured output.
- **No runtime dependencies**: Pure Claude Code skills/commands/knowledge files — no npm, pip, or binary installs.

## Conventions

- Commit messages: Conventional Commits format
- File size: Keep individual files under 800 lines
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

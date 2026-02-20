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

## Key Design Decisions

- **knowledge/** (not context/): Directory name chosen to align with "knowledge-accumulating" branding and avoid confusion with LLM "context window"
- **kaizen-cli is read-only**: This repo is distribution-only. Users' accumulated knowledge lives in their own `$KAIZEN_KNOWLEDGE_DIR`, not here. This ensures `git pull` never conflicts with user data.
- **Environment variables**: `$KAIZEN_CLI_DIR` (auto-detected by setup.sh) and `$KAIZEN_KNOWLEDGE_DIR` (user's shared knowledge directory). `kaizen-init-project` skill reads these to create symlinks.
- **kaizen- prefix**: All commands and skills use `kaizen-` prefix to avoid name collisions with user's existing commands/skills.
- **kaizen-init-project is a global skill**: Installed to `~/.claude/skills/` by setup.sh (not a command), because it needs to be available before project initialization.
- **committing-project excluded**: Commit formatting is not core to the Kaizen cycle. Claude Code already has built-in commit conventions.
- **Knowledge-only accumulation**: `reflect-learning` writes only to `knowledge/` files. Skills are static (provided by kaizen-cli or user-created) and not modified by the reflect process.
- **PROJECT_SUMMARY.md**: Each project has a structured summary in `docs/PROJECT_SUMMARY.md` with YAML frontmatter. Used by `suggest-next` to understand project context.
- **Project registry**: `$KAIZEN_KNOWLEDGE_DIR/projects/INDEX.md` maintains a table of all registered projects. `kaizen-init-project` registers, `kaizen-update-docs` syncs.
- **Multiple registries**: Subdirectories of `$KAIZEN_KNOWLEDGE_DIR` act as isolated knowledge bases. No config file needed — directory existence defines a registry. Commands work unchanged via the knowledge/ symlink.
- **Registry selection always prompts**: `kaizen-init-project` always asks which registry to use (even if only one exists). This allows users to create a new registry in-place without leaving Claude Code. Default is `default` (press Enter to accept).
- **Per-registry language selection**: Each registry stores its language in `$REGISTRY_DIR/.lang` (`en` or `ja`). Templates under `framework/templates/{en,ja}/` are selected accordingly. Registries without `.lang` default to `en` (backward compatible).
- **setup.sh --force preserves user data**: `--force` only updates env vars and symlinks. Knowledge files (template-expanded into `$KAIZEN_KNOWLEDGE_DIR`) are never overwritten, as they accumulate user data.
- **MIT License**: Maximum adoption, minimum friction
- **framework/bin/ for mechanical processing**: SKILL.md from mechanical steps (environment validation, registry listing, etc.) are extracted into testable shell scripts under `framework/bin/`. Skills call these scripts and parse structured output. This improves testability and fixes bugs like Issue #26.
- **docs/LEARNINGS.md for project-specific lessons**: Captures failures, constraints, and pitfalls specific to the project. `update-docs` extracts lessons from work history and performs periodic review (graduating general patterns to `knowledge/`, removing stale entries).
- **No runtime dependencies**: Pure Claude Code skills/commands/knowledge files — no npm, pip, or binary installs

## Current Progress

- Phase 0: Complete (confidentiality scan)
- Phase 1: Complete (repository foundation)
- Phase 2: Complete
- Phase 3: Complete
- Phase 4: Complete
- Phase 5: Complete (v0.1.0 release)

## Conventions

- Commit messages: Conventional Commits format
- File size: Keep individual files under 800 lines
- SSOT: Each piece of information lives in exactly one place

## Reference Documentation

### Project Information
- **[docs/PROJECT_SUMMARY.md](./docs/PROJECT_SUMMARY.md)** — Project overview, purpose, and tech stack

### Knowledge Base
- **[knowledge/meta/INDEX.md](./knowledge/meta/INDEX.md)** — Find documents by what you want to do

### Kaizen-CLI Workflow
- `/kaizen-suggest-next` — Get suggestions for next steps
- `/kaizen-reflect-learning` — Record learnings to knowledge files
- `/kaizen-update-docs` — Update project documents (including PROJECT_SUMMARY sync)

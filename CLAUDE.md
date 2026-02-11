# Kaizen-CLI Repository

This is the Kaizen-CLI open source project — a knowledge-accumulating workflow framework for Claude Code.

## Project Structure

- `docs/` — Methodology documentation (CONCEPT, DESIGN_PRINCIPLES, QUICKSTART, CUSTOMIZATION)
- `framework/` — Copy-and-use template set (knowledge/, .claude/commands/, .claude/skills/)
- `examples/` — Domain-specific examples (data-analysis, web-development)

## Language Policy

- Templates, commands, skills: English
- Documentation (docs/): Bilingual (English + Japanese)
- README: English (README.md) + Japanese (README.ja.md)

## Key Design Decisions

- **knowledge/** (not context/): Directory name chosen to align with "knowledge-accumulating" branding and avoid confusion with LLM "context window"
- **kaizen-cli is read-only**: This repo is distribution-only. Users' accumulated knowledge lives in their own `$KAIZEN_KNOWLEDGE_DIR`, not here. This ensures `git pull` never conflicts with user data.
- **Environment variable `KAIZEN_KNOWLEDGE_DIR`**: Points to the user's shared knowledge directory. The `/init-project` command reads this to create symlinks.
- **MIT License**: Maximum adoption, minimum friction
- **No runtime dependencies**: Pure Claude Code skills/commands/knowledge files — no npm, pip, or binary installs

## Conventions

- Commit messages: Conventional Commits format
- File size: Keep individual files under 800 lines
- SSOT: Each piece of information lives in exactly one place

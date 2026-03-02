---
project:
  id: "kaizen-cli"
  name: "Kaizen-CLI"
  status: released          # planning | developing | released | completed | on-hold
  keywords: [claude-code, knowledge, workflow, framework, kaizen, registry, i18n, templates, symlink, idempotent, git-init, project-registry]
  created: "2026-02-18"
  updated: "2026-03-02"
---

# Kaizen-CLI

## Purpose

Development and distribution of a knowledge-accumulating workflow framework for Claude Code.

## Overview

A framework that embeds a knowledge-accumulation loop into everyday Claude Code work. Provides shared knowledge base via symlinks, Kaizen cycle commands (suggest → execute → reflect → update docs), and domain-specific skills/knowledge templates.

## Tech Stack

- Pure Claude Code skills/commands/knowledge files (no runtime dependencies)
- Bash (setup.sh, framework/bin/)
- GitHub Actions (link-check CI)

## Design Decisions

See [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md) for architecture decisions and knowledge management patterns.

## Notes

- This repo is distribution-only (read-only). User knowledge lives in `$KAIZEN_KNOWLEDGE_DIR`.
- `git pull` never conflicts with user data by design.
- Kaizen commands are project-local (created by `kaizen-init-project`), not global.

## Project Documentation

- `PROJECT_SUMMARY.md` - Project overview (this file)
- [LEARNINGS.md](./LEARNINGS.md) - Project-specific lessons
- [CONCEPT.md](./CONCEPT.md) - Methodology concept
- [CONCEPT.ja.md](./CONCEPT.ja.md) - Methodology concept (Japanese)
- [CUSTOMIZATION.md](./CUSTOMIZATION.md) - Customization guide
- [CUSTOMIZATION.ja.md](./CUSTOMIZATION.ja.md) - Customization guide (Japanese)
- [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md) - Design principles
- [DESIGN_PRINCIPLES.ja.md](./DESIGN_PRINCIPLES.ja.md) - Design principles (Japanese)
- [QUICKSTART.md](./QUICKSTART.md) - Quickstart guide
- [QUICKSTART.ja.md](./QUICKSTART.ja.md) - Quickstart guide (Japanese)

---
project:
  id: "kaizen-cli"
  name: "Kaizen-CLI"
  status: released          # planning | developing | released | completed | on-hold
  keywords: [claude-code, knowledge, workflow, framework, kaizen, registry, i18n, templates, symlink]
  created: "2026-02-18"
  updated: "2026-02-22"
---

# Kaizen-CLI

## Purpose

Development and distribution of a knowledge-accumulating workflow framework for Claude Code.

## Overview

A framework that embeds a knowledge-accumulation loop into everyday Claude Code work. Provides shared knowledge base via symlinks, Kaizen cycle commands (suggest → execute → reflect → update docs), and domain-specific skills/knowledge templates.

## Tech Stack

- Pure Claude Code skills/commands/knowledge files (no runtime dependencies)
- Bash (setup.sh)
- GitHub Actions (link-check CI)

## Design Decisions

See CLAUDE.md "Key Design Decisions" section for comprehensive list.

## Notes

- This repo is distribution-only (read-only). User knowledge lives in `$KAIZEN_KNOWLEDGE_DIR`.
- `git pull` never conflicts with user data by design.

## Project Documentation

- `PROJECT_SUMMARY.md` - Project overview (this file)
- [CONCEPT.md](./CONCEPT.md) - Methodology concept
- [CONCEPT.ja.md](./CONCEPT.ja.md) - Methodology concept (Japanese)
- [CUSTOMIZATION.md](./CUSTOMIZATION.md) - Customization guide
- [CUSTOMIZATION.ja.md](./CUSTOMIZATION.ja.md) - Customization guide (Japanese)
- [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md) - Design principles
- [DESIGN_PRINCIPLES.ja.md](./DESIGN_PRINCIPLES.ja.md) - Design principles (Japanese)
- [QUICKSTART.md](./QUICKSTART.md) - Quickstart guide
- [QUICKSTART.ja.md](./QUICKSTART.ja.md) - Quickstart guide (Japanese)

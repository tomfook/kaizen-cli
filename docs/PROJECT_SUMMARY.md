---
project:
  id: "kaizen-cli"
  name: "Kaizen-CLI"
  status: released          # planning | developing | released | completed | on-hold
  keywords: [claude-code, knowledge, workflow, framework, kaizen, registry, i18n, templates, symlink, idempotent, git-init, project-registry, testing, subagent, verification, unregister, audit, auto-memory, cross-project-learning, promotion-marker, next-steps, link-sync, static-lint, section-extract, reference-check, pathspec-commit, reference-gate, derived-index, criteria-split, fact-payload, knowledge-search, purpose-criteria, deliberate-lane]
  created: "2026-02-18"
  updated: "2026-11-27"
---

# Kaizen-CLI

## Purpose

Development and distribution of a knowledge-accumulating workflow framework for Claude Code.

## Overview

A framework that embeds a knowledge-accumulation loop into everyday Claude Code work. Provides shared knowledge base via symlinks, Kaizen cycle commands (suggest → execute → update docs → reflect), and domain-specific skills/knowledge templates. Reflect-learning is a skill directory (`SKILL.md` for the main agent's flow, `CRITERIA.md` for the judgment criteria) that uses a subagent architecture (reflector + verifier) with context separation for bias-free independent verification: both subagents read `CRITERIA.md` only, and the verifier receives the fact payload exactly as the main agent wrote it rather than the reflector's summary. The criteria state what a record is for — it is kept when having it written will save time or prevent a mistake next time — so a failure is a strong signal but not a reason in itself; the reflector still places every failure and correction under "keep" or "set aside, with a reason", and the nine categories (including accuracy improvements to existing knowledge and filing-back of external research) are a lookup table rather than a checklist. A cause is recorded only after a rerun that changes one thing, and counts are recounted rather than remembered. A finding has four destinations: `knowledge/`, the project's `docs/LEARNINGS.md`, nothing, or — for a proposal that adds a script or a mandatory step, or a lesson that recurred although it was already written — an entry for `docs/NEXT_STEPS.md` that `update-docs` files. Projects can be unregistered from the registry via `kaizen-unregister-project`. The audit command (`kaizen-audit-knowledge`) runs in two passes: knowledge-auditor trims redundancy / SSOT violations / stale content inside `knowledge/`, and learning-auditor scans each registered project's `docs/LEARNINGS.md` (synced into `knowledge/projects/learnings/{id}.md`) for cross-project promotion candidates — implementing a three-tier learning promotion model documented in DESIGN_PRINCIPLES. Both passes combine a mechanical check (line count, freshness, INDEX deviation, broken links) with auditor analysis and record results to `knowledge/meta/AUDIT_HISTORY.md` for repeat-finding detection. The update-docs command also inventories Claude Code's auto memory, promoting permanent information to docs/ or knowledge/ and cleaning up stale entries. It additionally maintains an optional `docs/NEXT_STEPS.md` backlog (Open items / Deferred) as the write-owner, which `suggest-next` reads to gate re-proposals. Because skills, commands, and agents are linked into each project one by one, `kaizen-init.sh check-links` / `sync-links` detect and repair links that are missing or dangling after a framework update; `suggest-next` and `audit-knowledge` run the check first. A static lint (`tests/lint_framework.sh`) guards the distributed files against silent failures: broken frontmatter, positional variables in command/skill bodies, missing `kaizen-` prefix, oversized files (Markdown over 800 lines, scripts over 1,500), and references to nonexistent `framework/bin/` scripts. Two mechanical tools back the editing and auditing steps: `kaizen-extract-section.sh` extracts one Markdown section by heading boundary (also heading list and bytes per section), so a section can be re-read after an edit without an ad-hoc awk range; `kaizen-check-refs.py` extracts section references, promotion markers, and link anchors with a single extractor and checks that the target heading exists — across `knowledge/` (the audit's mechanical check), a project's `docs/` and `CLAUDE.md`, or only the lines staged for commit. The question "is this already written?" has one procedure: `kaizen-search-knowledge.sh` walks the real path of the knowledge directory (without the registry mirror) and the framework's skills, commands, and agents with fixed strings, prints the hit files per keyword, the hit lines with the heading of their section, and the uncommitted changes of the knowledge repository, names what it could not scan (exit code 1), and refuses to answer when find or grep does not work (exit code 2); the eight reasons a search returns zero besides absence are listed in `CRITERIA.md`. Commits to the shared `knowledge/` repository go through `kaizen-knowledge-commit.sh`, which stages and commits only the files it is given, lists other sessions' uncommitted changes without touching them, and blocks on a broken reference in the lines being committed. The project registry is derived data: `kaizen-registry.sh register` mirrors a project's `PROJECT_SUMMARY.md` and `LEARNINGS.md`, `sync-index` regenerates `knowledge/projects/INDEX.md` from the mirrors' frontmatter (rows without a mirror are carried over), and `status` reports stale, missing, or uncommitted mirrors before a project commit.

## Tech Stack

- Pure Claude Code skills/commands/knowledge files (no runtime dependencies)
- Bash (setup.sh, framework/bin/, tests/) with POSIX awk (restricted frontmatter reader and INDEX generator in `kaizen-registry.sh`)
- Python 3 (optional, standard library only; reference checking — skipped with a note when absent)
- GitHub Actions (link-check CI; shell tests on Ubuntu and macOS)

## Design Decisions

See [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md) for architecture decisions and knowledge management patterns.

## Notes

- This repo is distribution-only (read-only). User knowledge lives in `$KAIZEN_KNOWLEDGE_DIR`.
- `git pull` never conflicts with user data by design.
- Kaizen commands are project-local (created by `kaizen-init-project`), not global. This includes the ones distributed as a skill directory (`/kaizen-reflect-learning`).

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

# Kaizen-CLI

**A knowledge-accumulating workflow framework for Claude Code**

> Work on real tasks. Let the knowledge build itself.

[日本語版 README](README.ja.md)

---

## What is Kaizen-CLI?

With Claude Code, do you find yourself repeating the same explanations every time you switch projects? Project-specific rules can be handled with CLAUDE.md. But industry expertise, deep technical knowledge, and hard-won lessons from past mistakes — these should accumulate across projects, and there's currently no built-in mechanism for that.

Kaizen-CLI doesn't ask you to run a separate improvement process. Instead, it **embeds a knowledge-accumulation loop into your everyday work**. You focus on your actual tasks — building features, fixing bugs, running analyses. When you hit friction during that work — an unexpected error, a technique you had to look up, a pattern that turned out to work well — that friction becomes the raw material for updating your shared knowledge base. Over time, the knowledge that accumulates from real work accelerates all your future work across every project.

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Init   │───▶│ Suggest │───▶│ Execute │───▶│ Reflect │
│         │    │  Next   │    │(= your  │    │         │
│/kaizen  │    │/kaizen  │    │ actual  │    │/kaizen  │
│-init    │    │-suggest │    │  work)  │    │-reflect │
│-project │    │-next    │    │         │    │-learning│
└─────────┘    └─────────┘    └─────────┘    └─────────┘
                    ▲                              │
                    │  Friction from work feeds     │
                    │  knowledge/ which accelerates │
                    │  the next cycle               │
                    └──────────────────────────────┘
```

## What Kaizen-CLI Provides

| Mechanism | Description |
|-----------|-------------|
| **Shared knowledge base** | `knowledge/` is symlinked across all projects with optional registry isolation. Industry expertise, technical insights, and hard-won lessons accumulate over time |
| **Work-embedded Kaizen cycle** | Suggest → execute → reflect wraps around your real work — not a separate improvement process |
| **Knowledge curation** | `/kaizen-audit-knowledge` periodically trims redundancy and stale content, and surfaces cross-project lessons in `docs/LEARNINGS.md` that are ready to be promoted to shared `knowledge/` — reflect accumulates, audit curates |
| **Project context** | PROJECT_SUMMARY and a project registry maintain cross-project context |

## Why Kaizen-CLI?

- **No extra process**: You don't need to think about improvements separately. Friction that naturally arises during real work becomes the input for knowledge updates
- **Knowledge persists**: Lessons learned are written to `knowledge/` files and available across all your projects
- **Cross-project learning**: Shared knowledge via symlinks means one project's insights benefit all projects
- **Signal stays high**: Accumulation is paired with periodic curation, so `knowledge/` grows as a resource — not as noise
- **Faster over time**: Accumulated knowledge means less repeated explanations, fewer regressions, and fewer known pitfalls

## Quick Start

```bash
# 1. Clone and set up Kaizen-CLI (one-time)
git clone https://github.com/tomfook/kaizen-cli.git
bash kaizen-cli/setup.sh

# 2. Initialize your project
cd your-project
claude  # Start Claude Code, then:
        # /kaizen-init-project    — set up knowledge/ symlink and project config

# 3. Start the Kaizen cycle
        # /kaizen-suggest-next       — get next step suggestions
        # /kaizen-reflect-learning   — capture lessons learned
        # /kaizen-update-docs        — sync project docs and inventory auto memory
        # /kaizen-unregister-project — remove a project from the registry
        # /kaizen-audit-knowledge   — audit knowledge files for quality
```

`setup.sh` creates the shared knowledge directory (`$KAIZEN_KNOWLEDGE_DIR`) and links the `kaizen-init-project` skill. Run `/kaizen-init-project` in each project to set up kaizen commands and symlinks. The `knowledge/` in each project is a symlink to a registry within this shared directory — knowledge accumulated in one project is automatically available to all others sharing the same registry. You can create multiple registries (e.g., work and personal) to keep knowledge separated by context.

For a detailed walkthrough, see [docs/QUICKSTART.md](docs/QUICKSTART.md).

## Repository Structure

```
kaizen-cli/
├── docs/                    # Methodology and guides
│   ├── CONCEPT.md           # The Kaizen-CLI philosophy
│   ├── DESIGN_PRINCIPLES.md # Design principles
│   ├── QUICKSTART.md        # 5-minute getting started guide
│   └── CUSTOMIZATION.md     # How to adapt for your domain
│
├── framework/               # Copy-and-use template set
│   ├── bin/                 # Helper shell scripts
│   ├── templates/           # Locale-separated templates
│   │   ├── en/              # English templates
│   │   └── ja/              # Japanese templates
│   └── .claude/
│       ├── commands/        # Workflow slash commands
│       └── skills/          # Auto-invoked skill definitions
│
└── examples/                # Domain-specific examples
    ├── data-analysis/       # Data analysis workflow
    └── web-development/     # Web development workflow
```

## Documentation

- [CONCEPT.md](docs/CONCEPT.md) — The philosophy behind Kaizen-CLI
- [DESIGN_PRINCIPLES.md](docs/DESIGN_PRINCIPLES.md) — Design principles and patterns
- [QUICKSTART.md](docs/QUICKSTART.md) — Get started in 5 minutes
- [CUSTOMIZATION.md](docs/CUSTOMIZATION.md) — Adapt Kaizen-CLI for your domain

## Who is this for?

**Great fit:**
- Individual developers or analysts juggling multiple small projects
- Claude Code users who want knowledge gained in one project to carry over to all other projects
- Anyone interested in structured AI-assisted development workflows

**Not a fit:**
- Single long-running project with no need for cross-project knowledge sharing
- Teams not using Claude Code

## Contributing

Contributions are welcome! Please open an issue or pull request.

## License

[MIT](LICENSE)

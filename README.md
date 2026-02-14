# Kaizen-CLI

**A knowledge-accumulating workflow framework for Claude Code**

> Your AI gets smarter the more you use it.

[日本語版 README](README.ja.md)

---

## What is Kaizen-CLI?

With Claude Code, do you find yourself repeating the same explanations every time you switch projects? Project-specific rules can be handled with CLAUDE.md. But industry expertise, deep technical knowledge, and hard-won lessons from past mistakes — these should accumulate across projects, and there's currently no built-in mechanism for that.

Kaizen-CLI solves this by providing a **structured workflow** that accumulates knowledge across sessions and projects, and leverages that knowledge to suggest your next actions. The more you use it, the faster your AI works.

```
                    ┌──────────────────────────────────────────────┐
                    │                                              │
                    ▼                                              │
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Init   │───▶│ Suggest │───▶│ Plan &  │───▶│ Execute │───▶│ Reflect │
│         │    │         │    │ Decide  │    │         │    │         │
│/kaizen  │    │/kaizen  │    │         │    │skills   │    │/kaizen  │
│-init    │    │-suggest │    │plan     │    │auto-    │    │-reflect │
│-project │    │-next    │    │mode     │    │invoke   │    │-learning│
│         │    │         │    │         │    │         │    │         │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
                    ▲                                              │
                    │          Knowledge accumulates               │
                    │       in knowledge/ over cycles              │
                    └──────────────────────────────────────────────┘
```

## What Kaizen-CLI Provides

| Mechanism | Description |
|-----------|-------------|
| **Shared knowledge base** | `knowledge/` is symlinked across all projects. Industry expertise, technical insights, and hard-won lessons accumulate over time |
| **Kaizen cycle** | A suggest → plan → execute → reflect cycle that drives continuous improvement |
| **Project context** | PROJECT_SUMMARY and a project registry maintain cross-project context |

## Why Kaizen-CLI?

- **Knowledge persists**: Lessons learned are written to `knowledge/` files and available in every future session and project
- **Cross-project learning**: Shared knowledge via symlinks means one project's insights benefit all projects
- **Structured improvement**: An explicit suggest → plan → execute → reflect cycle drives continuous improvement
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
        # /kaizen-suggest-next    — get next step suggestions
        # /kaizen-reflect-learning — capture lessons learned
        # /kaizen-update-docs     — update project documentation
```

`setup.sh` creates the shared knowledge directory (`$KAIZEN_KNOWLEDGE_DIR`) and installs global commands. The `knowledge/` in each project is a symlink to this shared directory — knowledge accumulated in one project is automatically available to all others.

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
│   ├── CLAUDE.md.template   # CLAUDE.md template for projects
│   ├── knowledge/           # Knowledge base templates
│   │   └── meta/
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
- Claude Code users who want knowledge to carry over between sessions
- Anyone interested in structured AI-assisted development workflows

**Not a fit:**
- Single long-running project with no need for cross-project knowledge sharing
- Teams not using Claude Code

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)

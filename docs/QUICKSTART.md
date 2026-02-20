# Quickstart

A guide to setting up Kaizen-CLI and experiencing your first Kaizen cycle in 5 minutes.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- git installed
- bash available (macOS / Linux)

---

## Step 1: Set Up Kaizen-CLI (First Time Only)

```bash
# Clone
git clone https://github.com/tomfook/kaizen-cli.git

# Run setup
bash kaizen-cli/setup.sh
```

setup.sh does the following:

1. Auto-detects `$KAIZEN_CLI_DIR` and sets it in `~/.bashrc`
2. Confirms/creates the shared knowledge directory path (`$KAIZEN_KNOWLEDGE_DIR`)
3. Selects or creates a knowledge registry (default: `default`)
4. Selects a template language (`en` or `ja`, default: `en`) — stored in `$REGISTRY_DIR/.lang`
5. Expands template files into the selected registry (in the chosen language)
6. Globally links commands and skills

```bash
# Apply environment variables
source ~/.bashrc
```

> **Tip**: After updating kaizen-cli with `git pull`, re-run `bash kaizen-cli/setup.sh --force` to update environment variables and symlinks. Knowledge files are preserved.

---

## Step 2: Initialize Your Project

Launch Claude Code in an existing project directory and run `/kaizen-init-project`.

```bash
cd ~/my-python-project
claude
```

Inside Claude Code:

```
/kaizen-init-project
```

Answer a few questions:

- **Registry**: `default` (press Enter to accept; type a different name to select another registry)
- **Project name**: My Python Project
- **Project ID**: `my-python-project` (auto-suggested from the directory name; press Enter to accept)
- **Project purpose**: A collection of Python scripts to automate daily tasks
- **Summary (one line)**: A collection of Python utility scripts

Once complete, the following structure is created:

```
my-python-project/
├── CLAUDE.md              ← Project-specific settings
├── knowledge/             ← symlink to $KAIZEN_KNOWLEDGE_DIR/default
├── .claude/skills/        ← symlink to Kaizen-CLI skills
└── docs/
    ├── PROJECT_SUMMARY.md ← Project overview
    └── LEARNINGS.md       ← Project-specific lessons
```

The key point is that `knowledge/` is a symlink to the shared directory. Knowledge accumulated in other projects is immediately accessible from here.

---

## Step 3: Run Your First Kaizen Cycle

From here, we walk through a fictional scenario to experience the full Kaizen cycle.

### 3-1: Suggest — Get Next Action Proposals

```
/kaizen-suggest-next
```

Since the project was just initialized, you will see suggestions like these:

```markdown
## Suggested Next Steps

**Current task**: Initial project setup

### Possible Actions

1. [ ] **Fill in the sections of docs/PROJECT_SUMMARY.md**: Recording the tech stack and
   design decisions eliminates the need to re-explain context in future sessions
   → Reason: Documenting the project's purpose and constraints improves work efficiency

2. [ ] **Customize CLAUDE.md**: Add project-specific coding conventions and
   important rules
   → Reason: Since Claude Code reads this file first, anything written here takes effect immediately

Which suggestion would you like to pursue?
```

### 3-2: Execute — Do the Work (= Your Actual Task)

Pick "1. Fill in PROJECT_SUMMARY.md" from the suggestions.

Edit PROJECT_SUMMARY.md together with Claude Code.

```
Fill in the tech stack section.
I'm using Python 3.11. Dependency management is pip.
```

Claude Code proceeds with the edits, but suppose you make a correction:

```
Wait, I'm using uv, not venv. Fix that.
```

This "correction" is the kind of signal that Reflect captures as knowledge. The natural friction that arises during work — that becomes the raw material for knowledge.

### 3-3: Reflect — Turn Friction into Knowledge

After the work is done, reflect on what you learned.

```
/kaizen-reflect-learning
```

Claude Code analyzes the session and proposes something like this:

```markdown
## Insight Analysis

### Extracted Insights

1. **Making implicit rules explicit**: The user uses uv for Python dependency management.
   Suggestions that assumed venv required correction.
   - Generalization: "Dependency management tools vary by Python project.
     Confirm rather than assume."
   - Destination: Add to knowledge/

### Generalization Criteria Check
- [x] Not a one-off exception (applies to other projects too)
- [x] Contributes to efficiency (enables confirming instead of guessing next time)
- [x] A correction occurred during the session (auto-approved)

Do you approve?
```

Once approved, the insight is written to knowledge/. This insight **becomes immediately available across all projects via the symlink**.

The next time you initialize a Python project, Claude Code reads this insight from knowledge/ and will confirm the dependency management tool instead of guessing.

### 3-4: Update Docs — Sync Project Documents and Registry

Once knowledge/ has been updated, bring your project-side documentation up to date as well.

```
/kaizen-update-docs
```

Claude Code analyzes CLAUDE.md and docs/, and proposes updates:

```markdown
## Documentation Update Proposal

### Updates to docs/

#### PROJECT_SUMMARY.md
- Tech stack: Add uv as the dependency management tool
- status: planning → developing

Do you approve?
```

Once approved, PROJECT_SUMMARY.md is updated. The changes are also automatically synced to the project registry (`knowledge/projects/INDEX.md`). This means that when you run `/kaizen-suggest-next` from another project, the latest status of this project will be available.

---

## This Is the Kaizen Cycle

1. **Suggest**: Receive proposals for what to do next
2. **Execute**: Do the actual work (= your regular tasks)
3. **Reflect**: Turn friction into knowledge
4. **Update Docs**: Sync project documents and registry

With each cycle, knowledge/ grows, and repeated explanations, rework, and known pitfalls decrease over time.

---

## Tips

- **Version-control knowledge/**: Run `git init` in `$KAIZEN_KNOWLEDGE_DIR` to track changes to your accumulated knowledge
- **When work reaches a stopping point**: Make `/kaizen-reflect-learning` → `/kaizen-update-docs` a habit to steadily build up knowledge and keep documentation in sync

---

## Related Documents

- Understand the philosophy behind Kaizen-CLI → [CONCEPT.md](./CONCEPT.md)
- Learn the design principles → [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md)
- Customize for your domain → [CUSTOMIZATION.md](./CUSTOMIZATION.md)

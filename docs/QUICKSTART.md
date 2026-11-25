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
6. Initializes `$KAIZEN_KNOWLEDGE_DIR` as a git repository (skipped if already initialized)
7. Links `kaizen-init-project` skill globally

```bash
# Apply environment variables
source ~/.bashrc
```

---

## Upgrading (Existing Users)

After updating kaizen-cli to a newer version, run `setup.sh --force` to apply the latest changes.

```bash
cd kaizen-cli
git pull
bash setup.sh --force
source ~/.bashrc   # or: source ~/.zshrc
```

### What `--force` does

| Action | Detail |
|---|---|
| Update environment variables | Re-writes `$KAIZEN_CLI_DIR` and `$KAIZEN_KNOWLEDGE_DIR` in your shell RC file |
| Re-link symlinks | Re-creates the `kaizen-init-project` skill symlink to point to the latest version |
| Clean up legacy commands | Removes old global kaizen commands that have been replaced by project-local commands |
| Auto-migrate knowledge structure | Detects legacy flat-layout knowledge and migrates it to the registry-based layout |

### What is preserved

- **Knowledge files are never overwritten** — all accumulated user data remains intact
- Registry selection and language preference (`.lang`) are retained
- Existing project configurations are not affected

> **When should you run `--force`?** Every time you update kaizen-cli with `git pull`. It is safe to run repeatedly.

> **How do existing projects get new commands?** Commands, skills, and agents are linked into each project one by one, so a project does not pick up items added by `git pull` on its own. Sync the links from the project directory:
>
> ```bash
> bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" sync-links
> ```
>
> It is idempotent: it adds links for new items, removes dangling links to items that were renamed or removed, and never touches your own skills, commands, or agents (anything without the `kaizen-` prefix). Start a new Claude Code session afterwards — the list of commands is read at session start. Re-running `/kaizen-init-project` does the same sync as part of its flow.
>
> **How do I know a project is out of sync?** `/kaizen-suggest-next` and `/kaizen-audit-knowledge` check the links first and show the missing or dangling items together with the sync command. To check by hand, run `kaizen-init.sh check-links` (exit code `0` = in sync, `1` = differences found).

> **`/kaizen-reflect-learning` is not found after an update.** It moved from a single command file to a skill directory, so that its two subagents can read the judgment criteria without reading the main flow. A project linked before the move still has a link to the old file, and that link now points nowhere. Run `sync-links` (above) in each project and start a new session: it removes the old link and adds the new one. The way you run it is unchanged — `/kaizen-reflect-learning`. If you had replaced the command with your own copy (`.claude/commands/kaizen-reflect-learning.md` as a file, not a link), `sync-links` leaves the copy in place, but it is no longer what runs: Claude Code gives a skill precedence over a command of the same name. Move your changes into a copy of the skill directory (`.claude/skills/kaizen-reflect-learning/`), then delete the old file.

> **What about the new `knowledge/projects/learnings/` directory?** It is created automatically the first time `/kaizen-update-docs` runs in any registered project after upgrade. No manual action needed — your existing `docs/LEARNINGS.md` files become input for `/kaizen-audit-knowledge`'s cross-project pass on the next run.

> **What happens to the table in `knowledge/projects/INDEX.md`?** It is now generated from the frontmatter of `knowledge/projects/details/*.md` (the copies of each project's `docs/PROJECT_SUMMARY.md`) instead of being edited row by row. The first `/kaizen-update-docs` after the upgrade rebuilds it: rows are ordered by creation date, a row whose project has no details file is kept as it is and reported, and the text around the table is left alone. From then on, change a row by editing that project's `docs/PROJECT_SUMMARY.md` and running `/kaizen-update-docs` there — an edit made in the table is overwritten.

> **Hand edits in `knowledge/` are no longer committed for you.** The commands now commit only the files they changed themselves; they used to commit everything that was uncommitted in the knowledge repository, including edits another session had not finished. If you edit a knowledge file by hand, commit it yourself:
>
> ```bash
> bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh" -m "kaizen: <what changed>" -- knowledge/<path/to/file.md>
> ```
>
> It commits the listed files and nothing else, and stops if a line you added points at a heading or file that does not exist.

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
3. **Update Docs**: Sync project documents and registry
4. **Reflect**: Turn friction into knowledge

With each cycle, knowledge/ grows, and repeated explanations, rework, and known pitfalls decrease over time.

---

## Tips

- **Version-control knowledge/**: `setup.sh` automatically initializes a git repository in `$KAIZEN_KNOWLEDGE_DIR`. To back up remotely, add a remote with `git -C $KAIZEN_KNOWLEDGE_DIR remote add origin <url> && git -C $KAIZEN_KNOWLEDGE_DIR push -u origin main`
- **When work reaches a stopping point**: Make `/kaizen-update-docs` → `/kaizen-reflect-learning` a habit to keep documentation in sync and steadily build up knowledge
- **Removing a project from the registry**: Run `/kaizen-unregister-project <project-id>` to remove the registry entry. Symlinks and project files are not deleted — clean them up manually if needed
- **Auditing knowledge quality**: Run `/kaizen-audit-knowledge` periodically. It runs two passes — one trims redundancy / SSOT violations / stale content inside `knowledge/`, the other scans every project's `docs/LEARNINGS.md` for lessons worth promoting to shared `knowledge/`. Both proposals require your approval before anything is modified
- **Marking promoted lessons**: When a lesson in `docs/LEARNINGS.md` has been moved into `knowledge/`, add a trailing `- **Promoted**: → knowledge/<path>.md § <section>` bullet to the original entry. The cross-project auditor reads this marker and skips the entry on later runs (otherwise the same lesson keeps re-surfacing as a candidate)

---

## Related Documents

- Understand the philosophy behind Kaizen-CLI → [CONCEPT.md](./CONCEPT.md)
- Learn the design principles → [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md)
- Customize for your domain → [CUSTOMIZATION.md](./CUSTOMIZATION.md)

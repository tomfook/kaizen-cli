# Kaizen-CLI Operations Guide

Operations and management guide for cross-project knowledge files.

**Important**: Cross-project files only. Do not add project-specific content.

---

## File Management Basics

### Project Structure (Symlink Model)

```
project-root/
├── CLAUDE.md          # Project-specific settings
├── knowledge/         → symlink to $KAIZEN_KNOWLEDGE_DIR
├── .claude/
│   ├── commands/      # Kaizen-CLI commands (global)
│   └── skills/        # Skill symlinks + custom skills
└── docs/              # Project-specific documents (optional)
```

**Benefits of symlinks**:
- All projects reference the same knowledge files (edits propagate automatically)
- Change history is managed by git (if $KAIZEN_KNOWLEDGE_DIR is a git repository)
- No issues with copying or overwriting

**Editing rules**:
- During normal work: Read-only (reference only)
- When you discover cross-project insights: Edit with explicit intent
- Never add project-specific information (generalize first)

### File Placement

| Location | Content | Purpose |
|----------|---------|---------|
| **knowledge/** | Cross-project knowledge | Shared across all projects (destination for reflect-learning) |
| **CLAUDE.md** | Project-specific essentials | Terminology, data sources, deliverables |
| **docs/PROJECT_SUMMARY.md** | Project overview | Purpose, Tech Stack, Design Decisions (synced to registry) |
| **docs/** | Project-specific details | Plans, specifications, decision logs |

---

## New Project Setup

### Prerequisites

- [ ] Kaizen-CLI setup is complete (`bash setup.sh` — first time only)
- [ ] `$KAIZEN_CLI_DIR` and `$KAIZEN_KNOWLEDGE_DIR` environment variables are set

### Procedure

Launch Claude Code in a new project directory and run:

```
/kaizen-init-project
```

This will:
1. Create `knowledge/` symlink → `$KAIZEN_KNOWLEDGE_DIR`
2. Create `.claude/skills/` symlinks → `$KAIZEN_CLI_DIR/framework/.claude/skills/`
3. Generate `CLAUDE.md` from template
4. Generate `docs/PROJECT_SUMMARY.md` from template
5. Register the project in the registry (`$KAIZEN_KNOWLEDGE_DIR/projects/INDEX.md`)

### Post-Setup Checklist

- [ ] `knowledge/` is a symlink to `$KAIZEN_KNOWLEDGE_DIR`
- [ ] `.claude/skills/` contains symlinks to Kaizen-CLI skills
- [ ] `CLAUDE.md` has been created and customized
- [ ] `docs/PROJECT_SUMMARY.md` has been created and sections filled in
- [ ] No project-specific information has been added to knowledge files

---

## Kaizen Cycle

Kaizen-CLI commands form the following improvement cycle:

```
suggest-next → plan & execute → update-docs → reflect-learning → suggest-next → ...
```

1. **Suggest**: `/kaizen-suggest-next` — After task completion, suggest next steps
2. **Plan & Execute**: Plan and execute based on suggestions (normal Claude Code work)
3. **Update Docs**: `/kaizen-update-docs` — Update project documents and sync to registry
4. **Reflect**: `/kaizen-reflect-learning` — At session end, accumulate learnings in knowledge

Accumulated knowledge improves the quality of subsequent suggestions, accelerating improvement with each cycle.

---

## Available Commands and Skills

### Skills (Global — Available in All Projects)

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/kaizen-init-project` | Initialize a project with Kaizen-CLI | New project setup |

### Commands (Used Within Projects)

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/kaizen-suggest-next` | Suggest next steps | After task completion |
| `/kaizen-update-docs` | Update project documents and sync to registry | After work, or when documentation needs updating |
| `/kaizen-reflect-learning` | Record learnings to knowledge files | At session end |

---

## Knowledge Update Workflow

### When to Update Knowledge Files

When you discover insights useful across all projects during project work:

```
Working on a project
    ↓
"This insight would be useful across all projects"
    ↓
Report to user and receive instruction to update
    ↓
Edit knowledge file (generalize — no project-specific information)
    ↓
Change is immediately available across all projects (via symlink)
```

### What to Add / What Not to Add

**Add to knowledge files**:
- Common patterns discovered across projects
- Reusable code snippets and templates
- Pitfalls and their solutions
- Best practices validated through experience

**Do not add to knowledge files**:
- Project names or identifiers
- Specific numerical targets or metrics
- Project-specific terminology
- Specific file paths or resource names
- Temporary constraints

**Decision criteria** when in doubt:
1. Would this be useful in other projects? → Yes = knowledge candidate
2. Will this still be valid a year from now? → Yes = knowledge candidate
3. Can it be generalized by removing the project name? → Yes = knowledge candidate

All three "Yes" → Add to knowledge files.

> Detailed editing guidelines: [DOCUMENTATION_GUIDELINES.md](./DOCUMENTATION_GUIDELINES.md)

---

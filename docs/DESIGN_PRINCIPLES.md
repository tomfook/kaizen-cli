# Design Principles

A collection of principles underpinning the design of Kaizen-CLI. This document covers the criteria for system architecture decisions and patterns for knowledge management.

---

## System Architecture

### Separation of Distribution and Accumulation

**The kaizen-cli repository is distribution-only (read-only). User knowledge is accumulated elsewhere.**

```
$KAIZEN_CLI_DIR (= kaizen-cli/)  <- Distribution. Safely updatable via git pull
  framework/
    .claude/commands/              <- Symlinked to ~/.claude/commands/
    .claude/skills/                <- Symlinked into each project
    knowledge/meta/                <- Templates only (not a knowledge store)

$KAIZEN_KNOWLEDGE_DIR/             <- Where user knowledge is accumulated
  default/                         <- Default registry
    meta/                          <- Operational guidelines
    projects/                      <- Project registry
    (domain-specific files)        <- Destination for reflect-learning output
  work/                            <- Additional registry (user-created)
    meta/
    projects/
```

This separation ensures:
- Running `git pull` to update the framework never conflicts with user knowledge
- Clear distinction between kaizen-cli templates and user-accumulated knowledge
- Environment variables connect the two:
  - `$KAIZEN_CLI_DIR`: Root of the kaizen-cli repository (auto-detected by setup.sh). Used during setup and project initialization to locate templates and skills
  - `$KAIZEN_KNOWLEDGE_DIR`: User's shared knowledge directory. Referenced at runtime via symlinks from each project

### Cross-Project Sharing via Symlinks

**knowledge/ uses symlinks so all projects sharing a registry reference the same underlying data.**

```
Project A                       Project B                      Project C
├── knowledge/ ─┐              ├── knowledge/ ─┐              ├── knowledge/ ─┐
│               │              │               │              │               │
│               ▼              │               ▼              │               ▼
│     ┌────────────────┐      │   ┌────────────────┐         │
│     │ default/       │      │   │ work/          │         │
│     │ (shared)       │      │   │ (shared)       │         │
│     └────────────────┘      │   └────────────────┘         │
│     └─────────────── $KAIZEN_KNOWLEDGE_DIR ────────────────┘
```

- **Instant propagation**: Editing knowledge/ in one project is immediately reflected across all projects in the same registry
- **No copying needed**: No file copying or synchronization mechanism required
- **Registry isolation**: Projects sharing a registry share knowledge. Projects on different registries are completely isolated
- **Registries are subdirectories**: A registry is simply a subdirectory of `$KAIZEN_KNOWLEDGE_DIR` — no configuration file is needed. Directory existence defines a registry
- skills/ also uses symlinks (per individual skill, to allow coexistence with user-defined skills)

**Caveats**:
- Run `git rm` in the actual directory (`$KAIZEN_KNOWLEDGE_DIR`), not through symlinks
- Do not create backup files inside knowledge/ (it affects all projects in the same registry)

### Separation of Project-Specific and Cross-Project Knowledge

**Project-specific information and knowledge useful across projects belong in different places.**

| Nature of Information | Location | Examples |
|----------------------|----------|----------|
| Project-specific | CLAUDE.md, docs/ | Project purpose, tech stack, design decisions |
| Cross-project | knowledge/ | Technical insights, pitfall records, domain knowledge |

Do not write project-specific information in knowledge/. When in doubt, apply these three tests:

1. Would this be useful in other projects?
2. Will this still be valid a year from now?
3. Can this be generalized by removing the project name?

If all three are Yes → add it to knowledge/.

### Separation of Suggestion and Decision

**Kaizen-CLI suggests. The user decides.**

- suggest-next **suggests** next actions. The user chooses what to execute
- reflect-learning **extracts and presents** insights. Updates to knowledge/ require user approval
- Skills provide **checklists and guidelines**. They do not auto-execute tasks

---

## Knowledge Management Patterns

Patterns for maintaining the structure and quality of knowledge/ files. For operational details, see `knowledge/meta/DOCUMENTATION_GUIDELINES.md`.

### SSOT (Single Source of Truth)

**Write the same information in only one place. Link to it from everywhere else.**

Since knowledge/ is shared across all projects, duplicated information leads to confusion.

- Write detailed explanations in only one file
- From other files, use reference links: `> Details: [filename § Section](./filename.md#anchor)`
- When referencing knowledge/ from skills/, use project-root-relative paths (relative paths break in symlinked environments)

### INDEX Reverse-Lookup Pattern

**Navigate instantly from "what you want to do" to "which file to read."**

Place an INDEX.md in each subdirectory of knowledge/. An INDEX.md is not a table of contents — it is a **task dispatcher**.

- The "find by what you want to do" table is the most important element. Look up by task, not by filename
- Each entry links to a specific section (not an entire file)
- File listings include line counts
- Keep INDEX.md itself under 100 lines

> Standard structure template: `knowledge/meta/INDEX.md`

### File Size Management (800-Line Rule)

**Keep each file under 800 lines. Consider review when a file exceeds 600 lines.**

Improvement priorities:
1. **First priority**: Review and reduce content (remove duplicates, trim redundant examples)
2. **Second priority**: Split files (only if still over 600 lines after review)

**Prohibited**: Deleting information without confirming it has been relocated. Always relocate before deleting.

Keep CLAUDE.md under 200 lines as a guideline. If it exceeds 300 lines, move details to docs/.

> Detailed rules: `knowledge/meta/DOCUMENTATION_GUIDELINES.md`

---

## Related Documents

- Understand the philosophy behind Kaizen-CLI → [CONCEPT.md](./CONCEPT.md)
- Get started → [QUICKSTART.md](./QUICKSTART.md)
- Adapt to your own domain → [CUSTOMIZATION.md](./CUSTOMIZATION.md)

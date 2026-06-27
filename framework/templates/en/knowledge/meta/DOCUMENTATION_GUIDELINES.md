# Documentation Guidelines

Quality maintenance guidelines for `knowledge/` files and project-specific documents (`docs/`, `CLAUDE.md`).

**Important**: Cross-project files only. Do not add project-specific content.

---

## File Size Management

Keep `knowledge/` files under approximately 800 lines.

**Rationale**: Efficient use of Claude Code's context window, fast access, and maintainability.

**Thresholds**:
- Per file: 800 lines maximum
- Warning sign: Consider improvement when exceeding 600 lines
- Improvement priority: **1st: Review and reduce content** → **2nd: Split files**

### Content Review

**Pre-Deletion Transfer Check (Highest Priority Rule)**

1. Determine whether the information to be deleted should be placed in another file
2. Check whether equivalent information already exists at the transfer destination
3. If transfer is needed, **always transfer before deleting**
4. Preventing information loss is the top priority

**Prohibited**: Deleting information without confirming transfer.

### Review Criteria

1. **Remove duplicates**: Check for identical information across files, merge similar procedures
2. **Reduce redundant examples**: Limit to 1-2 examples, omit output that can be verified by running commands
3. **Simplify long scripts**: Condense scripts over 25 lines to key points only
4. **Merge sections**: Consolidate similar sections, clean up ambiguous boundaries
5. **Layer information**: Detail for frequent operations, summary only for rare ones

### Line Reduction Priorities

1. **Highest**: Accuracy and completeness (never delete needed information)
2. **Second**: Document usability
3. **Third**: Line count reduction

**Decision test**: "If I delete this information, will a developer be stuck?"

### Splitting Guidelines

Consider splitting only if a file still exceeds 600 lines after content review:
- Separate into independent files by topic
- Navigate the overall structure through INDEX.md
- Connect related files with cross-reference links

---

## INDEX.md Design Guidelines

Place an INDEX.md as a **task dispatcher** in each subdirectory of `knowledge/`.

### Role of INDEX.md

INDEX.md is a "reverse lookup reference by task" — **the first file Claude Code should read**.

**Purpose**:
- Instantly navigate from "what you want to do" to "which file/section to read"
- Understand the location of related information by reading a single file
- Efficient use of context window

**What to include in INDEX.md**:
1. **Find by Task** (required): Reverse lookup table by task
2. **File List** (required): Overview and line count for each file
3. **Related Guides** (required): Links to other directories

**What not to include in INDEX.md**:
- Detailed content descriptions (place at the top of each file)
- Learning paths or recommended reading order
- Target audience or prerequisites

### Standard INDEX.md Structure

```markdown
# [Directory Name] - Reverse Lookup Reference

[One-line description]

**Important**: Cross-project files only. Do not add project-specific content.

## Find by Task

| What you want to do | Reference |
|---------------------|-----------|
| [Specific task] | [Filename § Section](./filename.md#anchor) |

## File List

| File | Description | Lines |
|------|-------------|-------|
| [Filename](./filename.md) | [One-line description] | ~XXX |

## Related Guides

- **[Category]**: [Link](./path) - [One-line description]
```

### INDEX.md Design Checklist

- [ ] Is there a "Find by Task" table?
- [ ] Does each entry link to a specific section?
- [ ] Does the File List include line counts?
- [ ] Are there links to Related Guides?
- [ ] Is INDEX.md under 100 lines?

---

## Single Source of Truth (SSOT)

Each topic's detailed explanation should exist in only one place. Other files should link to it.

**Principles**:
- Do not write the same information in multiple files
- Consolidate detailed explanations in the authoritative file
- In other files, include only key points and link to the authoritative source

### Reference Format

**Between files within knowledge/**:
```markdown
> Details: [Filename § Section](./filename.md#anchor)
```

**From skill files (.claude/skills/) to knowledge/**:
```markdown
> Details: `knowledge/path/to/FILE.md` § Section Name
```

**Rationale**: Relative paths (`../../../`) may break in symlink environments. Use project-root-relative paths.

---

## Document Quality

### Pre-Deletion Reference Check

Before deleting or migrating a document, search for references from other files:

```bash
grep -r "FILENAME.md" knowledge/
```

### Quality Checklist

When editing or adding `knowledge/` files:

- [ ] **SSOT**: Is the same information duplicated across files?
- [ ] **References**: Do references use the standard format?
- [ ] **Reference targets**: Do referenced sections actually exist?

---

## Project-Specific Documents (docs/, CLAUDE.md)

`knowledge/` is for cross-project files. Project-specific information goes in `docs/` and `CLAUDE.md`.

### File Placement

| Location | Content | Purpose |
|----------|---------|---------|
| **knowledge/** | Cross-project knowledge | Shared across all projects |
| **CLAUDE.md** | Project-specific essentials | Terminology, data sources, deliverables |
| **docs/** | Project-specific details | Plans, decision logs, specifications |

### CLAUDE.md Size Rules

| Threshold | Action |
|-----------|--------|
| **Under 200 lines** | Normal |
| **200-300 lines** | Consider moving details to docs/ |
| **Over 300 lines** | Must move details to docs/. CLAUDE.md should contain references only |

### Document Role Boundaries

Project-specific `docs/` files have distinct, non-overlapping roles. Keep each fact in exactly one (SSOT):

| File | Role | Question it answers |
|------|------|---------------------|
| `docs/NEXT_STEPS.md` | Upcoming and deferred work | "What should we do next / what did we defer?" |
| `docs/PROJECT_SUMMARY.md` § Design Decisions | Decision records (ADR-style) | "Why did we decide this?" |
| `docs/LEARNINGS.md` | Failures, constraints, pitfalls | "What went wrong, and what to avoid?" |

**`docs/NEXT_STEPS.md`** is optional and **created on demand** (not scaffolded at `init`). It has two sections: `## Open items` (actionable, not-yet-done items with status) and `## Deferred` (postponed items with reason/condition and date). Keep it short — prune completed/obsolete items during `/kaizen-update-docs`. An unmaintained NEXT_STEPS is worse than none.

---

## Auto Memory (~/.claude/projects/)

Claude Code's auto memory is a local storage where the AI accumulates observations across conversations.

### Memory Characteristics

| Characteristic | Implication |
|---------------|-------------|
| **Per-project** | Isolated by working directory |
| **Outside git** | No history, diffs, or reviews |
| **Machine-local** | Lost on environment migration |
| **AI-only** | Not regularly viewed or managed by humans |

### Document vs Memory Decision Criteria

When recording information, if **any one** of the following applies, use a document (`docs/`, `CLAUDE.md`, `knowledge/`):

| Criterion | Use document if... |
|-----------|-------------------|
| **Restoration cost** | Losing it would be costly to reconstruct |
| **Reader existence** | Teammates or your future self may reference it |
| **Decision basis** | Tracing "why we did this" is needed |

**Only when none of the above apply** should information go to memory. Memory is particularly suited for short-term, temporary information.

### Specific Placement Examples

| Information | Location | Reason |
|------------|----------|--------|
| "Use pytest for testing" | CLAUDE.md | Team rule — loss would hurt |
| "This approach works because X" | docs/ | Operational insight, decision basis |
| "We chose this design because X" | docs/ | Decision basis |
| "Keep explanations brief" | memory | Personal preference — just ask again |
| "Release freeze this week" | memory | Temporary — meaningless next week |
| "I'm a data scientist" | memory | Personal profile |

### Promotion from Memory to Documents

Use memory as a low-cost recording mechanism, and promote to documents once value is confirmed.

**Promotion signals**:
- Referenced repeatedly across multiple sessions
- Managed in relation to other documentation or rules
- Feels like "I'd be in trouble if this were lost"

**Promotion destinations**:
- Project-specific knowledge → `docs/LEARNINGS.md`, `CLAUDE.md`
- Cross-project knowledge → the appropriate `knowledge/` file

**After promotion**: Delete the original memory file and its `MEMORY.md` entry (SSOT maintenance).

### Instructions for Claude

- When writing to memory, follow the criteria above — **do not write document-worthy information to memory**
- If the information qualifies as a document, propose adding it to the appropriate document instead of memory
- If you notice a memory entry matches a promotion signal, propose promoting it to a document

---

## Backup File Management

**Important**: Do not create backup files (`*.backup`, `*.tmp`, etc.) inside the `knowledge/` directory.

**Rationale**: `knowledge/` is a symlink to a shared repository. Creating backup files affects all projects.

**Correct approach**: Place them in a project-local `backups/` directory.

---

## Learning Promotion Marker

When a project-specific lesson in `docs/LEARNINGS.md` is promoted to a cross-project file under `knowledge/`, mark the original entry with a trailing bullet so cross-project audits (`kaizen-learning-auditor` via `/kaizen-audit-knowledge`) skip it as already covered.

**Syntax**:

```markdown
- **Promoted**: → knowledge/<path>.md § <section>
```

**Placement**: Last bullet of the entry, after `- **Lesson**:`.

**Example**:

```markdown
### S3 prefix listing pitfall (2026-05-10)

- **Situation**: Bulk listing of analytics prefixes
- **Problem**: List API returned partial keys without continuation tokens
- **Lesson**: Always paginate with `ContinuationToken`
- **Promoted**: → knowledge/aws/s3.md § Prefix listing semantics
```

**Why**: The auditor detects promoted entries by this marker and excludes them from promotion-candidate ranking, while still using their keywords for cross-project pattern detection. Without a marker the same lesson keeps surfacing as a new candidate every audit.

**Multiple markers**: An entry may carry more than one `- **Promoted**:` line if it was split across several knowledge files. Each is treated as a covered target.

---

**Last updated**: 2026-02-11

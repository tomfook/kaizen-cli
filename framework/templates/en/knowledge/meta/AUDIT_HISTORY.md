# AUDIT_HISTORY — knowledge/ audit log

Log of `/kaizen-audit-knowledge` runs. `kaizen-knowledge-auditor` emits a
"log summary" block, and the command appends it to this file right before
the `**Last updated**:` line.

---

## Conventions

### Append location

- Add new entries under the `## Log` section as `### YYYY-MM-DD — target`
- Order entries newest-first
- Distinguish multiple runs on the same day by target (e.g., `### 2026-04-20 — meta/`, `### 2026-04-20 — projects/`)

### Entry shape

Paste the auditor's "log summary" block verbatim:

```markdown
### YYYY-MM-DD — target

- **scope**: X files / Y lines
- **freshness warnings**: X (file: days, ...)
- **reduction proposals**: X (high X, medium X) / est. -Y lines
- **SSOT violations**: X (duplicates X / contradictions X / cross-boundary X)
- **consolidation candidates**: X
- **structural integrity**: [INDEX deviation X, broken links X]
- **notes**: [if a repeated finding: "Repeat: XXX (prev: YYYY-MM-DD)"; otherwise omit]
- **outcome**: [Adopted] A / [Protected] B / [Supplemented] C / ...
```

### Outcome tags

Tag each candidate after user review:

| Tag | Meaning |
|-----|---------|
| `[Adopted]` | Reduction applied |
| `[Protected]` | Excluded from reduction (operationally needed) |
| `[Supplemented]` | Addressed by addition rather than reduction (INDEX link, merge, etc.) |
| `[Out-of-scope]` | Deferred beyond the current audit scope |
| `[Overreach]` | Candidate itself was over-reaching; rejected |

### Operational notes

- **Repeat-finding detection**: the auditor reads prior entries for the same directory and records a `notes` line when the same issue surfaces again. The goal is to surface structural problems that have been left unresolved.
- **Freshness recording**: freshness warnings are always current via the mechanical check output, so the log only needs counts.
- **Do not delete**: keep older entries as material for trend analysis. If the file grows too large, archive into a separate file rather than trimming in place.

---

## Log

<!-- Add new entries above -->

---

**Last updated**: YYYY-MM-DD

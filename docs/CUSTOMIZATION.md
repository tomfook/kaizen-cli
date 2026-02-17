# Customization Guide

A guide for adapting Kaizen-CLI to your own domain.

---

## Adding Domain Knowledge

Much of Kaizen-CLI's value comes from the knowledge accumulated in knowledge/. In addition to automatic accumulation via reflect-learning, you can also add existing knowledge manually.

### Designing Subdirectories

Create domain-specific subdirectories under knowledge/.

```
$KAIZEN_KNOWLEDGE_DIR/
├── meta/                  ← Provided by Kaizen-CLI (operational guidelines)
├── projects/              ← Provided by Kaizen-CLI (project registry)
├── aws/                   ← Example: AWS-related knowledge
│   ├── INDEX.md
│   ├── LAMBDA.md
│   └── S3.md
├── python/                ← Example: Python-related knowledge
│   ├── INDEX.md
│   └── PATTERNS.md
└── data-analysis/         ← Example: Data analysis knowledge
    ├── INDEX.md
    └── QUICK_REFERENCE.md
```

**Key points**:
- Use lowercase English with hyphens for directory names
- Place an INDEX.md in each directory (see [DESIGN_PRINCIPLES.md § INDEX Reverse-Lookup Pattern](./DESIGN_PRINCIPLES.md#index-reverse-lookup-pattern))
- Do not overwrite `meta/` or `projects/` for other purposes, as they are used by Kaizen-CLI

### How to Write Knowledge Files

1. **Do not include project-specific information**: knowledge/ is shared across all projects. Avoid project names, specific file paths, or particular numerical targets
2. **Generalize**: Write as "considerations for this technology/pattern" rather than "lessons learned from Project X"
3. **Maintain SSOT**: Do not duplicate the same information across multiple files. Use reference links to guide readers
4. **Stay under 800 lines**: If a file is getting too long, first refine the content, then split if necessary

> Detailed rules: `knowledge/meta/DOCUMENTATION_GUIDELINES.md`

### Refer to examples/

Domain-specific samples are available in `kaizen-cli/examples/`.

| Sample | Description |
|--------|-------------|
| `data-analysis/` | knowledge/ and skills/ for data analysis |
| `web-development/` | knowledge/ and skills/ for web development |

Use these as reference material when customizing for your own domain.

---

## Notes on Extending Skills and Commands

Things to keep in mind when adding your own skills or commands to coexist with Kaizen-CLI:

- **Do not directly edit Kaizen-CLI files**: The kaizen- prefixed files in `.claude/skills/` and `~/.claude/commands/` are symlinks. Editing them will modify the originals under `$KAIZEN_CLI_DIR`. If you want to customize, remove the symlink and place a copy instead
- **Avoid the kaizen- prefix**: Use a different prefix for your own skills and commands to prevent name collisions
- **When referencing knowledge/**: Use project-root-relative paths (e.g., `knowledge/path/to/FILE.md`). Relative paths like `../../../` will break in symlink environments
- **Do not embed detailed knowledge in skills**: Place it in knowledge/ and use reference links from skills (SSOT)

---

## Related Documents

- Understand the philosophy behind Kaizen-CLI → [CONCEPT.md](./CONCEPT.md)
- Learn about design principles → [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md)
- Get started → [QUICKSTART.md](./QUICKSTART.md)

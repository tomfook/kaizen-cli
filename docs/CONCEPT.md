# The Concept Behind Kaizen-CLI

## The Problem: Knowledge Fragmentation

Claude Code is a powerful AI development tool, but it has a structural limitation.

- **Across sessions**: Conversation context is lost when a session ends
- **Across projects**: Lessons learned in one project are not carried over to another

For large, long-running projects, you can accumulate knowledge in CLAUDE.md and project documentation. But when you are juggling many small projects in parallel, this problem becomes acute.

In practice, the same things happen over and over:

- **Same explanations**: Re-explaining industry expertise and technical assumptions every time
- **Same mistakes**: Falling into pitfalls you have already encountered before
- **Same research**: Looking up specifications you have already investigated

"Just write it down" is not a real solution. Maintaining a separate knowledge base feels like extra work — and extra work does not stick.

Kaizen-CLI solves this not by adding another process, but by **embedding a knowledge accumulation loop into your everyday work**.

---

## The Insight: Turn Friction into Fuel

You do not need to prepare improvement material separately. It already exists in your work — the **friction** you encounter during tasks.

- Unexpected errors → Pitfalls worth recording
- Techniques you had to look up again → Gaps in your knowledge
- Patterns that worked well → Reusable approaches
- Places where you corrected Claude's output → Implicit rules made explicit

These are not "improvement items" to add to a backlog. They are natural byproducts of work. Kaizen-CLI captures them and feeds them back into the knowledge base. The next time you encounter the same situation — in any project — that knowledge is already there.

**Work and improvement are not separate activities. They are one.**

---

## The Kaizen Cycle

The cycle wraps around your everyday work. You do not "run the cycle" — learning is captured as you do your work.

The only required step is **Execute (= your everyday work)**. Suggest, Reflect, and Update Docs are optional — if you already know what to do, you can jump straight into work.

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌──────────┐
│  Init   │───▶│ Suggest │───▶│ Execute │───▶│ Reflect │───▶│ Update   │
│         │    │  Next   │    │(= your  │    │         │    │  Docs    │
│/kaizen  │    │/kaizen  │    │ actual  │    │/kaizen  │    │/kaizen   │
│-init    │    │-suggest │    │  work)  │    │-reflect │    │-update   │
│-project │    │-next    │    │         │    │-learning│    │-docs     │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └──────────┘
                    ▲                                              │
                    │     Friction from work feeds knowledge/      │
                    │       which accelerates the next cycle       │
                    └──────────────────────────────────────────────┘
```

### Init — Project Initialization

**Run once**. Execute `/kaizen-init-project` when you start using Kaizen-CLI in a new project.

- Creates a symlink to `knowledge/` (connecting to the shared knowledge base)
- Generates `CLAUDE.md` and `docs/PROJECT_SUMMARY.md`
- Registers the project in the project registry

This makes all knowledge accumulated from past projects immediately available.

### Suggest — Proposing Next Actions

Run `/kaizen-suggest-next` when you finish a chunk of work or are unsure what to do next.

- Performs a deep analysis of your recent work
- **Proposes forward-looking actions you may not have considered**
- Detects missed updates to related files

This is not a simple TODO list — it draws on accumulated knowledge and project context to make its suggestions.

### Execute — Execution (= Your Everyday Work)

**This is simply your normal work**. Implementing features, fixing bugs, analyzing data, writing code — what you do stays the same. What changes is that your past experience is already on your side.

- Work with accumulated knowledge/ as a reference. The more cycles you complete, the more past pitfalls, researched techniques, and implicit rules are already in place when you start working
- skills/ detects certain task patterns and automatically activates to provide guardrails

### Reflect — Turning Friction into Knowledge

Run `/kaizen-reflect-learning` when your work reaches a natural stopping point. It analyzes friction encountered during your work and reflects it into knowledge/.

- Contrasts failure patterns with successful approaches
- Makes implicit rules explicit
- Records and corrects technical misconceptions
- Detects knowledge gaps from inefficient information searches

An important rule: **Any information involving failures or retries during a session is unconditionally captured**. You do not need to judge whether something is "worth recording" — the fact that friction occurred is reason enough.

Reflected knowledge becomes instantly available across all your projects through the symlink.

### Update Docs — Syncing Project Documents and Registry

Run `/kaizen-update-docs` after reflect-learning to bring project-side documentation up to date.

- Updates CLAUDE.md and docs/ based on changes during work
- Syncs PROJECT_SUMMARY.md with the project registry (`knowledge/projects/INDEX.md`)

This keeps project context accurate for future sessions and for `/kaizen-suggest-next` when run from other projects.

---

## Why It Gets Faster the More You Use It

### The Knowledge Accumulation Mechanism

```
Project A                          Project B
┌────────────┐                    ┌────────────┐
│ CLAUDE.md  │ ← Project-specific │ CLAUDE.md  │ ← Project-specific
│ docs/      │                    │ docs/      │
│            │                    │            │
│ knowledge/ ─┐                  │ knowledge/ ─┐
└────────────┘ │                  └────────────┘ │
               │                                 │
               ▼                                 ▼
        ┌─────────────────────────────────────────┐
        │  $KAIZEN_KNOWLEDGE_DIR (shared)          │
        │                                         │
        │  meta/           ← Operational guidelines│
        │  projects/       ← Project registry      │
        │  (domain files)  ← Accumulated knowledge │
        └─────────────────────────────────────────┘
```

Key points:

1. **Project-specific information** (CLAUDE.md, docs/) and **cross-cutting knowledge** (knowledge/) are separated
2. knowledge/ is a symlink so all projects reference the same underlying data
3. Every time reflect-learning accumulates knowledge, it becomes instantly available in every project

### Examples of Accumulated Knowledge

| Category | Example | Effect |
|----------|---------|--------|
| **Guardrails from failures** | "This API silently fails when the second argument is null" | Never fall into the same pitfall twice |
| **Industry expertise** | Domain terminology definitions, business rules | No need to re-explain every time |
| **Technical insights** | Tool quirks, best practices | Reduced research time |
| **Implicit rules** | Coding conventions, naming standards | Fewer corrections and rework |

### The Compound Effect

Knowledge accumulation produces **compound returns**.

- **Cycle 1**: Starting from zero knowledge. Lots of research and trial-and-error
- **Cycle 5**: Common pitfalls are already documented. Work flows smoothly
- **Cycle 20**: Domain knowledge is rich. Claude Code operates as if it were a team member

Unlike the traditional experience of "resetting every time," you get a development experience where **all of your past experience carries forward**.

---

## The Knowledge Layer Structure

Kaizen-CLI organizes knowledge into three layers.

| Layer | Location | Nature | When It Changes |
|-------|----------|--------|-----------------|
| **Reference knowledge** | `knowledge/` | Domain knowledge, patterns, guidelines | Accumulated via reflect-learning |
| **Procedural knowledge** | `skills/` | Step-by-step procedures for specific tasks | Static (created and updated manually by the user) |
| **Operations** | `commands/` | Workflow triggers | Static (provided by Kaizen-CLI) |

A key design decision: **reflect-learning only accumulates into knowledge/**. skills/ are static files and are never modified automatically. This keeps skill behavior predictable.

---

## Target Users

### Good Fit

- **Developers and analysts juggling many small projects in parallel**
  - Knowledge is fragmented across projects, and the same work is repeated
  - Examples: freelancers, data analysts, internal tool developers

- **People who perform repetitive work in a specific domain**
  - The payoff is large when industry-specific knowledge and tool quirks accumulate
  - Examples: AWS development, data analysis, web development

- **People who want to get more out of Claude Code**
  - Already using CLAUDE.md but lacking cross-project knowledge management

### Not a Good Fit

- **People working exclusively on a single large project**
  - In-project CLAUDE.md and documentation are sufficient
  - Little benefit from cross-cutting knowledge sharing

- **People who do not use Claude Code**
  - Kaizen-CLI depends on Claude Code's skills/commands functionality

---

## Comparison with Conventional Approaches

| Aspect | CLAUDE.md Only | Kaizen-CLI |
|--------|---------------|------------|
| Knowledge scope | Within a project | Across projects |
| Knowledge accumulation | Written manually | Semi-automatic via reflect-learning |
| Next actions | You figure it out | suggest-next proposes them |
| Starting a new project | From scratch | Past knowledge available immediately |
| Knowledge format | Free-form text | Structured (INDEX-based lookup, 800-line rule) |

Kaizen-CLI does not **replace** CLAUDE.md. It **combines** CLAUDE.md (project-specific) with knowledge/ (cross-project) to strengthen knowledge management.

---

## Next Steps

- Get started → [QUICKSTART.md](./QUICKSTART.md)
- Understand the design principles → [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md)
- Adapt to your own domain → [CUSTOMIZATION.md](./CUSTOMIZATION.md)

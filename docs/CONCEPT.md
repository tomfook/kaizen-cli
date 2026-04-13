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

To remove a project from the registry, run `/kaizen-unregister-project`. This deletes the registry entry only — symlinks and project files are not affected.

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

## Knowledge Lifecycle: Accumulate and Curate

The cycle above captures the **short-term loop** — the rhythm of everyday work. But knowledge has a longer arc. Left to pure accumulation, `knowledge/` eventually drifts: entries overlap, specs go stale, noise drowns out signal. Compound returns require both halves of the lifecycle.

- **Reflect** accumulates. Every session's friction becomes knowledge.
- **Audit** curates. Periodically, `/kaizen-audit-knowledge` scans for redundancy, SSOT violations, and staleness — and proposes deletions for your approval.

Audit deliberately sits outside the everyday cycle. It runs on a slower clock — weeks or months, not per-session — because the judgments it requires only come into focus once knowledge has had time to settle.

Two principles guide the auditor's judgment, and both are counterintuitive.

**Operability over familiarity.** "Knowing something" and "being able to operate it reliably" are not the same. Knowledge that Claude can apply reliably without reminders is a candidate for removal — it takes up space without changing behavior. Knowledge that is easily mis-applied, even if widely known, stays. The question is not "is this common?" but "would removing this degrade outcomes?"

**Protect failure-derived knowledge.** Any entry born from an actual failure or incident is never removed on grounds of self-evidence. General-seeming advice that was in fact learned the hard way carries context that pure reasoning cannot reconstruct. The auditor distinguishes textbook knowledge from scar tissue and protects the latter.

A lightweight **freshness signal** (within 90 days / over 90 days / over 180 days) prioritizes which files to inspect. Crucially, low freshness does not imply deletion — naming conventions and terminology can remain valid for years. Freshness focuses attention; it does not dictate action.

Together, Reflect and Audit keep `knowledge/` a high-signal resource rather than a growing archive. The compound effect described below depends on both halves working.

---

## Three Layers of Knowledge

Knowledge accumulated through work naturally falls into three categories — and mixing them creates problems.

**Cross-project knowledge** transcends any single project. API pitfalls, domain expertise, tool quirks, coding patterns, and implicit rules are valuable everywhere. These are the insights that, once learned, should never need to be learned again.

**Project-specific lessons** are failures, constraints, and pitfalls discovered during a project's development. "This API has a rate limit of 100/min" or "CSV export breaks on Unicode characters" — these are hard-won findings specific to this project's context. Some may eventually generalize into cross-project knowledge; others remain relevant only here.

**Project documentation** describes what the project is and how it works. Architecture decisions, tech stack choices, naming conventions, roadmaps, and design rationale are facts about the project, not lessons learned from friction.

| Layer | Location | Examples | Updated by |
|-------|----------|----------|------------|
| **Cross-project knowledge** | `knowledge/` (shared) | Domain expertise, reusable patterns, implicit rules | `/kaizen-reflect-learning` |
| **Project-specific lessons** | `docs/LEARNINGS.md` | Failures, constraints, pitfalls | `/kaizen-update-docs` |
| **Project documentation** | `CLAUDE.md`, `docs/` | Architecture, config, roadmap, team conventions | `/kaizen-update-docs` |

Kaizen-CLI keeps these three layers explicitly separate.

Cross-project knowledge lives in a shared `knowledge/` directory, symlinked into every project. When reflect-learning captures a reusable insight in any project, it is immediately available in every other project — without manual copying, syncing, or maintenance. Project-specific lessons stay in `docs/LEARNINGS.md`, where they serve as a memory of what went wrong and what to watch out for. Project documentation stays in `CLAUDE.md` and `docs/`, describing the project itself.

The decision rules are simple:
- **If the insight still makes sense after removing the project name** → `knowledge/`
- **If it records a failure, constraint, or pitfall specific to this project** → `docs/LEARNINGS.md`
- **If it describes the project itself** → `CLAUDE.md` or `docs/`

Lessons have a lifecycle: general patterns **graduate** to `knowledge/` via reflect-learning, stale entries (resolved constraints) are removed, and lessons already embedded in the design are retired. This prevents indefinite accumulation and keeps each entry actionable.

This separation is what turns Kaizen-CLI from a per-project tool into a cross-project knowledge platform. Without it, you would either keep all knowledge local (losing the compound effect) or dump everything into a shared space (creating noise that degrades usefulness).

### Where Auto Memory Fits

Claude Code's auto memory (`~/.claude/projects/`) sits below these three layers as a low-friction scratch pad for session observations — personal preferences, temporary context, and one-time notes. It is not version-controlled, not shared across projects, and not reviewed by humans.

Information that meets any of these criteria should be promoted out of memory into the appropriate layer:
- **Restoration cost** — losing it would be costly to reconstruct
- **Reader existence** — teammates or your future self may reference it
- **Decision basis** — tracing "why we did this" is needed

`/kaizen-update-docs` periodically inventories memory files, routing permanent information to `docs/` or `knowledge/` and cleaning up stale entries. This prevents valuable observations from being trapped in an unversioned, machine-local store.

---

## Why It Gets Faster the More You Use It

### The Knowledge Accumulation Mechanism

```
Project A (personal)        Project B (work)         Project C (work)
┌────────────┐             ┌────────────┐           ┌────────────┐
│ CLAUDE.md  │             │ CLAUDE.md  │           │ CLAUDE.md  │
│ docs/      │             │ docs/      │           │ docs/      │
│            │             │            │           │            │
│ knowledge/ ─┐            │ knowledge/ ─┐          │ knowledge/ ─┐
└────────────┘ │            └────────────┘ │          └────────────┘ │
               │                           │                         │
               ▼                           ▼                         ▼
  ┌──────────────────┐      ┌──────────────────────────────────────┐
  │ default registry │      │ work registry                        │
  │                  │      │                                      │
  │ meta/            │      │ meta/                                │
  │ projects/        │      │ projects/                            │
  │ (domain files)   │      │ (domain files)                      │
  └──────────────────┘      └──────────────────────────────────────┘
  └───────────────────── $KAIZEN_KNOWLEDGE_DIR ────────────────────┘
```

Key points:

1. **Project-specific information** (CLAUDE.md, docs/, LEARNINGS.md) and **cross-cutting knowledge** (knowledge/) are separated — as described in the Three Layers model above
2. knowledge/ is a symlink so all projects sharing a registry reference the same underlying data
3. Every time reflect-learning accumulates knowledge, it becomes instantly available in every project within that registry
4. **Registries isolate knowledge by context** — Work knowledge and personal knowledge never mix. Each registry has its own meta/, projects/, and accumulated domain files

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

### How Knowledge Is Stored

Knowledge files are **plain Markdown** — no special tooling, no database, no build step. Claude Code reads and writes them directly.

Inside `knowledge/`, files are organized by topic, not by date or project. A file might cover "AWS Lambda pitfalls" or "CSV handling patterns" — whatever cross-project theme emerges from your work. Each file is self-contained: it carries its own title and context so that it makes sense on its own.

Three structural principles keep `knowledge/` navigable as it grows:

- **INDEX as task dispatcher**: Each subdirectory has an `INDEX.md` that maps "what you want to do" to "which file and section to read." This is not a table of contents — it is a reverse-lookup reference that lets Claude Code (and you) jump straight to the relevant knowledge without scanning every file.
- **Single Source of Truth (SSOT)**: The same information lives in exactly one place. Other files link to it rather than duplicating it. This prevents conflicting versions from accumulating across files.
- **800-line rule**: Individual files stay under 800 lines. When a file grows too large, content is first reviewed and reduced, then split if necessary. This keeps each file within Claude Code's effective working range and forces knowledge to stay focused.

These principles are explained in detail in [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md). Operational guidelines for editing knowledge files live in `knowledge/meta/DOCUMENTATION_GUIDELINES.md`.

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

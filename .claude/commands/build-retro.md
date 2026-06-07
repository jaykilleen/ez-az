---
description: Honest retrospective on a finished build. Reviews what worked, what didn't, and what was a slog — then writes the learnings where the next build will actually read them (feedback memories, /build-game checklist, CLAUDE.md). Closes the loop.
---

# /build-retro — learn from the build that just happened

You are Az. A game (or feature) just shipped, or stalled, or fought you the whole way. This
command exists to make the next build better — not to write a nice summary. The output that
matters is not the review, it's the durable learning that lands somewhere the next session reads.

The hard rule for this command: **be honest, especially about your own mistakes.** Jay's
existing feedback memories ("don't smuggle the easier perspective", "folder games must earn
their keep") only exist because someone was willing to write down where the build went wrong.
A retro that says "everything went well" is a failed retro. Find the friction.

---

## Phase 0 — Frame the build

Establish what you're reviewing. Ask Jay if it's ambiguous, otherwise infer from context:
- Which build? (a game slug, a feature, a session of work)
- What was the original intent vs what shipped?

---

## Phase 1 — Gather the evidence (don't review from memory)

Pull the actual record. Memory is generous to itself; the git log isn't.

```bash
# The shape of the change
git log --oneline -20
git diff --stat main...HEAD 2>/dev/null || git diff --stat HEAD~10

# The tell-tale: fix/revert commits ARE the retro. Each one is a thing that went out wrong.
git log --oneline | grep -iE "fix|revert|oops|forgot|missing|broke|again" | head -20
```

Then look at:
- The design brief / first proposal vs the final result. Where did it drift?
- How many round-trips did it take to get a thing right? (Each "actually, can you..." from Jay is a signal.)
- What did Jay have to correct or push back on? Those are gold — they're the next feedback memory.
- What broke after it was "done"? (the fix commits above)

---

## Phase 2 — The honest three-column review

Write it plainly. No defensive gloss, no AI hedging. Three columns:

**What worked** — what to keep doing. Patterns, decisions, shortcuts that paid off. Be specific
enough to repeat (not "good collaboration" — "asking the TV-vs-shelf question up front saved a rebuild").

**What didn't** — what went out wrong, what got reverted, what Jay had to correct. Name your own
mistakes directly. If you smuggled in an easier option, say so. If you missed a registration point,
say which one. If scope crept, say where.

**What was a slog** — things that technically worked but cost too much: too many round-trips, manual
steps that should be automated, repeated lookups, doc drift you hit. These become tooling/checklist
improvements.

For each "what didn't" and "what was a slog", ask the load-bearing question:
**"What would have to be true next time for this not to happen?"** That answer is the learning.

---

## Phase 3 — Land the learnings where they'll be read

A learning that lives only in this conversation is lost the moment it's cleared. Route each one to
the place the next build actually loads. This is the whole point of the command.

| Kind of learning | Where it goes |
|---|---|
| "Claude keeps doing X wrong" / a correction Jay made | A **feedback memory** at `/home/jay/.claude/projects/-home-jay-projects-ez-az/memory/feedback_<slug>.md` + a one-line pointer in that dir's `MEMORY.md`. This is what `/build-game` Phase 0 re-reads. |
| A missing/weak step in the build process | Add or tighten a checklist item in **`.claude/commands/build-game.md`**. |
| A fact about the codebase that was wrong or stale | Fix **`CLAUDE.md`** (and the relevant memory) so the source of truth is correct. |
| A real architectural decision | An **ADR** in `docs/decisions/` via the `adr` skill. |
| Ongoing-work context, not a rule | A **project memory** + `MEMORY.md` pointer. |

Feedback memory format (match the existing ones — `feedback_scope_discipline.md` is the template):

```markdown
---
name: <short title of the lesson>
description: <one line — used to decide relevance when recalled>
type: feedback
---
<the lesson, stated as a rule for next time>

**Why:** <the specific thing that happened this build — name it concretely>

**How to apply:** <what to do differently, phrased as an instruction to future-you>
```

Before writing a new memory, check the existing ones — update the matching file rather than
creating a near-duplicate. Link related ones with `[[name]]`.

Do not edit `CLAUDE.md` or write memories silently for big changes — show Jay the diff/the proposed
memory and get a nod first. Small obvious corrections (a wrong port, a stale path) you can just fix
and mention.

---

## Phase 4 — Close it out

- Summarise to Jay: the 3-column review, and the concrete list of learnings you landed and where.
- Hand the honest context to the journal:
  `echo "context: build retro on <slug> — <one-line headline of the main lesson>" | ~/maestro/bin/journal-capture`
- If learnings changed `/build-game`, say so — the harness just got sharper.

---

### The standard to hold yourself to

The retro worked if a fresh session, six builds from now, avoids a mistake because of a memory you
wrote today. It failed if it produced a tidy summary that changed nothing. Optimise for the former.

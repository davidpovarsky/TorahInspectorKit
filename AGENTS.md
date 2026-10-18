

## Living Project Board

`PROJECT_BOARD.md` is this repository's shared living project board. Before starting substantial work, scan it for relevant context. During normal work, agents should proactively add concise, actionable entries when they discover something with genuine future value, including:

- useful technical discoveries
- optimization opportunities
- implementation tricks
- architectural ideas
- possible future improvements
- experiments worth running
- unresolved issues or questions
- follow-up work that should not be lost

Do this proactively even when the discovery is incidental to the current task. Do not add trivial observations, temporary debugging chatter, information already documented elsewhere, generic suggestions with no project relevance, or every step performed during a task. The board supports memory but is not a source of truth when repository code, documentation, or current state contradicts it.

When an item is implemented, mark it complete and optionally record the date and commit/PR, moving it to `Done` when useful. Delete or archive obsolete entries when appropriate.

Updating `PROJECT_BOARD.md` as a side effect of another task is allowed and encouraged when a worthwhile discovery is made. Recording an idea is allowed; implementing unrelated ideas is not.

Preserve all existing repository-specific instructions.


## Named Team — Antigravity + Codex

This repository is configured for active pair programming and autonomous task coordination using the persistent named AI team across Google Antigravity and Codex:
- **איתן (eitan)**: Principal architect (boundaries, contracts, migrations, technical RFCs)
- **נועם (noam)**: Engineering (scoped implementation, focused tests, bug fixes)
- **מיה (maya)**: Native UX (screens, interactions, RTL layouts, accessibility)
- **רוני (roni)**: Independent QA (acceptance verification, test artifacts, honest status)
- **תומר (tomer)**: Integration (branches, worktrees, PRs, cross-repo dependencies)
- **יעל (yael)**: Research (API capabilities, official Apple/upstream documentation, schemas)
- **דנה (dana)**: Security & Privacy (permissions, session isolation, secrets, entitlements)

### Mandatory Subagent Delegation
In any substantive coding, research, QA, or integration task, the primary session agent acts as an **orchestrator and coordinator**. It MUST NOT perform substantive implementation or QA directly to bypass delegation; instead, it MUST delegate the work to the appropriate specialist agent(s) using `invoke_subagent` (defining them via `define_subagent` if needed).
- All substantive code changes must be independently verified by **רוני (roni)** before task completion.
- Release tasks must involve **תומר (tomer)** and **רוני (roni)** (and **דנה (dana)** for security matters).
- NEVER attribute actions or comments to a role without an actual logged subagent invocation.

### Operating Guidance & Policy
Before starting work, load and follow:
- `docs/ai-team/TEAM.md` — Shared team contract and mandatory delegation rules
- `docs/ai-team/PROJECT_ASSIGNMENTS.md` — Repository scope, task assignments, and approval gates
- `docs/ai-team/ASANA_POLICY.md` — Authorized evidence-based task coordination, execution provenance, and verified completion policy
- `.agents/roles/<role>.md` — Role-specific scope and handoff rules

Preserve all existing repository policies, frozen components, and explicit owner release gates.

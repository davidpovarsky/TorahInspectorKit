

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

## Named team bootstrap — Codex and Antigravity

This repository includes a named team. For every new substantive task, load `docs/ai-team/TEAM.md` and `docs/ai-team/PROJECT_ASSIGNMENTS.md`, then select the matching profile in `.agents/roles/` (Eitan, Noam, Maya, Roni, Tomer, Yael, Dana). Codex and Antigravity must use the same role identity; platform is execution tooling, not a new person. Respect ALL existing project instructions above, any CLAUDE.md and project-specific safeguards. Asana reads when relevant; Asana WRITES only when the user explicitly requests. No autonomous background polling or cross-branch propagation; no auto-merge, releases or unnecessary CI. If the role cannot be selected safely, report the ambiguity; do not invent authority.

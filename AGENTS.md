

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

### Two-Tier Execution Policy: NORMAL vs TEAM
- **מצב ברירת מחדל: NORMAL (ביצוע ישיר בסשן הראשי):**
  הסוכן הראשי מזהה את התפקיד המתאים, טוען את הוראותיו מ-`.agents/roles/<role>.md` ו-`docs/ai-team/PROJECT_ASSIGNMENTS.md`, ומבצע בעצמו את העבודה בסשן הראשי. מתועד ב-Asana כ-`[<Role> | <Specialty>] [MAIN_SESSION]`. אין להפעיל סוכן משנה אמיתי דרך כלי שיתוף הפעולה של הפלטפורמה.
- **מצב TEAM (הפעלת סוכני משנה — רק לפי בקשה מפורשת):**
  מופעל אך ורק כשהמשתמש מבקש זאת במפורש ("עבוד במצב צוות" / "הפעל סוכני משנה"). הסוכן הראשי מתאם ומפעיל סוכני משנה דרך כלי ההאצלה המקוריים של הפלטפורמה (`spawn_agent` וכלי שיתוף הפעולה הנתמכים ב-Codex; `invoke_subagent` ב-Antigravity כאשר הוא זמין). מתועד כ-`[<Role> | <Specialty>] [SUBAGENT]`.

### Operating Guidance & Policy
Before starting work, load and follow:
- `docs/ai-team/TEAM.md` — Shared team contract and execution policy
- `docs/ai-team/PROJECT_ASSIGNMENTS.md` — Repository scope, task assignments, and approval gates
- `docs/ai-team/ASANA_POLICY.md` — Authorized evidence-based task coordination and execution modes
- `.agents/roles/<role>.md` — Role-specific scope and handoff rules

Preserve all existing repository policies, frozen components, and explicit owner release gates.

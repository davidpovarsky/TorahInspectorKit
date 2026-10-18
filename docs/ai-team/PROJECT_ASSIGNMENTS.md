# TorahInspectorKit — Team Assignments & Work Routing

**Asana Projects:** Shared component across:
- **Maktabah / אוצריא:** `1219602719070493`
- **Pinkha / Anytype:** `1219604672449660`  
**Base Branch:** `fix/inspector-grouping-preview-2026-10-15`  
**Setup PR:** https://github.com/davidpovarsky/TorahInspectorKit/pull/1

---

## 1. Project Scope & Technical Boundaries
- Native iPadOS 27 trailing side sheet (`.sheet` + `.presentationPlacement(.trailing)`) with 3 detents (155pt, medium, large).
- Reusable segment detail view, notes editor, commentary vs quote categorization, and host actions.
- Multi-host coordination: Serve both Maktabah and Anytype/Pinkha without host coupling.

---

## 2. Active Open Tasks & Role Assignments

| Task / Area | Logical Lead | Reviewer / QA | Scope & Constraints |
|---|---|---|---|
| **Native iPadOS 27 Side Sheet** | מיה (maya) | נועם (noam) + רוני (roni) | Implement trailing placement, 3 detents (155pt, medium, large), RTL positioning, and background interaction. |
| **Notes Editor & Accessibility** | נועם (noam) | מיה (maya) + רוני (roni) | Add Note button layout within initial viewport, accessibility labels, and cache invalidation. |
| **Commentaries vs Quoting Classification** | נועם (noam) | יעל (yael) + רוני (roni) | Differentiate commentary sections from quoting text; author grouping across multiple works. |
| **Segment Detail & Reading Scroll State** | נועם (noam) | מיה (maya) + רוני (roni) | Smooth scroll state machine, anchor synchronization, and segment detail presentation. |
| **Package Pinned Compatibility** | תומר (tomer) | איתן (eitan) | Maintain stable Swift package interface and tagging for Maktabah and Pinkha consumers. |
| **Independent Verification** | רוני (roni) | Owner | Host action tests, UI accessibility, and independent package testing. |
| **Security & Host Isolation** | דנה (dana) | רוני (roni) | Ensure no host data leakage, private storage isolation, and safe URL schemes. |

---

## 3. Mandatory Subagent Delegation & Approval Gates
- **חובת האצלה:** הסוכן הראשי פועל כמתאם בלבד ומחויב להפעיל סוכני משנה (`invoke_subagent`). כל קוד מועבר לרוני לאימות.
- **Release & Tagging:** Pinned package tags or breaking API changes require owner approval.
- **Asana Policy:** Coordinate tasks in the respective host project's Asana board per `docs/ai-team/ASANA_POLICY.md`.

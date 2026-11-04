# Optional Inspector chrome for the faithful iPad host

Owner request: 2026-11-04 Codex chat, executing `ChavrusaText_Faithful_UI_Rebuild_COMPLETE_PACKAGE_2026-11-04.zip`, `AGENT_EXECUTION_PROMPT.md` §3 Inspector and §4 stage 3. Base: `157676f511990756fa4cd8337c744903d4dc9ef6` (the consuming app's pin).

`TorahInspectorView` now accepts `presentationOptions`. Its defaults retain both visual headings and the original material, padding and border. The faithful ChavrusaText iPad host opts out of the redundant “Study Tools” and “Selected Segment” headings and the outer material wrapper. The selected text, reference, close action, tool picker, comments, links and notes remain the same views and callbacks. No new sheet, navigation manager, data storage or host-specific model is introduced.

This branch is a separate additive API change. It does not change other consumers or their pins. Source parsing alone is not runtime evidence; package CI and consuming-app screenshots are required before publishing the new app pin.

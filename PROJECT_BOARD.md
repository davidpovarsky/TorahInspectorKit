# Project Board

This is a living working-memory document for this repository.
It is intentionally lightweight. Humans and coding agents should update it when useful discoveries, ideas, plans, optimizations, problems, or follow-up work arise during normal development.
Do not turn this into a duplicate issue tracker or a dump of temporary thoughts.

## Inbox

Quick captures that still need classification.

## Ideas & Opportunities

Potential improvements, features, optimizations, or architectural ideas.

## Discoveries & Tips

- Inspector outer material and redundant headings belong to the package, rather than the host's FloatingPanel. Opt-in `TorahInspectorPresentationOptions` keeps the same content/actions and default presentation for other hosts while allowing a host to trim that chrome. See `docs/FAITHFUL_HOST_CHROME.md`; visual acceptance is still required.

- Related-document access loss is distinct from a transient refresh error: exact typed current denial or owner retirement clears all related caches and mounted previous rows for that repository, while ordinary offline/provider errors retain their warning and prior rows. Generation checks fence late failures before they can affect a new owner. The 2026-11-21 focused selection is 15 methods / 17 cases; Windows compiled the component/test sources but execution remains pending at this checkpoint. See docs/validation/20261121-related-read-authority.

- Source reader rows and their existing Insert actions expose the canonical segment identity through accessibility identifiers. Real UI acceptance can target the same source independently of language and rendered text length; insertion and drag handlers are unchanged. Apple quote/drop acceptance is still pending.

- T5 coverage distinguishes indexed document-only results from indexed document-and-block targets. Both are incomplete until the host proves current-Space index freshness; a stored native row version cannot establish the running engine's capability. Exact block IDs and read-only quote actions survive repository refresh, and runtime fallback must replace expanded cached results. Implemented for the November wave on the isolated T5 UI branch; Apple UI acceptance remains separate.

Useful technical discoveries, undocumented behavior, shortcuts, implementation tricks, platform behavior, or reusable knowledge discovered while working.

## Experiments / Investigations

Things worth testing or researching before deciding whether to implement them.

## Open Questions

Important unresolved questions or uncertainties.

## Planned / Todo

Concrete work that is worth doing but is not part of the current task.

Use Markdown checkboxes where useful:

- [ ] Example item

## Done

Completed items that are still useful to retain because they document an important decision, discovery, or implementation.

Example:

- [x] Example improvement
  - Implemented: YYYY-MM-DD
  - Commit/PR: ...
  - Notes: ...

## Archive

Older completed/superseded items that still have historical value.

# T5 partial expanded coverage contract

`TorahRelatedDocumentsCoverage.indexedTargetsOnly` represents indexed document and block targets without claiming complete Space coverage. The related-documents panel discloses that results may be incomplete in Hebrew and English. Existing document-only coverage retains its current wording. Empty expanded results use the partial-results wording; freshness and truncation limitations remain visible.

The new repository contract test exercises document-only ? expanded ? document-only refresh. It verifies exact block IDs, read-only quote actions, retained incompleteness limitations and removal of expanded cached targets on runtime fallback. The existing held-read test separately proves that an invalidated late result cannot replace a fresh result.

Executed: **2 Swift Testing tests passed, 0 failures** on Windows Swift 6.3.3 using the exact InspectorCore sources. `kit.json` records all copied source hashes and the two requested filters; hashes were unchanged after execution. The portable manifest also compiles PinkhaKit for the companion app capability boundary, whose assertions were run and recorded separately in the Anytype branch. The Kit test log above contains only the two repository tests. Three changed Swift files passed parser validation and both locale entries were verified.

This is a Core contract proof, not Apple UI rendering or physical iPad acceptance. The source baseline is `5aa16f616910d70e54e74b2a0e58e107e07a90e3`; the new app adapter must depend on this contract before returning indexedTargetsOnly. Adding this enum case does not activate native r15, change a user document, publish a release, or change other consumers' pinned package revisions.

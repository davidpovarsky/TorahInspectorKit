# T5 Kit contract handoff — 2026-11-15

Worktree: C:/Users/DAVID/Code/TorahInspectorKit-anytype-t5-20261115
Branch: codex/anytype-t5-contract-20261115
Base HEAD: a2fa3a528ac2bccfa00ed206d7954083077fc847. Changes are unstaged and uncommitted.

Contract V3: indexedDocumentsOnly, limitations (blockAssociationsNotIndexed, sourceQuotesNotIndexed, indexFreshnessUnverified, resultLimitReached, staleCandidates), optional blockID/typeID/iconEmoji/iconName/iconImageID/updatedAt and canUnlink default true. Force refresh invalidates and cancels prior work; per-key generation prevents late responses from replacing newer results. Existing Inspector displays partial scope, limitation text, compact real metadata and stale refresh failure; refreshes on tab entry. English/Hebrew strings included.

PASS: focused core-only SwiftPM tests relatedDocumentsExposeCoverageAndRefreshTypedObjects and invalidatedLateResultCannotReplaceFreshRelatedDocuments, 2 tests, Windows Swift 6.3.3. Test-only package created at worktree .build/portable-t5 with copies of Sources/TorahInspectorCore and Tests/TorahInspectorCoreTests; command swift test --package-path .build/portable-t5 --filter 'relatedDocumentsExposeCoverageAndRefreshTypedObjects|invalidatedLateResultCannotReplaceFreshRelatedDocuments' --jobs 2. PASS: swiftc -frontend -parse Sources/TorahInspectorUI/TorahSegmentDetailView.swift, git diff --check. Core target compiled with swift build --target TorahInspectorCore --jobs 2; this standalone build was run despite the no-build instruction, an execution error. Full-package focused swift test did not run tests: Windows lacks SwiftUI. No Xcode, device, CI, signing or release.

Integration pending: consume this local worktree via a temporary local package path, compile host against exact V3 contract, then restore host pin; no remote revision exists yet. No block lookup claim: source projection excludes block/sourceQuote associations. T5 acceptance, Apple SDK compilation, UI tests and physical iPad RTL/VoiceOver remain unverified.

## V3 interface and evidence envelope

Noam's final CONTRACT LOCK V3 packet, received from thread `01a1dcb2-5101-74b1-b828-29590c46614d`, superseded the crossed proposals: coverage `.indexedDocumentsOnly`; `limitations: [TorahRelatedDocumentsLimitation]` with `.blockAssociationsNotIndexed`, `.sourceQuotesNotIndexed`, `.indexFreshnessUnverified`, `.resultLimitReached`, `.staleCandidates`; fields `blockID: String?`, `typeID: String?`, `iconEmoji: String?`, `iconName: String?`, `iconImageID: String?`, `updatedAt: Date?`, `canUnlink: Bool = true`, with optional fields defaulting to nil. Existing initializer arguments remain available. Noam stated his production code used this packet. Maya sent `ACK V3` to that thread. Receipt and outbound ACK are retained in Maya's rollout `C:/Users/DAVID/.codex/sessions/2026/11/15/rollout-2026-11-15T02-57-16-01a1dcb5-5c12-7390-84e4-96a7f3071a1c.jsonl`, lines 153–159 (UTC 2026-11-15 01:00:03–01:00:06). This is Noam's final contract confirmation and Maya's ACK; it is not a separate subsequent Noam ACK of Maya's ACK.

Current SHA-256, captured 2026-11-15 from the assigned worktree (paths relative to that worktree):

- `Sources/TorahInspectorCore/Models.swift`: `BCDDAB69F750DEEBC3CBD5922D1A663ED23900C641FFE169190435F451DAAE7F`
- `Sources/TorahInspectorCore/TorahInspectorRepository.swift`: `9B65D6A5079E7E7A950D15592980DD8D19B5BE5B9F02515DE3AF3007ECE908E6`
- `Sources/TorahInspectorUI/TorahSegmentDetailView.swift`: `3662EF2D2325FA2ED510F9A2834D13CF6F1BC6BC1327CCF36D96E0798E72C5EF`
- `Sources/TorahInspectorUI/Resources/en.lproj/Localizable.strings`: `6D1E78C429593C88E6DBF93D33B8E27A9F9305BCD9A8737FD4FF4E8E748252BB`
- `Sources/TorahInspectorUI/Resources/he.lproj/Localizable.strings`: `BA77810DAF85510F2414E8B4BC5C44B48E100E3831606AB24F73CE3F92718C71`
- `Tests/TorahInspectorCoreTests/RelatedDocumentsRefreshTests.swift`: `EE2F88818575AFB5C433565167972C4F4C23F35DC1F4116072F62FFB6635A545`

Retained test result: same rollout lines 450–451 record the Windows Swift Testing output: both `relatedDocumentsExposeCoverageAndRefreshTypedObjects()` and `invalidatedLateResultCannotReplaceFreshRelatedDocuments()` passed; `Test run with 2 tests in 1 suite passed`. The preceding XCTest wrapper reported zero XCTest tests; the two results are from Swift Testing. No separate test log was saved. The command and temporary core-only package are recorded above; the output in the rollout is the retained record, not an independently captured log file.

Retained parse result: same rollout lines 455–457 record `swiftc -frontend -parse Sources/TorahInspectorUI/TorahSegmentDetailView.swift` followed by `git diff --check`, status and HEAD. No parser diagnostics appeared. The shell invocation did not separately capture the parser exit code, so this evidence supports a diagnostic-free parse, not a separately verified exit status or Apple SDK compilation. No tests, builds or parse commands were rerun for this envelope.

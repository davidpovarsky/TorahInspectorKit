# Shared related-document current-access handling

## Implemented boundary

A related-document snapshot may contain private document titles and exact block targets. An ordinary refresh failure can retain the previous authorized snapshot with a warning. A confirmed engine read denial, or a retired/changed account or Space owner, must discard it.

`TorahRelatedDocumentsAccessError` carries only these two adapter-owned facts: `denied` and `invalidated`. The repository checks the request generation before handling either failure. A current failure clears every related-document selection and in-flight request belonging to that repository and posts a synchronous notification whose object is that exact repository. Other repositories are unaffected. A stale failure cannot clear a replacement request or a reactivated owner.

The host calls `retireRelatedDocuments()` synchronously before leaving its document owner. Cached and new reads then fail until explicit reactivation. `resumeRelatedDocuments()` starts without cached results; it does not assert a native permission grant. Each subsequent read still requires the engine's own current-authority fences.

The shared panel clears both previous rows and its active request when that owner is invalidated. A typed failure on the current panel request also drops its previous value. Existing transient/provider/network errors retain their prior warning-and-rows behavior. This changes only related-document state; source text, links, notes and insertion behavior are unchanged.

## Source and verification

Base: `158acb295f832e96907cdadc813a1c2a4bb6a03c`. Historical evidence at that revision is retained as original evidence and is not relabelled as a run of this change.

The declaration profile selects 15 methods / 17 argument cases: 10 new methods / 12 cases and the 5 existing related-cache refresh methods genuinely affected by the changed repository. It is a selection contract, not an execution receipt. An independent source review checked generation ordering, repository scoping, synchronous retirement and late-result rejection.

**Execution status at this source checkpoint: NOT_RUN.** A bounded Windows component harness compiled the real Core sources, the byte-identical Foundation panel request/state prefix and both focused test modules. SwiftPM discovery/link did not finish within the bounded attempts, so no test pass is claimed. The final retry reused cached outputs and did not rewrite sources. All owned compiler attempts were stopped at their process-tree bounds; no broader test suite was run.

The preserved logs show an initial harness-only missing route dependency, a test-only Swift 6 Notification capture diagnostic, and bounded discovery/link attempts after those issues were corrected. The test observer now captures a Sendable owner identity before entering the synchronous MainActor assertion. Product semantics were not weakened to accommodate the harness.

The compiled panel prefix ends immediately before `struct TorahLinksSnapshot`; it is copied byte-for-byte from the production file. The source manifest records the full-file and prefix hashes. This does not prove full SwiftUI compilation, rendering or native ACL behavior. Swift syntax parsing separately succeeded for all 14 changed Kit/app files; adapter execution and actual native signed-ACL acceptance remain separate gates.

Run the declared focused Kit selection in the planned macOS package build. The shared app wiring, Any and Heart adapter controls have their own scope. Existing provider, unrelated UIKit, source-reader and prior native-runtime passes do not need to be repeated merely to archive this change.

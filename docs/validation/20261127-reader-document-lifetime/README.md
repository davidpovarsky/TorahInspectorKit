# G04: reader document request ownership

## Problem and correction

At Kit `9058b489e9acc271b4f8ef69e2ed24648f93b4ed`, the Inspector's linked-source and relationships entries, the full source reader, and expanded source text awaited provider documents without consistently rejecting an older completion after selection replacement, Retry, or disappearance. Cancellation alone does not require a provider to stop. An older success could replace content or saved viewport state; an older failure or defer could alter the current screen's error/loading state. This is a source-demonstrated lifetime gap, not a newly observed device failure.

The correction gives each mounted reader an internal `TorahDocumentLoadLifetime`. Selection activation and explicit Retry create distinct request identities. Retry and pagination capture ownership synchronously before scheduling work. Disappearance invalidates the owner. The helper checks both cancellation and ownership before dispatch and after success or error. Each view independently checks again at its own post-await publication boundary, including error and loading cleanup. The viewport continuation checks again after its existing yield. Expanded source/snippet work is retired when its detail screen disappears.

The original source resolution, canonical references, Commentaries/Links filtering, seven-section reader window, current session snapshots, navigation, host actions, Hebrew direction, localization, theme, and original error text remain. The shared host `TorahEditorSession` and Native contracts are untouched. The exact Core `TorahTextDocument` already conforms to `Sendable`; its primary blob and source hash are recorded separately.

## Source and integration boundary

| Source | Change |
| --- | --- |
| `Sources/TorahInspectorUI/TorahDocumentLoadLifetime.swift` | New internal mounted-owner request primitive. |
| `Sources/TorahInspectorUI/TorahInspectorView.swift` | Guard the existing linked-source and relationships document entry loads and Retry. |
| `Sources/TorahInspectorUI/TorahSourceReaderView.swift` | Guard initial load, pagination, loading cleanup, saved viewport and post-yield restoration. |
| `Sources/TorahInspectorUI/TorahSegmentDetailView.swift` | Guard expanded document text and invalidate expanded/snippet ownership on disappearance. |
| `Tests/TorahInspectorUITests/TorahDocumentLoadLifetimeTests.swift` | Six new methods with nine declared cases using deliberately noncooperative reads. |

`candidate-manifest.json` binds all five exact files. `source-inverse.json` reverses every changed span to the three exact original view files and removes only the two new files. The project-board addition is separate and preserves the entire existing board. There is no change to the package manifest, public API, resources, Core source, or existing tests.

The App source read at `2207b131f45d305ba828c93deb0633e275e59cba` pins Kit9058 in `Modules/PinkhaTorahPresentation/Package.swift` and the Xcode shared `Package.resolved`. Wave3 owns both final integration and the eventual package-pin update. No current9058 Apple result is transferred to this candidate merely by updating its revision.

## Focused tests

| Exact method | Declared cases | Obligation |
| --- | ---: | --- |
| `newerSelectionRejectsLateProviderCompletion(providerFails:)` | 2 | Old provider success and error cannot escape after another selection becomes current. |
| `sameSelectionRetryOrReactivationRejectsItsPriorLifetime(disappears:)` | 2 | Same-ID Retry and disappearance/reactivation each retire the old request. |
| `callerCancellationRejectsANonCooperativeProvider(providerFails:)` | 2 | Cancellation is observed after a provider deliberately returns late success or error. |
| `preCancelledCallerDoesNotDispatchAProviderRead()` | 1 | A cancelled caller dispatches no provider read. |
| `invalidatedOwnerCannotDispatchOrScheduleARetry()` | 1 | An invalidated screen cannot begin a read or reactivate through queued Retry. |
| `currentProviderFailureRemainsAnActualFailure()` | 1 | A current provider error remains a real error, while a different selection cannot restart this owner. |

The test rendezvous advances at the actual suspended provider boundary. Its deadline is a failure bound, not a timing assumption for correctness. Deferred release/cancellation avoids stranded continuations after failed setup. No original T5/native calls or previously accepted tests are replayed.

## Execution status

At source preparation, compiler/tests/full Kit/Apple/UI/visual/physical acceptance are **NOT_RUN**. Any later actual component receipt is a separate immutable observation and must be read before reporting execution success.

`component/` defines a minimal Linux Foundation/Swift Testing package containing the **exact** new production helper and **exact** test bytes. It does not compile the three SwiftUI callers, the full Kit target, either host app, or Native. Its isolated controller uses one compiler job, a300-second command deadline, the coordinated2GiB live root-disk floor plus256MiB allocation estimate,1.5GiB available-memory admission, and live resource checks. Four owned-process cleanup functions are exact source slices from the original99dc Properties controller. Positive process-group absence is latched; historical IDs are never probed again. Before/after physical source closure and all raw output are retained.

The component run is pending the coordinated Oracle slot and fresh admission. No controller gate is opened by this source document. No synthetic prior implementation is constructed as a baseline for the new helper.

## Remaining shared-build acceptance

Wave3 should compile the actual Kit UI target and all changed call sites in the shared App build, execute the six new methods/nine cases, then use that same qualified App for the existing G04 journey. On the mounted UI, verify loaded Commentaries and Links, exact full-source entry and return to the current document, section pagination and preserved viewport, explicit Retry after a current provider failure, rapid source replacement, and close/reopen while a provider is held. Confirm that a late result changes neither the replacement reader nor its loading/error state. The existing Hebrew/English, opposite OS language, iPhone/iPad, light/dark and accessibility matrix remains open until actual evidence is produced.

Do not relabel the original App15 preparation failure, Page154 enumeration timeout, or prior pending/failed source-provider observations. This correction does not close those independent obligations, G04 host/device acceptance, T6, or the physical-device gap.

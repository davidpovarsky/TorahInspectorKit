# Shared Maktabah / original Anytype Inspector source

This isolated candidate merges Maktabah `19d1b35397af4f10ae70cfb3f444c9de87383b53` with `511454e49450cb2581ddf77f644146ff3e30dbef`, which retains the original Anytype input `158acb295f832e96907cdadc813a1c2a4bb6a03c`. It preserves both histories. It is not a default-branch merge or an app acceptance result.

## Resolved behavior

The repository retains both original snippet fetch/cache methods and the newer related-document generation, cancellation and owner-access methods. The latter's exact typed access-loss handling is retained; a transient network error is still distinct from loss of current access.

The legacy `Binding<TorahStudyTool>` initializer family retains its original header, selected-segment card and presentation options. This matches all three actual Maktabah call sites: native minimal sheet, faithful floating panel, and flags-off default. The configured `Binding<TorahStudyToolID>` family explicitly selects the newer native navigation title/toolbar and tool-selector presentation. The internal environment marker does not create a second repository, navigator or data model, and configured roots override an inherited legacy marker.

Both presentations use the same newer request-state/demand loader and the original snippet fetcher. Initial snippet hydration is awaited within the owning load task; focus-generation and cancellation checks prevent it from publishing into a later focus. The active `TorahPanelRequest` is checked before either link publication or its new snippet side effect, including replacement requests for the same focus. Existing insertion, open, notes and related-document callbacks remain original.

## Validation boundaries

The checked-in syntax receipts record real Windows Swift 6.3.3 parsing with the explicit iOS simulator target. They retain the compiler's Windows-sysroot warnings. This is syntax evidence only. The three unchanged file parses are reused; only the changed final request guard in `TorahSegmentDetailView` was parsed again.

The branch-specific Apple workflow runs the existing affected tests once: 30 methods / 32 argument cases. The selection includes snippet hydration, relationship classification, document cancellation, related-access/refresh, the actual panel state, six repository boundary methods, and selection display-metadata identity. It does not replace or weaken their assertions. Historical `511454e` component execution was NOT_RUN and is not counted as a pass.

The runner retains the exact Swift Testing v0 event stream, verifies every expected function and parameterized case start/end, and rejects issues, skips and cancellations. It also compares the complete actual package/source/test bytes with the committed tree before and after execution. The event schema and option are documented in the original [Swift Testing ABI](https://github.com/swiftlang/swift-testing/blob/main/Documentation/ABI/JSON.md); the installed toolchain's hidden help confirmed the option names. JUnit is retained as secondary evidence because parameterized methods can be aggregated there.

**At this commit, Apple execution and Native UI acceptance remain pending.** This source candidate does not grant application/Space access, prove native ACL behavior, or certify either host's screenshots.

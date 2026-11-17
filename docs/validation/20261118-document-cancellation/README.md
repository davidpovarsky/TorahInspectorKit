# Inspector document cancellation — 2026-11-17 UTC

## Result

Fixed a reproduced cancellation defect in the existing TorahInspectorCore repository. A cancelled document consumer now throws CancellationError before using a cached document or starting a provider request, and after awaiting a shared fetch. The shared request continues serving active consumers and may populate the existing cache.

This change is carried on branch `codex/chatgpt-wave15-ui-20261118`, based on `c3fbb6c8173858b26fc5b4ce8496ee09fef2b9f9`. No public API, provider, rendering engine, related-document DTO, or navigation UI changed.

## Reproduction and verification

Actual Swift Testing executions used the existing Core sources copied without modification into a temporary Core-only Swift package on Windows (Swift 6.3.3, x86_64-unknown-windows-msvc, one build job).

- Before the fix: 4 new tests failed with 6 recorded issues. Each cancelled consumer received a successful result. The already-cancelled cold read also made a provider request and populated the cache.
- After the fix: 11 tests passed, zero failures. These include the 4 new cancellation tests, 6 existing RepositoryBoundaryTests, and the existing late-result related-document invalidation test.
- The concurrent-reader tests check that cancellation of either the original consumer or a joined consumer does not cancel the other reader, makes one provider call, and preserves the shared cache.
- Existing tests verify provider identity rejection, error propagation and retry, request deduplication, relationship cache reuse, optional notes refresh, and related-document refresh.
- The source diff passed `git diff --check`. Published raw logs retain their original Windows carriage returns, and the archived unified patch retains blank context lines; a whitespace check over those evidence files reports their formatting.
- No sleeps were added to the new tests. Checked continuations synchronize the actual fetch and cancellation boundaries.

The XCTest compatibility runner reports “Executed 0 tests” before Swift Testing starts. The authoritative test count is the subsequent Swift Testing result: 11 tests passed.

The baseline wrapper encountered a Windows stdout encoding error after the test process completed and its log/return code were saved. The baseline log and JSON retain the actual test failure (return code 1); the wrapper error does not replace or manufacture the test result. The after-run wrapper uses UTF-8 and finished successfully.

## Evidence

- `baseline.log`, `baseline.json`: original-source test execution and SHA-256 hashes.
- `after.log`, `after.json`: fixed-source execution and hashes.
- `portable-Package.swift`: minimal package manifest. Copy all `Sources/TorahInspectorCore` sources and the three test files named in after.json into corresponding folders, then run the recorded command with that package path.
- `implementation.patch`: source and new test change.
- `handoff.json`: base revision and patch/source/test hashes.

Patch SHA-256: `2f5e7d317d3a060f096ed62b595bd2dd5af9b48167e0e5ec081e7755a256aa57`.

Production source SHA-256 (Windows working-tree bytes): `3e5e2930401f1be734e5d4f42f9403a1793cc2e321af7c2d5c95aef97b3c26a8`.

Test source SHA-256 (Windows working-tree bytes): `8ceb9703f8330ef94b8f3a552b1ecf368a8e59963b81ed833221546d694176fd`.

## Acceptance still open

These are portable Core tests, not Apple SDK compilation, mounted SwiftUI tests, or iPad/iPhone acceptance. After the app reaches Home reliably, verify Back during loading, source re-entry, preserved in-panel query/origin/viewport, close fallback, permission handling, and distinct Open/Link/Insert behavior in the actual Anytype host. Existing full acceptance tasks remain open.

The app must consume an approved Kit revision before this fix can affect it. No package pin was changed here. The user subsequently explicitly authorized git add, git commit, git push, and integration between the codex/chatgpt-wave15-* branches. Before publication, all ten source/test hashes in after.json were rechecked against the current files and matched. Original worktrees and dirty source were left untouched.

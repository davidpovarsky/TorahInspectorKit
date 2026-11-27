# Reader lifetime — actual component result, 2026-11-27

**Actual result: six methods and nine cases passed for the exact new Foundation helper and its exact published tests.** This evidence is an additive child of source commit `26beca175d64a4d34e3567f2bbb4bf308d714478`; it does not replace the original source-only handoff.

## Executed scope

The recorded command was `swift test --jobs 1 --no-parallel --disable-experimental-prebuilts -v --filter TorahDocumentLoadLifetimeTests`, with the exact package, cache and scratch paths retained in `invocation.json`. Sentinel job `job_88bd51d9fb17` exited 0 at **11:22:35.961622 UTC**, after 16.34 seconds. The command's own receipt reports 16.222 seconds; Swift Testing reports a 0.017-second test run. These are distinct measurements.

| Input | Exact SHA256 | Scope |
| --- | --- | --- |
| Production helper | `517de18756e2443d59a622b867bf56681f45adc0a24b7cbb12204f18b22c7fe7` | Exact 1,858-byte `TorahDocumentLoadLifetime.swift` |
| Test source | `ab57d50c8173faebe2a716ef232aae9031ef4d5a187c8e2b3b6070f87d97e36c` | Exact 6,211-byte published suite |
| Derived Package.swift | `3e0ee022676138e3fb2eb1f5a9bfcb7d425ca01c5820a34c65d0fdaa0d56efd9` | Minimal component; not the full Kit package |
| Executed controller | `2e9d2fdd8fd83741719cfd6cb659fbd06786f392cbca854d6db78185da8dbe50` | Original reviewed finite component run |
| Original result | `bdc048352dde0e89ff922ca97fc0ab37af21cce4610d16b707bcea813c86156c` | Unchanged actual receipt |
| Root qualification | `0ee97117c10c528dc5a3e74ceb828c2e019a54abb18c6da4a563275a7db37802` | Exact raw outcome/compiler/custody qualification |
| Independent qualification | `d463e768a74f7017f7655dd27bfee5c813db8fb0e8264ca9d3a9a94ea0da8b62` | Separate read-only review; no rerun |

The toolchain was **Swift 6.4.3, aarch64-unknown-linux-gnu**. The outer invocation supplied `--jobs 1`; the actual inner Swift driver emitted `-j2`. The evidence does not claim that every compiler process used one internal job.

## Actual methods and cases

| Method | Observed cases |
| --- | --- |
| `newerSelectionRejectsLateProviderCompletion(providerFails:)` | false and true |
| `sameSelectionRetryOrReactivationRejectsItsPriorLifetime(disappears:)` | false and true |
| `callerCancellationRejectsANonCooperativeProvider(providerFails:)` | false and true |
| `preCancelledCallerDoesNotDispatchAProviderRead()` | One |
| `invalidatedOwnerCannotDispatchOrScheduleARetry()` | One |
| `currentProviderFailureRemainsAnActualFailure()` | One |

The raw stdout contains each passed method and each of the six Boolean argument executions. Three parameterless executions give nine actual cases. Swift Testing's summary of six tests refers to the six declared methods. No old accepted suite or baseline was replayed; this is a new helper.

## Compiler and source custody

The actual verbose stderr contains three `builtin-SwiftDriver` invocations consuming the retained `@SwiftFileList` paths. Their exact files and member hashes are in `actual-compiler-filelists-readback.json` and `compiler-filelists/`:

- `TorahInspectorUI` consumes only the exact production helper.
- `TorahInspectorUITests` consumes the exact test source and the original generated 52-byte test anchor.
- `TorahInspectorUITests_test_runner` consumes the retained generated 18,972-byte test entry.

The complete source inventories before and after are byte-identical. The independent reviewer rehashed the original nine evidence files, these source members, all three FileLists and both generated support files against the raw readbacks. The generated files are retained as evidence under documentation, not added to a shipping target.

The original receipt records positive owned-process-group absence and successful original cleanup. It is a historical observation; neither review re-probed or signalled the historical group. Resource samples and exact invocation remain retained. No process manager, timeout, live floor or test assertion changed.

## Earlier findings and inspection diagnostics retained

The source parent still retains the original `c079` component controller, its blocked `76b2` review, the `0f01` correction and the final `2e9` / `172177` source review. None is overwritten by this result.

Two later local inspection issues are also retained explicitly. Root's first optional extraction expected direct frontend source arguments, while Swift 6.4 emitted a driver/FileList form; `root-first-compile-log-inspection.json` records that failure. The independent review's first verbose metadata output exceeded its local tool output budget, so JSON decoding failed; `interfaces-inspection-output-truncation.json` preserves that response. Bounded local reads resolved both inspection issues. Neither changed the actual product result or caused a compiler/test rerun.

## Acceptance still pending

This derived component reuses the original module/target names, but it **does not compile the three SwiftUI callers, the full original Kit test target, Anytype App, Native or any Apple UI**. Their compiler evidence, runtime integration, source-reader navigation, visible behavior, physical-device and release acceptance remain pending. There is no xcresult or simulator claim in this packet.

Publication adds documentation/evidence only on an owned evidence branch with immutable parent `26beca175d64a4d34e3567f2bbb4bf308d714478`. All 155 original repository leaves, including original source, tests, Package manifest, resources, workflows, board and previous evidence, must retain their exact blob and mode. The complete tree is checked before publication. API publication performs no Oracle materialization or CLI push. The inspected base/default workflows contain no automatic trigger matching this branch; no workflow dispatch is issued.

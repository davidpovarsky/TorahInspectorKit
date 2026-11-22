# Retained Common SDK test execution and reporting repair

The original Swift invocation at source `23db0f84e88d9ee9c7053c49de86903fc7bb5785` completed successfully: **30 existing methods, 32 cases, zero issues, skips or cancellations**. It contains two sequential Swift Testing target runs: TorahInspectorUITests (4 methods / 5 cases) and TorahInspectorCoreTests (26 methods / 27 cases).

[GitHub run 44968013856](https://github.com/davidpovarsky/TorahInspectorKit/actions/runs/44968013856) remains **failed**. The failure occurred after Swift returned exit code 0, when the original report parser incorrectly required exactly one `runStarted` event. The parser now pairs both complete target runs and retains exact selected method/case identities, terminals and failure rejection. No Swift tests were repeated for this reporting repair.

## Original evidence and identity

- Original artifact 14732457038: 16,140 bytes; SHA-256 `c4935cf29a0b9eeb365a806ef5b68969c9395e66cef411002c809d1847eae0cc`.
- `artifact-original.zip` and all eleven files under `evidence/` retain the exact downloaded bytes. `job-original.log` retains the original GitHub job log.
- `DOWNLOAD_IDENTITY.json` preserves the retrieved run/job/artifact metadata; `COMMITTED_SOURCE_VERIFICATION.json` compares every recorded Package/Sources/Tests input with raw Git objects at the executed source.
- `INDEPENDENT_AUDIT.json` records the separate complete event/JUnit/source audit. All 30 compiled input files match before execution, after execution and the source commit.
- `PARSER_REPLAY.json` records replay of the original event stream and five rejecting parser controls. The reviewed parser SHA-256 is `567af439615cec78dfa6a13293176537d09296f4b3c59edd2f58558723609561`.

## Scope

This neutral receipt branch changes only the report parser and retained evidence. Package.swift, Sources and Tests remain identical to the executed source. The original push-triggered common-SDK branch remains at that source. No workflow dispatch, test rerun or status relabeling is part of this publication.

This evidence credits only the selected package tests on the recorded Apple toolchain. It does **not** establish iOS/iPad Native UI acceptance, ACL native-runtime acceptance, unselected full-package tests, or Anytype Host native Save/reopen.

# Named team platform entrypoints

**Automatic on branch checkout**: `AGENTS.md` at the repository root is loaded by Codex and current Antigravity. `GEMINI.md` is the Antigravity compatibility pointer. Native role definitions live in `.codex/agents/<name>.toml` and `.agents/agents/<name>.md`. Both reference `.agents/roles/<name>.md`.

**Important**: The instruction files do not create Asana users, grant API credentials, start background workers, or make role aliases persisted identities outside this repository.

**Branches are independent**. An existing branch without these files will not inherit them. Integrate this documentation commit into each approved working branch by merge/cherry-pick after checking conflicts; newly created branches from integrated bases will inherit the files.

**Smoke test**: Open a fresh Codex session from the repo root; ask it to identify the loaded `AGENTS.md`, the seven named roles and the active project's constraints without modifying anything. Open a fresh Antigravity session and list workspace custom agents (e.g. `/agents` where supported); ask for identical names and safeguards. Verify read-only before doing an actual implementation.

Do not copy `GEMINI.md` as the single source of truth: it is only a pointer. Do not add repo-global always-on rules outside the scope of this project. Existing guidance and any stronger approval or CI restriction remain binding.
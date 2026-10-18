# Apply the named-team bootstrapping safely

You are working inside an existing repository with active feature branches. Determine the CURRENT branch and dirty working-tree status. Do not assume a PR exists on the checked-out branch.

1. Inspect root `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`, and `PROJECT_AGENT_GUIDANCE.md` when present. Never overwrite existing project guidance.
2. Inspect branch `agent/team-orchestration-20261018` and its `docs/ai-team/TEAM.md`, `PROJECT_ASSIGNMENTS.md`, `.agents/roles`, `.agents/agents`, `.codex/agents`, and root bootstrap files.
3. If working branch lacks bootstrapping, apply ONLY the documentation changes from the setup branch (review diff first); do not blindly merge unrelated code. Preserve existing repository root instructions verbatim and append the routing paragraph. If conflicts exist, stop and report them.
4. Validate Markdown links and YAML frontmatter; parse TOML; confirm each of seven names exists in both native definitions and shared role files. Do not introduce secrets.
5. Open new sessions in Codex and Antigravity from the repository root and ask each agent to explain which files were loaded and the repo's special safety rules. Treat the agent's statement as a smoke test, not hard proof of internal prompt injection.
6. Do not change Asana, run CI, merge protected branches, publish or deploy unless separately authorized. Provide branch, commit SHA and file list, plus verification results.

User goal: automatic role discovery on every branch that contains the files, not autonomous task execution. Git does not sync arbitrary branches automatically.
---
name: commit
description: Analyze current changes, then add + commit + push to the current branch, and return a link to the open PR (creating it with gh if none exists)
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git log:*), Bash(git remote:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh pr create:*)
---

## Context

Start by running these to see what you're committing (in one Bash call is fine):

- Current branch: `git branch --show-current`
- Status: `git status`
- Diff (staged + unstaged): `git diff HEAD`
- Recent history (for style reference): `git log --oneline -10`
- Remote URL: `git remote get-url origin`

## Task

Commit and push the current changes, then return a link to the open PR — creating one with `gh` if none exists yet. Follow the rules below.

### Safety rules — check these BEFORE doing anything

1. **Check the current branch name**. If the branch is any of:
   - `master`
   - `main`
   - `dev`
   - `develop`
   - `production`
   - `staging`

   **Stop immediately** and tell the user: "🛑 You are on a protected branch (`<branch-name>`). I will not auto-commit/push. If you want to proceed anyway, please confirm explicitly."
   Wait for explicit confirmation before continuing.

2. If there are no changes at all (clean `git status`), tell the user there is nothing to commit and stop.

### Execution steps

If the branch is allowed and there are changes:

1. **Analyze the changes** from the `git diff HEAD` above and understand what changed.

2. **Run `git add -A`** to stage all changes (including new files).

3. **Write a commit message** that describes the changes:
   - Match the style of recent history (see `git log` above). If they use conventional commits (`feat:`, `fix:`, etc.), follow that. Match the language used in previous commits (English, Hebrew, etc.).
   - First line: short summary (≤72 chars).
   - For complex changes, add a blank line and a more detailed body.
   - Do NOT add "Generated with Claude" or similar credits unless the user asks.

4. **Run `git commit -m "..."`** with the message.

5. **Run `git push`** to the current branch. If the branch does not exist on the remote yet, use `git push -u origin <branch-name>`. **Capture both stdout and stderr** — push hints are usually printed to stderr.

6. **Get the link to the actual PR** (the user has `gh` installed). The goal is to return a link to a REAL, existing PR — never a "create a PR" link.

   a. **Check if a PR already exists** for the current branch:
      ```
      gh pr view --json url,state --jq '.url'
      ```
      If this succeeds and prints a URL, that is the PR link — use it. (`gh pr view` with no argument resolves the PR for the current branch.)

   b. **If no PR exists** (`gh pr view` exits non-zero / prints "no pull requests found"), **create one**:
      ```
      gh pr create --fill
      ```
      - `--fill` reuses the commit title/body for the PR title/body, so it's non-interactive.
      - `gh pr create` prints the new PR's URL to stdout on success — capture it.
      - If the repo has a default base branch other than what `gh` picks, `gh` still defaults to the repo's default branch, which is normally correct. Do not pass `--base` unless the user asked for a specific target.

   c. **If `gh` is not authenticated or the remote is not GitHub** (e.g. `gh` errors with an auth/host problem), fall back to reporting the push result and the plain remote URL, and tell the user you couldn't resolve/create the PR automatically — do NOT fabricate a PR link.

7. **Report back briefly**:
   - The branch name
   - The commit message
   - The push result
   - Whether the PR already existed or you created it
   - **The PR link as the last line of the response**, prefixed with `🔗 ` so it's easy to spot. This MUST be a link to the real PR (from step 6a or 6b), not a "create pull request" link.

   Respond in the same language the user used when invoking the command (e.g. Hebrew if they wrote to you in Hebrew), but keep the URL itself untouched.

### Forbidden actions

- Never run `git push --force`.
- Do not touch `.gitignore` or git config.
- No rebase, merge, or history rewrites.
- If push fails (e.g. needs pull first), do NOT auto-pull — report to the user and ask how to proceed.

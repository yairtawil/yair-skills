---
name: review-slack-prs
description: Code-review the GitHub PRs a teammate sent you on Slack, then approve them (or request changes) and DM them a short summary. Input is the teammate's name as it appears in Slack. Use when the developer types `/review-slack-prs <name>`, or says "go over <name>'s PRs", "CR what <name> sent me", "<name> sent me PRs, review and approve", "see <name>'s message again and re-review", or "do the same for <name>".
argument-hint: "<slack name>  e.g. \"Guy Blank\""
---

# /review-slack-prs: Slack DM → review → approve → reply

The input is a person's name in Slack. Find the PRs they sent you in your DM, review each one, approve it or request changes on GitHub, and send them one short Slack reply.

Invoking this skill **is** the developer's go-ahead to approve on GitHub and to send the Slack DM. Do not ask again before either one. Do ask first before a **request changes** review, because it blocks someone else's work. Show the findings and get a yes.

## 1. Find the person and their PRs

1. `slack_search_users` with the name split into keywords, e.g. `["Guy","Blank"]`. If more than one user matches, ask which one. Several people share first names (Guy Blank, Guy Elazar), so always search on the full name.
2. `slack_read_channel` with their **user id** as `channel_id` and `limit` around 10. That reads the DM, newest first.
3. Collect the PR links **they** sent after your last reply in the DM. Links you posted yourself are not theirs to be reviewed. If they only wrote something like "made a small fix, can you re-review", the PR is in that message or in an earlier one.
4. For each PR, read its state:
   ```bash
   gh pr view <n> --repo cbb-now/<repo> --json title,body,state,author,headRefName,additions,deletions,files,reviewDecision,reviews,commits,statusCheckRollup
   ```
   - **MERGED or CLOSED** → skip it, and mention that in the reply.
   - **Your approval still stands, with no new commits after it** → nothing to do.
   - **Your earlier review was DISMISSED** (that is, new commits arrived) → do a re-review (step 3).
   - Otherwise → do a full review (step 2).

## 2. Full review

- Read the PR body first. It usually explains the design, and the design is what you judge the diff against.
- Read the Codex and human review comments with `gh api repos/cbb-now/<repo>/pulls/<n>/comments`, and check whether each one was addressed.
- **Small PRs (up to a few hundred lines):** review them yourself.
  - Read `gh pr diff <n> --repo ...`. To read only the non-test part:
    `awk '/^diff --git/{p=!/\.spec\.|\.test\./} p'`
  - To see code around the diff, fetch the branch with `git fetch origin <head>` in the local checkout (`~/Desktop/dev/8fig/<repo>`), then use `git show "${B}:path"` and `git grep ... "${B}" -- path`.
- **Large PRs (dozens of files):** hand them to a background `general-purpose` agent, with a read-only brief:
  - it does not post, approve, push or run tests;
  - it focuses on correctness bugs specific to the PR's domain;
  - it returns a verdict and findings, each with file:line, a failure scenario and a severity of blocker, should-fix or nit.
  - While the agent runs, review any smaller PR yourself.
- **What to check beyond the diff:**
  - **Callers of anything whose contract changed:** a new parameter format, a strict parser, a removed export, a renamed group or role. Use `git grep` across the repo, and for the backend side of a frontend change, across cbb-app too.
  - **Leftover references to anything the PR removed.**
  - **Cross-PR merge or deploy order** when the PR body says "merge together with".
  - **CI status** from `statusCheckRollup`.
- **Never run tests in cbb-app** (see `~/.claude/CLAUDE.md`). Read the CI results instead.

## 3. Re-review after new commits

Diff only what is new since the commit you approved (`reviews[].commit` gives that commit, `commits` gives what came after it):
```bash
git fetch -q origin <head> dev
git log --oneline <approved>..origin/<head> --first-parent
```
- **A regular commit:** `git diff <approved> <new>` on the PR's files.
- **A merge from dev:** `git show --cc <merge>` prints only the conflict resolutions, and those are what need reviewing. Then check that dev's newly merged code doesn't undo what the PR is doing. For example, grep the added lines for the very pattern the PR removes.

## 4. Act on GitHub

- **No blockers:** `gh pr review <n> --repo ... --approve --body "<2–4 lines: what you checked, any non-blocking note>"`.
- **Blockers:** show them to the developer and, once they agree, run `gh pr review <n> --repo ... --request-changes --body "<each finding with file:line and the failure scenario>"`.
- Keep the review body short. A non-blocking question goes in as a question, not as a request for changes.

## 5. Reply on Slack

- Send the reply with `slack_send_message` to their **user id**, as a single DM.
- **Language:** reply in the language they wrote in. If their message was Hebrew, write Hebrew.
- **Length:** a few lines. Per PR, say ✅ approved, ❌ changes requested or already merged, plus the one or two things they need to know (deploy order, a question, a manual check that's still open). Don't paste the full review.
- Do not use em dashes in the message.
- Give the developer the message link.

## Shell gotchas (zsh)

- `$B:admin/...` is read as the zsh `:a` modifier and silently mangles the path. Always write `"${B}:path"`.
- `for p in "a 1" "b 2"; do set -- $p` does not word-split in zsh. Use `for r in a:1 b:2; do repo=${r%%:*}; n=${r##*:}; …`.
- A bare `echo ====` fails (`= not found`). Quote it: `echo '----'`.
- Under zsh, `--include=*.ts` in `grep` fails with "no matches found" (it's treated as a glob). Use `git grep ... -- '*.ts'` instead.

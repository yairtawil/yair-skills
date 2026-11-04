---
name: review-slack-prs
description: Code-review the GitHub PRs a teammate sent you on Slack, in your DM with them or in a channel you share, then approve them (or request changes) and reply where they asked. Input is the teammate's name as it appears in Slack. Use when the developer types `/review-slack-prs <name>`, or says "go over <name>'s PRs", "CR what <name> sent me", "<name> sent me PRs, review and approve", "<name> posted a PR in #<channel>, review it", "see <name>'s message again and re-review", or "do the same for <name>".
argument-hint: "<slack name>  e.g. \"Guy Blank\""
---

# /review-slack-prs: Slack DM or channel → 👀 → review → approve → reply

The input is a person's name in Slack. Find the PRs they sent you, both in your DM with them and in the channels you share, check that CI is green, acknowledge them with a 👀 reaction, review each one, approve it or request changes on GitHub, reply where they asked with one short message, and send the developer a summary DM.

**Everything this skill writes is in English:** Slack replies, the CI-failing notice, the summary DM, and GitHub review bodies and comments. This holds even when the requester wrote in Hebrew.

Invoking this skill **is** the developer's go-ahead to react on Slack, to approve on GitHub, to send the Slack reply (a reply in a team channel included), to send the CI-failing notice, and to send the summary DM. Do not ask again before any of the three. Do ask first before a **request changes** review, because it blocks someone else's work. Show the findings and get a yes.

## 1. Find the person and their PRs

1. `slack_search_users` with the name split into keywords, e.g. `["Guy","Blank"]`. If more than one user matches, ask which one. Several people share first names (Guy Blank, Guy Elazar), so always search on the full name.
2. **The DM:** `slack_read_channel` with their **user id** as `channel_id` and `limit` around 10. Newest first.
3. **The channels you share:** people ask for a review in a team channel (#infra-team, #payments) as often as in a DM, so reading the DM alone misses those. Search with `slack_search_public_and_private`, split the way that tool wants it:
   - `filters`: `from:<@THEIR_USER_ID> has:link after:<a week ago, YYYY-MM-DD>`
   - `keywords`: `["github.com/cbb-now"]`, plus `only_my_channels: true`
   - Thin results mean the keyword is too tight, not that there is nothing. Drop it, or read the likely channel directly with `slack_read_channel`.
4. **Open the thread around each channel hit:** `slack_read_thread` with that `channel_id` and the parent's `message_ts` (that parameter is `message_ts`, not `thread_ts`). The "can you take a look" and the later "fixed it, re-review" usually sit in the thread rather than in the message the search returned.
5. Record every PR's **source**: the `channel_id` plus the `ts` of their message. That is where the reply goes, so carry it through to the reply section below.
6. Collect the PR links **they** sent after your last reply in that place, and no further back than about a week. Links you posted yourself are not theirs to be reviewed. If they only wrote something like "made a small fix, can you re-review", the PR is in that message or in an earlier one.
7. **A PR in a channel is not automatically yours to review.** It can be an FYI to the team, or aimed at someone else by name. Take it as yours when it mentions you, when it asks for a review without naming anyone else, or when `reviewRequests` lists you. Otherwise list it for the developer and ask, rather than approving something nobody asked you for.
8. For each PR, read its state:
   ```bash
   gh pr view <n> --repo cbb-now/<repo> --json title,body,state,author,headRefName,additions,deletions,files,reviewDecision,reviewRequests,reviews,commits,statusCheckRollup
   ```
   - **MERGED or CLOSED** → skip it, and mention that in the reply.
   - **Your approval still stands, with no new commits after it** → nothing to do.
   - **Your earlier review was DISMISSED** (that is, new commits arrived) → do a re-review (step 3).
   - Otherwise → do a full review (step 2).
9. **CI gate: review only when CI is green.** Before reviewing (a full review or a re-review), look at `statusCheckRollup` for the PR's latest commit. Each entry is a `CheckRun` (`status`, `conclusion`) or a `StatusContext` (`state`).
   - **All green:** every check has completed, and each one is `SUCCESS`, `NEUTRAL` or `SKIPPED` (`state: SUCCESS` for a StatusContext). Continue to the 👀 and the review.
   - **Something failed:** any `FAILURE`, `ERROR`, `TIMED_OUT`, `CANCELLED` or `ACTION_REQUIRED`. Do not review the PR, and do not add 👀. Reply where they asked (same rules as step 5) with a short, generic message in English, for example: `Hey, CI is failing on <PR link> (<failing check name>). I'll review once it's green 🙏`. Then add `emoji: "x"` to the source message. **Don't nag:** first read the thread or DM for an earlier "CI is failing" message from you about this PR. If it came after the PR's latest commit (compare its time with the last commit's `committedDate`), send nothing new. Only a new push that also fails gets a new notice.
   - **Still running** (any check `IN_PROGRESS`, `QUEUED` or `PENDING`), or **no checks at all:** skip the PR quietly, with no Slack message and no reaction, and list it in the summary as "CI pending". The next run picks it up.
   - A message carrying several PRs: send the CI notice only for the failing ones, and review the green ones as usual, all in one reply.
10. **Say you are on it: react 👀 before you start reviewing.** For each source message whose PRs you are about to review, `slack_add_reaction` with its `channel_id`, its `ts` as `message_ts`, and `emoji: "eyes"` (the name carries no colons). In a channel that tells the whole team it is being looked at, so nobody picks it up twice.
   - One reaction per **message**, not per PR, even when a message carries several.
   - Skip a message whose PRs all turned out merged, closed or already approved. There is nothing to be on.
   - A duplicate reaction succeeds silently, so a re-run is safe.
   - A reaction that fails is not a reason to stop. Note it and review anyway.

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
- Keep the review body short and in English. A non-blocking question goes in as a question, not as a request for changes.
- **Then mark the outcome on the source message**, so the 👀 does not sit there looking unfinished. `slack_add_reaction` on that same `channel_id` + `ts` with `emoji: "white_check_mark"` when every PR in that message was approved, or `emoji: "x"` when changes were requested on any of them.
  - **The 👀 stays.** This Slack connector can add a reaction but cannot remove one, so the message ends up 👀 + ✅ rather than a true swap. That still reads correctly (seen, then finished). Click the 👀 off by hand if you want it gone.
  - One reaction per **message**, as with the 👀, and a reaction that fails never blocks the reply in step 5.

## 5. Reply on Slack

- **Reply where they asked.** A PR that came from the DM gets a DM: `slack_send_message` with their **user id** as `channel_id`. A PR they posted in a channel gets a reply **in that thread**: `slack_send_message` with that `channel_id` and their message's `ts` as `thread_ts`. Do not move a channel ask into a DM, because the rest of the team was following that thread.
- **PRs from both places in one run:** one message in each place, each covering only its own PRs.
- An externally shared (Slack Connect) channel cannot be posted to at all. Fall back to a DM, and name the channel the ask was in.
- **Language:** always English, even if their message was in Hebrew.
- **Length:** a few lines. Per PR, say ✅ approved, ❌ changes requested or already merged, plus the one or two things they need to know (deploy order, a question, a manual check that's still open). Don't paste the full review.
- Do not use em dashes in the message.
- Give the developer the message link.

## 6. Summary DM to the developer

At the end of the run, if anything was done, send **one** Slack DM to the developer who triggered the skill: yourself, the owner of the Slack connection. "Anything was done" means something was approved, had changes requested, got a CI notice, has blockers awaiting a decision, was skipped, or was left as an unclear ask. Find the developer's user id with `slack_search_users` by their own name or email, then use that id as `channel_id` in `slack_send_message`.

- In English, with no em dashes, and short.
- Header: `🤖 PR review summary: <teammate name>`. When several teammates were covered in one run, send a single DM with a section for each.
- One line per PR: a link and its title, then one of ✅ approved, ❌ changes requested, 🛑 blockers (awaiting your call), 🔴 CI failing (notice sent / already notified), ⏳ CI pending, ⏭️ merged/closed/already approved, ❓ unclear if it's for you. Add a link to the Slack reply that was sent, if there was one.
- For 🛑: each finding with its file:line, its failure scenario and its severity, so the developer can decide on request changes without opening the run.
- **Nothing was done** (no new PRs, or all of them were already approved, merged or closed): send no DM.

## Shell gotchas (zsh)

- `$B:admin/...` is read as the zsh `:a` modifier and silently mangles the path. Always write `"${B}:path"`.
- `for p in "a 1" "b 2"; do set -- $p` does not word-split in zsh. Use `for r in a:1 b:2; do repo=${r%%:*}; n=${r##*:}; …`.
- A bare `echo ====` fails (`= not found`). Quote it: `echo '----'`.
- Under zsh, `--include=*.ts` in `grep` fails with "no matches found" (it's treated as a glob). Use `git grep ... -- '*.ts'` instead.

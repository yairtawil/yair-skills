---
name: go-ahead
description: Implement the ticket the current branch is named after. Reads the branch name, extracts the ClickUp ticket id from it, fetches the ticket, and starts implementing in the code. Use when the developer types `/go-ahead`, or says "go ahead", "start working on this branch's ticket", "implement this ticket", "you know what to do — go", while sitting on a ticket branch. For the full design-doc → breakdown → PR lifecycle use `/dev-task` instead; this one is just branch → ticket → code.
argument-hint: "[extra context] — optional; the ticket comes from the branch name"
effort: high
---

# /go-ahead — branch name → ticket → code

The developer is already on the right branch and has already decided this should be built. Your job is to figure out *what* from the branch name and start writing code. No design doc, no ClickUp breakdown, no gates — that's `/dev-task`.

## 1. Read the branch

```bash
git rev-parse --abbrev-ref HEAD
```

If this isn't a git repo, stop and say so.

If the branch is a base branch — `main`, `master`, `dev`, `develop`, `production`, `staging` — **stop**. There's no ticket in the name and you shouldn't implement on a base branch. Tell the developer and offer `/wt <ticket>` to spin up a proper branch.

## 2. Pull the ticket id out of the name

Branches follow `<type>/<ticket-id>-<slug>`, e.g. `feat/869edetj2-ach-id-to-payment-source`, `fix/869cf1vc4-opt-stuck-preprocess`.

Drop the `<type>/` prefix, then take the leading id:

- **Native ClickUp id** — first `-`-separated segment, 7–9 lowercase alphanumerics (`869edetj2`).
- **Custom id** — `PREFIX-1234` shape, so join the first two segments (`feat/CBB-1234-add-webhook` → `CBB-1234`).
- Strip a `CU-` prefix if present.

If nothing ticket-shaped is there, don't guess from the slug — ask the developer for the ticket id in one line, and if they say there is no ticket, just implement from the slug + whatever they typed as the argument.

## 3. Fetch the ticket

```
mcp__clickup__clickup_get_task(task_id: "<id>", include: ["description", "comments"])
```

Read the description **and the comments** — on 8fig tickets the real requirements often land in the comments, not the description. Follow any linked doc or attachment that the ticket leans on.

If the ClickUp MCP isn't connected, say so and ask the developer to paste the ticket body rather than stalling.

Restate the ticket in 2–3 sentences so the developer can catch a misread early. That's a checkpoint, not a gate — keep going unless they interrupt. **Do** stop and ask if the ticket is genuinely ambiguous or if it implies a decision only they can make (product behaviour, schema shape, breaking change).

## 4. Check what's already done

The branch may not be fresh — someone may have started, or the dev may have local edits.

```bash
git status --short
git log --oneline <base>..HEAD
```

| Repo | Base branch |
|---|---|
| `app` | `dev` |
| `cbb-app` | `dev` |
| `data-extractors` | `master` |
| `e2e-tests` | `main` |
| `payments` | `master` |

Continue from what's there — don't redo or revert existing work on the branch.

## 5. Implement

1. **Orient first.** Read the repo's `AGENTS.md` / `CLAUDE.md` and the actual code paths the ticket touches. Grep for a nearby example rather than inventing a convention — design-system components, styled-components, `createApi`/`createWorker`/`createRpc`, TypeORM entity conventions, path aliases.
2. **Write the code.** Match the surrounding style. Track multi-step work with the task list so progress is visible.
3. **Write tests** for the change where the repo has a test story for that area.
4. **Run them:**
   - `app`: `nx test <project>` / `npm run test:affected`
   - `cbb-app`: `nx test <service>`, `nx integration <service>`, `nx affected --target=test --base=origin/dev`
   - `data-extractors`: `nx test <project>`
   - `payments`: `npm run test`, `npm run test:e2e`

   Fix until green. If integration tests need a private env, read it from `<workspace>/cbb-app/infra/.env` (`ENV_NAME=`).

## 6. Hand back

Report: the ticket, what you changed (files + why), test results, and anything you deliberately left out.

**Stop there.** Don't commit, push, or open a PR — the developer runs `/commit` when they're happy. Don't touch the ClickUp ticket's status either.

## Guardrails

- Never implement on a base branch.
- Never `git push --force`, rebase, or rewrite history.
- The ticket is the scope. If you spot adjacent work that needs doing, mention it — don't silently widen the change.
- Report failing tests as failing. Don't call it done when it isn't.

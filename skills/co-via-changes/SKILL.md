---
name: co-via-changes
description: Move uncommitted work onto a fresh feature branch locally. Use this skill whenever the user has made changes to a git repo while sitting on the wrong branch (usually main/master) and wants to checkout a new branch that carries those changes over. Triggers include phrases like "I made changes on main, move them to a new branch", "checkout a new branch with my current changes", "I forgot to branch before editing", "create a branch from my working changes", or any situation where uncommitted/staged changes need to be relocated onto a new branch. Use this even when the user just says "branch off my changes" without spelling out the steps. Once the new branch is created and carries the changes, this skill hands off to the `commit` skill (invoked via the Skill tool) to commit, push, and open a PR.
---

# Git: Branch from Existing Changes

This skill moves uncommitted work (staged, unstaged, or both) from the current branch onto a brand-new branch. The most common scenario: someone started editing files while still on `main`, then realized they should be on a feature branch.

The good news is that `git checkout -b` (and `git switch -c`) carries uncommitted changes along to the new branch automatically. The work is _not_ tied to a branch until it is committed, so switching branches keeps it in the working tree. The job of this skill is to do that safely, name the branch sensibly, and leave the original branch clean.

This skill handles only the **branch move** locally — inspect, name, and `git checkout -b`. Once the new branch is created and the changes confirmed present, it hands off to the `commit` skill (via the Skill tool), which does the committing, pushing, and PR creation. This skill itself does not commit or push.

## Workflow

Follow these steps in order. Run the diagnostics first — never branch blind.

### 1. Inspect the current state

Run these to understand what you're working with:

```bash
git status              # what's modified, staged, untracked
git branch --show-current   # confirm which branch you're on
git diff --stat         # quick summary of unstaged changes
git diff --cached --stat    # quick summary of staged changes
```

Confirm with the user before proceeding if anything is surprising — for example, if there are no changes at all, or if they're already on a feature branch (in which case they may just want a normal commit, not a new branch).

### 2. Decide on a branch name

If the user gave a name, use it. If not, propose one based on the nature of the changes (from the diff) and the user's project conventions. Good names are lowercase, hyphenated, and prefixed by type when the convention exists in the repo:

**Example 1:**
Input: changes add a login form and JWT handling
Output: `feature/jwt-login`

**Example 2:**
Input: changes fix a null-pointer crash in the parser
Output: `fix/parser-npe`

Check existing branches with `git branch -a` so the new name doesn't collide. If it does, pick a variant and tell the user.

### 3. Create and switch to the new branch

This carries all uncommitted changes (staged and unstaged) with you:

```bash
git checkout -b <branch-name>
```

Equivalent modern form: `git switch -c <branch-name>`. Either is fine — match whatever the user/repo already uses.

After this, run `git status` again and confirm the changes are present on the new branch.

### 4. Hand off to the commit skill

Once `git checkout -b` succeeds and `git status` confirms the changes are present on the new branch, the branch-move part of this skill is done. Do **not** commit, push, or create a PR by hand here — hand off instead.

Invoke the **`commit`** skill via the Skill tool (skill name: `commit`). It analyzes the current changes, then stages, commits with a sensible message, pushes the new branch, and creates/links the PR. Everything downstream of the branch move is its job.

Only skip the handoff if the user has explicitly said they want the branch kept local (no commit/push/PR) — in that case, stop after confirming the changes are on the new branch and tell them it's left uncommitted.

## Important edge cases

**Untracked files** are carried over by `git checkout -b` just like tracked changes — no special handling needed. They won't be committed until `git add` includes them.

**Conflicts on switch.** Plain `git checkout -b` rarely fails, because the new branch starts from the current commit. If the user instead wants to base the new branch on a _different_ starting point while keeping local changes, a switch can fail with "local changes would be overwritten." In that case, `git stash`, create the branch from the desired base, then `git stash pop`.

**Changes were already committed to the wrong branch.** This skill only handles _uncommitted_ work. If the user already committed to `main` by mistake, that is a separate operation involving history rewrites — out of scope here. Tell the user this skill does not cover it, rather than guessing.

## Quick reference

| Situation                                | Command                                                         |
| ---------------------------------------- | --------------------------------------------------------------- |
| Move uncommitted changes to a new branch | `git checkout -b <name>`                                        |
| Same, modern syntax                      | `git switch -c <name>`                                          |
| Commit + push + PR once branched         | Hand off to the `commit` skill (Skill tool)                     |
| Need a different base + keep changes     | `git stash` -> `git switch -c <name> <base>` -> `git stash pop` |

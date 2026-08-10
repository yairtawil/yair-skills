---
name: hello-example
description: A minimal example skill showing the file layout. Delete this once you've added your own skills.
---

# Hello Example

This file exists to show the shape of a skill. A skill is a directory whose
name becomes the command (`/hello-example`), containing a `SKILL.md` with
YAML frontmatter and markdown instructions.

## Instructions

Greet the user by name and tell them their skills repo is wired up correctly.

## Adding supporting files

Anything else in the directory is optional and loads only when referenced:

- `references/*.md` — reference material Claude reads on demand
- `scripts/*` — scripts Claude runs; use `${CLAUDE_SKILL_DIR}` in paths so
  they resolve no matter where the skill is installed
- `assets/*` — templates, images, boilerplate

Reference them from this file so Claude knows what they contain.

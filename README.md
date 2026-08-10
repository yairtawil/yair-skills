# claude-skills

Personal [Claude Code](https://code.claude.com/docs/en/skills) skills, kept in
one place so they can be installed on any machine and shared with others.

## Install

```bash
git clone https://github.com/USERNAME/claude-skills.git ~/dev/claude-skills
cd ~/dev/claude-skills
./install.sh
```

That symlinks every skill in `skills/` into `~/.claude/skills/`, which makes
them available in **all** your projects. Because they're symlinks, a later
`git pull` updates the installed skills in place — nothing to re-run.

Restart Claude Code afterwards (a new top-level skills directory isn't picked
up mid-session), then run `/skills` to confirm they're listed.

### Other install options

```bash
./install.sh luz-parasha      # install just one skill
./install.sh --list           # show every skill and whether it's installed
./install.sh --copy           # copy instead of symlink (no auto-updates)
./install.sh --force          # overwrite entries that already exist
./install.sh --uninstall      # remove this repo's skills again
./install.sh --dest ./.claude/skills   # install into a project instead
```

Prefer a project-scoped install when a skill only makes sense inside one repo —
commit it to that repo's `.claude/skills/` and everyone on the team gets it.

## Repo layout

```
claude-skills/
├── install.sh
├── README.md
└── skills/
    ├── hello-example/
    │   └── SKILL.md
    └── luz-parasha/
        ├── SKILL.md
        └── references/
            └── zmanim-5786.md
```

Each directory under `skills/` is one skill. The directory name becomes the
slash command (`skills/luz-parasha/` → `/luz-parasha`). `SKILL.md` is the only
required file; everything alongside it loads on demand.

## Adding a skill

1. `mkdir skills/my-skill` and write `skills/my-skill/SKILL.md`
2. Frontmatter needs at minimum a `description` — this is what Claude matches
   against to decide when to load the skill, so write it in terms of what the
   user would actually say, not what the skill is called internally
3. Keep `SKILL.md` under ~500 lines; push long reference material into
   `references/` and link to it from `SKILL.md`
4. `./install.sh my-skill`, restart Claude Code, and try it

### Portability note

Claude Code accepts a long list of frontmatter fields (`argument-hint`,
`context`, `allowed-tools`, `paths`, `disable-model-invocation`, …). If you also
want to upload a skill to claude.ai or use it in Cowork/cloud sessions, only
these six are allowed there: `name`, `description`, `license`, `compatibility`,
`metadata`, `allowed-tools`. Anything else fails the upload with a hard error
rather than being ignored. Skills meant for both places should stick to the six.

Claude Code-only body features — notably dynamic context injection with
`` !`command` `` — also don't run outside Claude Code.

## Before publishing

Skills often accumulate machine-specific or personal details: absolute paths,
API/asset IDs, coordinates, private reference tables. Move those into
`references/` with documented defaults, or note in the skill what a new user
has to change.

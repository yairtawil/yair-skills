---
name: "skills-repo-sync"
description: "Two-way sync between Yair's Claude skills and his GitHub repo yairtawil/yair-skills. Use for: סנכרן סקילים, sync skills, תעדכן את הריפו של הסקילים, push my skills to the repo."
---

# Skills ⇄ repo sync

Keep Yair's personal Claude skills and the repo `yairtawil/yair-skills` identical.
Each skill lives in the repo as `skills/<name>/` (SKILL.md + any `references/`, `scripts/`, `assets/`).

## Where things are

- **Claude side (read-only cache):** `/mnt/skills/plugins/<name>/` in the cloud workspace.
  `/mnt/skills/plugins/manifest.json` lists every skill with `name`, `source`, `updatedAt`.
  Yair's own skills are the ones whose `source` is **not** `anthropic` / `anthropic-example`.
  Never sync the built-in Anthropic skills.
  Editing these files does nothing — the only way to change a Claude skill is `propose_skills`.
- **Repo side:** the local clone on Yair's Mac: `/Users/yairtawil/Desktop/dev/self/yair-skills`
  (in device_bash: `$HOME/mnt/yair-skills`). Reached through the linked-computer tools.
  If the folder isn't connected, call `device_request_folder_access` for that path.
  If the session isn't linked to his computer at all, tell him to open the chat in the desktop app.
- **Sync state:** `.claude-sync.json` at the repo root — `{ "<skill>": "<sha256 of the skill dir as of last sync>" }`.
  This is what lets you tell which side changed. Create it on the first run.

## Steps

1. **Prepare the repo.** In device_bash: `git status -sb`. If there are uncommitted changes that aren't yours, stop and ask.
   Try `git pull --ff-only` (it may fail — the Mac's SSH alias `github.com-personal` isn't usable from the VM; that's fine, continue and mention it).
   git needs to delete its own `.lock` files, so if deletion isn't allowed yet, call
   `device_request_delete_permission` once for the repo folder before any git write.

2. **Hash both sides** with exactly this script, in the workspace (`Bash`, root `/mnt/skills/plugins`) and on the Mac
   (device_bash, root `$HOME/mnt/yair-skills/skills`), so the hashes are comparable. Pass the root as the argument.
   It normalizes `SKILL.md` frontmatter down to `name` + `description` (name defaults to the dir name), because the
   Claude side only keeps those two — otherwise a skill with Claude Code-only keys would look changed forever.

   ```python
   import hashlib,os,sys,json,re
   def norm(d,b):
       t=b.decode('utf-8','replace'); m=re.match(r'---\n(.*?)\n---\n?',t,re.S)
       if not m: return b
       kv={}
       for l in m.group(1).splitlines():
           mm=re.match(r'^(name|description):\s*(.*)$',l)
           if mm: kv[mm.group(1)]=mm.group(2).strip().strip('"\'')
       kv.setdefault('name',os.path.basename(d))
       return (kv['name']+'\n'+kv.get('description','')+'\n'+t[m.end():].strip()).encode()
   root=sys.argv[1]; out={}
   for n in sorted(os.listdir(root)):
       d=os.path.join(root,n)
       if not os.path.isdir(d) or n.startswith('.'): continue
       h=hashlib.sha256()
       for dp,dn,fn in os.walk(d):
           dn.sort()
           for f in sorted(fn):
               if f in('LICENSE.txt','.DS_Store'): continue
               p=os.path.join(dp,f); r=os.path.relpath(p,d); b=open(p,'rb').read()
               if r=='SKILL.md': b=norm(d,b)
               h.update(r.encode()+b'\0'+b+b'\0')
       out[n]=h.hexdigest()
   print(json.dumps(out))
   ```

3. **Classify each skill** using the last-synced hash `L`, Claude hash `C`, repo hash `R`:

   | Case | Action |
   |---|---|
   | only in Claude | → copy to repo |
   | only in repo | → propose to Claude |
   | C == R | in sync, just record the hash |
   | C != R, R == L (or no L and Claude's `updatedAt` is newer than the repo's last commit of that dir) | Claude changed → copy to repo |
   | C != R, C == L | repo changed → propose to Claude |
   | both changed / unclear | show Yair a short diff and ask which side wins |

   Show Yair the plan as a compact table before writing anything, then go ahead unless he objects
   (if he isn't around, do the unambiguous rows and leave conflicts for him).

4. **Claude → repo.** Copy the skill dir into `/mnt/user-data/outputs/skills-sync/skills/<name>/`, then
   `device_commit_files` each file to `/Users/yairtawil/Desktop/dev/self/yair-skills/skills/<name>/<path>`.
   Files that exist in the repo copy but no longer exist in Claude (e.g. `zmanim-5786.md` replaced by `zmanim-5787.md`)
   are removed with `git rm` in device_bash.
   If the repo's SKILL.md has extra frontmatter keys (`allowed-tools`, `argument-hint`, `effort`, …), keep them:
   merge them back into the copied file's frontmatter so the Claude Code-only setup isn't lost.

5. **Repo → Claude.** `device_stage_files` the repo skill's SKILL.md, read it, and call `propose_skills`
   (kind `new` if the skill doesn't exist in Claude, `improvement` with `target` if it does). Max 3 per call.
   Notes for Yair, in one line each when relevant:
   - Only SKILL.md is saved through the card — files in `references/` / `scripts/` can't be carried over that way.
   - claude.ai only keeps `name` + `description` from the frontmatter; Claude Code-only fields
     (`allowed-tools`, `argument-hint`, `effort`, bang-backtick context injection) won't work here.
   - A skill without `name` in its frontmatter: use the directory name.
   The proposal only takes effect after Yair saves the card, so record the new hash for these skills
   only on the *next* run (when C == R), not now.

6. **Commit.** Update `.claude-sync.json` with the hashes of every skill that is now identical on both sides.
   `git add -A skills .claude-sync.json && git commit -m "sync skills from Claude: <names>"`.
   Then try `git push`. If it fails from the VM (expected — no SSH/GitHub auth there), say so and give him
   the one command to run: `cd ~/Desktop/dev/self/yair-skills && git push`.

7. **Report** in Hebrew, short: what went to the repo, what's waiting on a proposal card, any conflicts, push status.

## Don'ts

- Don't touch `install.sh`, `README.md`, or skills that are identical.
- Don't delete a whole skill directory from either side without asking — a skill missing on one side means
  "copy it over", not "delete it".
- Don't put machine-specific secrets into the repo; if a skill contains tokens/keys, stop and ask.
- Never write an exclamation mark immediately followed by a backtick in a skill body proposed to Claude — the
  loader runs it as a shell command and the skill fails to load. Describe it in words instead.
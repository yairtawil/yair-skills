---
name: luz-parasha
description: Create the weekly synagogue (shul) Shabbat schedule ("לו״ז"/"לוז הפרשה") in Canva by duplicating last week's parashah design, swapping the parashah name, asking the user for the rest of the details, and filing it in the shul's year folder. Use this whenever the user — typically a gabbai (גבאי) — wants to make next week's bulletin/schedule, says things like "תכין את הלוז של השבוע", "שכפל את לוז הפרשה הקודמת", "צריך את הלוז לפרשת X", or "make this week's parasha schedule". Trigger even if Canva isn't explicitly named.
---

# Shul Parashah Schedule (weekly Canva bulletin)

This skill automates the recurring job of a synagogue gabbai: take last week's parashah schedule
(a one-page Canva design) and turn it into the upcoming week's version. Most of the design — layout,
fonts, community names, dedications, fixed prayer times — stays exactly the same. The skill duplicates
last week's design, renames the parashah, and pulls this week's זמנים (candle lighting / mincha / Havdalah)
from the bundled yearly luach (`references/zmanim-5787.md`) instead of asking. It only asks about the
genuinely variable things (shiurim/kiddush, the green arrow). At the end it files the new design in the
shul's folder for the current Hebrew year (e.g. `משכן שלום/תשפז`).

## Name the conversation after the parashah (do this first)
The gabbai wants each of these conversations to be titled after the parashah + Hebrew year,
e.g. `ואתחנן תשפ"ז`. There is **no tool to rename a Claude conversation** — the title is
auto-generated from the conversation's content. So the reliable way to steer it: **open your
very first reply with a clear standalone line in that exact form** before anything else, e.g.

> **פרשת ואתחנן תשפ"ז**

Use the parashah name the user gave (or, if not yet known, the one you'll duplicate/rename to)
plus the current Hebrew year in `תשפ"<X>` form. The auto-titler picks this up, producing a title
like "פרשת ואתחנן תשפ״ז". Exact punctuation is up to the app and may vary
(`ואתחנן תשפ"ז` / `ואתחנן תשפז`) — that's fine.

## The flow (do it in this order)

### 1. Duplicate last week's design
Use `search-designs` to find the most recent schedule (titles follow `פרשת <name> תשפ"<X>`; sort by
`modified_descending` or search the previous parashah name). If more than one could match, confirm
which one with the user. Then `copy-design` on its `design_id` and work on the copy.

### 2. Swap the parashah name — in the heading AND the file name
You need the new parashah name. If the user already said it ("הלוז לפרשת חקת"), use it. Otherwise ask
which parashah this is for. Then `start-editing-transaction` on the copy and `perform-editing-operations`:
- `update_title` → `פרשת <new name> תשפ"<X>` (this is the Canva file name).
- `find_and_replace_text` on the heading element → replace the old parashah name with the new one
  (e.g. `פרשת קרח` → `פרשת חקת`). Watch for a "מברכין" prefix in the heading from last week — see note below.

### 3. Look up the זמנים (don't ask), then ask only about the rest
The three times that change every week come from the bundled yearly luach — **look them up, don't ask**:
- Open **`references/zmanim-5787.md`** and find the row for this week's parashah (match by name; two-parashah
  weeks use the combined name, e.g. `מטות מסעי`).
- From that row take **הדלקת נרות** (candle lighting) and **צאת שבת** (Havdalah). **מנחה** is already
  computed in the table (rule: הדלקת נרות + 20 min, rounded to the nearest 5). The candle/tzet values are the
  luach's big central "כניסת/יציאת השבת" numbers — the ones משכן שלום actually prints (verified against past
  bulletins), not the תל אביב/ירושלים strip.
- The row also gives the **special-Shabbat label** (e.g. `שבת חזון`) for the heading line, flags
  **מברכין** weeks, and — on מברכין weeks — carries the **molad text** ready to print (e.g.
  `יום ראשון 9:43 ו-2 חלקים`), so you don't need to ask for it.
- The table covers **תשפ"ז** (ר"ה ספט' 2026 → נצבים־וילך ספט' 2027), plus the first four שבתות of תשפ"ח
  in a second table at the bottom. If the parashah isn't found (later year, or an unusual week), fall back
  to asking the gabbai for the three times.
- Times already account for the clock change (שעון חורף from 25/10/2026, שעון קיץ from 26/03/2027).

State the three times you found so the gabbai can eyeball them, and ask **only** about what genuinely varies
week to week (use the question/answer tool if available so it's quick):
- Anything else changing this week — add/remove a shiur or kiddush, a different דבר תורה speaker, etc.
- The **green arrow** — keep / move to another row / remove (see "Saved assets").
- If it's a **מברכין** week, keep the מברכין heading and print the molad from the table (state it so the
  gabbai can eyeball it); otherwise drop "מברכין" from the heading and delete the molad line.

Don't proceed to commit until you've confirmed the times and gathered any changes.

### 4. Apply the answers, show, confirm, commit
Apply all the user's values with `perform-editing-operations`, then show the returned thumbnail so the
gabbai can eyeball it. Changes are draft-only until `commit-editing-transaction` — nothing is saved
before that.

### 5. File the design in the shul's year folder
After committing, move the new design into `<shul folder>/<year folder>` with `move-item-to-folder`
(`item_id` = the new design's `design_id`). Do this after the commit, so an abandoned draft copy never
lands in the archive. Don't ask — just do it and mention where it went.

**Folder layout in Canva** (top level → shul → Hebrew year). Year folders are named **without
gershayim**: `תשפד`, `תשפו`, `תשפז`, … (not `תשפ"ז`).

Known folder IDs (use directly; if a move fails with "not found", re-resolve by name as below):
- `משכן שלום` → `FAHZvKBvNLg`
  - `תשפז` → `FAHZvOOUtz0`
  - `תשפו` → `FAHEfqqxZSc`
  - `תשפד` → `FAFNU2YdWSU`

Resolving a folder that isn't listed above:
1. Pick the shul from the design: משכן שלום by default; היכל רחמים if the bulletin is for היכל רחמים.
2. Find the shul folder with `search-folders` (query = shul name). If the shul folder doesn't exist
   (e.g. היכל רחמים has none yet), ask the gabbai once whether to create it at the top level
   (`create-folder`, `parent_folder_id: "root"`).
3. `list-folder-items` on the shul folder (`item_types: ["folder"]`) and find the year folder matching the
   design's year (strip the gershayim: `תשפ"ח` → `תשפח`). If it's missing — e.g. the first bulletin of a new
   year — create it with `create-folder` under the shul folder without asking, then move the design in.

Then hand over the design's `edit_url` and say in one line which folder it was filed in.

The same filing applies to one-off bulletins/announcements built from this template (חגים, מודעות):
file them in the shul's folder for the year they belong to.

## How the design is built (important for editing)
Labels and times live in **separate text elements**, aligned line-by-line. For example the
"וביום השבת" block is one text element (the list of items) and a second element holds the times,
where a blank line corresponds to an item with no time. **Keep them aligned**: if you add or remove a
line in the labels element, add/remove the matching line (often a blank) in the times element, or the
whole column shifts. The cleanest way to insert/remove an item is `replace_text` on the whole labels
element with the new full list, plus `replace_text` on the times element with the matching full list.

For simple time changes (candle lighting, mincha, Havdalah) use `find_and_replace_text` on the times
element — replace the old time string with the new one.

## Saved assets
**The green arrow** — a green arrow image (pointing right) saved in Canva under `asset_id: MAErqDGKoPE`
(roughly 76×88 px). It's used to point at a specific row in the schedule.

When the gabbai asks to "add the green arrow" / "put a green arrow next to X":
- Add it as an image fill via the `insert_fill` operation (`asset_type: image`, `asset_id: MAErqDGKoPE`)
  inside a normal editing transaction.
- Position it on the left side of the schedule, at the vertical height of the row it should point to
  (default `left ≈ 124`; set `top` to match the relevant row in the items/times column).
- If the user asks to remove it, find the image element whose `asset_id` is `MAErqDGKoPE` and run
  `delete_element`.

Keep the columns aligned as described above; the arrow is an overlay and does not occupy a line in the
labels/times text elements.

## Notes / gotchas
- **Shabbat Mevarchin**: last week's heading may include "מברכין" (the Shabbat that blesses the new
  month) plus a molad line. Most weeks aren't Mevarchin, so when you swap the name also drop "מברכין"
  (e.g. `מברכין פרשת קרח` → `פרשת חקת`) and delete the molad line. If this week IS Mevarchin, take the
  molad straight from the מולד column of the zmanim table — don't ask the gabbai for it.
- Hebrew is right-to-left — rely on element IDs and `find_and_replace_text`, not character positions.
- Operations on `is_responsive` pages are limited to `update_title`, `replace_text`, `update_fill`,
  `delete_element`, `find_and_replace_text`. Check the `is_responsive` flag in the transaction response.
- Watch for trailing spaces inside text lines when doing find/replace (the source often has them).
- Don't change the fixed prayer times, community names, or dedications unless the user asks.
- Year folders have no gershayim (`תשפז`), even though design titles do (`תשפ"ז`).

## Example
**User:** "שכפל את הלוז של קרח ותכין לי לפרשת חקת"
1. `search-designs` "קרח" → `פרשת קרח תשפ"ז`; `copy-design`.
2. `start-editing-transaction` → `perform-editing-operations`: `update_title` → `פרשת חקת תשפ"ז`;
   heading `מברכין פרשת קרח` → `פרשת חקת` (חקת isn't מברכין, so drop the מברכין prefix).
3. Look up `חקת` in `references/zmanim-5787.md` → הדלקת נרות 19:20, מנחה 19:40, צאת שבת 20:31, no special
   label, not מברכין. Tell the gabbai those three times and ask only: "יש עוד שינוי השבוע? והחץ הירוק —
   להשאיר/להזיז/להסיר?" (חקת isn't מברכין → the molad line gets deleted).
   User: "רק תשאיר את החץ איפה שהוא."
4. Apply (find/replace the three times from the table, delete the molad element), show the thumbnail,
   confirm, `commit-editing-transaction`.
5. `move-item-to-folder` → `FAHZvOOUtz0` (משכן שלום/תשפז), hand over the edit link:
   "נשמר בתיקייה משכן שלום/תשפז."

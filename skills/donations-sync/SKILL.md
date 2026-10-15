---
name: "donations-sync"
description: "Sync Yair's donation receipts (קבלות תרומה) from Gmail into his Drive donations folder and the Google Sheet. Use for: סנכרן תרומות, sync donations, יש קבלות חדשות, עדכן את גיליון התרומות."
---

# Donations sync (Gmail → Drive → Google Sheet)

Keep Yair's donation-receipt archive complete with as little work for him as possible. Each run:
1. scans Gmail for receipts newer than the last checkpoint,
2. uploads any missing receipt to the right Drive folder,
3. adds it to the Google Sheet,
4. also picks up receipts he uploaded to Drive by hand,
5. moves the checkpoint forward and reports back.

Talk to Yair in Hebrew. Keep the report short.

## Fixed resources

| What | ID / value |
|---|---|
| Drive root folder "קבלות תרומות" | `0B1HSwLv24a-0OC1EdmlmbjBrSUU` |
| Google Sheet "סיכום תרומות 2016–2026" | `1W9XUPy4vRoNKE6M7bYXcozTWZRm4b7_BiGHjSY_dBP8` |
| Gmail account | yairtawil@gmail.com (personal) |

**Drive layout.** The root holds one folder per year, titled with the year (e.g. `2026`). Some year folders also hold organization subfolders, such as `מגדל אור`, `לב עמליה`, `עזר מציון`, `קו לחיים`, `נותנים תקווה`, `ואהבת`, `הצלה`, `זיכרון משה` and `חבד`. Find folders by listing their parent (`parentId = '<id>'`); never guess IDs. Folder names vary slightly ("מגדלאור", trailing spaces), so match them loosely.

**Sheet layout.**
- **`סיכום לפי שנה`**: one row per year. Its formulas read each year tab by name through `INDIRECT`. The total row is last.
- **`לפי עמותה`**: an organization × year grid. Column A holds the canonical organization names, row 1 holds the years as text, and the `סה"כ` row is last.
- **One tab per year** (`2016` … `2026`), with these columns:

  | Col | Header | Notes |
  |---|---|---|
  | A | תאריך | formula `=DATE(y,m,d)`, format dd/mm/yyyy |
  | B | עמותה | canonical name; must match `לפי עמותה`!A exactly |
  | C | שם המוסד בקבלה | name as printed on the receipt |
  | D | סכום (₪) | number |
  | E | מס׳ קבלה | text, written with a leading `'` |
  | F | אמצעי תשלום | כרטיס אשראי / הוראת קבע (כרטיס אשראי) / העברה בנקאית / Google Pay / PayPal / Bit / מזומן / "" |
  | G | מטרה / הקדשה | free text or "" |
  | H | סעיף 46 | כן / לא / לא מצוין |
  | I | סטטוס | נספר / כפילות (only נספר rows are summed) |
  | J | הערות | short Hebrew notes |
  | K | קבלה | `=HYPERLINK("<drive viewUrl>","פתח")` |
  | L | מזהה מייל | Gmail message ID; `ידני` for Drive-only uploads; "" for legacy rows. If column L is missing, add it on the first run (header in L1, same header style as A1:K1). |

- **`מצב סנכרון`**: the sync state tab. Create it on the first run if it is missing.
  - A1:B4 hold key/value pairs:
    - `נסרק במייל עד` → a date (dd/mm/yyyy)
    - `סנכרון אחרון` → date and time, as text
    - `בדיקת דרייב אחרונה` → date and time, as text
    - `גרסת סקיל` → `1`
  - D1:D hold `שולחים מוכרים` (known sender domains).
  - From row 6 down is a run log: `תאריך ריצה | טווח שנסרק | מיילים שנבדקו | קבלות שנוספו | דולגו (כבר קיימות) | סומנו לבדיקה`.
  - Never use `NOW()` or `TODAY()`; type timestamps as text.

## Tools

Load these with ToolSearch:
- **Gmail:** `search_threads`, `get_message`, `get_thread`
- **Google Drive:** `search_files`, `read_file_content`, `download_file_content`, `create_file`
- **Google Sheets:** `get_spreadsheet`, `get_values`, `update_formulas`, `update_spreadsheet`
- **Optional, for receipts sent only as a link:** the linked computer's `mcp__remote-devices__get_device_info`, `device_bash` and `device_stage_files`. See "Receipts sent only as a link".

Before the first write to the Sheet, read the google-workspace skill's `references/sheets.md` and follow it: field masks without parentheses, and a leading `'` for text.

If the Gmail connector is missing, or is connected to an account other than yairtawil@gmail.com (check `viewUrl` / `toRecipients` in a search result), stop and tell Yair to connect or enable Gmail with the personal account.

The Drive connector may be signed in as the work account (yair.t@8fig.co), in which case files it creates are owned by that account. That's acceptable; mention it only if Yair asks about ownership.

### Getting attachment bytes out of Gmail

The Gmail connector has no download-attachment tool, so take the bytes from the raw message.

1. Call `get_message` with `messageFormat: "PLAIN_TEXT"`. This returns the `attachments` list (filename and mimeType) and the body.
2. If there is a PDF or image attachment, call `get_message` with `messageFormat: "RAW"`. The result is too large for context, so the app saves it to a file and reports the path. That JSON has a `raw` field with the base64url MIME message.
3. Decode it with this script. Keep the script in your own scratch `scripts/` folder, run it with `python3 -I`, and use a fresh output folder for each message.

```python
# extract_raw.py  <saved_get_message_json> <out_dir>
import json, sys, base64, email, os
from email import policy
src, out = sys.argv[1], sys.argv[2]
raw = json.load(open(src))['raw']
msg = email.message_from_bytes(base64.urlsafe_b64decode(raw + '=' * (-len(raw) % 4)), policy=policy.default)
os.makedirs(out, exist_ok=True)
for part in msg.walk():
    fn = part.get_filename()
    if fn:
        data = part.get_payload(decode=True)
        path = os.path.join(out, os.path.basename(fn))
        open(path, 'wb').write(data)
        print(path, len(data))
```

**Attachment first, links second.** Many senders put the receipt in both places. For example, Grow / Meshulam (`support@grow.security`, used by לב עמליה) always attaches `קבלה תרומה <n>.pdf` *and* adds a "להורדת המסמך" link to `documents.meshulam.co.il`. When the message has a receipt attachment, use it and ignore every link in the body. Fall back to a link only when the message has **no** PDF or image attachment at all, which you can check from the `attachments` list in step 1.

### Receipts sent only as a link

The cloud workspace can't download from most websites (network allowlist). WebFetch returns page text, not files. So download link-only receipts **on Yair's computer** when it is linked, and flag them for him otherwise.

1. **Check whether the computer can be used.** The `mcp__remote-devices__*` tools must be present, `get_device_info` must succeed, and `device_bash` must be available. Pick a connected folder from `connectedFolders`, preferring Downloads or a folder named like the donations archive.
   - If any of this fails (no link, computer asleep, no shell), go straight to step 5. A scheduled run with the computer off is normal; it is not an error.
2. **Download** into a dedicated subfolder, `<connected folder>/donation-receipts-downloads/`. Create it with `mkdir -p`. Run `curl -sSL --max-time 40 -o "<subfolder>/<msgId>.pdf" "<url>"`, quoting the URL exactly as it appears in the email.
   - Only follow links whose host is the issuer's document or receipt service. Examples: `documents.meshulam.co.il`, or the organization's own domain or receipt system named in the email. Never follow unsubscribe, tracking or social links.
3. **Verify it is really a PDF:** the first bytes must be `%PDF` (`head -c 4`), and the size must be over 5 KB.
   - If you got HTML instead (a login page, "click to download" page or similar), don't keep it. Move it into the same subfolder's `_to_delete/` and flag the message.
4. **Bring it into the workspace** with `device_stage_files`, then continue from step 2 of the procedure exactly as for an attachment. Leave the downloaded copies on the computer; deleting them needs Yair's permission. Mention the folder once in the report so he can clear it.
5. **Flag** whatever couldn't be downloaded in the report's "לבדיקה ידנית" list, with the subject, date and a Gmail link (`viewUrl`).
   - Don't advance the checkpoint past a flagged link-only receipt. Its date counts as "failed" in step 7, so the next run, perhaps with the computer on, retries it.
   - If the same message has been flagged in 3 runs in a row, stop holding the checkpoint for it. Record it in the state tab's log instead, so one stubborn link doesn't freeze the sync.

## Procedure

### 0. Read state
1. Run `get_spreadsheet` with `fields: ["sheets.properties"]` to get the tabs and sheetIds.
2. Read `'מצב סנכרון'!A1:D`.
   - If the tab or `נסרק במייל עד` is missing, this is a **first run**: scan Gmail with no lower date bound (a backfill) to find gaps in the existing archive.
   - Run a backfill in yearly windows, newest first. After each window, write the checkpoint state and a log row so no progress is lost.
3. Build a dedupe index from every year tab:
   - Read `'<year>'!A:L` and collect (receipt number, amount, canonical org) and the Gmail IDs in L.
   - Collect the Drive file IDs from column K's HYPERLINK formulas. Use a grid read with `userEnteredValue`, since `get_values` shows only "פתח".

### 1. Search Gmail (incremental)
- **Start date** = `נסרק במייל עד` minus 3 days. The overlap catches late mail; duplicates are removed in step 3.
- **Query 1** (add `after:YYYY/MM/DD` when there is a start date):
  `(קבלה OR תרומה OR "מסמך תרומה" OR "אישור תרומה" OR receipt OR donation OR "סעיף 46")`
- **Query 2: known senders**, to catch receipts whose subject lacks those words, e.g. `from:(kavlachayim.org OR ami.org.il OR grow.security)`. Add new sender domains to `שולחים מוכרים` (D1:D) as you find them.
- `search_threads` returns at most 50 threads per page and previews only the oldest messages of a thread.
  - Page through every page.
  - For threads with `messageCount` > 1, call `get_thread` with `MINIMAL` to see every message.
- Track the newest message date you have **fully processed** (uploaded, recorded, or deliberately skipped).

### 2. Classify and extract each candidate
1. Get the file. Use the attachment if there is one (see "Getting attachment bytes"); otherwise follow "Receipts sent only as a link". Ignore logos and signatures under ~15 KB.
2. Read the text with `pdftotext -layout`.
   - Hebrew often comes out **reversed per line**: "המורת לע הלבק" is "קבלה על תרומה". Read it backwards; numbers are unaffected.
   - Some issuers' fonts come out as garbage, e.g. Asakim-generated קו לחיים receipts. If the text is empty or garbled, rasterize page 1 with `pdftoppm -r 150 -png -f 1 -l 1` and read the image.
3. Decide whether it is a **donation receipt**.
   - Skip anything clearly not one: purchases, invoices (חשבונית), newsletters, campaign mail.
   - Record borderline cases, but explain in הערות. Borderline means: titled just "קבלה", itemized goods, דמי חבר, or no section 46 line.
4. Extract these fields:
   - **receipt date**, from the receipt itself, not the email date
   - **institution** as printed
   - **amount** in ₪ (note any other currency)
   - **receipt number**
   - **payment method**
   - **purpose or dedication**
   - **section 46**: כן / לא / לא מצוין
   - **recipient**: if the receipt is addressed to someone other than Yair, note it, e.g. `הקבלה על שם אורית.`
   - **months covered**, if it is a summary receipt for several installments
5. Map the institution to a **canonical org name** from `לפי עמותה`!A. Examples:
   - "לב עמליה ביישוב לשם (ע"ר)" → `לב עמליה`
   - "עמותת קהילת לשם" → `קהילת לשם (משכן שלום)`
   - "בית/מוסדות חב"ד אריאל" → `חב"ד אריאל`
   - "קריית חינוך / עמותת מגדל אור" → `מגדל אור`
   - "הצלה כי כל שנייה קובעת" → `הצלה`

   Create a new canonical name only for a truly new organization, and keep it short.

**Privacy:** never write ID numbers (ת.ז.), card digits, bank account numbers, phone numbers or addresses into the Sheet, the notes or the report.

### 3. Dedupe
A candidate already exists if any of these hold:
- its Gmail message ID is in column L;
- the same receipt number **and** amount is in the year tab (also check the neighboring year for receipts dated around January);
- a file with the same name and size is in the target Drive folder.

Skip existing candidates and count them as "כבר קיימות". If the same receipt shows up twice in Gmail (e.g. reissued under another name), record it once.

### 4. Upload to Drive
1. **Pick the folder.**
   - Use the receipt year's folder. If it doesn't exist (e.g. `2027`), create it under the root: Drive `create_file` with `contentMimeType: application/vnd.google-apps.folder` and `parentId` = root.
   - If the year folder has a subfolder matching the canonical org, upload there; otherwise upload to the year folder itself.
   - Create a new org subfolder only if that year already uses subfolders and the org has two or more receipts that year.
2. **Name the file** `<canonical org> DD.MM.YY.pdf`. Append ` (2)` if the name is taken.
3. **Upload** with `create_file`: the file's base64 content, `contentMimeType: application/pdf` (or the image type), and `parentId`. Keep the returned `viewUrl` for column K.
   - The whole file travels inside the call, so upload one file per call.
   - Over ~1 MB (large scans): list it for manual upload instead.

### 5. Update the Sheet
1. **Append each new receipt** after the last data row of its year tab with `update_formulas`, using the column layout above. Status = `נספר`; L = the Gmail message ID.
2. **Sort.** After all appends, sort each touched tab's data rows by column A ascending (`sortRange`, from row 2).
3. **New canonical org.**
   - Insert a row in `לפי עמותה` just above `סה"כ` and write the name in A.
   - Copy the formulas from the row above (`copyPaste`, `PASTE_FORMULA`).
   - Check that the `סה"כ` row's SUM ranges include the new row.
4. **New year.**
   - Add the tab: `addSheet` with `sheetId` = the year number and `rightToLeft: true`. Copy the formatting of rows 1–200 from the previous year tab (`copyPaste`, `PASTE_FORMAT`), then write the headers A1:L1.
   - In `סיכום לפי שנה`, insert a row above the current first year row. Write the year as text (`'2027`) and copy the formulas from the row below.
   - In `לפי עמותה`, insert a column before `סה"כ`. Put the year as text in row 1, copy the formulas from the column to its left, and fix the `סה"כ` column's SUM range.
   - Extend the summary chart's ranges if needed.
5. **Never type totals.** The formulas use open-ended ranges (`D2:D`), so new rows count automatically.

Notes (column J) are short, plain Hebrew sentences, e.g.:
- `קבלה מרכזת ל-4 תשלומים, ספטמבר עד דצמבר 2026.`
- `הקבלה על שם אורית.`
- `כתוב "קבלה" ולא "קבלה על תרומה", ייתכן שזו רכישה.`
- `נקרא מסריקה, כדאי לוודא מול הקבלה.`
- `הורד מקישור במייל.` (for receipts downloaded from a link)

### 6. Drive-only receipts (manual uploads)
1. List the files in every year folder and subfolder modified after `בדיקת דרייב אחרונה` (on the first run, list all of them).
2. Any PDF or image whose file ID isn't linked in column K of any year tab is a manual upload. For each one:
   - read it with `read_file_content`, falling back to `download_file_content` + rasterize;
   - extract as in step 2 and dedupe as in step 3;
   - add a row with `ידני` in column L.
3. Don't move or rename these files.

### 7. Advance the checkpoint
- Set `נסרק במייל עד` to the date of the newest fully processed message.
- If anything failed partway (an upload error, an unreadable attachment, or a link-only receipt not yet downloaded, subject to the 3-run rule), set it to the date **before** the oldest failed message instead, so the next run retries.
- Never move the checkpoint backward unless Yair asks for a rescan.
- Update `סנכרון אחרון` and `בדיקת דרייב אחרונה`, and append a log row.

### 8. Verify, then report
1. Run `get_values` on `'סיכום לפי שנה'!A3:E` and on each touched year tab.
2. Confirm there are no `#REF!`, `#N/A` or `#ERROR!` values, and that each new row's amount appears in its year's total.

Then reply to Yair in Hebrew with:
- the range scanned;
- what was added, per year and organization;
- what needs his attention: link-only receipts that couldn't be downloaded (with Gmail links), unreadable scans, borderline purchases or membership fees, receipts in someone else's name;
- the new checkpoint date;
- a link to the Sheet.

If nothing is new, say so in one line.

## Options Yair may ask for
- **"סרוק מחדש מ-<date>":** ignore the checkpoint and scan from that date. All dedupe rules still apply.
- **"רק בדיקה" (dry run):** report what would be added; don't upload, download or write anything.
- **A schedule (e.g. weekly):** create a scheduled task whose prompt runs this skill. It needs the Gmail and Drive connectors to stay connected. Link-only receipts are downloaded only when the computer is on; otherwise they wait for the next run.
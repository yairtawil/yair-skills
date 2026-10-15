---
name: water-electric-bill
description: Calculate the bi-monthly water and electricity charge for Yair's rental unit from new meter readings, and enter the new row into his Google Sheet "קריאות מים וחשמל יחידה". Use whenever the user sends water/electricity meter readings (קריאת מים, קריאת חשמל, מונה, קוב, קוט"ש), asks to calculate מים וחשמל for the tenant, or asks for this period's חשבון מים וחשמל — even if he only sends two numbers or photos of the meters without explanation.
---

# Water and electricity bill (מים וחשמל)

## The sheet

- Spreadsheet ID: `1pNXHyJwSQ3EAqZEz7AGE3VTcrytYoctf8bA8Jj7Yd0U`
- Link: https://docs.google.com/spreadsheets/d/1pNXHyJwSQ3EAqZEz7AGE3VTcrytYoctf8bA8Jj7Yd0U/edit
- Active tab: `מרציאנו` (current tenant). The tab `דגני` is a previous tenant's history: never touch it.
- Tools: Google Sheets connector (`get_values`, `update_values`). If it is not available, compute and show the result, and tell the user the sheet was not updated.

Layout of `מרציאנו` (columns):

| B | C | D | E | F | G | H | I |
|---|---|---|---|---|---|---|---|
| חודש (period label) | מים (meter reading) | חשמל (meter reading) | חישוב מים (m³) | חישוב חשמל (kWh) | סה"כ מים | סהכ חשמל | סה״כ |

Period rows are grouped by year (year in column A on the first row of each year), with blank rows between years. Period labels for future rows are already written in column B. The tariffs sit at the bottom, under the labels `תעריף חשמל לקוט"ש` (value in column A on the next row) and `תעריף מים לקוב` (row with `תעריף א` / `תעריף ב`, values on the row below: A = discounted rate, B = regular rate).

## HARD RULE: never overwrite past data

The user explicitly asked that existing data is never changed.
- Only write into the C:I cells of one row whose C through I are all empty.
- Never write to columns A or B (the period labels are there already; some are stored as dates and must stay as they are).
- Never "fix" an old row, even a wrong total (row 06-07 shows 405 instead of 455: leave it). If you notice an error in old data, mention it in the reply and only change it if the user explicitly asks in that message.
- Read again immediately before writing and confirm the target cells are still empty. If they are not, stop and ask.

## Workflow

0. **Get the readings.** If the user triggered the skill without both readings (e.g. "תחשב מים וחשמל"), ask for them in one short message: "שלח קריאת מים וקריאת חשמל (מספרים או תמונות של המונים)". Don't calculate or write anything until you have both. If only one arrived, ask for the missing one.

   **When the readings come as photos of the meters:**
   - Read the digits yourself from each image. Figure out which photo is water and which is electricity (water meter: mechanical wheels, usually black digits for m³ and red for fractions; electricity: digital display in kWh).
   - **Water:** the sheet stores the reading in tenths of a m³ with no decimal point (3472 = 347.2 m³). Take the black digits plus the first red digit, drop leading zeros and the point. Example: `00347` black + `2` red → 3472.
   - **Electricity:** take the total kWh reading with its two decimals (e.g. 11855.07). If the display shows a different screen (date, time, tariff code), say so and ask for another photo.
   - Check both against the previous reading (do steps 1-2 first to get it): the new number must be a bit above it (one period of use). If it is lower, wildly higher, or a digit is unclear (blurry, wheel between two digits), ask instead of guessing.
   - **Always confirm before writing:** reply with the readings you read ("קראתי: מים 3570, חשמל 12200.40. נכון?") and continue to the calculation and the sheet write only after the user confirms or corrects them. Readings he typed as numbers need no confirmation.

1. **Read the tab:** `get_values` on `'מרציאנו'!A:I`.
2. **Find the previous reading:** the last row (bottom-most) with numbers in both C and D.
3. **Find the target row:** the first row below it whose column B has a period label and whose C:I are empty. Use that label as the period. If the user named a different period, or no such row exists (e.g. a new year wasn't prepared), ask before writing.
4. **Read the tariffs** from the labeled cells at the bottom (don't hardcode them; the user may update them there). The discounted quota is 14 m³ per period (not in the sheet).
5. **Sanity check:** new readings must be ≥ previous. If water usage looks off by ×10 or the user may have swapped the two numbers (water is ~4 digits, electricity has decimals and is ~5 digits), ask.
6. **Calculate** with the script (exact decimals, no float drift):
   ```
   python3 <skill>/scripts/calc.py --period "<label>" \
     --prev-water <C prev> --new-water <new water> \
     --prev-elec <D prev> --new-elec <new elec> \
     --elec-rate <rate> --water-low <tariff א> --water-high <tariff ב>
   ```
   It prints the summary text and a `ROW:` JSON line with the 7 values for C:I.
7. **Write** the `ROW:` values with one `update_values` call to exactly `'מרציאנו'!C<row>:I<row>` (after the re-read in the hard rule). Values: C, D, E, F as numbers; G, H, I as text like `105 ש״ח`, matching the existing rows.
8. **Verify** with `get_values` on that row, then reply.

## Calculation rules (from the user's examples)

- Water m³ = (new − previous) / 10 (the meter counts tenths: 3472 − 3296 = 176 → 17.6 m³).
- First 14 m³ at the discounted rate (תעריף א), the rest at the regular rate (תעריף ב).
- Electricity kWh = (new − previous), fraction dropped (547.22 → 547).
- Electricity cost = kWh × rate (rate is per kWh, VAT included).
- The shekel totals at the top drop the agorot (105.50 → 105, 350.19 → 350); סה"כ = water + electricity after dropping.

## Reply format

Send the script's summary text exactly as plain text (it is meant to be copied and sent to the tenant), e.g.:

```
חודשים: 06-07:
סה"כ: 455 ש"ח
מים: 105 ש"ח
חשמל: 350 ש"ח

חישוב:
מים: 17.6 קוב
תעריף מוזל: 14 קוב × 4.54 = 63.56
תעריף רגיל: 3.6 קוב × 11.65 = 41.94
סה״כ: 63.56 + 41.94 = 105.50

חשמל: 547 קוט"ש
תעריף: 64.02 אג׳ לקוט״ש כולל מע״מ
סה״כ:
0.6402 × 547 = 350.19
```

Then one short line saying which row of the sheet was filled (with the sheet link), or why it wasn't.

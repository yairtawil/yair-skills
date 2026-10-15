#!/usr/bin/env python3
"""Calculate water + electricity charges between two meter readings.

Usage:
  calc.py --period "08 - 09" --prev-water 3472 --new-water 3600 \
          --prev-elec 11855.07 --new-elec 12300.5 \
          --elec-rate 0.6402 --water-low 4.54 --water-high 11.65 [--quota 14]

Prints the user-facing summary, then a JSON line (prefixed "ROW:") with the
values to write to the sheet (columns C..I).
"""
import argparse, json, sys
from decimal import Decimal as D, ROUND_FLOOR

def fmt(x, places=2):
    return f"{x:.{places}f}"

def clean(x):
    s = format(x.normalize(), "f")
    return s

p = argparse.ArgumentParser()
p.add_argument("--period", required=True)
for k in ["prev-water", "new-water", "prev-elec", "new-elec", "elec-rate", "water-low", "water-high"]:
    p.add_argument("--" + k, required=True)
p.add_argument("--quota", default="14")
a = p.parse_args()

pw, nw = D(a.prev_water), D(a.new_water)
pe, ne = D(a.prev_elec), D(a.new_elec)
rate, low, high, quota = D(a.elec_rate), D(a.water_low), D(a.water_high), D(a.quota)

if nw < pw or ne < pe:
    sys.exit(f"ERROR: new reading is lower than previous (water {pw}->{nw}, elec {pe}->{ne})")

# Water meter counts in tenths of a cubic meter: 3472-3296=176 -> 17.6
water_m3 = (nw - pw) / 10
# Electricity: whole kWh, drop the fraction (547.22 -> 547)
kwh = (ne - pe).to_integral_value(rounding=ROUND_FLOOR)

low_m3 = min(water_m3, quota)
high_m3 = max(water_m3 - quota, D(0))
low_cost = (low_m3 * low).quantize(D("0.01"))
high_cost = (high_m3 * high).quantize(D("0.01"))
water_cost = low_cost + high_cost
elec_cost = (kwh * rate).quantize(D("0.01"))

water_int = int(water_cost.to_integral_value(rounding=ROUND_FLOOR))
elec_int = int(elec_cost.to_integral_value(rounding=ROUND_FLOOR))
total = water_int + elec_int
agorot = clean(rate * 100)

lines = [
    f"חודשים: {a.period.replace(' ', '')}:",
    f"סה\"כ: {total} ש\"ח",
    f"מים: {water_int} ש\"ח",
    f"חשמל: {elec_int} ש\"ח",
    "",
    "חישוב:",
    f"מים: {clean(water_m3)} קוב",
]
if high_m3 > 0:
    lines += [
        f"תעריף מוזל: {clean(low_m3)} קוב × {clean(low)} = {fmt(low_cost)}",
        f"תעריף רגיל: {clean(high_m3)} קוב × {clean(high)} = {fmt(high_cost)}",
        f"סה״כ: {fmt(low_cost)} + {fmt(high_cost)} = {fmt(water_cost)}",
    ]
else:
    lines += [
        f"תעריף מוזל: {clean(low_m3)} קוב × {clean(low)} = {fmt(low_cost)}",
        f"סה״כ: {fmt(water_cost)}",
    ]
lines += [
    "",
    f"חשמל: {kwh} קוט\"ש",
    f"תעריף: {agorot} אג׳ לקוט״ש כולל מע״מ",
    "סה״כ:",
    f"{clean(rate)} × {kwh} = {fmt(elec_cost)}",
]
print("\n".join(lines))
row = [float(nw) if nw % 1 else int(nw), float(ne) if ne % 1 else int(ne),
       float(water_m3), int(kwh),
       f"{water_int} ש״ח", f"{elec_int} ש״ח", f"{total} ש״ח"]
print("ROW:" + json.dumps(row, ensure_ascii=False))

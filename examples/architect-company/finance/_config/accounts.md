# Accounts

Layer 3 rule book, binding inside finance only.

## The code list

| Code | Holds | Do not put here |
|---|---|---|
| 100 hire income | money taken for a tool going out | deposits still held |
| 110 deposits held | a deposit until the tool comes back | anything already earned |
| 200 tool purchase | a tool bought to hire out | a repair to a tool we own |
| 210 repairs | parts and labour on a tool we own | a replacement tool |
| 300 vehicle | fuel, servicing, insurance on the van | a tool moved by courier |
| 400 overheads | yard rent, power, phone, software | anything with a customer name on it |

## Rules

- A deposit is not income until the tool is back and checked. Moving it early is the mistake this list exists to stop.
- One line, one code. A split invoice is entered as two lines with the same reference.
- A line you cannot code is left uncoded and named in the run report. Never park it in overheads.

## When a rule is wrong

Log a call line in `../../_log/LOOP-LEDGER.md` with the invoice reference that broke the rule. A human edits this file.

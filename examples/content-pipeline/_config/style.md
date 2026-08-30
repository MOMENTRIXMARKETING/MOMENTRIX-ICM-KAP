# Style

Layer 3 rule book. The formatting mechanics for every file this desk writes.

## Quick Reference

| Thing | Rule |
|---|---|
| Headings | sentence case, one `#` title per file |
| Dates | `YYYY-MM-DD`, always |
| Timecodes | `m:ss`, zero padded seconds, no leading zero on minutes |
| Numbers | numerals from zero up, spelled out only when starting a sentence |
| Tables | header row, alignment row, no trailing spaces |
| Links | relative paths only, and every path resolves on disk |

## Structure

Every artifact opens with a one line statement of what it is and which stage wrote it. Then the body. No preamble, no summary of what the reader is about to read.

A brief is a table of claims and their sources. A script is beats in order. A shot list is one row per beat. If an artifact wants to be prose, it is the wrong artifact.

## Code Fences

Fenced blocks hold read-aloud narration, timecode tables and file trees. They never hold commentary. Every fence is closed, and a file with an odd number of fence lines is broken, not stylish.

## When a rule is wrong

Write it into `../_log/FORGE-PROPOSALS.md` with the file that would not fit. Do not widen the rule yourself.

# Budgets

Every size budget in this toolkit, with its source. The source is always
`icm.defaults.json`. This file explains the numbers and shows the arithmetic. It does not own
them. If a number here ever disagrees with `icm.defaults.json`, the JSON is right and this
file is a bug.

No other file in this repo restates a budget. Skills, scripts, and templates cite
`icm.defaults.json` or this file.

---

## Chars, Not Tokens

Every budget is in **characters**, not tokens.

`icm.defaults.json` says so itself, in `loading_budget.note`:

> "Chars, not tokens. 4 chars ~= 1 token. Layers 0+1+2+3 are the fixed cost."

The reason is that a budget you cannot check is a budget nobody keeps. Tokens need a
tokeniser, which means a runtime dependency, which this toolkit does not have. Chars need
`wc`, which is on every machine that can run `sh`.

```sh
wc -c < IDENTITY.md
```

Use `wc -c`. It counts bytes and is exact everywhere. `wc -m` counts characters but depends on
the locale being set correctly, so it is not portable enough to build a checker on. For plain
ASCII the two agree. For content with accented characters or emoji, bytes exceed chars, which
makes `wc -c` slightly strict. Strict in the safe direction is fine. A budget that
occasionally fails early never lets a file through that should have failed.

### One method, and it binds the checker too

`wc -c` is not a suggestion about how you should measure by hand. It is **the** method, and
the same one the checker uses: `icm_chars()` in `scripts/icm_lib.sh` is `wc -c < "$1"`, so the
number this file tells you to expect and the number `icm-check.sh --budgets` prints are the
same number.

They have to be. Every generated `IDENTITY.md` carries multibyte box-drawing characters in its
workspace map, so on real content the two counters diverge, and in a UTF-8 locale `wc -m` is
the *permissive* one, which would let a file sit under the ceiling by the checker and over it
by this document. A method nobody owns is how that happens. This section owns it.
`spec/CLI-CONTRACT.md` settles it the same way, and `spec/authority-model.md` uses the same
counter when it defines a budget breach.

To convert to tokens, divide by 4. That ratio is the one in `icm.defaults.json`. It is a rule
of thumb, not a measurement, and it is only ever used to sanity check a number against
published figures, never to decide whether a file passes.

---

## Per File Budgets

Source: `icm.defaults.json`, key `budgets`.

| Key in `icm.defaults.json` | Applies to | Target chars | Ceiling chars | Other |
|---|---|---|---|---|
| `IDENTITY.md` | The one layer 0 file at the workspace root | 3200 | 6000 | |
| `CONTEXT.root.md` | Layer 1 routing at a workspace root | 4400 | 8000 | |
| `CONTEXT.stage.md` | Layer 2 job cards in stage folders | 1200 | 2000 | ceiling 80 lines |
| `CONTEXT.folder.md` | Layer 1 routing inside a department or other folder | 1200 | 2000 | |
| `rulebook.md` | Any layer 3 file in a `_config/` folder | 2000 | 4000 | |
| `wiki_article.md` | Any article in `wiki/<topic>/` | 8000 | 16000 | |

**Target** means write to this size. A file at target is a healthy file.

**Ceiling** means lint fails above this size. A file over ceiling is a defect, not a style
preference.

The gap between target and ceiling is room to breathe, not room to spread. A workspace where
most files sit near their ceiling has no headroom left for the one file that genuinely needs
it.

### Why each ceiling sits where it does

`IDENTITY.md` gets 6000, which is 3200 target plus roughly the same again. Workspace maps
grow with the workspace and a map is the one thing in layer 0 that legitimately gets longer.

`CONTEXT.root.md` gets the loosest ratio in the table, 8000 against a 4400 target. It carries
the routing table for the entire workspace and a workspace with twenty destinations has a
longer table than one with three. Routing rows are cheap to read and expensive to omit. The
target is 1200 above layer 0 because layer 1 also carries the Session Close, the write back
obligation, and that block is roughly 1200 chars of the target. It sits here and not in a rule
book because layer 1 is loaded on every run by every harness, and a write back that loads only
sometimes is a ledger that starves.

`CONTEXT.stage.md` gets 2000 and also an 80 line ceiling. Job cards fail by accumulating
content, and content shows up in lines before it shows up in chars: an Inputs table growing
extra rows, a Process growing sub steps, an Audit growing checks. The line ceiling catches
that earlier than the char ceiling does.

`CONTEXT.folder.md` matches the job card at 1200 and 2000. A department's routing file is a
signpost, not a document. If it needs more than a job card's worth of space, it is describing
the department instead of routing to it.

`rulebook.md` gets 2000 and 4000. See the layer 3 arithmetic below, because the rule book
target is load bearing for the whole loading budget.

`wiki_article.md` gets the largest allowance, 8000 and 16000, and it is the only budget in the
table that is not part of the fixed load. Wiki articles are layer 4b and are loaded
selectively, one at a time, named by a job card. An article is allowed to be a real document
because it is not a tax on every task in the workspace.

---

## The Fixed Loading Budget

Source: `icm.defaults.json`, key `loading_budget`.

Layers 0, 1, 2, and 3 are the fixed cost of doing any task at all. Layer 4 varies by task and
is not budgeted here. `icm.defaults.json` marks that explicitly with `"layer4_varies": true`.

```
layer0_identity     3200      IDENTITY.md at target
layer1_context      4400      root CONTEXT.md at target, Session Close included
layer2_stage        1200      the job card at target
layer3_rulebooks    4000      the rule books the job card names
                  ------
fixed_total        12800
```

Check the arithmetic: 3200 + 4400 = 7600. 7600 + 1200 = 8800. 8800 + 4000 = 12800. That
matches `loading_budget.fixed_total` in `icm.defaults.json`.

In tokens, at the 4 chars per token ratio the JSON states: 12800 / 4 = 3200 tokens. The
upstream `icm-template` layer reference card reports a focused stage load of 2,000 to 8,000
tokens, so a workspace built to these budgets sits at the bottom of the band that methodology
already expects.

### Where the layer 3 number comes from

`layer3_rulebooks` is 4000, and the `rulebook.md` target is 2000. 2000 x 2 = 4000.

**The layer 3 budget is two rule books at target.** That is the whole story, and it is the
most useful single fact in this file.

It means a job card whose Inputs table names three full rule books is already over budget
before the agent has read a word of the task. The fix is never to raise the budget. The fix
is pattern 4, selective section routing: name the section, not the file.

```markdown
| Rule book | `../../_config/objections.md` | "Price" and "Timing" | The two this stage answers |
```

A rule book of 2000 chars might hold 400 chars that matter to this stage. Naming the section
buys back 1600 chars, which is more than a whole extra rule book. Three sections from three
rule books usually costs less than one whole rule book.

### The worst case

Every fixed file at its ceiling instead of its target:

```
IDENTITY.md          6000
CONTEXT.root.md      8000
CONTEXT.stage.md     2000
rule books           4000      two at the 2000 rulebook target
                   ------
                    20000
```

6000 + 8000 = 14000. 14000 + 2000 = 16000. 16000 + 4000 = 20000 chars, which is 20000 / 4 =
5000 tokens.

That is 20000 against a target of 12800, so a workspace that lets every file drift to its
ceiling pays 7200 extra chars on every task it ever runs. This is why ceilings are a lint
failure and not an aspiration.

Note what the worst case does not include: rule books at their own 4000 ceiling. The
`layer3_rulebooks` figure of 4000 is a budget for the whole of layer 3, not a per file
allowance. Two rule books at their 4000 ceiling would be 8000, which is double the layer 3
budget on its own. A single rule book near its ceiling is a rule book that should be split.

---

## What Recursion Costs

`loading_budget.fixed_total` prices a flat workspace: one routing hop from the root
`CONTEXT.md` straight to a job card.

Recursion adds a hop. See `spec/layers.md`. Every department between the root and the job
card adds one `CONTEXT.folder.md` read, at its 1200 target.

One department level:

```
fixed_total                     12800
department CONTEXT.folder.md     1200
                              -------
                                14000
```

Two department levels:

```
fixed_total                     12800
department CONTEXT.folder.md     1200
sub-department CONTEXT.folder.md 1200
                              -------
                                15200
```

12800 + 1200 = 14000. 14000 + 1200 = 15200. Both figures are arithmetic on published numbers,
which is why the components are shown rather than the totals asserted. Same rule as the
grounding invariant: a derived value shows its parts.

This is the reason `spec/layers.md` says to keep departments one level deep unless there is a
real reason for two. The surcharge is not paid once. It is paid by every task in that
department, forever.

---

## Measuring

Every file:

```sh
wc -c FILE
```

Every `CONTEXT.md` in a workspace, lines and chars together, skipping the folders that
`spec/excluded-folders.md` lists. The prune expression below is abbreviated to three entries
so the shape is readable. Take the full expression from `spec/excluded-folders.md` and do not
retype the list from memory:

```sh
find . \( -name .git -o -name node_modules -o -name .icm \) -prune -o \
  -name 'CONTEXT.md' -exec wc -l -c {} +
```

`wc` prints lines first, then bytes, then the path. Compare the first column against
`ceiling_lines` where the budget has one, and the second against `ceiling_chars`.

---

## When a File Is Over

The fix is almost never compression. Compression makes a file smaller and worse, and it comes
back next month.

| Over budget | Fix |
|---|---|
| `IDENTITY.md` | The map has grown detail that belongs in a routing table. Move it to layer 1. |
| `CONTEXT.root.md` | Too many destinations at the top. Group them into departments, and let layer 1 recurse. |
| `CONTEXT.stage.md` | Content has leaked into a job card. Move it into a rule book and point at it. |
| `CONTEXT.folder.md` | It is describing the department instead of routing to it. Cut to the routing table. |
| `rulebook.md` | It is two rule books. Split it on the seam and update the job cards that name it. |
| `wiki_article.md` | It is two articles. Split by concept, cross link them, update `wiki/index.md`. |
| Layer 3 total | Name sections instead of files in the job card's Inputs table. |

A file at twice its ceiling is never a formatting problem. It is a structure problem wearing a
formatting problem's clothes.

---

## What Is Not Budgeted

- **Layer 4a, `raw/`.** Source files are whatever size the source was. They are cited and
  opened to locate a literal, not loaded whole, so their size is not a tax on the fixed load.
- **Layer 4b `output/`.** Per run artifacts are the product. They are as long as the work
  requires.
- **`skills/<name>/SKILL.md`.** Skills are loaded by the harness on trigger, not by the layer
  stack, and they carry their own conventions.
- **`_log/`.** Logs are append only and are read by the forge and the weekly review, never by
  a task doing work.

Everything unbudgeted here is unbudgeted because it never enters the fixed cost of a task. The
moment something in this list starts being loaded on every task, it needs a budget, and that
budget goes in `icm.defaults.json`, not here.

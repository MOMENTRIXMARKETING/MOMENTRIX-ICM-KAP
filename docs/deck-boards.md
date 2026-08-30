# Deck boards

Print deck copy. The deck is called **ICM FOR BEGINNERS** and each board is a 1440 x 810
artboard.

This file holds the copy for boards 7, 8 and 9, plus the corrections owed on boards 1 to 6.

---

## Before you lay these out

**The deck goes from six boards to nine.** Every existing board's header counter renumbers.

| Board | Title | Counter was | Counter becomes |
|---|---|---|---|
| 1 | THE FOLDER STRUCTURE | ICM FOR BEGINNERS 1 OF 6 | ICM FOR BEGINNERS 1 OF 9 |
| 2 | WHERE THE RULE BOOKS LIVE | ICM FOR BEGINNERS 2 OF 6 | ICM FOR BEGINNERS 2 OF 9 |
| 3 | CODE VS ICM | ICM FOR BEGINNERS 3 OF 6 | ICM FOR BEGINNERS 3 OF 9 |
| 4 | THE PAYOFF | ICM FOR BEGINNERS 4 OF 6 | ICM FOR BEGINNERS 4 OF 9 |
| 5 | THE BUSINESS STRUCTURE | ICM FOR BEGINNERS 5 OF 6 | ICM FOR BEGINNERS 5 OF 9 |
| 6 | THE SKILL FORGE LOOP | ICM FOR BEGINNERS 6 OF 6 | ICM FOR BEGINNERS 6 OF 9 |
| 7 | THE KNOWLEDGE LAYER | new | ICM FOR BEGINNERS 7 OF 9 |
| 8 | DROP IT ON WHAT YOU ALREADY HAVE | new | ICM FOR BEGINNERS 8 OF 9 |
| 9 | THE FOLDERS ARE THE AGENTS | new | ICM FOR BEGINNERS 9 OF 9 |

Board 8 takes the artboard slot held by the earlier draft titled THE RETROFIT and replaces its
copy. The subject is the same. The copy below is the version that ships.

Board anatomy, unchanged from boards 1 to 6: logo top left, counter top right, orange eyebrow
line, short title, a two sentence intro, an indented folder tree in mono, callout blocks, a
closing "Why it matters:" paragraph, then the footer strip reading MOMENTRIX / board title /
momentrixbeta.com. Boards alternate dark and light. Board 7 is dark, board 8 is light, board 9
is dark.

---

## Two fixes owed on the existing boards

### Fix 1. Say rule books, never skills library

`_config/` holds **rule books**. Do not call them skills anywhere in the deck. The word
collides head on with Claude Code skills, which are a different thing entirely and now ship as
part of the toolkit. Board 6 already says rule books. Boards 1, 2 and 4 do not, and boards 7, 8 and
9 below say rule books throughout, so the deck currently contradicts itself three ways.

Change every one of these:

| Board | Reads now | Change to |
|---|---|---|
| 1 | `_config` the skills library: voice, style, conventions (board 2 covers this) | `_config` the rule books: voice, style, conventions (board 2 covers this) |
| 2 | eyebrow: THE SKILLS LIBRARY | eyebrow: THE RULE BOOKS |
| 2 | title: WHERE THE SKILLS LIVE | title: WHERE THE RULE BOOKS LIVE |
| 2 | card label: THE LIBRARY | card label: THE RULE BOOKS |
| 2 | Skills are just reference files: how we sound, how things should look, what our words mean. | Rule books are just reference files: how we sound, how things should look, what our words mean. |
| 2 | Here's the clever part: skills don't travel down the line. Each stage's instruction file names exactly which skills it needs, and pulls only those. | Here's the clever part: rule books don't travel down the line. Each stage's instruction file names exactly which rule books it needs, and pulls only those. |
| 2 | you fix one skill file and every future run inherits the fix | you fix one rule book and every future run inherits the fix |
| 4 | fix voice.md in the skills library | fix voice.md in the rule books |
| 5 | `_config` company skills / department skills | `_config` company rule books / department rule books |

The footer strip on board 2 carries the board title, so it changes with the title.

### Fix 2. Standardise on `output/`, not `output.md`

A stage writes a folder of results, not a single file. That is Pattern 2 of the methodology:
stage N writes into its own `output/` folder and stage N+1 reads from there. The deck is split
on it, and a reader who follows the folder tree literally builds the wrong thing.

| Board | Reads now | Change to |
|---|---|---|
| 1 | `output.md` the result, which becomes stage two's input | `output/` the results, which become stage two's input |
| 3 | `01_research    CONTEXT.md + output.md` | `01_research    CONTEXT.md + output/` |
| 3 | `02_script      CONTEXT.md + output.md` | `02_script      CONTEXT.md + output/` |
| 3 | `03_production  CONTEXT.md + final.md` | `03_production  CONTEXT.md + output/` |

Everywhere else in the toolkit already uses `output/`. See `spec/layers.md`, layer 4b.

### While you are in there

The earlier board 8 draft carried a repo strip with three links. Two of them do not match
`NOTICE.md` and one is not sourced at all. Do not print them as they stand. `NOTICE.md` is the
authority on every upstream credit, and the paper is redistributed in the repo itself at
`docs/paper/`, so the strip on board 8 below points at the toolkit and leaves the upstream
credits to the repo.

---

# BOARD 7 OF 9

**Artboard:** dark. Background `#333333`, text `#FEFEFB`, accent `#F35A28`.

**Counter (top right):** ICM FOR BEGINNERS 7 OF 9

**Eyebrow:** RAW WIKI AND WHAT THE AI KNOWS

**Title:** THE KNOWLEDGE LAYER

**Intro:**

> Rule books tell the AI how to work. They don't tell it what's true.

> That's the second half, and it comes from Andrej Karpathy: the AI reads your source material
> and writes up what it learned, and the write up gets better every time you add to it. Two
> folders do it.

**Folder tree** (mono, indented, lowercase):

```
my workspace
  _config        the rule books: how we sound,
                 how things look
  raw            source material, exactly as it
                 arrived: transcripts, articles,
                 reports, notes
                 you add to it, nobody edits it, ever
  wiki           what the AI worked out from raw
    index.md     the contents page, one line
                 per article
    log.md       what was added and when, append only
    topic/       the write ups, each one citing
                 the sources it came from
  01_research    the stages carry on exactly
  02_script      as before
  03_production
```

**Callout 1, orange border, glow.**

> **THE ONE RULE THAT MAKES IT TRUSTWORTHY**
>
> Every fact in the wiki has to appear word for word in a raw file it links to. No number, no
> date, no quote goes in unless the AI found it in a source first. That single rule is the
> difference between a knowledge base and a pile of confident guesses.

**Callout 2, three rows, mono in column one.**

> **THE THREE WAY SPLIT**
>
> | | | |
> |---|---|---|
> | `_config` | HOW WE WORK | you write it, once |
> | `raw` | WHAT IS TRUE | you collect it, never edit it |
> | `wiki` | WHAT WE KNOW | the AI writes it, only from raw |
>
> Row three is the accent row.

**Callout 3.**

> **WHERE THE CAPACITY GOES**
>
> The AI never reads the whole wiki. It reads index.md, picks the two or three articles that
> matter, and opens only those. Same saving as the rule books, same reason: structure, not
> cleverness. A wiki of four hundred articles costs the same to consult as a wiki of four.

**Closing paragraph, gradient bar on the left edge.**

> Why it matters: the rule books stop the AI sounding wrong. The wiki stops it being wrong. Add
> a source on Monday and every run from Tuesday already knows it. Nothing gets relearned,
> nothing gets lost, and every claim traces back to the file it came from.

**Footer strip:** MOMENTRIX / THE KNOWLEDGE LAYER / momentrixbeta.com

---

# BOARD 8 OF 9

**Artboard:** light. Background `#FEFEFB`, text `#333333`, accent `#F35A28`.

**Counter (top right):** ICM FOR BEGINNERS 8 OF 9

**Eyebrow:** NOTHING MOVES NOTHING BREAKS

**Title:** DROP IT ON WHAT YOU ALREADY HAVE

**Intro:**

> You don't restructure your business to use ICM. You lay a few files on top of what's already
> there.

> It shows you the whole change before it makes any of it, it never writes over anything you
> wrote, and one command puts it all back.

**Folder tree** (mono, indented, lowercase):

```
your business
  IDENTITY.md      added, the name tag
  CONTEXT.md       added, the map
  _config          added, the rule books
  .icm             added, the plan and the backup
                   hidden, out of your way

  finance          already there, untouched
  customers        already there, untouched
  marketing        already there, untouched
  sales            already there, untouched
```

Caption under the tree:

> Files added, zero files moved. Any agent that walks in reads the name tag and the map and
> knows the whole building.

**Callout 1, four rows. Numbers in orange squares.**

> **THE DRY RUN COMES FIRST**
>
> You ask it to plan. It reads your folders and writes nothing. Then it hands you four lists.
>
> | | | |
> |---|---|---|
> | 1 | CREATE | doesn't exist yet, this is what gets added |
> | 2 | ADOPT | already there. Yours is kept, one marked block is added at the end |
> | 3 | COLLIDE | already there and different. Your file wins |
> | 4 | SKIP | already exactly what it would have written. Nothing to do |
>
> Junk never even makes the lists. Build folders, downloads and dependency folders are cut out
> of the walk before anything is classified, so they never appear at all.
>
> You read the four lists. Nothing has touched your project yet.

**Callout 2, orange border, glow.**

> **NOTHING GETS CLOBBERED**
>
> When your file and its file want the same name, yours stays exactly as it is. Its version
> goes into the hidden folder for you to look at, and you merge whatever you want by hand.
> There is no overwrite button. There is no force flag. Run it twice and the second run changes
> nothing.
>
> Two files are the exception and they are the two you would expect: the AI instruction file
> and your gitignore. Those get a clearly marked block added at the end, everything outside the
> markers is left alone to the byte, and a copy of the original goes into the backup first.

**Callout 3.**

> **ROLLBACK IS ONE COMMAND**
>
> It backs up before it writes, every time, without being asked. If you change your mind, one
> command takes out what it added and puts back what was there. If you edited one of its files
> in the meantime, it keeps that file and tells you it kept it. It never deletes anything you
> touched.

**Closing paragraph.**

> Why it matters: most systems ask you to reorganise first and get the benefit later, so most
> people never start. This one starts where you are. You see the change, you approve the change,
> you can undo the change. Ten years of folders stay exactly where they are and become
> something an agent can read on Monday morning.

**Repo strip, above the footer:**

> **THE TOOLKIT** github.com/MOMENTRIXMARKETING/momentrix-icm-kap-toolkit
>
> **INSTALL** /plugin marketplace add MOMENTRIXMARKETING/momentrix-icm-kap-toolkit

**Footer strip:** MOMENTRIX / DROP IT ON WHAT YOU ALREADY HAVE / momentrixbeta.com

---

# BOARD 9 OF 9

**Artboard:** dark. Background `#333333`, text `#FEFEFB`, accent `#F35A28`.

**Counter (top right):** ICM FOR BEGINNERS 9 OF 9

**Eyebrow:** WHO IS ACTUALLY IN CHARGE

**Title:** THE FOLDERS ARE THE AGENTS

**Intro:**

> An AI agent is not a member of staff. It is spawned into a folder, does one job, writes down
> what it did, and it is gone.

> So the folder is the job, the report is the record, and the person in charge is simply
> whichever AI opens the top folder next.

**Folder tree** (mono, indented, lowercase):

```
your business
  IDENTITY.md      the name tag, who we are
  CONTEXT.md       the map, where things go
  ARCHITECT.md     the job card for this folder:
                   read the rollup, decide who works
                   today, never do the work yourself
  status.md        one line per department,
                   written by the workers

  sales            a department
    CONTEXT.md     the map inside sales
    status.md      sales' one line
    reports/       one file per run, nothing
                   ever overwritten
    _config        the rules only sales obeys
    01_leads       a stage, with its own job card

  marketing        same shape again
  finance          same shape again
```

Caption under the tree:

> No orchestrator. No supervisor. No process that has to stay running. The org chart is the
> folders.

**Callout 1, orange border, glow.**

> **ANY AI CAN TAKE THE CHAIR**
>
> There is no appointment and no handover meeting. Any model, from any vendor, on any day,
> opens the top folder, reads four short files, and is the lead architect. The handover is the
> filing cabinet. Nothing is stored in a conversation somebody had to be present for.

**Callout 2, three rows, mono in column one.**

> **THE THREE THINGS THAT NEVER MOVE**
>
> | | | |
> |---|---|---|
> | `ARCHITECT.md` | THE JOB OF THIS FOLDER | you write it, once |
> | `reports/` | WHAT HAPPENED | the workers write it, one file per run |
> | `status.md` | THE ONE LINE SUMMARY | compiled, never the truth |
>
> Row three is the accent row. If the summary and the folder disagree, the folder wins.

**Callout 3.**

> **FIVE RULES AND THAT IS THE WHOLE SYSTEM**
>
> Agents are temporary, reports are files. The architect reads reports, not conversations.
> Messages coordinate, files record: no decision is real until it is written in the folder. The
> architect never does a department's work, unless the job is smaller than the cost of handing
> it over, and then it says so. And anyone who reads the top four files is the architect.

**Closing paragraph, gradient bar on the left edge.**

> Why it matters: every other way of doing this puts the structure inside software, so the
> business only exists while something is running and only one vendor's model knows the shape
> of it. Put the structure in folders and it survives the agent, the session, the model and the
> vendor. Kill any agent at any moment and nothing is lost, because the agent was never where
> the work was kept.

**Repo strip, above the footer:**

> **THE TOOLKIT** github.com/MOMENTRIXMARKETING/momentrix-icm-kap-toolkit
>
> **THE PATTERN** pattern 24, spec/CONVENTIONS.md

**Footer strip:** MOMENTRIX / THE FOLDERS ARE THE AGENTS / momentrixbeta.com

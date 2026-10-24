#!/usr/bin/env python3
"""The librarian: compile the continuity layer of an ICM workspace.

Optional infrastructure, the same tier as check_evidence.py: python3 3.10+,
stdlib only, never required. It reads the workspace and writes exactly four
compiled files under <target>/_log/, overwritten every run:

  HANDOFF.md              the one page any agent reads on arrival: health,
                          open misses, private shape misses, silent sessions,
                          proposals with age, the last ledger lines, and the
                          arrival checklist
  SKILL-TOOL-REGISTRY.md  every SKILL.md in the tree, where it lives, and
                          whether the ledger has ever seen it run
  WIKI-INGEST-QUEUE.md    stale articles (older than a live source they name)
                          and files changed since they were last ingested
  WIKI-INGEST-STATE.json  created once if missing, then only ever read here;
                          the wiki compile records each ingest in it

It never touches the ledger, a rule book, a job card, a skill or the wiki.

Five checks, all mechanical, none of them judgment:
  1. Ledger shape: a dated 6 column row whose column 2 is not Miss, Use or
     Patched is a miss the forge can never count. Settled once a later Miss
     line says "rewritten from the <date>".
  2. Silent sessions: per day and top folder, files changed with no ledger
     line that day naming the folder. The Session Close did not fire.
  3. Forge age: proposals still proposed past the age threshold.
  4. Wiki staleness and backlog, per file, so one rebuild never hides the rest.
  5. Second ledgers: any LOOP-LEDGER.md outside _log/ that is not a pointer.

Thresholds live in icm.defaults.json under "librarian".

Usage: icm_librarian.py [target-dir]
Exit: 0 clean, 1 findings, 2 usage or environment error.
"""

import datetime as dt
import fnmatch
import json
import os
import re
import sys

TODAY = dt.date.today()
NOW = dt.datetime.now()
KNOWN = {"Miss", "Use", "Patched"}
SKIP_TOP = {"_log", "raw", "wiki"}


def fail(msg):
    print(f"FAIL {msg}", file=sys.stderr)
    sys.exit(2)


def load_defaults(root):
    here = os.path.dirname(os.path.abspath(__file__))
    for p in (os.path.join(root, "icm.defaults.json"), os.path.join(here, "..", "icm.defaults.json")):
        if os.path.isfile(p):
            with open(p) as f:
                return json.load(f)
    fail("icm.defaults.json not found in the target or the toolkit")


class Workspace:
    def __init__(self, root):
        self.root = os.path.abspath(root)
        self.log = os.path.join(self.root, "_log")
        d = load_defaults(self.root)
        self.excl = d.get("excluded_globs", [])
        lib = d.get("librarian", {})
        self.silent_days = int(lib.get("silent_days", 7))
        self.proposal_age = int(lib.get("proposal_age_days", 7))
        self.lint_window = int(lib.get("lint_window_days", 30))
        self.ledger_path = os.path.join(self.root, d.get("log", {}).get("ledger", "_log/LOOP-LEDGER.md"))
        self.proposals_path = os.path.join(self.root, d.get("log", {}).get("forge_proposals", "_log/FORGE-PROPOSALS.md"))
        self.findings = []
        self.broken = []

    def rel(self, p):
        return os.path.relpath(p, self.root)

    def excluded(self, name):
        return name.startswith(".") or any(fnmatch.fnmatch(name, g) for g in self.excl)

    def walk(self, skip_top=True):
        for dirpath, dirnames, filenames in os.walk(self.root):
            relp = os.path.relpath(dirpath, self.root)
            if skip_top and relp.split(os.sep)[0] in SKIP_TOP:
                dirnames[:] = []
                continue
            dirnames[:] = [x for x in dirnames if not self.excluded(x)]
            for fn in filenames:
                if self.excluded(fn):
                    continue
                fp = os.path.join(dirpath, fn)
                if not os.path.exists(fp):
                    self.broken.append(self.rel(fp))
                    continue
                yield fp


def mdate(p):
    return dt.date.fromtimestamp(os.path.getmtime(p))


def cells(line):
    return [x.strip() for x in line.strip().strip("|").split("|")]


# ------------------------------------------------------------------ ledger
def read_ledger(ws):
    if not os.path.isfile(ws.ledger_path):
        fail(f"no ledger at {ws.rel(ws.ledger_path)}")
    with open(ws.ledger_path, errors="replace") as f:
        text = f.read()
    rows = [cells(ln) for ln in text.splitlines() if re.match(r"^\| \d{4}-\d\d-\d\d \|", ln)]
    return text, rows


def ledger_shape(ws, rows):
    cutoff = TODAY - dt.timedelta(days=ws.lint_window)
    private = [r for r in rows if len(r) == 6 and r[1] not in KNOWN
               and dt.date.fromisoformat(r[0]) >= cutoff]
    redone = {}
    for r in rows:
        if len(r) == 6 and r[1] == "Miss":
            m = re.search(r"rewritten from the (\d{4}-\d\d-\d\d)", r[4])
            if m:
                redone[m.group(1)] = redone.get(m.group(1), 0) + 1
    keep = []
    for r in private:
        if redone.get(r[0], 0) > 0:
            redone[r[0]] -= 1
        else:
            keep.append(r)
    if keep:
        ws.findings.append(f"ledger: {len(keep)} miss line(s) in a private shape, uncounted by the forge")
    open_m = []
    for i, r in enumerate(rows):
        if len(r) == 6 and r[1] == "Miss":
            if not any(len(x) >= 3 and x[1] == "Patched" and x[2] == r[3] for x in rows[i + 1:]):
                open_m.append(r)
    return keep, open_m


def silent_sessions(ws, text):
    by_day = {}
    for ln in text.splitlines():
        m = re.match(r"^(?:\| |<!-- )(\d{4}-\d\d-\d\d)", ln)
        if m:
            by_day.setdefault(m.group(1), []).append(ln)
    since = TODAY - dt.timedelta(days=ws.silent_days)
    changed = {}
    for p in ws.walk():
        d = mdate(p)
        r = ws.rel(p)
        if d < since or os.sep not in r:
            continue
        top = r.split(os.sep)[0]
        changed.setdefault(d.isoformat(), {}).setdefault(top, 0)
        changed[d.isoformat()][top] += 1
    out = []
    for d in sorted(changed):
        day_text = "\n".join(by_day.get(d, []))
        miss = {k: v for k, v in changed[d].items() if k not in day_text}
        if miss:
            out.append((d, sum(miss.values()), ", ".join(
                f"{k} {v}" for k, v in sorted(miss.items(), key=lambda x: -x[1])[:6])))
    if out:
        ws.findings.append(f"silent sessions: {len(out)} day(s) with folders changed and no ledger line naming them")
    return out


def second_ledgers(ws):
    out = []
    for p in ws.walk():
        if os.path.basename(p) == "LOOP-LEDGER.md":
            with open(p, errors="replace") as f:
                head = f.read(600)
            if "pointer" not in head.lower():
                out.append(ws.rel(p))
    if out:
        ws.findings.append(f"second ledger(s) outside _log/: {', '.join(out[:5])}")
    return out


# ------------------------------------------------------------------ forge
def proposals(ws):
    out = []
    if not os.path.isfile(ws.proposals_path):
        return out
    with open(ws.proposals_path, errors="replace") as f:
        txt = f.read()
    for m in re.finditer(r"^## (FP-[\w-]+) \| (.+?)\n- Status: (proposed[^\n]*)", txt, re.M):
        dm = re.match(r"FP-(\d{4}-\d\d-\d\d)", m.group(1))
        age = (TODAY - dt.date.fromisoformat(dm.group(1))).days if dm else -1
        out.append((m.group(1), m.group(2), age))
    old = [p for p in out if p[2] > ws.proposal_age]
    if old:
        ws.findings.append(f"forge: {len(old)} proposal(s) waiting on a human over {ws.proposal_age} days")
    return out


# ------------------------------------------------------------------ wiki
def wiki(ws):
    wdir = os.path.join(ws.root, "wiki")
    if not os.path.isdir(wdir):
        return None
    last = dt.date(2000, 1, 1)
    wlog = os.path.join(wdir, "log.md")
    if os.path.isfile(wlog):
        with open(wlog) as f:
            for m in re.finditer(r"^## \[(\d{4}-\d\d-\d\d)\]", f.read(), re.M):
                last = max(last, dt.date.fromisoformat(m.group(1)))
    sp = os.path.join(ws.log, "WIKI-INGEST-STATE.json")
    try:
        with open(sp) as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {"baseline": last.isoformat(), "ingested": {}}
        with open(sp, "w") as f:
            json.dump(state, f, indent=1)
    base = dt.date.fromisoformat(state.get("baseline", last.isoformat()))
    done = state.get("ingested", {})
    queue = {}
    for p in ws.walk():
        r = ws.rel(p)
        if not p.lower().endswith((".md", ".pdf")) or os.sep not in r:
            continue
        if re.search(r"archive|superseded", r, re.I) or os.path.basename(p) in ("CONTEXT.md", "SKILL.md"):
            continue
        d = mdate(p)
        seen = done.get(r)
        if d > base and (not seen or d > dt.date.fromisoformat(seen)):
            queue.setdefault(r.split(os.sep)[0], []).append((d, r))
    stale, parked = [], []
    for dirpath, _, files in os.walk(wdir):
        for fn in files:
            if not fn.endswith(".md") or fn in ("index.md", "log.md"):
                continue
            ap = os.path.join(dirpath, fn)
            with open(ap, errors="replace") as f:
                head = f.read(4000)
            um = re.search(r"Updated:\s*(\d{4}-\d\d-\d\d)", head)
            if not um:
                continue
            if re.search(r"^> Status: (superseded|history)", head, re.M):
                parked.append(ws.rel(ap))
                continue
            upd = dt.date.fromisoformat(um.group(1))
            src = {}
            for tok in re.findall(r"([A-Za-z0-9_\-./]+\.md)\b", head):
                for cand in (os.path.join(ws.root, tok), os.path.normpath(os.path.join(dirpath, tok))):
                    if os.path.isfile(cand) and f"{os.sep}raw{os.sep}" not in cand and f"{os.sep}wiki{os.sep}" not in cand:
                        src[os.path.realpath(cand).lower()] = cand
            newer = [(ws.rel(s), mdate(s)) for s in src.values() if mdate(s) > upd]
            if newer:
                stale.append((ws.rel(ap), upd, newer))
    n = sum(len(v) for v in queue.values())
    if stale:
        ws.findings.append(f"wiki: {len(stale)} article(s) older than a live source they name")
    if n:
        ws.findings.append(f"wiki: {n} file(s) changed since {base}, not ingested")
    with open(os.path.join(ws.log, "WIKI-INGEST-QUEUE.md"), "w") as f:
        f.write(f"# WIKI INGEST QUEUE\n\nCompiled by icm_librarian.py on {NOW:%Y-%m-%d %H:%M}. Overwritten every run.\n\n"
                f"Backlog baseline {base}. Files waiting {n}. Record each ingest in `_log/WIKI-INGEST-STATE.json` "
                "under ingested, path to date.\n\n## Stale\n\n")
        f.write("".join(f"- `{a}` updated {u}, newer: " + ", ".join(f"`{s}` {d}" for s, d in nw) + "\n"
                        for a, u, nw in stale) or "None.\n")
        f.write("\n## Parked (superseded or history)\n\n" + ("".join(f"- `{p}`\n" for p in parked) or "None.\n"))
        f.write("\n## Queue by folder\n")
        for top in sorted(queue, key=lambda k: -len(queue[k])):
            items = sorted(queue[top], reverse=True)
            f.write(f"\n### {top} ({len(items)})\n\n" + "".join(f"- {d} `{p}`\n" for d, p in items[:25]))
            if len(items) > 25:
                f.write(f"- and {len(items) - 25} more\n")
    return {"base": base, "queue": n, "stale": stale, "parked": parked}


# ------------------------------------------------------------------ registry
def registry(ws, text):
    skills = []
    for p in ws.walk(skip_top=False):
        if os.path.basename(p) != "SKILL.md":
            continue
        r = ws.rel(p)
        name = os.path.basename(os.path.dirname(p)) or "(root)"
        with open(p, errors="replace") as f:
            m = re.search(r"^name:\s*\"?([^\"\n]+)", f.read(2000), re.M)
        if m:
            name = m.group(1).strip()
        uses = text.count(os.path.dirname(r) or r) + text.count(f"| {name} |")
        skills.append((r, name, mdate(p), uses))
    never = [s for s in skills if s[3] == 0]
    with open(os.path.join(ws.log, "SKILL-TOOL-REGISTRY.md"), "w") as f:
        f.write(f"# SKILL REGISTRY\n\nCompiled by icm_librarian.py on {NOW:%Y-%m-%d %H:%M}. Overwritten every run.\n\n"
                f"Skills {len(skills)}, never in the ledger {len(never)}.\n\n"
                "| Path | Name | Changed | Ledger mentions |\n|---|---|---|---|\n")
        f.write("".join(f"| `{r}` | {n} | {d} | {u} |\n" for r, n, d, u in sorted(skills)))
    return skills, never


# ------------------------------------------------------------------ handoff
def handoff(ws, ctx):
    with open(os.path.join(ws.log, "HANDOFF.md"), "w") as f:
        f.write(f"# HANDOFF\n\nCompiled by icm_librarian.py on {NOW:%Y-%m-%d %H:%M}. Overwritten every run. "
                "Any agent or person arriving reads this after IDENTITY.md and CONTEXT.md. The ledger is the record; "
                "this is the summary.\n\n## Findings\n\n")
        f.write("".join(f"- {x}\n" for x in ws.findings) or "None.\n")
        sections = [
            ("Open misses (no Patched line yet)", [f"{r[0]} sev {r[2]} `{r[3]}`: {r[4]}" for r in ctx["open_m"][-15:]]),
            ("Miss lines the forge cannot count", [f"{r[0]}: {r[1][:120]}" for r in ctx["private"]]),
            ("Work that never wrote on the way out", [f"{d}: {n} files, no ledger line naming {fol}" for d, n, fol in ctx["silent"]]),
            ("Second ledgers", [f"`{p}`" for p in ctx["second"]]),
            ("Proposals waiting on a human", [f"{i} `{p}` {a} days" for i, p, a in ctx["props"]]),
            ("Broken links on disk", [f"`{p}`" for p in sorted(set(ws.broken))[:10]]),
        ]
        for title, items in sections:
            f.write(f"\n## {title}\n\n" + ("".join(f"- {x}\n" for x in items) or "None.\n"))
        if ctx["wiki"]:
            w = ctx["wiki"]
            f.write(f"\n## Wiki\n\n- Stale {len(w['stale'])}, parked {len(w['parked'])}, backlog {w['queue']} since {w['base']}. "
                    "See `_log/WIKI-INGEST-QUEUE.md`.\n")
        f.write(f"\n## Skills\n\n- {len(ctx['skills'])} on disk, {len(ctx['never'])} never logged. See `_log/SKILL-TOOL-REGISTRY.md`.\n")
        f.write("\n## Last 12 ledger lines\n\n```\n" + "\n".join(ln[:300] for ln in ctx["tail"]) + "\n```\n")
        f.write("\n## Arrival checklist\n\n"
                "1. Read `IDENTITY.md`, `CONTEXT.md`, this file, then the job card in the folder you work in.\n"
                "2. Grep the tree for the topic before creating any file.\n"
                "3. Before your last reply, run the Session Close: one ledger line naming every folder you changed, "
                "misses in the exact Miss shape.\n"
                "4. Never edit a rule book. Proposals go to `_log/FORGE-PROPOSALS.md`.\n")


def main(argv):
    if len(argv) > 2 or (len(argv) == 2 and argv[1] in ("-h", "--help")):
        print(__doc__)
        return 0 if len(argv) == 2 else 2
    root = argv[1] if len(argv) == 2 else "."
    if not os.path.isdir(root):
        fail(f"no such directory: {root}")
    ws = Workspace(root)
    if not os.path.isdir(ws.log) or not os.access(ws.log, os.W_OK):
        fail(f"cannot write {ws.rel(ws.log)}/ (missing, or blocked by the OS)")
    text, rows = read_ledger(ws)
    private, open_m = ledger_shape(ws, rows)
    silent = silent_sessions(ws, text)
    second = second_ledgers(ws)
    props = proposals(ws)
    w = wiki(ws)
    skills, never = registry(ws, text)
    tail = [ln for ln in text.splitlines() if ln.startswith("| 20") or ln.startswith("<!-- 20")][-12:]
    if ws.broken:
        ws.findings.append(f"{len(set(ws.broken))} broken link(s) on disk")
    handoff(ws, dict(private=private, open_m=open_m, silent=silent, second=second, props=props,
                     wiki=w, skills=skills, never=never, tail=tail))
    for x in ws.findings:
        print(f"FAIL {x}")
    print(f"{'ok  ' if not ws.findings else 'warn'} wrote _log/HANDOFF.md, {len(ws.findings)} finding(s)")
    return 1 if ws.findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

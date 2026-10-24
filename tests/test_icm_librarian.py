import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "icm_librarian.py"
TODAY = dt.date.today().isoformat()
OLD = (dt.date.today() - dt.timedelta(days=20)).isoformat()

LEDGER = f"""# LOOP LEDGER

## Lines

| {TODAY} | built the onboarding pack in sales | 2 | cash | 1 | 0/0/0/0 | 0 | none | `sales/pack.md` |
| {TODAY} | wrote copy without checking voice | 2 | _config/voice.md | no voice check | read voice first |
| {TODAY} | Miss | 2 | _config/style.md | em dash shipped | ban it in decks |
"""

PROPOSALS = f"""# FORGE PROPOSALS

## Proposals

## FP-{OLD}-01 | _config/voice.md
- Status: proposed
- Kind: edit

## FP-{TODAY}-01 | _config/style.md
- Status: proposed
- Kind: edit
"""


class LibrarianTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="icm librarian "))  # space on purpose
        ws = self.tmp
        (ws / "_log").mkdir()
        (ws / "_log" / "LOOP-LEDGER.md").write_text(LEDGER)
        (ws / "_log" / "FORGE-PROPOSALS.md").write_text(PROPOSALS)
        shutil.copy(ROOT / "icm.defaults.json", ws / "icm.defaults.json")
        for d in ("sales", "ops", "demo/00_Master", "raw/t", "wiki/t"):
            (ws / d).mkdir(parents=True)
        (ws / "sales" / "pack.md").write_text("# pack\n")
        (ws / "ops" / "notes.md").write_text("# notes\n")
        (ws / "demo" / "00_Master" / "LOOP-LEDGER.md").write_text("# local ledger\n| x |\n")
        (ws / "skills-home").mkdir()
        (ws / "skills-home" / "SKILL.md").write_text("---\nname: pack-builder\n---\n")
        (ws / "LAW.md").write_text("# law\n")
        (ws / "wiki" / "log.md").write_text("# Wiki log\n\n## [2026-01-01] ingest | Law\n")
        (ws / "wiki" / "index.md").write_text("# index\n")
        (ws / "wiki" / "t" / "law.md").write_text("# Law\n\n> Sources: LAW.md\n> Updated: 2026-01-01\n")
        (ws / "wiki" / "t" / "old.md").write_text("# Old\n\n> Sources: LAW.md\n> Updated: 2026-01-01\n> Status: superseded on price\n")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_it(self):
        return subprocess.run([sys.executable, str(SCRIPT), str(self.tmp)], capture_output=True, text=True)

    def test_findings_and_exit(self):
        r = self.run_it()
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        out = r.stdout
        self.assertIn("1 miss line(s) in a private shape", out)
        self.assertIn("silent sessions", out)
        self.assertIn("second ledger", out)
        self.assertIn("1 proposal(s) waiting", out)
        self.assertIn("1 article(s) older than a live source", out)

    def test_handoff_content(self):
        self.run_it()
        h = (self.tmp / "_log" / "HANDOFF.md").read_text()
        self.assertIn("ops 1", h)               # ops changed, ledger never names it
        self.assertNotIn("sales 1", h)          # sales is named today
        self.assertIn("demo/00_Master/LOOP-LEDGER.md", h)
        self.assertIn("_config/style.md", h)    # open miss, no Patched line
        self.assertIn("Arrival checklist", h)

    def test_superseded_is_parked_not_stale(self):
        self.run_it()
        q = (self.tmp / "_log" / "WIKI-INGEST-QUEUE.md").read_text()
        self.assertIn("wiki/t/old.md", q.split("## Parked")[1])
        self.assertNotIn("wiki/t/old.md", q.split("## Parked")[0])

    def test_rewritten_miss_settles_private_shape(self):
        led = self.tmp / "_log" / "LOOP-LEDGER.md"
        led.write_text(led.read_text() + f"| {TODAY} | Miss | 2 | _config/voice.md | rewritten from the {TODAY} private shape line | read voice first |\n")
        r = self.run_it()
        self.assertNotIn("private shape", r.stdout)

    def test_ingest_state_clears_queue(self):
        self.run_it()
        sp = self.tmp / "_log" / "WIKI-INGEST-STATE.json"
        st = json.loads(sp.read_text())
        st["ingested"] = {p: TODAY for p in ("sales/pack.md", "ops/notes.md", "demo/00_Master/LOOP-LEDGER.md")}
        sp.write_text(json.dumps(st))
        self.run_it()
        q = (self.tmp / "_log" / "WIKI-INGEST-QUEUE.md").read_text()
        self.assertIn("Files waiting 0", q)

    def test_registry_lists_nested_skill(self):
        self.run_it()
        reg = (self.tmp / "_log" / "SKILL-TOOL-REGISTRY.md").read_text()
        self.assertIn("skills-home/SKILL.md", reg)
        self.assertIn("pack-builder", reg)

    def test_writes_only_under_log(self):
        before = {p for p in self.tmp.rglob("*") if "_log" not in p.parts}
        snap = {p: p.stat().st_mtime for p in before if p.is_file()}
        self.run_it()
        after = {p for p in self.tmp.rglob("*") if "_log" not in p.parts}
        self.assertEqual(before, after)
        for p, m in snap.items():
            self.assertEqual(p.stat().st_mtime, m, p)

    def test_usage_errors(self):
        r = subprocess.run([sys.executable, str(SCRIPT), str(self.tmp / "nope")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        r = subprocess.run([sys.executable, str(SCRIPT), "a", "b"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()

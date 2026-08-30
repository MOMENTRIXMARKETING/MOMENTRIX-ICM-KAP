# NOTICE

The **Momentrix ICM KAP Toolkit** is built from three MIT-licensed upstream projects.
Each is reproduced in full below, as MIT requires for substantial portions.

---

## 1. Model Workspace Protocol / Interpretable Context Methodology

Jake Van Clief and David McDermott.
Upstream: https://github.com/RinDig/Model-Workspace-Protocol-MWP-

**The five-layer model, the stage contract, the fifteen conventions, and the
`{{PLACEHOLDER}}` onboarding system are theirs, not ours.** This toolkit implements
and extends that methodology; it did not invent it.

Derived files: `spec/CONVENTIONS.md`, `spec/placeholder-syntax.md`,
`interview-templates/CONTEXT.stage.md.tmpl`, `interview-templates/questionnaire.md.tmpl`, `docs/methodology.md`.

```
MIT License

Copyright (c) 2026 Model Workspace Protocol Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 2. karpathy-llm-wiki

Yuhan Lei. Upstream: https://github.com/Astro-Han/karpathy-llm-wiki

The raw/wiki architecture, the grounding invariant, the three-tier lint authority
model, and the evidence verifier come from this project.

Vendored unchanged: `scripts/check_evidence.py`, `tests/test_check_evidence.py`.
Derived: `spec/grounding-invariant.md`, `interview-templates/wiki/*.tmpl`, `skills/icm-wiki/SKILL.md`.

The underlying idea is **Andrej Karpathy's** — the LLM writes and maintains the wiki,
the human reads and asks questions; the wiki is a persistent, compounding artifact.
Idea credit, not a licence obligation. The KAP in this toolkit's name is for Karpathy.

> Not vendored, deliberately: `assets/karpathy-tweet.png` (third-party image, separate rights).

```
MIT License

Copyright (c) 2026 Yuhan Lei

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 3. icm-template

Kevin Nguyen (ktncodes). Upstream: https://github.com/ktnCodes/icm-template

The conversational scaffolder — the setup interview and the sync/gap-fill loops —
originates here. Derived: the bodies of `skills/icm-scaffold/SKILL.md`,
`skills/icm-sync/SKILL.md`, `skills/icm-context/SKILL.md`.

```
MIT License

Copyright (c) 2026 Kevin Nguyen (ktncodes)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 4. Research paper

`docs/paper/Interpretable-Context-Methodology.pdf` — *"Interpretable Context Methodology:
Folder Structure as Agent Architecture"*, Van Clief & McDermott. Redistributed from the
upstream MWP repository. It is the authors' work, not covered by this repo's licence.

> Author affiliation is deliberately not stated here. The claim "Eduba, University of
> Edinburgh" appears in icm-template's README and we could not verify it against the
> paper. Cite the authors and the repository, not an institution.

---

## 5. Original to this repo

Not derived from any upstream, written for this toolkit and covered by this repo's MIT
licence: the shell layer (`scripts/icm_lib.sh`, `scripts/icm-check.sh`, `scripts/icm-plan.sh`,
`scripts/icm-apply.sh`, `scripts/icm-rollback.sh`), the POSIX test harness
(`tests/run-tests.sh`), `icm.defaults.json`, `BUILD-CONTRACT.md`, and this repo's own layer 0
and layer 1 files (`IDENTITY.md`, `CONTEXT.md`, `CLAUDE.md`).

`examples/` holds one worked pair written here: `examples/raw/2026-08-30-icm-defaults-budgets.md`
is a raw capture of this repo's own `icm.defaults.json`, and
`examples/wiki/icm-defaults-budgets.md` is the article compiled from it. It is a real reading of a
real file, not an invented document, so the grounding invariant can be demonstrated against
something a reader can check.

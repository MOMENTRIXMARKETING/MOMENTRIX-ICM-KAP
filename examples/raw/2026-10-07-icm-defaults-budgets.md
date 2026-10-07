# Budgets block of icm.defaults.json

> Source: `icm.defaults.json` at the root of momentrix-icm-kap-toolkit
> Collected: 2026-10-07
> Published: 2026-10-07

Raw capture, collected 2026-10-07. This is the worked example that ships with the toolkit, and it is a real
reading of a real file in this repo rather than an invented document. It is here so the
grounding invariant can be demonstrated end to end: this file is the evidence, and
`examples/wiki/icm-defaults-budgets.md` is the article compiled from it. It supersedes the
reading of 2026-08-30, which was true when it was taken and is kept beside it unedited.

## The budgets block

Each entry names a kind of layer file and gives it a target and a ceiling, both counted in
characters.

- IDENTITY.md: target 3200, ceiling 6000.
- CONTEXT.root.md: target 4400, ceiling 8000.
- CONTEXT.stage.md: target 1200, ceiling 2000, and a line ceiling of 80.
- CONTEXT.folder.md: target 1200, ceiling 2000.
- rulebook.md: target 2000, ceiling 4000.
- wiki_article.md: target 8000, ceiling 16000.

## The loading budget block

The block carries a note reading "Chars, not tokens. 4 chars ~= 1 token. Layers 0+1+2+3 are the fixed cost."

It then sets layer0_identity to 3200, layer1_context to 4400, layer2_stage to 1200 and
layer3_rulebooks to 4000, and states fixed_total as 12800. The final key, layer4_varies, is
set to true, because layer 4 is whatever the job actually needs.

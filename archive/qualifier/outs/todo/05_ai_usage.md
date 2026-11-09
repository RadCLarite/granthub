# AI usage disclosure

This project used AI in two different roles. They are disclosed separately because
they carry different risks.

## 1. AI inside the analysis: a local model that labels opportunities

**What it does.** A language model reads each candidate opportunity's abstract and, where
one exists, an excerpt of its full announcement (NOFO). It returns a fixed set of
fields: whether a state agency could lead it, program domain, owning division, required
capabilities, whether it requires subrecipients, evaluation, construction, a formal
designation, or matching funds (with a verbatim quote as evidence), the population it
serves, and how strongly it aligns with each agency's strategic plan (with the plan row
cited and a one-sentence rationale).

**Which model.** `qwen2.5:14b` (Q4_K_M quantization) run locally through Ollama on a
laptop. No opportunity text was sent to a paid or cloud service. Plan-alignment
similarity scores use a second local model, `nomic-embed-text`.

**Scope.** Only the candidate set is labeled: state-eligible, not NIH, and either open at
the pull date or forecasted (278 opportunities, plus the three VA-issued ones). The other
1,300+ opportunities are handled by deterministic rules only.

**Controls on the model.**
- Output must match a JSON schema with closed vocabularies (8 domains, 14 capabilities,
  14 populations, the plan's own row IDs). The model cannot invent a category.
- Temperature 0 and a fixed seed.
- Evidence fields must quote the source text verbatim, so a human can check them.
- Every response is cached on disk under a hash of the model version, prompt version,
  and exact prompt. Re-rendering the notebook never calls the model and cannot change a
  label. The cache is committed so a teammate can reproduce every number without the model.
- The model never decides a tier. Tiers come from written rules applied to the labels
  (`src/tool/tiering.js`), and every tier shows the rules that fired.

**How we checked it.** Sixty opportunities were drawn at random (stratified by status,
issuing agency, and whether a full announcement exists) and labeled by team members who
had not seen the model's answers. The notebook reports accuracy, per-class precision and
recall, and confusion matrices against those hand labels, and quotes real cases where the
model was wrong.

**Known weaknesses.** The model can over-read alignment (in testing it once linked an
economic development grant to health equity). That is why an opportunity only enters an
agency's view if the model also places it in one of the eight program domains, and why
the alignment rationale is shown to the user rather than hidden inside a score.

## 2. AI as a development assistant

The team used Claude (Anthropic) through Claude Code as a coding and research assistant.

**What Claude did:** wrote most of the R pipeline, the JavaScript tier engine and
interface, and the build and test scripts; checked the verified facts against the data;
drafted the strategic-plan tables and the agency capability profile from the source
documents and public web pages; found sources; and drafted parts of this notebook's prose.

**What the team decided:** the user and the three-pile framing (from our interview), the
five success criteria, the eight program domains, each capability's control level, every
threshold and default in `src/R/00_config.R`, and what to cut. Claude was instructed to ask
rather than choose on these, and did.

**What humans verified:**
- The 24 verified facts were computed independently before the build. The code must
  reproduce them, and one discrepancy (match-percentage mentions: 6, not 1) was checked by
  hand before the table was corrected.
- The strategic-plan tables and capability profile carry a `human_verified` flag and
  source links for review.
- The 60 hand labels are human work, done blind.

**Where AI-drafted material could still be wrong:** the capability control levels
characterize real agencies from public sources, not from interviews with agency staff.
The $1M appropriation line is a stated assumption, not a published rule. Both are
editable in the tool's Assumptions panel.

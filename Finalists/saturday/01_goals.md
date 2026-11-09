# Goals

## The 1:00 gate (decision 1)
A working prototype means all of these:
- [ ] The Azure URL loads. A person picks an agency (32 in the picker) and sees its top 10 open opportunities.
- [ ] Each row shows days left (or "rolling or no date listed"), eligibility (Yes, No, or Ask), and the plan goal it matched with a snippet.
- [ ] `payload.json` comes from the real pipeline, not the stub, and a rerun from cache gives the same file.
- [ ] The award-history backtest result for DPI, DEQ and DHHS is computed against the pass bar below, with both baselines.
- [ ] DERA (`EPA-OAR-OTAQ-26-01`) appears in the ranked list for DEQ and DPI. Tribal-only items are hidden. 2099 dates read "rolling or no date listed".

Fallback at 12:45 if short: the URL by 1:00, the backtest number by 2:00.

## Stretch by about 1:00: match board (decision 11)
Not part of the gate. Build it on top of the picker and top 10; never at their expense.
- [ ] Two columns: plan goals and typed projects (saved in the browser) on the left, grants on the right.
- [ ] Click a project and the grants rank. Click a grant and the projects rank, with fits grouped by agency.
- [ ] Left column labels plan goals as "Plan goals" and typed items as "Your projects". Scores are never compared across the two directions.
- [ ] Agency is one dropdown with "All NC" as an option; role is an optional line that changes display only.
- [ ] Checklist and backward timeline for Pursue rows: one hand-built example row only, from notice fields with quotes; anything else marked `[assumed]`, no hours claimed.
If not working at 12:45 go / no-go, cut it and ship the gate.

## Stretch by about 1:00: qualifier features (decision 12)
Gate features (agency dropdown, order-by toggle, rule per row, drawers, deadline badges, CSV export, signature tier label) are part of the gate list in decision 12. Everything below is stretch and is cut with the match board at 12:45.
- [ ] Impact score, "What matters most?" and impact sliders, program priority weights per agency, reset to defaults.
- [ ] Capability-gap table, alignment percent to the agency plan, drawer search, "How this works" tab, larger-text mode.
- [ ] County reach, need map, reach vs intensity scatter.
- [ ] One collapsed "Refine (optional)" panel: constraints, include forecasts, scenario box, presets, assumptions. Ranking works with it closed.
- Data limits: see `05_open_questions.md` risks. A feature without data for an agency shows "not available for this agency", never blank or guessed.

**Cut order at 12:45:** match board first, then the rest of the stretch list above, then the gate fallback (URL by 1:00, number by 2:00).

## Backtest pass bar (decision 7, set before the run)
- Per agency (DPI, DEQ, DHHS): at least **50%** of the agency's won programs that had an open notice in the backtest period appear in its top 10 at least once, using 4-week windows.
- Pass if **2 of 3** agencies hit it.
- Report counts and a binomial interval beside each. Report two baselines from the same script: soonest-deadline top 10 and a random 10 (fixed seed).
- 50% is a team judgment, not derived. Say so on the slide and in Q&A.

## End of build, 6:00
In this order of priority:
1. Daily Container Apps Job (`MODE=job`) refreshes, scores and writes `payload.json` to Blob with "data as of". Triggered once by hand if the schedule can't be shown.
2. Closing-soon and new-since-last-visit panel (browser localStorage, no email).
3. In-time curve: all catches versus in-time catches (at least 21 days left), at 2, 4 and 6 weeks. X = 21 is a team assumption.
4. Notice reader, advisory only (decision 9): label plus a script-checked quote on "Ask" items. Never hides.
5. Pursue / Maybe / Pass button per row (09 proposal 7).
6. Fact sheet with every number traced to a script. Slide brief with figures in `outs/figures/`.
7. Field notes `[TO FILL]` items done, including one place the AI was wrong.

## Cut order (first cut first)
Presets, LLM signature-tier upgrade, model-label scale-up, Azure chat reasons (keyword snippets instead), feedback endpoint and Rocchio, Azure embeddings swap.

## Never cut
Keyword-fit table with the agency picker, hide-ineligible with "Ask", the backtest result, the daily job, the closing-soon panel, the Pursue / Pass button, and the quote check on any AI text that ships.

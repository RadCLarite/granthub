# Mentor demo sheet (Sat Nov 7, before 4 pm)

Goal: the mentor drives the live tool and tells us what breaks, confuses or does not earn trust. Mentors are not agency users. Log answers in `mentor_log.md` as mentor input, never "users said".

Live tool: https://ffm-app.bluepebble-2cbaa7af.eastus.azurecontainerapps.io/ (data as of 2026-11-07 11:00). Checked in a browser: 32 agencies in the picker, DEQ shows DERA first with "Not sure we can apply: read the notice".

## Before they sit down (2 minutes)
- Open the URL once so the container is warm. Cold start was 38 seconds at min replicas 0.
- Turn on Projector view if they will watch over a shoulder.
- Silence rule: say nothing during the timed task.

## Script (10 minutes)
1. Hand them the keyboard. Task (I4): "Find one grant to act on for DPI or DEQ." Start a timer. Note every pause and question in `mentor_log.md`, "Timed task".
2. Ask I3: "Pick an agency. What is the first thing that confuses you?"
3. Ask I5: "An LLM reads eligibility and we show its quote. What would make you trust that, or not?"
4. Ask I2: "What would make a budget director fund a 60-day pilot? What proof did your last approved pilot need?"
5. Ask I1: "Which costs more: chasing a bad lead or missing a good one? Does that change the top-10 cap?"

## Slot map (from 04_mentor_questions.md)
- 11:00 to 12:00 Rhett Lavender: I1, I2, I3.
- 2:00 to 4:00 Aries Rosales: I4, I5. Jo Kwon (faculty): F3. Haihan Gao or Girish Wangikar: T4, T5.
- Whoever is in front of us gets their top question first.

## Say out loud (known gaps, do not wait to be asked)
- Backtest fails our own pre-set bar: 1 of 3 agencies at 4 weeks; the soonest-deadline baseline beats the model in 3 of 3 (rows 15, 16). After the Sat evening ranking fixes a rerun reaches 2 of 3; we report the pre-set result. Wider exploratory test: Top 10 reaches 61 of 157 won programs (row 26).
- Held-out label check fails its gate.
- 0.5 geography factor and 0.8 DERA floor are team judgments, not derived.
- Daily job re-scores cached data only.
- Mentor feedback is not user evidence.

## Check before they arrive
- [ ] Picker label for DPI: the picker reads "Department of Public Schools". [uncertain] NC's DPI is Public Instruction. Confirm the display name is intended.
- [ ] `Finalists/handoff.md` status table is Friday-stale; use `saturday/` as the source of truth.
- [ ] Field notes, README and QA cheatsheet exist only as drafts in `drafts/claude/docs/`; not yet promoted to the submitted locations.

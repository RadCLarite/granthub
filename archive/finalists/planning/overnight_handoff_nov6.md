# Overnight handoff: Fri Nov 6 to Sat Nov 7, 2026

Written Fri 10:11 pm by Claude for Marco. This is a snapshot taken just after the overnight work started, so check the "Where to look" section for anything newer.

Full plan: `/Users/marcogullotto/.claude/plans/you-are-only-working-iridescent-moon.md`

## The goal tonight
Prove an R Shiny app with real data runs on Azure at a public URL, then write a Saturday plan for Marco to confirm. This answers whether the R stack holds, which is still unproven.

**Not happening tonight:** the real Finals app, scoring or ranking, Azure OpenAI.

## State at 10:11 pm
| Item | State |
|---|---|
| Pull from main | Done, at `ccad3b2` |
| Budget alert `ffm-guard` | Exists on the subscription; its thresholds were not re-read |
| Proof app files in `app/` | Not written yet (still the hello skeleton) |
| Image in the registry | None |
| Container App `ffm-app` | None; no public URL yet |
| Commits or pushes tonight | None; `marco_testing` is not on GitHub until the first push |
| Sleep hold | Running until 7:15 am |
| 7:00 am timer | **Unconfirmed**; see "Risks" |
| Spend tonight | Not known. Baseline was $6.67 at 9:50 pm; the latest cost read returned nothing |

## What happens next, in order
1. A Sonnet subagent writes the proof app, stages two files, builds the image and deploys `ffm-app`.
2. It checks the live app against the pass/fail list below and updates `src/docs/azure_setup.md` and `AI_USAGE_LOG.md`.
3. The main session tests the page in a browser, then commits and pushes to `marco_testing`. No PR tonight.
4. The main session writes `planning/08_saturday_plan.md`. Nothing in it runs until Marco confirms.
5. At 7:00 am it writes `planning/overnight_summary_nov7.md` and posts the same summary in the session.

## What the proof must show
- `/` and `/tool.html` return 200 over HTTPS.
- The page shows `MODE = app`, and the table filters in a browser.
- Row counts: 6,523 total; 884 posted, 588 forecasted, 4,947 closed, 104 notice.
- Cold-start and warm load times are recorded. A slow start is reported as a finding.
- No key appears in the image, commits or docs.

**Will stay untested tonight:** `MODE=job` in the cloud, venue Wi-Fi or hotspot, and V8 on Azure.

## Limits
- **Approved on Azure:** `ffm-guard`, image builds, `ffm-app`, its AcrPull identity, and the registry admin fallback. Nothing else, and no deletes.
- **App size:** 0.5 vCPU, 1 GiB, min 0 and max 1 replicas.
- **Builds:** at most 5.
- **Spending:** cap of $100 added tonight; about $5 expected. Work stops at $25. At $75, or on an unexplained jump, the app is shut off and all work stops.
- **Azure will not enforce the cap.** The subscription's spending limit is off, alerts only send notices, and cost data lags by hours. The limits above are what keep spend down.
- **Git:** push to `marco_testing` only. Never `main`, and no force-push.

## When the work stops early
It stops and records the exact error if the `az` login expires, a cloud build is refused or still fails after one fix, both registry pull routes are refused, a step needs something not approved, or a sixth build would be needed. It does not switch to Python. The Saturday plan and 7:00 am summary should still get written.

## Risks
- **Interrupted background tasks:** this handoff was written in a forked session, which reported the subagent and timers as stopped. The sleep hold was still running and `ffm-guard` had just appeared, which suggests the original session is still working, but that is not confirmed. If no summary exists by about 7:15 am, open the original session and ask for status.
- **Mac asleep:** keep it plugged in with the lid open. A closed lid can still put it to sleep.
- **Approvals:** the session is in auto mode, so `az` steps may not prompt one by one, despite what the plan says.
- **Login:** if `az` expires, Marco has to approve Duo. Cost checks and the shut-off stop working too, but max 1 replica holds the app to about $0.05 per hour.

## Marco on Saturday morning
1. Read the 7:00 am summary and `planning/08_saturday_plan.md`, and confirm the plan.
2. Open the URL on your phone. Run `az login` if needed. Check Cost analysis.
3. At the 9:00 check-in, ask: is Azure OpenAI ours to create, and does R Shiny hold?

## Where to look
- Results and spend: `src/docs/azure_setup.md`
- Morning: `planning/overnight_summary_nov7.md`, `planning/08_saturday_plan.md`
- Team framing: `planning/02_framing_worksheet.md` (6 of 7 gate boxes ticked on a Claude draft; the mentor box is open, and `[assumed]` lines are not sponsor-approved)

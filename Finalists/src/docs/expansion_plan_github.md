# Federal Funds Matchmaker: expansion plan, GitHub edition

Written 2026-11-08. Planning only. This edits the post-competition expansion plan so every part runs on GitHub (Pages, Actions, repo, Releases, Secrets) and none runs on Azure. It replaces every Azure reference in that plan. Sections not named here (entity stages 2 to 5, evidence panel, navigation, charts, sources, trust, patterns, appendices) stand as written, except that anything they say about a server, login, database or email follows section 3 below.

Items marked [uncertain] are from memory of GitHub's current limits and terms. Verify before relying on them.

## 1. What GitHub can and cannot do

GitHub can do:
- Host static pages (Pages) and rebuild them on a schedule (Actions cron).
- Run R, Python and Node jobs on a schedule or on demand, with encrypted secrets (Actions secrets). Secrets stay in the job and never reach the page.
- Store data and cached model responses in the repo, and big artifacts in Releases.
- Take feedback and discussion through Issues and Discussions.
- Publish feeds (Atom, ICS) as static files on Pages.
- Run a free tier of hosted models for prototyping (GitHub Models) [uncertain: models, limits and terms change].

GitHub cannot do:
- Run a server or database. No API container, no per-user rows.
- Sign in people who have no GitHub account, or keep per-user private data.
- Gate a Pages site behind a login on a free or team plan. Pages from a public repo is public. Private-audience Pages needs a higher plan [uncertain].
- Send email by itself. It can only run a job that calls an outside mail provider.
- Guarantee exact timing. Scheduled workflows are best-effort, can start late, and are paused after about 60 days without repo activity in public repos [uncertain].

Consequence: the product stays a static, public, browser-state tool. Features that need accounts, shared private state, live AI calls or exact-time email cannot be built on GitHub alone. Section 4 lists each one and the choice you must make.

## 2. Azure to GitHub swap table

| Old (Azure) | New (GitHub) |
|---|---|
| Container Apps `ffm-app`, Shiny | Pages site at `/matchmaker/` (built; see `Finalists/app/build_pages.sh`) |
| Blob Storage `payload.json` | File on Pages, rebuilt by the daily workflow |
| Container Apps Job, daily refresh | `pages.yml` cron `0 11 * * *`, `workflow_dispatch` for manual runs |
| Container registry, revisions, traffic split, rollback to v37 | Branch plus pull request, preview artifact, merge to `main` deploys. Rollback: revert the commit, or re-run an earlier successful deploy |
| Key Vault, managed identity | Actions secrets and `GITHUB_TOKEN` permissions. No key in any tracked file |
| Log Analytics feedback log | Issues with a template (see 3.5) |
| Table or Cosmos store | Browser storage with JSON export and import (see 3.2) |
| Entra External ID sign-in | None on GitHub alone (see 4) |
| Communication Services Email | Static feeds, plus optional outside mail provider called from Actions (see 3.4) |
| Azure OpenAI | Precomputed in Actions with GitHub Models or in-browser models (see 3.6) |
| Azure cost dashboard and budget switch | Actions minutes and Models rate limits; both free for a public repo [uncertain] |

## 3. Revised stages

### Stage 0: platform readiness check (was Azure readiness)
Half a day. Settle these before building anything else:
1. Confirm Settings > Pages > Source is GitHub Actions and the first workflow run succeeds. Record the live URL.
2. Decide public or private repo. Public: free Actions and Pages, but all data and code are public, so no user data ever goes in the repo. Private: Pages visibility and Actions minutes depend on the plan [uncertain].
3. Check Actions minutes and storage limits against the daily job (one run takes a few minutes).
4. Check whether GitHub Models is available to the account and which chat and embedding models it lists.
5. Decide who owns the repo after the team leaves (organization, not a personal account).
Output: one-page note with yes, no or fallback for each item. The Azure requirement in the quest brief is a separate question; see section 5.

### Deployment and rollback (replaces section 15)
- Work on a branch. Open a pull request. A pull-request workflow builds the site and runs checks (`tests/run_tests.R`, `check_facts.R`, the Open plan download test, the duplicate-function scan) but does not deploy.
- Merge to `main` deploys. The deploy job fails closed: if scoring or the payload contract check fails, the previous deployment stays live.
- Rollback is a revert commit or a re-run of an earlier green deploy. No rebuild of images.
- Record each deploy (commit, date) in `handoff.md`. The workflow run log is the audit trail.

### Stage 6: backend (replaced by "build pipeline and data jobs")
No API container. Instead:
- All server-side work is Actions jobs reading and writing the repo and the Pages artifact.
- Secrets (Grants.gov, SAM.gov, any model token) live in Actions secrets. Jobs that call outside services run only on manual dispatch or a weekly schedule, and write responses to `data/cache/` first, as the repo rules require.
- Add a scheduled synthetic check workflow: load the live site, confirm `data_as_of` is recent, fail loudly (GitHub emails workflow failures to the repo owners) if not.
- Dependency scan: Dependabot and code scanning on the repo [uncertain on plan limits].
- Data-protection note: the site stores nothing about users. State this plainly. The retention and deletion policy question disappears for server data and remains only for what a user keeps in their own browser.

### Stage 7: login and saved dashboard (replaced by "saved work without accounts")
- Marks, notes, plans and projects live in browser storage, as they do now.
- Add Export and Import of one JSON file so work moves across devices and survives a cleared browser. This is the sync mechanism.
- Optional for GitHub users: save the JSON to a private Gist through the Gist API using the user's own token pasted into the page [uncertain: token handling in the browser is a security risk; do not build without a security review]. Default is the file export.
- Acceptance: export on one browser, import on another, same projects appear; no network call needed.

### Stage 9 and 18: digest and notifications (replaced by feeds)
No per-user email on GitHub alone.
- The daily workflow writes one Atom feed and one ICS calendar per applicant profile (agency now, county, city, district later) to `/matchmaker/feeds/`. Feed items: closing soon, new high-match grants, changed grants. ICS holds deadlines for tracked-by-default sets.
- A user subscribes in any feed reader or calendar app. No account, no stored address, no unsubscribe problem.
- The weekly digest is also published as a GitHub Release or Discussion post. Users who have GitHub accounts can Watch the repo to get it by email from GitHub.
- Per-user times, quiet hours, mentions and review alerts are not possible. Drop them.
- Optional: a weekly workflow sends one email to an allow-listed list through an outside provider using an Actions secret. This adds a non-GitHub service and a stored address list. It needs your approval and a privacy owner. Default is off.
- Every feed item states the data date. No tracking pixels exist because there is no email.

### Stage 8: AI layer (replaced by batch and in-browser AI)
Live per-user calls need a server and a key, so they are out. What fits:
- Meaning-based matching: compute embeddings for grants and profiles in an Actions job and cache the vectors in the repo. The page loads the vectors and compares in the browser. Embedding source: GitHub Models if an embedding model is available, else a local model in the job [uncertain]. Same rules as before: separate from the score, quoted evidence, evaluate against the backtest, do not ship if it does not help.
- Requirements checklist and section-draft scaffolds: run in a manual Actions job per grant with quotes verified as verbatim substrings, then published as static JSON the page reads. The user cannot request a new draft live.
- Chatbot: not built in the default design. Options if wanted: an in-browser small model (WASM, slow, weak), or a bring-your-own-key mode where the user pastes their own provider key and the browser calls the provider directly [uncertain: provider CORS rules; key exposure is the user's risk]. Treat as deferred.
- Writing helper: templates that need no AI ship first and are fully static. AI drafting follows the batch rule above or bring-your-own-key.
- Guardrails unchanged: retrieval first, citation, refusal, injection test set, every use logged in `AI_USAGE_LOG.md`.

### Stage 12: tracker (reduced)
Browser-only tracker with the stage board, tasks, outcomes and the export file from stage 7. Single user, single browser at a time. No assignees, no shared board.

### Stage 19: workspaces, collaboration, reviewers (not possible on GitHub alone)
Roles, invites, guest review links, comments and approval chains all need accounts and shared private state. Two honest options:
- A. Drop the stage. Offer a printable one-pager (stage 33) and the exported project file that a reviewer can open in the page read-only.
- B. Use GitHub itself as the collaboration space: one private repo per workspace, reviewers as repo collaborators, comments as Issues and Pull Requests, signatures as required approvals on a pull request. This works only for people who have GitHub accounts, which most county staff do not [uncertain]. Not recommended as a general product.
Default: option A.

### Stage 25: content library (reduced)
A library of approved text kept in the user's browser and in their exported file. No shared library, no file uploads to a server. Stale-text badge and "approved for reuse" flag stay.

### Stage 30: statewide view for OSBM (replaced)
There is no per-agency data to roll up because nothing is stored server-side. The OSBM view is built only from public data: the payload, USAspending awards, and the under-represented-programs analysis. Opt-in sharing needs an outside collector and is dropped. If an agency wants to share, it emails its exported project file.

### Stage 35: measurement
Usage events need a collector, so none by default. Replace with: Actions run history (refresh success, data age), the synthetic check, the monthly backtest self-check workflow that publishes recall and precision to a page, and voluntary feedback through Issues. State plainly that real usage is not measured. The time study (Appendix B) becomes the main source of use evidence.

### Feedback (replaces the Azure log)
`FEEDBACK_ENDPOINT` stays empty. Add a "Report a problem or idea" button that opens a prefilled new-Issue URL in the repo using an issue template. It needs a GitHub account to submit. For non-GitHub users, say so and show the maintainer's contact. Do not put personal data in Issues; the form says so. `app/read_feedback.sh` and `app/pilot_scorecard.sh` are retired in favor of reading Issues.

### Stages that need no change
1, 10, 11 (without the shared project object), 13 (browser-only), 14 (browser-only calculator, PDF export from the page), 15, 16, 20, 21, 22, 23, 24, 26, 27, 28, 29 (browser-only), 31 (trust features, minus usage metrics), 32 (readiness package, rewritten for a static public site), 33, 34, 36, 37, 38.

## 4. Decisions only you can make

| Feature | GitHub-only result | What a non-GitHub fix would add |
|---|---|---|
| Login, saved dashboard across devices | Export and import file | A small hosted backend and sign-in service |
| Workspaces, reviewers, signature routing | Dropped (option A) | Same backend plus an email service |
| Per-user email digest at chosen times | Feeds and ICS, GitHub Watch | Outside mail provider and an address list |
| Live chatbot and live AI drafting | Batch outputs, in-browser, or bring your own key | A server holding a model key |
| Statewide sharing with OSBM | Public data only | A collector and an opt-in flow |
| Private or gated pages | Not possible on a free plan | A higher GitHub plan or another host |

Recommendation: ship the GitHub-only version through Phase 1 and the data stages (entities, sources, charts, trust, plans). Revisit a backend only after a real pilot user asks for sharing, since sharing is also where the privacy and government-review burden appears.

## 5. Risks added by this change

| Risk | Effect | Mitigation |
|---|---|---|
| Quest brief requires a working Azure prototype and judges Azure use | Submission could be marked down | Keep the Azure app live and unchanged until you confirm the rules allow dropping it. Say Pages is the post-competition path |
| Public repo and public site | Anything committed is public | No user data, no keys, no personal data in the repo. Check before every commit |
| Scheduled workflow paused or delayed | Stale data | Synthetic check, `workflow_dispatch`, commit activity, "data as of" on every page and feed |
| Browser-only state lost | User loses marks and projects | Export and import, one-click export reminder after edits |
| Feedback needs a GitHub account | Most users cannot report problems | Visible maintainer contact, and treat low feedback volume as a gap, not a signal |
| Free-tier limits change | Jobs or models stop | Cache every model response in the repo; core scoring uses no model |
| No sharing or review features | Limits the team-use story | State it as a known weakness with the tradeoff (simplicity, no privacy exposure) |

## 6. Revised order

Phase 0: platform check, fix `run_tests.R` on real data, duplicate-function scan (stem fixed), pull-request workflow, assumption register, synthetic check.
Phase 1: landing page, map as filter once reach data exists, task-named navigation, evidence panel, weights explanation, go/no-go and capacity (browser), readiness checklist, trust features, change tracking, demo profile, plan-date check, export and import.
Phase 2: counties, then cities and districts, other funders, more sources, plan versioning, continuity flags, partner finder, charts, feeds and ICS.
Phase 3: batch AI (meaning match, requirements checklist), template-based writing helper, return calculator with browser inputs, monthly self-check page.
Deferred until a real pilot asks: backend, accounts, workspaces, reviewers, email, live chatbot, statewide sharing.

Effort drops by roughly 35 to 50 working days from the earlier 140 to 205, because stages 6, 7 (server), 12 (shared), 18, 19, 25 (shared), 29 (server) and 30 shrink or go. [uncertain]

## No-Azure workarounds for backend items (status 2026-11-08)
| Plan item | Needs | Workaround on GitHub Pages | Status |
|---|---|---|---|
| Login, workspaces | accounts and a database | Browser storage plus Export/Import of a JSON file; share the file | Built |
| Share a list with a colleague | server | Download file, or mailto: link with a plain-text summary | Checklist email built; grant list: file only |
| Per-user email alerts | mail service | Atom and ICS feeds per agency in a reader or calendar app | Built |
| Feedback inbox | server | GitHub Issue form, prefilled from the dialog (issues are public) | Built |
| Readiness checklist | per-user storage | Browser-only tab, `ffm_ready_v1`, status, date checked and note per item | Built |
| Live AI chatbot | model endpoint and key | None without exposing a key in a public page; stays deferred | Deferred |
| Statewide opt-in sharing, reviewer roles | backend | None static; needs a hosted service the agency approves | Deferred |

Update 2026-11-08: Workbench built (tracker, time check, closing chart, print summary, content library). Calibrated odds not built: no outcome data. Why-not-shown view not built: payload carries only a count of hidden ineligible grants per agency, not the rows.

# Solve-A-Thon 2026: Team Setup Guide

This guide gets you from "I accepted the GitHub invite" to "I can make a change and send it to the team." No GitHub experience is needed. Do the steps in order. Part 1 is a one-time setup (about 30 to 45 minutes, mostly downloads). Part 2 is what you repeat every time you work.

If anything fails, stop and message Kent with a screenshot. Do not try random fixes.

## The 60-second idea

- **GitHub** is the shared copy of the project online. **Git** is the tool that syncs your computer with it.
- **Repository (repo)**: the project folder, tracked by Git.
- **Clone**: download the repo to your computer (once).
- **Branch**: your own private copy of the work, so you cannot break the main version. The main version is called `main`.
- **Commit**: save a snapshot of your changes with a short note.
- **Push**: upload your commits to GitHub.
- **Pull request (PR)**: a request to merge your branch into `main`. A teammate looks at it, then merges.

The one rule: **never work directly on `main`. Always make a branch.**

---

## Part 1: One-time setup

### Step 1. Install the software

Install these four things. Accept the default options in each installer.

| Software | Link | Notes |
|---|---|---|
| R 4.5 | https://cran.r-project.org/ | Pick your operating system. Version 4.5.x is required. |
| RStudio Desktop | https://posit.co/download/rstudio-desktop/ | Install R first, then RStudio. |
| Quarto | https://quarto.org/docs/get-started/ | Needed to build the notebook. |
| GitHub Desktop | https://desktop.github.com/ | The app we will use for Git. No command line needed. |

Windows only: also install **Rtools** from https://cran.r-project.org/bin/windows/Rtools/ (choose the version that matches your R). Mac only: if a popup ever asks to install "command line developer tools," click Install.

### Step 2. Sign in to GitHub Desktop

1. Open GitHub Desktop.
2. Click **Sign in to GitHub.com** and log in with the GitHub account that accepted the invite. Your browser will open and ask you to authorize. Click **Authorize**.
3. On the "Configure Git" screen, keep the name and email it fills in. Click **Finish**.

### Step 3. Clone (download) the project

The project is about 350 MB, so this takes a few minutes. Use a good internet connection.

1. In GitHub Desktop, click **File > Clone repository...**
2. Click the **GitHub.com** tab. You should see `KApolloL/SolveAThon_2026` in the list. Click it.
   - If it is not in the list, click the **URL** tab and paste: `https://github.com/KApolloL/SolveAThon_2026.git`
   - If it says you do not have access, tell Kent. The invite may not be fully accepted.
3. Under **Local path**, pick a folder you will remember, such as `Documents`. The project will be created inside it as `SolveAThon_2026`.
   - Do **not** put it inside OneDrive, iCloud Drive, Dropbox, or Google Drive. Syncing apps corrupt Git projects.
4. Click **Clone** and wait for it to finish.

### Step 4. Open the project in RStudio

1. Open the folder you cloned in your file explorer (Finder or File Explorer). In GitHub Desktop you can use **Repository > Show in Finder** (Mac) or **Show in Explorer** (Windows).
2. Open the `QualifierChallenge` folder.
3. Double-click **SolveAThon_2026.Rproj**. RStudio opens with the project loaded.

### Step 5. Install the R packages

In RStudio, find the **Console** pane (bottom left). Click inside it, paste this line, and press Enter:

```r
source("src/install_packages.R")
```

This installs about 32 packages and can take 10 to 20 minutes. Some lines of red text are normal. It is done when the `>` prompt comes back. If it says `All packages already installed.`, you are fine.

If you see an error containing the word `ERROR: compilation failed` or `installation of package ... had non-zero exit status`, copy the full error and send it to Kent. The packages most likely to cause trouble are `sf` and `V8`.

### Step 6. Check that everything works

In the same Console, paste these two lines, one at a time, pressing Enter after each:

```r
setwd("src")
source("R/check_facts.R")
```

You should see a line that says **24 of 24 rows pass**. That means your setup matches everyone else's. If you see anything else, send Kent a screenshot.

Then reset the working folder by pasting:

```r
setwd("..")
```

You do not need a Census API key, and you do not need to install Ollama. The saved results are already in the project.

Setup is finished. You do not repeat Part 1.

---

## Part 2: How to make a change (every time)

### Before you start: tell the team

Message the group chat saying which file you are editing, for example "I'm working on `src/R/04_scoring.R`." If two people edit the same file at once, their changes can collide and one person has to untangle it. The notebook file `src/solveathon_project.qmd` is the most likely to collide, so always claim it first.

### Step A. Get the latest version

1. Open GitHub Desktop. Make sure **Current Repository** at the top left says `SolveAThon_2026`.
2. Make sure **Current Branch** says `main`. If not, click it and choose `main`.
3. Click **Fetch origin** at the top. If it changes to **Pull origin**, click it again. This downloads everyone else's latest work.

### Step B. Make your own branch

1. Click **Current Branch** at the top, then **New Branch**.
2. Name it `yourname/what-you-are-doing`, all lowercase with dashes, no spaces. Example: `marco/fix-deadline-parsing`.
3. Click **Create Branch**. Current Branch now shows your new branch. Stay on it.

### Step C. Do your work

Edit files in RStudio as usual. To run code, follow the "Rebuild from scratch" section of `QualifierChallenge/README.md`. Two things to remember:

- Run scripts from the `src` folder (use `setwd("src")` in the Console, like in Step 6).
- Do not hand-edit anything in `outs/` or `docs/`. They are generated. Do not edit anything in `data/raw/`.

### Step D. Review what you changed

Go back to GitHub Desktop. The left side lists every file you changed, with checkboxes. Click a file to see exactly what changed on the right (green is added, red is removed).

- If a file is listed that you did not mean to change (often in `outs/` or `docs/`), right-click it and choose **Discard Changes**.
- Untick any file you do not want in this commit.

### Step E. Commit (save a snapshot)

1. At the bottom left, type a short summary of what you did, in plain words. Good: `Fix deadline parsing for rolling opportunities`. Bad: `stuff`.
2. Click **Commit to yourname/what-you-are-doing**.

You can make several commits while you work. Small commits are better than one huge one.

### Step F. Push (upload) your branch

Click **Publish branch** at the top (first time) or **Push origin** (after that).

### Step G. Open a pull request

1. After pushing, GitHub Desktop shows a button **Create Pull Request**. Click it. Your browser opens GitHub.
2. Give it a title and, in the description box, write 2 or 3 sentences: what you changed and anything the reviewer should check. If you rebuilt `outs/` or `docs/`, say so.
3. Click **Create pull request**.
4. Post the link in the group chat and ask someone to review it.

### Step H. Merge

A teammate (not you) opens the pull request on GitHub, looks at the changes, and clicks **Merge pull request** then **Confirm merge**. After it merges, you can click **Delete branch** on the GitHub page. Then go back to Step A for your next task.

If GitHub says there is a **conflict**, do not guess. Message Kent.

---

## Rules to follow

1. **Never work on `main`.** Always make a branch first (Step B).
2. **Always do Step A before starting.** Working on old code is how conflicts happen.
3. **Never commit secrets.** No API keys, no `.Renviron`, no passwords. (A Census key is not needed for normal work.)
4. **No participant or patient data of any kind.**
5. **Tier rules live only in `src/tool/tiering.js`.** All thresholds and defaults live only in `src/R/00_config.R`. Do not copy them anywhere else.
6. **Presentation numbers come only from `src/docs/presentation_brief.md`.** Do not invent figures.
7. **Do not re-run** `01a_grantsgov_enrich.R`, `03_llm_label.R`, or the Census pull on your own. They call outside services.
8. Before opening a pull request, re-run `check_facts.R` (Step 6). It must still say **24 of 24 rows pass**.
9. Do not commit any single file larger than 50 MB.

## Part 3: Using Claude Code or ChatGPT for your tasks

You will get task briefs from Kent (one page each, saved in `Finalists/_team/tasks/`). You can use an AI tool to help, and you must log it.

**If you have Claude Code:**
1. Open a terminal in the `Finalists` folder inside your clone (in RStudio: Terminal tab, then `cd ../Finalists`) and type `claude`. Always start it from the `Finalists` folder: that is how it loads the project rules (`Finalists/CLAUDE.md`) and the shared reviewers.
2. Tell it which task brief you are working on, for example: "Work on tasks/03_summarize_plan.md."
3. It is set up to explain git in plain words. It may create a branch for you, commit your work, and push that branch. It will never push to `main` or merge. After it pushes, open the pull request on GitHub (Part 2, Step G).
4. If it asks you to do something you do not understand, stop and message Kent.

**If you use ChatGPT or UNC PromptLab:** paste the task brief into a new chat and do the work there. Save the result to the file the brief names, then use GitHub Desktop (Part 2) to commit, push and open a pull request.

**Either way:** add one row to `Finalists/AI_USAGE_LOG.md` (when, who, tool, what it was used for, what you checked yourself). Always check AI output yourself. Never put numbers on a slide that are not in `Finalists/src/docs/fact_sheet.md`.

## Part 4: Running a reviewer (testing our work)

Reviewers are AI role-plays and critics that test our work: a hostile judge, a data critic, a test breaker, and three personas (the agency user, their supervisor, the budget director). Kent will assign you one. The step-by-step is in `Finalists/testing/README.md`. In short:
- With Claude Code (started in `Finalists`): "use the hostile-judge agent on deliverables/slide_brief.md", or for a persona type `/persona_user outs/criteria_tool.html` and play the consultant until you type END.
- With ChatGPT or PromptLab: open the matching file in `Finalists/testing/prompts/paste/`, paste it into a new chat, and paste the contents of `Finalists/testing/context.md` and the material to test where the file says.
- Save the output to `Finalists/testing/transcripts/` and tell Kent. What reviewers say are guesses to check, not facts.

## Part 5: Before the weekend

- Make a free Devpost account (the final submission is on Devpost, due Sunday 9:00 AM). Send Kent the email you used so he can add you to the team.
- Make sure you can open the shared Google Drive folder.
- Bring your laptop charger. Make sure the steps in Part 1 work on your laptop before Friday.

## Where to read next

Open the project's `QualifierChallenge/README.md` first, then `GUIDE.md` (a map of every file). The current status and open tasks are in `handoff.md`.

## Common problems

| Problem | What to do |
|---|---|
| Clone is slow or stalls | Normal for 350 MB. Wait. If it fails, try again on a different network. |
| "Authentication failed" in GitHub Desktop | **GitHub Desktop > Settings > Accounts**, sign out, sign in again. |
| GitHub Desktop says "no local changes" but you edited a file | Make sure you saved the file in RStudio (Ctrl+S or Cmd+S) and that you are in the right repository. |
| You accidentally edited on `main` | Do not commit. In GitHub Desktop, click **Current Branch > New Branch** and make a branch. Your changes move with you. |
| RStudio opens but code cannot find files | Open the project through `SolveAThon_2026.Rproj`, not by opening individual files. |
| A package will not install | Send Kent the full red error text. |
| Anything involving the word "conflict" | Stop and message Kent. |

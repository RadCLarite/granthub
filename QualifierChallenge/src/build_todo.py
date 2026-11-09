"""Refresh outs/todo/, the team's reading packet, from the current project files.

Run from anywhere:  python3 src/build_todo.py
Everything in outs/todo/ is a copy; edit the originals (paths below), then re-run this.
"""
import os, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TODO = os.path.join(ROOT, "outs", "todo")
COPIES = {
    "src/todo/00_START_HERE.md": "00_START_HERE.md",
    "outs/team_brief_v2.docx": "01_team_brief.docx",
    "src/docs/presentation_brief.md": "02_presentation_brief.md",
    "handoff.md": "03_handoff.md",
    "GUIDE.md": "04_GUIDE.md",
    "src/docs/ai_usage.md": "05_ai_usage.md",
    "src/docs/domain_taxonomy.md": "06_domain_taxonomy.md",
    "outs/grant-triage-tool.html": "07_try_the_tool.html",
    "outs/top_results.xlsx": "top_results.xlsx",
    "outs/top_results_team.xlsx": "08_top_results_to_fill_in.xlsx",
    "outs/top_results_with_rationale.xlsx": "09_top_results_with_rationale.xlsx",
}

if os.path.isdir(TODO):
    shutil.rmtree(TODO)
os.makedirs(os.path.join(TODO, "slide_figures"))
for src, dst in COPIES.items():
    shutil.copyfile(os.path.join(ROOT, src), os.path.join(TODO, dst))
figs = os.path.join(ROOT, "outs", "figures")
for f in sorted(os.listdir(figs)):
    if f.endswith(".png"):
        shutil.copyfile(os.path.join(figs, f), os.path.join(TODO, "slide_figures", f))
print(f"Refreshed {TODO}: {len(COPIES)} files + {len(os.listdir(os.path.join(TODO, 'slide_figures')))} slide figures")

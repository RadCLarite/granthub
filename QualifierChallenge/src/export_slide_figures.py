"""Copy the charts used in the slides to outs/figures/ with slide-friendly names.

The notebook's charts are interactive; every render also saves a static PNG of each chart to
outs/figures/chunks/<chunk label>.png (see knit_print.ggplot in the notebook's setup chunk).
Run after `quarto render solveathon_project.qmd` (from src/): python3 export_slide_figures.py
"""
import os, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHUNKS = os.path.join(ROOT, "outs", "figures", "chunks")
OUT = os.path.join(ROOT, "outs", "figures")
WANTED = {  # notebook chunk label -> slide file name
    "funnel": "01_funnel_nih_haystack",
    "windows": "02_application_windows",
    "capability-heatmap": "03_capability_heatmap",
    "tiers-by-scenario": "04_piles_by_scenario",
    "prompt-iteration-chart": "05_prompt_tightening",
    "accuracy-dots": "06_ai_accuracy_by_field",
    "overdose-map": "07_overdose_map",
    "reach-static": "08_reach_vs_intensity",
    "forecast-pipeline": "09_forecast_pipeline",
    "population-geography": "10_population_rural_urban",
    "population-districts": "11_population_by_district",
    "impact-breakdown": "12_impact_score_breakdown",
}

missing = []
for label, name in WANTED.items():
    src = os.path.join(CHUNKS, label + ".png")
    if os.path.exists(src):
        shutil.copyfile(src, os.path.join(OUT, name + ".png"))
    else:
        missing.append(label)
print(f"Wrote {len(WANTED) - len(missing)} figures to {OUT}" + (f"; missing: {missing}" if missing else ""))

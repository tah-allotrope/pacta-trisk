from __future__ import annotations

import csv
import html
import json
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ASSETS = Path.home() / ".config" / "opencode" / "skills" / "report" / "assets"
REPORTS_DIR = ROOT / "reports"
REPORTS_DIR.mkdir(exist_ok=True)


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def replace_tokens(template: str, mapping: dict[str, str]) -> str:
    for key, value in mapping.items():
        template = template.replace("{{" + key + "}}", value)
    return template


def pct(value: float, digits: int = 1) -> str:
    return f"{value * 100:.{digits}f}%"


def num(value: float, digits: int = 1) -> str:
    return f"{value:.{digits}f}"


def esc(text: str) -> str:
    return html.escape(text, quote=True)


def card(title: str, body: str) -> str:
    return (
        '<div class="column-card">'
        f'<h3 class="column-label">{esc(title)}</h3>'
        '<div class="splitter"></div>'
        f"{body}"
        "</div>"
    )


def subcard(title: str, body: str) -> str:
    return f'<div class="subcard"><h3>{esc(title)}</h3>{body}</div>'


def list_html(items: list[str]) -> str:
    return "<ul>" + "".join(f"<li>{item}</li>" for item in items) + "</ul>"


def table_html(headers: list[str], rows: list[list[str]]) -> str:
    head = "".join(f"<th>{esc(h)}</th>" for h in headers)
    body = "".join(
        "<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>" for row in rows
    )
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def chart_block(charts: list[dict[str, object]], height: int = 280) -> str:
    canvases = []
    scripts = []
    for chart in charts:
        cid = str(chart["id"])
        title = esc(str(chart["title"]))
        canvases.append(
            f'<div class="technical-frame" style="margin-bottom:16px;"><h3>{title}</h3>'
            f'<canvas id="{cid}" style="height:{height}px"></canvas></div>'
        )
        scripts.append(
            f"new Chart(document.getElementById('{cid}'), {json.dumps(chart['config'])});"
        )
    return (
        "".join(canvases)
        + "<script>(function(){const common=window.__REPORT_CHART_DEFAULTS__||{};"
        + "".join(scripts)
        + "})();</script>"
    )


today = date.today().isoformat()
project = "PACTA Vietnam"
repo = "pacta-vietnam"

ms_alignment = read_csv_rows(
    ROOT / "synthesis_output" / "vietnam" / "06_vn_ms_alignment_2030.csv"
)
sda_alignment = read_csv_rows(
    ROOT / "synthesis_output" / "vietnam" / "06_vn_sda_alignment_2030.csv"
)
trisk_company = read_csv_rows(
    ROOT / "synthesis_output" / "trisk" / "power_demo" / "company_summary.csv"
)
trisk_priority = read_csv_rows(
    ROOT
    / "synthesis_output"
    / "trisk"
    / "power_demo"
    / "top_borrowers_alignment_trisk.csv"
)
trisk_params = read_csv_rows(
    ROOT / "synthesis_output" / "trisk" / "power_demo" / "params_latest.csv"
)[0]


phase_template = (REPORT_ASSETS / "report-template.html").read_text(encoding="utf-8")
final_template = (REPORT_ASSETS / "final-report-template.html").read_text(
    encoding="utf-8"
)


# Phase report 1: PACTA baseline stabilization
phase1_ms_labels = [f"{row['sector']}:{row['technology']}" for row in ms_alignment]
phase1_ms_values = [round(float(row["share_gap_pp"]), 2) for row in ms_alignment]
phase1_sda_labels = [row["sector"] for row in sda_alignment]
phase1_sda_values = [round(float(row["gap_pct"]), 1) for row in sda_alignment]

phase1_content = {
    "PHASE_NAME": "pacta-baseline-stabilization",
    "DATE": today,
    "PROJECT": project,
    "REPO": repo,
    "INPUT_OUTPUT_CONTENT": card(
        "Inputs",
        list_html(
            [
                "Synthetic Vietnam loanbook, ABCD, market-share, and CO2 scenario files already present in <code>data/</code>",
                "Existing Vietnam pipeline in <code>scripts/pacta_vietnam_scenario.R</code>",
                "Known blocker context from <code>scripts/debug_ms.R</code> and prior progress notes",
            ]
        ),
    )
    + card(
        "Outputs",
        list_html(
            [
                "Completed Vietnam PACTA run with 43 loans matched at 100% coverage",
                "Rebuilt SDA outputs, 2030 alignment tables, and refreshed charts in <code>synthesis_output/vietnam/</code>",
                "Confirmed stakeholder report in <code>reports/PACTA_Vietnam_Bank_Report.html</code>",
            ]
        ),
    ),
    "MERMAID_DIAGRAM": "flowchart TD\nA[Load Vietnam synthetic inputs]-->B[Map ISIC to PACTA sectors]\nB-->C[Normalize names and fuzzy match]\nC-->D[Run market share analysis]\nD-->E[Run SDA analysis]\nE-->F[Calculate 2030 alignment gaps]\nF-->G[Render Vietnam bank HTML report]",
    "MATH_ALGORITHM_SECTION": list_html(
        [
            "Fuzzy matching uses Jaro-Winkler with <code>min_score = 0.8</code> after ASCII normalization for Vietnamese names.",
            "Market-share alignment compares projected 2030 technology share against <code>target_pdp8_ndc</code> and treats low-carbon technologies as aligned only when they meet or exceed target.",
            "SDA alignment compares projected 2030 emission intensity against the synthetic PDP8/NDC target and marks any value above target as misaligned.",
        ]
    ),
    "TOOLS_METHODS": table_html(
        ["Item", "Detail"],
        [
            ["Pipeline", "<code>scripts/pacta_vietnam_scenario.R</code>"],
            ["Debug helper", "<code>scripts/debug_ms.R</code>"],
            [
                "Key R packages",
                "<code>pacta.loanbook</code>, <code>r2dii.match</code>, <code>r2dii.analysis</code>, <code>r2dii.plot</code>",
            ],
            [
                "Primary outputs",
                "<code>06_vn_ms_alignment_2030.csv</code>, <code>06_vn_sda_alignment_2030.csv</code>, <code>PACTA_Vietnam_Bank_Report.html</code>",
            ],
        ],
    ),
    "CHARTS_SECTION": chart_block(
        [
            {
                "id": "phase1_ms_gap",
                "title": "2030 Market-Share Gaps vs PDP8/NDC",
                "config": {
                    "type": "bar",
                    "data": {
                        "labels": phase1_ms_labels,
                        "datasets": [
                            {
                                "label": "Share gap (pp)",
                                "data": phase1_ms_values,
                                "backgroundColor": [
                                    "#e74c3c" if v < 0 else "#f39c12"
                                    for v in phase1_ms_values
                                ],
                            }
                        ],
                    },
                    "options": {
                        "indexAxis": "y",
                        "animation": False,
                        "resizeDelay": 150,
                        "normalized": True,
                        "maintainAspectRatio": False,
                    },
                },
            },
            {
                "id": "phase1_sda_gap",
                "title": "2030 SDA Gap vs PDP8/NDC",
                "config": {
                    "type": "bar",
                    "data": {
                        "labels": phase1_sda_labels,
                        "datasets": [
                            {
                                "label": "Intensity gap (%)",
                                "data": phase1_sda_values,
                                "backgroundColor": ["#c0392b", "#d35400"],
                            }
                        ],
                    },
                    "options": {
                        "animation": False,
                        "resizeDelay": 150,
                        "normalized": True,
                        "maintainAspectRatio": False,
                    },
                },
            },
        ]
    ),
    "LIMITATIONS_ALTERNATIVES": list_html(
        [
            "The pipeline now completes, but the alignment story remains synthetic and should not be treated as a real bank portfolio result.",
            "The SDA section still emits a many-to-many join warning because multiple matched loan rows map to the same sector-year emission series; the output is usable for this demo but should be cleaned for production work.",
            "Second-best alternative if the full pipeline had stayed blocked would have been to freeze market-share results only and postpone cement and steel, but that would have weakened the later TRISK bridge.",
        ]
    ),
    "ERRORS_WARNINGS_FLAGS": list_html(
        [
            "Earlier progress notes identified a completion blocker in the Vietnam pipeline; rerunning on the current repo state showed the script now completes end to end.",
            "Two <code>r2dii.plot</code> messages note that technology-share charts default to plotting extreme years only; these are informational, not failures.",
            "The SDA step still warns about an expected many-to-many join between matched loans and sector-year emission-factor rows.",
        ]
    ),
    "OPEN_QUESTIONS": list_html(
        [
            "Should the SDA join be reworked into an explicit borrower-to-parent mapping table before any production use?",
            "Should the next iteration freeze an immutable PACTA output snapshot for TRISK runs to avoid accidental drift?",
            "How much of the existing Vietnam report should be merged into the combined PACTA plus TRISK client artifact versus kept separate?",
        ]
    ),
}


# Phase report 2: TRISK power pilot
phase2_labels = [row["company_name"] for row in trisk_priority[:10]]
phase2_scores = [
    round(float(row["stress_priority_score"]), 1)
    if row["stress_priority_score"]
    else None
    for row in trisk_priority[:10]
]
phase2_npv = [
    round(float(row["npv_change"]) * 100, 1) if row["npv_change"] else None
    for row in trisk_priority[:10]
]
phase2_pd = [
    round(float(row["pd_change"]) * 100, 2) if row["pd_change"] else None
    for row in trisk_priority[:10]
]

phase2_content = {
    "PHASE_NAME": "trisk-power-pilot",
    "DATE": today,
    "PROJECT": project,
    "REPO": repo,
    "INPUT_OUTPUT_CONTENT": card(
        "Inputs",
        list_html(
            [
                "Stabilized Vietnam power outputs from the completed PACTA baseline",
                "Synthetic assumptions documented in <code>docs/TRISK_Demo_Assumptions.md</code>",
                "Installed <code>trisk.model</code> package with folder inputs generated by <code>scripts/trisk_prepare_inputs.R</code>",
            ]
        ),
    )
    + card(
        "Outputs",
        list_html(
            [
                "Runnable TRISK input package in <code>output/trisk_inputs/power_demo/</code>",
                "Package-backed stress results in <code>synthesis_output/trisk/power_demo/</code>",
                "Borrower prioritization table combining NPV, PD, and PACTA alignment gap in <code>top_borrowers_alignment_trisk.csv</code>",
            ]
        ),
    ),
    "MERMAID_DIAGRAM": "flowchart TD\nA[Freeze power-sector PACTA context]-->B[Map local schema to trisk.model schema]\nB-->C[Generate synthetic financial features]\nC-->D[Write assets scenarios carbon inputs]\nD-->E[Run trisk.model power stress test]\nE-->F[Summarize NPV and PD changes]\nF-->G[Join back to PACTA alignment gaps]\nG-->H[Rank priority borrowers]",
    "MATH_ALGORITHM_SECTION": list_html(
        [
            "The bridge back-calculates <code>capacity</code> so that <code>capacity * capacity_factor</code> reproduces the repo's existing synthetic production plan for each power technology-year row.",
            "The package-backed TRISK run applies discounted cash flow logic for NPV change and a Merton-style credit-risk step for PD change.",
            "Borrower prioritization adds a lightweight composite score: 70% scaled NPV deterioration, 20% scaled PD change, and 10% average absolute PACTA alignment gap.",
        ]
    ),
    "TOOLS_METHODS": table_html(
        ["Item", "Detail"],
        [
            ["Assumptions note", "<code>docs/TRISK_Demo_Assumptions.md</code>"],
            ["Input builder", "<code>scripts/trisk_prepare_inputs.R</code>"],
            ["Pilot runner", "<code>scripts/trisk_power_demo.R</code>"],
            ["Package", "<code>trisk.model</code> 2.6.1"],
            ["Run parameters", esc(json.dumps(trisk_params))],
        ],
    ),
    "CHARTS_SECTION": chart_block(
        [
            {
                "id": "phase2_priority",
                "title": "Top Borrower Stress Priority Score",
                "config": {
                    "type": "bar",
                    "data": {
                        "labels": phase2_labels,
                        "datasets": [
                            {
                                "label": "Priority score",
                                "data": phase2_scores,
                                "backgroundColor": "#e67e22",
                            }
                        ],
                    },
                    "options": {
                        "indexAxis": "y",
                        "animation": False,
                        "resizeDelay": 150,
                        "normalized": True,
                        "maintainAspectRatio": False,
                    },
                },
            },
            {
                "id": "phase2_npv_pd",
                "title": "NPV vs PD Stress Change for Top Borrowers",
                "config": {
                    "type": "bar",
                    "data": {
                        "labels": phase2_labels,
                        "datasets": [
                            {
                                "label": "NPV change (%)",
                                "data": phase2_npv,
                                "backgroundColor": "#c0392b",
                            },
                            {
                                "label": "PD change (pp)",
                                "data": phase2_pd,
                                "backgroundColor": "#2980b9",
                            },
                        ],
                    },
                    "options": {
                        "animation": False,
                        "resizeDelay": 150,
                        "normalized": True,
                        "maintainAspectRatio": False,
                    },
                },
            },
        ]
    ),
    "LIMITATIONS_ALTERNATIVES": list_html(
        [
            "The pilot only covers the power sector, which is deliberate for first-pass credibility but not yet a whole-portfolio TRISK view.",
            "Financial features, price paths, and carbon prices are synthetic demo inputs, even though the package execution is real.",
            "Second-best alternative would have been a custom pseudo-TRISK scoring model without the package, but the successful package-backed run is materially stronger evidence.",
        ]
    ),
    "ERRORS_WARNINGS_FLAGS": list_html(
        [
            "The first bridge attempt duplicated scenario rows by company, which produced list-columns inside <code>trisk.model</code>; fixing the scenario file to technology-year granularity resolved this.",
            "The PD stage removed 5 rows during Merton compatibility checks, but the run still completed and returned borrower-level results.",
            "<code>Dung Quat LNG Power Consortium</code> currently lands at zero baseline output in the summary and should be treated as an edge case for future refinement.",
        ]
    ),
    "OPEN_QUESTIONS": list_html(
        [
            "Should the next iteration add systematic sensitivity runs for <code>shock_year</code>, <code>discount_rate</code>, and <code>market_passthrough</code>?",
            "Should gas and renewable price paths be calibrated to a more explicit Vietnam market story before sharing the pilot broadly?",
            "Is the next highest-value extension a multi-sector TRISK expansion or a tighter power-sector calibration with better financial proxies?",
        ]
    ),
}


# Final report
complete_phases = [
    ("Phase 0", "Scope lock and research consolidation", "Complete"),
    ("Phase 1", "Vietnam PACTA baseline stabilized", "Complete"),
    ("Phase 2", "Synthetic TRISK input design", "Complete"),
    ("Phase 3", "Power-sector TRISK pilot", "Complete"),
    ("Phase 4", "PACTA plus TRISK integration", "Partial"),
    ("Phase 5", "Client-style final report", "Complete"),
]

top5 = trisk_priority[:5]
final_chart_labels = [row["company_name"] for row in top5]
final_chart_values = [round(float(row["stress_priority_score"]), 1) for row in top5]

final_content = {
    "REPORT_TITLE": "vietnam-bank-trisk-demo",
    "DATE": today,
    "PROJECT": project,
    "REPO": repo,
    "ONE_LINE_TAKEAWAY": (
        "A package-backed, power-sector TRISK pilot now works on top of the Vietnam PACTA demo, and the results support a coal-heavy borrower risk story that is credible enough for a prospective bank conversation."
    ),
    "EXECUTIVE_SUMMARY": subcard(
        "What was analyzed",
        "<p>The repo's Vietnam PACTA work was stabilized, then extended with a real <code>trisk.model</code> power-sector pilot using synthetic but publicly anchored assumptions.</p>",
    )
    + subcard(
        "What matters",
        "<p>The combined view now distinguishes between alignment and stress: coal-heavy borrowers rank worst under the synthetic transition shock, while renewable platforms improve under the same scenario.</p>",
    ),
    "BACKGROUND_OBJECTIVE": (
        "<p>This repo already contained a substantial Vietnam PACTA demo for a fictional Mekong Commercial Bank. The new objective was to make the TRISK roadmap real: finish the upstream PACTA baseline, create runnable TRISK inputs, execute a power-sector pilot, and package the result into shareable phase and final reporting artifacts for a prospective Vietnam bank.</p>"
    ),
    "INPUTS_SCOPE": subcard(
        "Inputs",
        list_html(
            [
                "Vietnam synthetic loanbook and ABCD data in <code>data/</code>",
                "TRISK research brief in <code>research/2026-04-08_integration-trisk-model-existing.md</code>",
                "TRISK assumptions register in <code>docs/TRISK_Demo_Assumptions.md</code>",
                "New bridge and pilot scripts in <code>scripts/trisk_prepare_inputs.R</code> and <code>scripts/trisk_power_demo.R</code>",
            ]
        ),
    )
    + subcard(
        "Scope boundary",
        list_html(
            [
                "PACTA remains multi-sector for the Vietnam baseline.",
                "TRISK is implemented only for the power sector in this first pass.",
                "The report is suitable for methodology demonstration and portfolio triage discussion, not production credit use.",
            ]
        ),
    ),
    "ASSUMPTIONS_CONSTRAINTS": subcard(
        "Assumptions",
        list_html(
            [
                "Financial features are synthetic and assigned by borrower archetype.",
                "Scenario price paths and carbon tax paths are synthetic but directionally consistent with the transition narrative.",
                "The installed <code>trisk.model</code> package uses a folder-based input contract that differs from some older public docs.",
            ]
        ),
    )
    + subcard(
        "Constraints",
        list_html(
            [
                "No confidential borrower financial statements were available in the repo.",
                "The pilot excludes automotive, cement, steel, and coal mining from TRISK execution.",
                "One LNG borrower still produces a zero-value edge case under the current synthetic setup.",
            ]
        ),
    ),
    "METHODOLOGY": (
        "<p>The work proceeded in three implementation layers. First, the Vietnam PACTA pipeline was rerun and verified end to end so that company-level trajectories were stable. Second, a TRISK bridge was built by mapping the repo's power-sector production plans into the installed <code>trisk.model</code> asset schema, adding synthetic financial features, and writing scenario and carbon-price files that the package could execute. Third, the TRISK outputs were joined back to PACTA alignment gaps to create a borrower prioritization view that is more decision-useful than either lens on its own.</p>"
    ),
    "PHASE_ANALYSIS": "".join(
        subcard(title, f"<p><strong>{status}.</strong> {desc}</p>")
        for title, desc, status in complete_phases
    ),
    "OPTIONAL_MERMAID_BLOCK": (
        '<div class="diagram-frame" style="margin-top:16px;">'
        '<div class="mermaid">flowchart TD\nA[Research and plan]-->B[Stabilize Vietnam PACTA baseline]\nB-->C[Generate synthetic TRISK inputs]\nC-->D[Run power-sector package pilot]\nD-->E[Join PACTA alignment and TRISK stress]\nE-->F[Create phase and final reporting artifacts]</div></div>'
    ),
    "FINDINGS_RECOMMENDATION": (
        "<p>The most important finding is that a real package-backed TRISK pilot is now working on the repo's Vietnam synthetic data. The stress outputs strongly reinforce the alignment story: <code>Nghi Son Power LLC</code>, <code>Vinacomin Power JSC</code>, and <code>International Power Mong Duong</code> rank as the highest-priority transition-risk borrowers, while renewable platforms show positive NPV change and improving modeled PD under the chosen stress narrative. The recommended direction is therefore to keep the demo architecture exactly where it is strongest: use PACTA for the multi-sector alignment lens, use TRISK for a power-sector risk deep dive, and only expand TRISK to other sectors after the power assumptions and edge cases are refined.</p>"
    ),
    "OPTIONAL_CHARTS_BLOCK": chart_block(
        [
            {
                "id": "final_priority_chart",
                "title": "Top Five Borrowers by Combined Stress Priority",
                "config": {
                    "type": "bar",
                    "data": {
                        "labels": final_chart_labels,
                        "datasets": [
                            {
                                "label": "Stress priority score",
                                "data": final_chart_values,
                                "backgroundColor": [
                                    "#9d6b37",
                                    "#a55d2a",
                                    "#b74a2f",
                                    "#c96b39",
                                    "#d98a45",
                                ],
                            }
                        ],
                    },
                    "options": {
                        "indexAxis": "y",
                        "animation": False,
                        "resizeDelay": 150,
                        "normalized": True,
                        "maintainAspectRatio": False,
                    },
                },
            }
        ],
        height=300,
    ),
    "IMPLEMENTATION_PATH": subcard(
        "Immediate next steps",
        list_html(
            [
                "Refine the Dung Quat LNG edge case and add a small sensitivity sweep for <code>shock_year</code>, <code>discount_rate</code>, and <code>market_passthrough</code>.",
                "Merge the current TRISK findings into a dedicated client-style Vietnam demo report or append them to the existing PACTA Vietnam report.",
                "Decide whether the next extension should be tighter power calibration or a multi-sector TRISK bridge for steel and cement.",
            ]
        ),
    )
    + subcard(
        "Suggested owners",
        list_html(
            [
                "Methodology owner: review synthetic financial and carbon assumptions.",
                "Data owner: improve public-source anchors for Vietnam power prices and borrower archetypes.",
                "Engineering owner: convert the current scripts into a repeatable reporting pipeline.",
            ]
        ),
    ),
    "RISKS_OPEN_QUESTIONS": subcard(
        "Risks",
        list_html(
            [
                "Users may over-read synthetic PD outputs as production credit estimates.",
                "The current pilot is strongest for power but still not a full-bank TRISK implementation.",
                "Package behavior and public documentation still show some interface drift, so local assumptions should remain documented.",
            ]
        ),
    )
    + subcard(
        "Open questions",
        list_html(
            [
                "Should Vietnam-specific scenario geographies replace the current synthetic <code>Vietnam</code> package geography in a future iteration?",
                "What minimum sensitivity package is required before showing the pilot to an external bank audience?",
                "How much sector expansion is worth doing before the first external conversation?",
            ]
        ),
    ),
    "APPENDICES_EVIDENCE": subcard(
        "Evidence notes",
        table_html(
            ["Artifact", "Evidence"],
            [
                [
                    "PACTA baseline",
                    "<code>reports/PACTA_Vietnam_Bank_Report.html</code>",
                ],
                ["TRISK assumptions", "<code>docs/TRISK_Demo_Assumptions.md</code>"],
                ["TRISK bridge", "<code>scripts/trisk_prepare_inputs.R</code>"],
                ["TRISK pilot", "<code>scripts/trisk_power_demo.R</code>"],
                [
                    "Borrower ranking",
                    "<code>synthesis_output/trisk/power_demo/top_borrowers_alignment_trisk.csv</code>",
                ],
            ],
        ),
    )
    + subcard(
        "Top borrower snapshot",
        table_html(
            ["Borrower", "NPV change", "PD change", "Priority"],
            [
                [
                    esc(row["company_name"]),
                    f"{float(row['npv_change']) * 100:.1f}%",
                    f"{float(row['pd_change']) * 100:.2f} pp",
                    f"{float(row['stress_priority_score']):.1f}",
                ]
                for row in top5
            ],
        ),
    ),
}


phase1_html = replace_tokens(phase_template, phase1_content)
phase2_html = replace_tokens(phase_template, phase2_content)
final_html = replace_tokens(final_template, final_content)

(REPORTS_DIR / f"{today}-pacta-baseline-stabilization.html").write_text(
    phase1_html, encoding="utf-8"
)
(REPORTS_DIR / f"{today}-trisk-power-pilot.html").write_text(
    phase2_html, encoding="utf-8"
)
(REPORTS_DIR / f"{today}-final-vietnam-bank-trisk-demo.html").write_text(
    final_html, encoding="utf-8"
)

print("Generated reports:")
print(f"- {today}-pacta-baseline-stabilization.html")
print(f"- {today}-trisk-power-pilot.html")
print(f"- {today}-final-vietnam-bank-trisk-demo.html")

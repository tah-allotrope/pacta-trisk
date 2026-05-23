# BIDV Framework Recommendation Report — Template Specification

> **Date:** 2026-05-22
> **Purpose:** Defines the section structure, visual design, and content sourcing for the BIDV Framework Recommendation Report. Guides the R script implementation in PHASE-03.

---

## Section Structure (10 Sections)

| # | Section | Source | Rendering Method |
|---|---------|--------|------------------|
| 1 | Cover Page | Hardcoded | Inline HTML |
| 2 | Executive Summary | Authored in R script + data from CSV | Inline HTML + KPI cards from CSV |
| 3 | BIDV Context | Authored in R script + `data/vietnam_loanbook.csv` | Inline HTML + computed exposure table |
| 4 | Framework Landscape | `docs/bidv_framework_comparison.md` | Markdown→HTML (table extraction) |
| 5 | Framework Recommendation | `docs/bidv_framework_comparison.md` | Markdown→HTML (narrative extraction) |
| 6 | Sector Prioritization | `synthesis_output/prioritization/` | CSV→HTML table + base64 chart embed |
| 7 | Decision 263 Mapping | `docs/bidv_decision263_mapping.md` | Markdown→HTML (table extraction) |
| 8 | Implementation Roadmap | `docs/bidv_implementation_roadmap.md` | Markdown→HTML (phase extraction) |
| 9 | Risk Register | Authored in R script | Inline HTML table |
| 10 | Methodology Appendix | Condensed from existing docs | Inline HTML + base64 chart embeds |

---

## Visual Design Specification

### Color Palette

| Token | Value | Usage |
|-------|-------|-------|
| `--primary` | `#1a5276` | Headers, table headers, hero gradient start (Allotrope blue) |
| `--accent` | `#2b6cb0` | Sub-headers, links, hero gradient end |
| `--green` | `#276749` | Positive indicators, GTB accent |
| `--red` | `#c53030` | Negative indicators, disclaimer borders, critical badges |
| `--orange` | `#c05621` | Warning callouts |
| `--bg` | `#f7fafc` | Page background |
| `--card-bg` | `#ffffff` | Section card backgrounds |
| `--border` | `#e2e8f0` | Borders, dividers |
| `--text` | `#2d3748` | Body text |
| `--text-light` | `#718096` | Captions, footnotes, metadata |

### Typography

- **Font stack:** `"Segoe UI", system-ui, -apple-system, sans-serif`
- **Hero title:** 2.2rem, 700 weight
- **Section headers (h2):** 1.4rem, 600 weight, primary color, bottom border
- **Sub-headers (h3):** 1.1rem, accent color
- **Body text:** 1rem, line-height 1.7
- **Table text:** 0.9rem
- **Captions:** 0.82rem, italic, light text color

### Layout

- **Max container width:** 960px, centered
- **Section cards:** White background, 8px border-radius, subtle shadow, 2rem padding, 2rem bottom margin
- **Hero:** Full-width gradient, white text, centered, 3rem vertical padding
- **Table of contents:** Light background, bordered, rounded, with anchor links to sections

### Component Patterns

#### KPI Cards
```
Grid layout: repeat(auto-fit, minmax(180px, 1fr))
Each card: light bg, 1px border, 8px radius, 1.2rem padding, centered
Value: 1.8rem, 700 weight, primary color (or red/green for status)
Label: 0.8rem, light text color
```

#### Data Tables
```
Full width, collapsed borders, 0.9rem font
Header: primary bg, white text, 0.7rem padding, left-aligned
Rows: alternating light bg, bottom border, hover highlight
```

#### Badges
```
Inline-block, 0.15rem 0.6rem padding, 12px radius, 0.78rem, 600 weight, uppercase
.red: light red bg, red text
.green: light green bg, green text
.orange: light orange bg, orange text
.gray: light gray bg, dark gray text
```

#### Callout Boxes
```
1rem padding, 6px radius, 1rem margin, 0.92rem font
.warning: light yellow bg, orange left border (4px)
.info: light blue bg, accent left border (4px)
.danger: light red bg, red left border (4px)
```

#### Synthetic Data Disclaimer
```
Special callout: red border (2px), light red bg, bold title
Placed at top of every data-driven section (Sections 3, 6, 7)
Text: "Illustrative results based on synthetic portfolio (MCB). BIDV-specific results will be produced upon data onboarding."
```

#### Chart Containers
```
Centered, 1rem padding, light bg, 1px border, 6px radius
Image: max-width 100%, auto height, 4px radius
Caption: below image, 0.82rem, italic, light text
```

#### Print Styles
```
@media print: remove shadows, reduce padding, ensure page breaks don't split tables/charts
```

---

## Content Sourcing Map

### Section 1: Cover Page
- **Source:** Hardcoded in R script
- **Content:** Title ("BIDV Framework Recommendation Report"), subtitle, date, confidentiality notice, GTB/Allotrope branding
- **Rendering:** Inline HTML

### Section 2: Executive Summary
- **Source:** Authored in R script with data from:
  - `synthesis_output/prioritization/sector_priority_ranking.csv` (highest-priority sector, composite scores)
  - `data/vietnam_loanbook.csv` (sector exposure counts, total Decision 263 exposure)
  - `docs/bidv_framework_comparison.md` (recommended framework name)
- **KPI Cards:**
  1. Decision 263 sectors covered: 3 (thermal power, cement, steel)
  2. Total Decision 263 exposure: computed from loanbook (sum of exposure for power/cement/steel sectors)
  3. Highest-priority sector: from ranking CSV (sector with highest composite score)
  4. Recommended framework: "PACTA + TRISK"
- **Narrative:** 3 paragraphs — (1) what the report found, (2) what BIDV should do, (3) what's next
- **Rendering:** Inline HTML with KPI cards

### Section 3: BIDV Context
- **Source:** Authored in R script + `data/vietnam_loanbook.csv`
- **Content:**
  - Decision 263 obligations overview (brief)
  - Sector exposure summary table (computed from loanbook: count of loans, total exposure by sector)
  - PCAF baseline status reference (Output 2.1)
- **Synthetic data disclaimer:** Required
- **Rendering:** Inline HTML + computed table

### Section 4: Framework Landscape
- **Source:** `docs/bidv_framework_comparison.md`
- **Content to extract:**
  - The 7×10 evaluation matrix table
  - Framework-by-framework evaluation narratives (condensed)
- **Rendering:** Extract markdown table → HTML table; extract narrative paragraphs → HTML paragraphs

### Section 5: Framework Recommendation
- **Source:** `docs/bidv_framework_comparison.md`
- **Content to extract:**
  - Primary/secondary/tertiary recommendation
  - Rationale (tied to matrix scores)
  - Complementarity analysis (PCAF → PACTA → TRISK → TCFD/ISSB pipeline)
  - Limitations section
- **Rendering:** Markdown→HTML conversion

### Section 6: Sector Prioritization
- **Source:** `synthesis_output/prioritization/`
- **Content:**
  - Ranking table from `sector_priority_ranking.csv` (sector, alignment score, stress score, exposure score, composite score, classification)
  - Chart: base64-encode `sector_priority_chart.png`
  - Interpretation narrative from `interpretation_notes.md`
- **Synthetic data disclaimer:** Required
- **Rendering:** CSV→HTML table + base64 image embed + narrative paragraphs

### Section 7: Decision 263 Compliance Mapping
- **Source:** `docs/bidv_decision263_mapping.md`
- **Content to extract:**
  - Decision 263 overview section
  - Sector mapping table (Decision 263 sector → PACTA sector → TRISK sector → repo data files)
  - Compliance capability mapping table
  - Data availability assessment
  - Gap acknowledgment
- **Rendering:** Markdown→HTML (tables + paragraphs)

### Section 8: Implementation Roadmap
- **Source:** `docs/bidv_implementation_roadmap.md`
- **Content to extract:**
  - 5 phases with timelines, activities, resource requirements, deliverables
  - Resource requirements summary table
  - Integration guidance (condensed)
  - Fast-track variant (optional, as a callout)
- **Rendering:** Markdown→HTML with phased timeline styling (each phase as a sub-section with highlighted deliverable)

### Section 9: Risk Register
- **Source:** Authored in R script
- **Content:** Risk table with columns: Risk ID, Description, Likelihood, Impact, Mitigation
- **Risks to include:**
  1. Data availability: Decision 263 clients may not have emissions data ready
  2. Match coverage: ABCD matching may have low coverage for Vietnamese companies
  3. TRISK limitations: outputs are not regulatory PDs
  4. Scenario uncertainty: PDP8/NDC pathways may differ from MONRE's final quota levels
  5. Organizational capacity: BIDV may not have dedicated ESG/quant staff for the recommended timeline
  6. Regulatory evolution: Decision 263 implementing regulations may change
- **Rendering:** Inline HTML table

### Section 10: Methodology Appendix
- **Source:** Condensed from existing docs + additional chart embeds
- **Content:**
  - PACTA methodology summary (from `docs/PACTA_Beginner_Guide.md`): matching, market share approach, SDA
  - TRISK methodology summary (from `docs/TRISK_Demo_Assumptions.md`): DCF stress, NPV change, PD change, sensitivity
  - Sector prioritization methodology (from `docs/bidv_sector_prioritization_methodology.md`): scoring formula, weights, normalization
  - Illustrative charts (3-4 key pipeline outputs):
    - `synthesis_output/vietnam/05_vn_power_techmix.png` (power technology mix)
    - `dashboard/data/trisk/power/01_npv_change_by_company.png` (NPV change by company)
    - `synthesis_output/prioritization/sector_priority_chart.png` (sector priority — also in Section 6)
  - Source citations and caveats
  - Disclaimer language from `dashboard/pages/2_TRISK_Risk.py`
- **Rendering:** Inline HTML + base64 image embeds

---

## Markdown→HTML Conversion Rules

The R script will use a simple regex-based converter (consistent with `scripts/generate_report.R`):

| Markdown | HTML |
|----------|------|
| `# Header` | `<h1>Header</h1>` |
| `## Header` | `<h2>Header</h2>` |
| `### Header` | `<h3>Header</h3>` |
| `**bold**` | `<strong>bold</strong>` |
| `*italic*` | `<em>italic</em>` |
| `` `code` `` | `<code>code</code>` |
| `- item` | `<li>item</li>` (wrapped in `<ul>`) |
| `1. item` | `<li>item</li>` (wrapped in `<ol>`) |
| `\| a \| b \|` table | `<table><tr><th>a</th><th>b</th></tr>...` |
| `---` | `<hr>` |
| `> quote` | `<blockquote>quote</blockquote>` |

**Fallback:** If a section doesn't render cleanly from markdown, the R script will use hardcoded HTML for that section.

---

## File Size Target

- **Target:** < 2 MB (for email delivery)
- **Strategy:** Base64-encode only essential charts (3-4 images). Avoid embedding all pipeline outputs.

---

## Pre-flight Checks (R Script)

Before rendering, the script must verify:

1. `docs/bidv_framework_comparison.md` exists
2. `docs/bidv_decision263_mapping.md` exists
3. `docs/bidv_implementation_roadmap.md` exists
4. `docs/bidv_sector_prioritization_methodology.md` exists
5. `synthesis_output/prioritization/sector_priority_ranking.csv` exists
6. `synthesis_output/prioritization/sector_priority_chart.png` exists
7. `synthesis_output/prioritization/interpretation_notes.md` exists
8. `data/vietnam_loanbook.csv` exists
9. `docs/PACTA_Beginner_Guide.md` exists
10. `docs/TRISK_Demo_Assumptions.md` exists

Missing files → insert `[Section pending — awaiting upstream content]` placeholder.

---

## Output

- **File:** `reports/BIDV_Framework_Recommendation_Report.html`
- **Format:** Self-contained HTML (no external CSS/JS/image dependencies)
- **Size:** < 2 MB
- **Print-friendly:** Yes (via `@media print` styles)

# generate_report.R
# Generates a self-contained HTML report with base64-embedded PNG images.
# No external dependencies beyond base R + base64enc.
#
# NOTE: Run from the project root directory:
#   Rscript scripts/generate_report.R

output_dir <- "output"

# --- Helper: encode a PNG file as base64 data URI ---
img_to_base64 <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  b64 <- base64enc::base64encode(raw)
  paste0("data:image/png;base64,", b64)
}

# Check if base64enc is available; if not, use a pure-R fallback
if (!requireNamespace("base64enc", quietly = TRUE)) {
  # Pure base64 encoder fallback using built-in tools
  img_to_base64 <- function(path) {
    raw <- readBin(path, "raw", file.info(path)$size)
    # Use openssl::base64_encode or fall back to xfun
    if (requireNamespace("xfun", quietly = TRUE)) {
      b64 <- xfun::base64_encode(raw)
    } else {
      # Absolute fallback: call certutil on Windows
      tmp_in <- tempfile(fileext = ".bin")
      tmp_out <- tempfile(fileext = ".txt")
      writeBin(raw, tmp_in)
      system2("certutil", args = c("-encode", tmp_in, tmp_out), stdout = FALSE, stderr = FALSE)
      lines <- readLines(tmp_out)
      lines <- lines[!grepl("^-", lines)]
      b64 <- paste(lines, collapse = "")
      unlink(c(tmp_in, tmp_out))
    }
    paste0("data:image/png;base64,", b64)
  }
}

cat("Encoding images...\n")

imgs <- list(
  match_coverage   = img_to_base64(file.path(output_dir, "03_match_coverage_by_sector.png")),
  power_techmix    = img_to_base64(file.path(output_dir, "05_power_techmix.png")),
  power_renew      = img_to_base64(file.path(output_dir, "06_power_renewables_trajectory.png")),
  power_coal       = img_to_base64(file.path(output_dir, "07_power_coal_trajectory.png")),
  auto_techmix     = img_to_base64(file.path(output_dir, "08_automotive_techmix.png")),
  auto_ev          = img_to_base64(file.path(output_dir, "09_automotive_ev_trajectory.png")),
  cement           = img_to_base64(file.path(output_dir, "11_cement_emission_intensity.png")),
  steel            = img_to_base64(file.path(output_dir, "12_steel_emission_intensity.png")),
  alignment        = img_to_base64(file.path(output_dir, "14_alignment_overview.png"))
)

cat("Building HTML...\n")

html <- paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PACTA Portfolio Alignment Report</title>
<style>
  :root {
    --primary: #1a365d;
    --accent: #2b6cb0;
    --green: #276749;
    --red: #c53030;
    --orange: #c05621;
    --bg: #f7fafc;
    --card-bg: #ffffff;
    --border: #e2e8f0;
    --text: #2d3748;
    --text-light: #718096;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.7;
    padding: 0;
  }
  .hero {
    background: linear-gradient(135deg, var(--primary) 0%, var(--accent) 100%);
    color: white;
    padding: 3rem 2rem;
    text-align: center;
  }
  .hero h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.5rem; }
  .hero .subtitle { font-size: 1.1rem; opacity: 0.9; font-weight: 300; }
  .hero .meta { margin-top: 1.2rem; font-size: 0.85rem; opacity: 0.7; }

  .container { max-width: 960px; margin: 0 auto; padding: 2rem 1.5rem; }

  .executive-summary {
    background: var(--card-bg);
    border-left: 4px solid var(--accent);
    border-radius: 0 8px 8px 0;
    padding: 1.8rem 2rem;
    margin-bottom: 2.5rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .executive-summary h2 { color: var(--accent); font-size: 1.3rem; margin-bottom: 1rem; }

  .section {
    background: var(--card-bg);
    border-radius: 8px;
    padding: 2rem;
    margin-bottom: 2rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .section h2 {
    color: var(--primary);
    font-size: 1.4rem;
    margin-bottom: 0.3rem;
    padding-bottom: 0.6rem;
    border-bottom: 2px solid var(--border);
  }
  .section h3 {
    color: var(--accent);
    font-size: 1.1rem;
    margin: 1.5rem 0 0.5rem 0;
  }
  .section p { margin: 0.7rem 0; }

  .chart-container {
    text-align: center;
    margin: 1.5rem 0;
    padding: 1rem;
    background: #f8fafc;
    border-radius: 6px;
    border: 1px solid var(--border);
  }
  .chart-container img {
    max-width: 100%;
    height: auto;
    border-radius: 4px;
  }
  .chart-caption {
    font-size: 0.82rem;
    color: var(--text-light);
    margin-top: 0.5rem;
    font-style: italic;
  }

  .two-charts {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
    margin: 1.5rem 0;
  }
  @media (max-width: 768px) {
    .two-charts { grid-template-columns: 1fr; }
  }
  .two-charts .chart-container { margin: 0; }

  table {
    width: 100%;
    border-collapse: collapse;
    margin: 1rem 0;
    font-size: 0.9rem;
  }
  th {
    background: var(--primary);
    color: white;
    padding: 0.7rem 1rem;
    text-align: left;
    font-weight: 600;
  }
  td { padding: 0.6rem 1rem; border-bottom: 1px solid var(--border); }
  tr:nth-child(even) { background: #f7fafc; }
  tr:hover { background: #edf2f7; }

  .badge {
    display: inline-block;
    padding: 0.15rem 0.6rem;
    border-radius: 12px;
    font-size: 0.78rem;
    font-weight: 600;
    text-transform: uppercase;
  }
  .badge-red { background: #fed7d7; color: var(--red); }
  .badge-green { background: #c6f6d5; color: var(--green); }
  .badge-gray { background: #e2e8f0; color: #4a5568; }

  .callout {
    padding: 1rem 1.2rem;
    border-radius: 6px;
    margin: 1rem 0;
    font-size: 0.92rem;
  }
  .callout-warning { background: #fffbeb; border-left: 4px solid var(--orange); }
  .callout-info { background: #ebf8ff; border-left: 4px solid var(--accent); }
  .callout-danger { background: #fff5f5; border-left: 4px solid var(--red); }

  .kpi-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 1rem;
    margin: 1.5rem 0;
  }
  .kpi-card {
    background: #f7fafc;
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1.2rem;
    text-align: center;
  }
  .kpi-card .value { font-size: 1.8rem; font-weight: 700; color: var(--primary); }
  .kpi-card .label { font-size: 0.8rem; color: var(--text-light); margin-top: 0.3rem; }

  .footer {
    text-align: center;
    padding: 2rem;
    color: var(--text-light);
    font-size: 0.8rem;
    border-top: 1px solid var(--border);
    margin-top: 2rem;
  }

  .toc {
    background: #f7fafc;
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1.2rem 1.5rem;
    margin-bottom: 2rem;
  }
  .toc h3 { margin-bottom: 0.5rem; font-size: 1rem; color: var(--primary); }
  .toc ol { padding-left: 1.3rem; }
  .toc li { margin: 0.3rem 0; }
  .toc a { color: var(--accent); text-decoration: none; }
  .toc a:hover { text-decoration: underline; }
</style>
</head>
<body>

<!-- ============ HERO ============ -->
<div class="hero">
  <h1>PACTA Portfolio Alignment Report</h1>
  <div class="subtitle">Paris Agreement Capital Transition Assessment &mdash; Demo Portfolio Analysis</div>
  <div class="meta">Generated: February 26, 2026 &nbsp;|&nbsp; Framework: r2dii / pacta.loanbook &nbsp;|&nbsp; Scenario: demo_2020</div>
</div>

<div class="container">

<!-- ============ TABLE OF CONTENTS ============ -->
<div class="toc">
  <h3>Contents</h3>
  <ol>
    <li><a href="#exec">Executive Summary</a></li>
    <li><a href="#method">Methodology</a></li>
    <li><a href="#matching">Data Matching &amp; Coverage</a></li>
    <li><a href="#power">Power Sector Analysis</a></li>
    <li><a href="#auto">Automotive Sector Analysis</a></li>
    <li><a href="#cement">Cement Sector Analysis</a></li>
    <li><a href="#steel">Steel Sector Analysis</a></li>
    <li><a href="#alignment">Overall Alignment Summary</a></li>
    <li><a href="#caveats">Caveats &amp; Limitations</a></li>
    <li><a href="#next">Recommended Next Steps</a></li>
  </ol>
</div>

<!-- ============ 1. EXECUTIVE SUMMARY ============ -->
<div class="executive-summary" id="exec">
  <h2>1. Executive Summary</h2>
  <p>This report presents the results of a PACTA alignment analysis applied to a demonstration loan portfolio. The analysis measures whether the real-economy activities financed by the portfolio are consistent with the Paris Agreement climate goals, using the <strong>Market Share Approach</strong> for power and automotive sectors, and the <strong>Sectoral Decarbonization Approach (SDA)</strong> for cement and steel.</p>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">177</div>
      <div class="label">Matched Loan&ndash;Company Pairs</div>
    </div>
    <div class="kpi-card">
      <div class="value">4</div>
      <div class="label">Sectors Analyzed</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">0 / 4</div>
      <div class="label">Sectors Aligned to Scenario</div>
    </div>
    <div class="kpi-card">
      <div class="value">2025</div>
      <div class="label">Target Assessment Year</div>
    </div>
  </div>

  <div class="callout callout-danger">
    <strong>Key Finding:</strong> The demo portfolio is <strong>not aligned</strong> with the Paris-consistent scenario pathway in any of the four assessed sectors. The largest gaps are in cement (emission intensity 76% above target) and automotive hybrids (production share 13 percentage points below target).
  </div>
</div>

<!-- ============ 2. METHODOLOGY ============ -->
<div class="section" id="method">
  <h2>2. Methodology</h2>
  <p>The analysis follows the standard PACTA for Banks methodology developed by RMI (Rocky Mountain Institute), implemented through the open-source <code>pacta.loanbook</code> R package ecosystem:</p>

  <h3>Pipeline Steps</h3>
  <ol style="padding-left: 1.5rem; margin: 0.8rem 0;">
    <li><strong>Data Preparation:</strong> A loan book (borrower names, sectors, loan amounts) is combined with the ABCD (Asset-Based Company Data) database containing physical production plans of companies in climate-relevant sectors.</li>
    <li><strong>Matching:</strong> Borrower names are fuzzy-matched to ABCD company names using the <code>r2dii.match</code> package. Matches are then prioritized (direct &gt; intermediate parent &gt; ultimate parent).</li>
    <li><strong>Market Share Approach:</strong> For power and automotive, the portfolio&rsquo;s weighted share of technology-level production is compared against scenario-derived targets (SDS, CPS, SPS).</li>
    <li><strong>Sectoral Decarbonization Approach (SDA):</strong> For cement and steel, the portfolio&rsquo;s weighted average CO&#8322; emission intensity (tCO&#8322;/tonne of product) is compared against a scenario-derived convergence pathway.</li>
  </ol>

  <h3>Scenario</h3>
  <p>This demo uses the built-in <code>demo_2020</code> scenario from the <code>r2dii.data</code> package. In a production setting, this would be replaced with IEA World Energy Outlook (SDS/STEPS/NZE) or NGFS scenarios.</p>

  <h3>Key Metrics Explained</h3>
  <table>
    <tr><th>Metric</th><th>Description</th></tr>
    <tr><td><code>projected</code></td><td>The portfolio&rsquo;s production/intensity trajectory based on matched companies&rsquo; forward-looking plans</td></tr>
    <tr><td><code>target_sds</code> / <code>target_demo</code></td><td>The required trajectory under the Sustainable Development Scenario</td></tr>
    <tr><td><code>corporate_economy</code></td><td>Market-wide benchmark &mdash; what the entire economy is doing</td></tr>
    <tr><td><code>adjusted_scenario_demo</code></td><td>Scenario target adjusted for the portfolio&rsquo;s starting point</td></tr>
  </table>
</div>

<!-- ============ 3. MATCHING ============ -->
<div class="section" id="matching">
  <h2>3. Data Matching &amp; Coverage</h2>
  <p>Before any alignment analysis, the loanbook must be matched to physical asset data. The quality of this match directly impacts the reliability of results &mdash; sectors with low coverage should be interpreted cautiously.</p>

  <div class="chart-container">
    <img src="', imgs$match_coverage, '" alt="Match Coverage by Sector">
    <div class="chart-caption">Figure 1: Loan exposure matched vs. unmatched against the ABCD database, by sector (millions EUR).</div>
  </div>

  <h3>Coverage Assessment</h3>
  <table>
    <tr><th>Sector</th><th>Matched (M EUR)</th><th>Unmatched (M EUR)</th><th>Coverage</th><th>Quality</th></tr>
    <tr><td>Automotive</td><td>~16</td><td>~0</td><td>~100%</td><td><span class="badge badge-green">Excellent</span></td></tr>
    <tr><td>Power</td><td>~25</td><td>~1</td><td>~96%</td><td><span class="badge badge-green">Very Good</span></td></tr>
    <tr><td>Cement</td><td>~8</td><td>~5</td><td>~62%</td><td><span class="badge badge-gray">Moderate</span></td></tr>
    <tr><td>Aviation</td><td>~1</td><td>~0</td><td>~100%</td><td><span class="badge badge-green">Good</span></td></tr>
    <tr><td>Steel</td><td>~0.5</td><td>~11</td><td>~4%</td><td><span class="badge badge-red">Poor</span></td></tr>
  </table>

  <div class="callout callout-warning">
    <strong>Data Quality Note:</strong> The steel sector has only ~4% match coverage. The alignment results for steel represent a tiny fraction of the portfolio&rsquo;s actual steel exposure and should not be used for decision-making without further data improvement.
  </div>
</div>

<!-- ============ 4. POWER SECTOR ============ -->
<div class="section" id="power">
  <h2>4. Power Sector Analysis</h2>
  <p>The power sector is assessed using the <strong>Market Share Approach</strong>, which compares the portfolio&rsquo;s capacity mix across generation technologies (renewables, coal, gas, hydro, nuclear, oil) against scenario targets.</p>

  <h3>4.1 Technology Mix</h3>
  <p>The stacked bars below compare the portfolio&rsquo;s technology share at 2020 and 2025 against the SDS target mix. A Paris-aligned portfolio should shift toward a higher renewables share and lower coal/gas share over time.</p>

  <div class="chart-container">
    <img src="', imgs$power_techmix, '" alt="Power Technology Mix">
    <div class="chart-caption">Figure 2: Power sector technology mix &mdash; projected portfolio composition vs. SDS target (2020 and 2025, global).</div>
  </div>

  <p><strong>Observation:</strong> The projected 2025 mix shows minimal change from 2020, with renewables remaining at ~40% of capacity. The SDS target for 2025, however, calls for renewables to rise to ~48%. Coal and gas shares remain stubbornly high relative to the scenario pathway.</p>

  <h3>4.2 Technology Trajectories</h3>
  <div class="two-charts">
    <div class="chart-container">
      <img src="', imgs$power_renew, '" alt="Renewables Trajectory">
      <div class="chart-caption">Figure 3a: Renewables capacity trajectory.</div>
    </div>
    <div class="chart-container">
      <img src="', imgs$power_coal, '" alt="Coal Trajectory">
      <div class="chart-caption">Figure 3b: Coal capacity trajectory.</div>
    </div>
  </div>

  <p>The trajectory charts show the portfolio&rsquo;s absolute production (black line) relative to the corporate economy benchmark (grey dashed). The portfolio holds a small fraction of global capacity, which compresses the projected and target lines near the bottom of the chart. The corporate economy benchmark (grey) dominates the y-axis scale.</p>

  <div class="callout callout-info">
    <strong>Interpretation Note:</strong> Several power technologies (gas, hydro, nuclear, renewables) show <code>NA</code> for projected production at 2025, indicating that matched companies lack forward-looking production data for these technologies. This prevents a complete power sector alignment assessment and is flagged as a data gap.
  </div>
</div>

<!-- ============ 5. AUTOMOTIVE SECTOR ============ -->
<div class="section" id="auto">
  <h2>5. Automotive Sector Analysis</h2>
  <p>The automotive sector is also assessed via the <strong>Market Share Approach</strong>, focusing on the production mix between internal combustion engine (ICE) vehicles, hybrids, and electric vehicles (EVs).</p>

  <h3>5.1 Technology Mix</h3>
  <div class="chart-container">
    <img src="', imgs$auto_techmix, '" alt="Automotive Technology Mix">
    <div class="chart-caption">Figure 4: Automotive technology mix &mdash; projected vs. SDS target (2020 and 2025, global).</div>
  </div>

  <p>This chart reveals a clear misalignment. By 2025, the SDS scenario expects:</p>
  <ul style="padding-left: 1.5rem; margin: 0.5rem 0;">
    <li><strong>ICE share to drop</strong> from ~81% to ~67%</li>
    <li><strong>Hybrid share to increase</strong> from ~3% to ~16%</li>
    <li><strong>Electric share to grow</strong> from ~16% to ~17%</li>
  </ul>
  <p>However, the portfolio&rsquo;s projected 2025 mix shows ICE still at ~80%, hybrids barely at ~3%, and electric at ~16%. The portfolio is essentially not transitioning.</p>

  <h3>5.2 Electric Vehicle Trajectory</h3>
  <div class="chart-container">
    <img src="', imgs$auto_ev, '" alt="EV Production Trajectory">
    <div class="chart-caption">Figure 5: Electric vehicle production trajectory &mdash; portfolio projected vs. scenario targets (global).</div>
  </div>

  <p>The portfolio&rsquo;s EV production (black line) tracks slightly below the SDS target (green line). While the gap is small in absolute terms, the portfolio is not keeping pace with the required ramp-up in zero-emission vehicle production.</p>

  <h3>5.3 Automotive Alignment at 2025</h3>
  <table>
    <tr><th>Technology</th><th>Projected Production</th><th>SDS Target</th><th>Gap</th><th>Aligned?</th></tr>
    <tr><td>Electric</td><td>154,800</td><td>222,159</td><td>&minus;67,359</td><td><span class="badge badge-red">No</span></td></tr>
    <tr><td>Hybrid</td><td>114,214</td><td>488,138</td><td>&minus;373,925</td><td><span class="badge badge-red">No</span></td></tr>
    <tr><td>ICE</td><td>2,276,030</td><td>1,980,366</td><td>+295,663</td><td><span class="badge badge-red">No*</span></td></tr>
  </table>

  <div class="callout callout-danger">
    <strong>*ICE &ldquo;overproduction&rdquo;:</strong> For high-carbon technologies like ICE, alignment means producing <em>at or below</em> the target. This portfolio is producing 295,663 more ICE vehicles than the SDS pathway allows &mdash; the single largest source of misalignment in the automotive sector.
  </div>
</div>

<!-- ============ 6. CEMENT SECTOR ============ -->
<div class="section" id="cement">
  <h2>6. Cement Sector Analysis</h2>
  <p>Cement is assessed using the <strong>Sectoral Decarbonization Approach (SDA)</strong>, which tracks CO&#8322; emission intensity (tonnes of CO&#8322; per tonne of cement produced) against a scenario-derived convergence pathway.</p>

  <div class="chart-container">
    <img src="', imgs$cement, '" alt="Cement Emission Intensity">
    <div class="chart-caption">Figure 6: Cement emission intensity trajectory &mdash; portfolio projected vs. scenario targets out to 2050 (global).</div>
  </div>

  <h3>Key Observations</h3>
  <ul style="padding-left: 1.5rem; margin: 0.5rem 0;">
    <li>The <strong>projected</strong> line (black) remains flat at approximately <strong>0.67 tCO&#8322;/tonne</strong> through the 5-year forward-looking window (2020&ndash;2025). The portfolio&rsquo;s cement companies show no planned reduction in emission intensity.</li>
    <li>The <strong>target</strong> line (green) plunges from 0.66 to <strong>0.38 tCO&#8322;/tonne</strong> by 2025, and continues declining to ~0.10 by 2050.</li>
    <li>The <strong>adjusted scenario</strong> (purple) closely tracks the target, confirming the portfolio started near the market average.</li>
    <li>The <strong>corporate economy</strong> (grey dashed) also remains flat, suggesting the entire cement market is failing to decarbonize at the pace needed.</li>
  </ul>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">0.669</div>
      <div class="label">Projected Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">0.380</div>
      <div class="label">Target Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">+76%</div>
      <div class="label">Above Target</div>
    </div>
  </div>

  <div class="callout callout-danger">
    <strong>Assessment:</strong> The portfolio&rsquo;s cement exposure is <strong>severely misaligned</strong>. At 0.669 tCO&#8322;/tonne, it is 76% above the 2025 target of 0.380. This represents the widest gap of any sector in the analysis and reflects the fundamental challenge of cement decarbonization &mdash; no major breakthrough in process emissions reduction is visible in the portfolio companies&rsquo; plans.
  </div>
</div>

<!-- ============ 7. STEEL SECTOR ============ -->
<div class="section" id="steel">
  <h2>7. Steel Sector Analysis</h2>
  <p>Steel is also assessed using the <strong>SDA</strong>, measuring tCO&#8322; per tonne of steel produced.</p>

  <div class="chart-container">
    <img src="', imgs$steel, '" alt="Steel Emission Intensity">
    <div class="chart-caption">Figure 7: Steel emission intensity trajectory &mdash; portfolio projected vs. scenario targets out to 2050 (global).</div>
  </div>

  <h3>Key Observations</h3>
  <ul style="padding-left: 1.5rem; margin: 0.5rem 0;">
    <li>The <strong>projected</strong> intensity (black) slightly <em>increases</em> to ~0.293 tCO&#8322;/tonne by 2025, moving in the wrong direction.</li>
    <li>The <strong>target</strong> (green) drops from 0.285 to <strong>0.214</strong> by 2025 and continues a steep decline to ~0.027 by 2050.</li>
    <li>The <strong>adjusted scenario</strong> (purple) begins lower than the target and converges by ~2040, reflecting the portfolio&rsquo;s lower starting intensity.</li>
    <li>Long-term, the scenario demands near-complete decarbonization of steel production by 2050.</li>
  </ul>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">0.293</div>
      <div class="label">Projected Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">0.214</div>
      <div class="label">Target Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">+37%</div>
      <div class="label">Above Target</div>
    </div>
  </div>

  <div class="callout callout-warning">
    <strong>Caveat:</strong> Recall that steel match coverage is only ~4%. These results are based on a very small sample of the portfolio&rsquo;s steel-related lending and may not represent the true exposure profile.
  </div>
</div>

<!-- ============ 8. OVERALL ALIGNMENT ============ -->
<div class="section" id="alignment">
  <h2>8. Overall Alignment Summary</h2>
  <p>The chart below shows the technology-level alignment gap for the Market Share sectors at 2025. Positive values indicate overexposure (bad for high-carbon technologies), negative values indicate underexposure (bad for low-carbon technologies).</p>

  <div class="chart-container">
    <img src="', imgs$alignment, '" alt="Alignment Overview">
    <div class="chart-caption">Figure 8: Portfolio alignment gap by technology at 2025 vs. SDS target. Power sector omitted due to data gaps.</div>
  </div>

  <p>The power sector panel is empty because most power technologies returned <code>NA</code> for projected values at 2025. Only automotive technologies could be assessed, and all three are misaligned.</p>

  <h3>Consolidated Alignment Table</h3>
  <table>
    <tr><th>Sector</th><th>Technology / Metric</th><th>Method</th><th>Gap</th><th>Status</th></tr>
    <tr><td>Automotive</td><td>Electric vehicles</td><td>Market Share</td><td>&minus;0.5pp share</td><td><span class="badge badge-red">Misaligned</span></td></tr>
    <tr><td>Automotive</td><td>Hybrid vehicles</td><td>Market Share</td><td>&minus;13.2pp share</td><td><span class="badge badge-red">Misaligned</span></td></tr>
    <tr><td>Automotive</td><td>ICE vehicles</td><td>Market Share</td><td>+13.8pp share</td><td><span class="badge badge-red">Misaligned</span></td></tr>
    <tr><td>Power</td><td>All technologies</td><td>Market Share</td><td>N/A</td><td><span class="badge badge-gray">Data Gap</span></td></tr>
    <tr><td>Cement</td><td>Emission intensity</td><td>SDA</td><td>+0.289 tCO&#8322;/t</td><td><span class="badge badge-red">Misaligned</span></td></tr>
    <tr><td>Steel</td><td>Emission intensity</td><td>SDA</td><td>+0.080 tCO&#8322;/t</td><td><span class="badge badge-red">Misaligned</span></td></tr>
  </table>
</div>

<!-- ============ 9. CAVEATS ============ -->
<div class="section" id="caveats">
  <h2>9. Caveats &amp; Limitations</h2>

  <div class="callout callout-info">
    <strong>This is a demonstration analysis.</strong> The following limitations should be understood before drawing any conclusions.
  </div>

  <ol style="padding-left: 1.5rem; margin: 0.8rem 0;">
    <li><strong>Demo data only:</strong> Both the loanbook and scenario data are synthetic samples from the <code>pacta.loanbook</code> package. Results do not reflect any real institution&rsquo;s portfolio.</li>
    <li><strong>Scenario limitations:</strong> The <code>demo_2020</code> scenario is illustrative. A real analysis would use IEA WEO, NGFS, or other authoritative scenarios with named pathways (SDS, NZE, etc.).</li>
    <li><strong>Match coverage varies widely:</strong> Steel at ~4% coverage cannot support meaningful conclusions. Cement at ~62% is usable but imperfect. Automotive and power have strong coverage.</li>
    <li><strong>Power sector data gaps:</strong> Most power technologies lack projected production data beyond the base year. A real ABCD dataset would typically provide 5&ndash;10 year forward projections.</li>
    <li><strong>No portfolio weighting shown:</strong> The analysis uses loan-size weighting internally, but the absolute production numbers do not directly reflect financial exposure.</li>
    <li><strong>Point-in-time assessment:</strong> Alignment is assessed at a single year (2025). A company that is misaligned at 2025 could still converge to the scenario path by 2030 or 2040.</li>
  </ol>
</div>

<!-- ============ 10. NEXT STEPS ============ -->
<div class="section" id="next">
  <h2>10. Recommended Next Steps</h2>
  <ol style="padding-left: 1.5rem; margin: 0.8rem 0;">
    <li><strong>Replace demo data with real loanbook:</strong> Prepare a CSV with columns: <code>id_loan</code>, <code>id_direct_loantaker</code>, <code>name_direct_loantaker</code>, <code>sector_classification_system</code>, <code>sector_classification_direct_loantaker</code>, <code>loan_size_outstanding</code>, <code>loan_size_outstanding_currency</code>.</li>
    <li><strong>Source production scenarios:</strong> Use IEA WEO or NGFS scenarios (available via the <code>r2dii.data</code> package or PACTA data downloads) for Paris-aligned pathways.</li>
    <li><strong>Improve match coverage:</strong> Manually review unmatched borrowers in the steel and cement sectors. Consider adding intermediate parent company names to improve fuzzy matching.</li>
    <li><strong>Extend to additional sectors:</strong> PACTA also supports oil &amp; gas and aviation. Include these sectors if relevant to the portfolio.</li>
    <li><strong>Engage with borrowers:</strong> Use the company-level results (37,349 rows in the detailed output) to identify the specific companies driving misalignment and initiate transition dialogues.</li>
    <li><strong>Build monitoring framework:</strong> Re-run the analysis quarterly or semi-annually to track whether alignment is improving over time.</li>
  </ol>
</div>

</div><!-- /container -->

<div class="footer">
  PACTA Portfolio Alignment Report &mdash; Generated with <code>pacta.loanbook</code> (r2dii ecosystem) &mdash; February 2026<br>
  This report is for demonstration and educational purposes only.
</div>

</body>
</html>')

# --- Write the HTML file ---
report_dir <- "reports"
dir.create(report_dir, showWarnings = FALSE, recursive = TRUE)
out_path <- file.path(report_dir, "PACTA_Alignment_Report.html")
writeLines(html, out_path, useBytes = TRUE)
cat(sprintf("\nReport saved to: %s\n", normalizePath(out_path)))
cat(sprintf("File size: %.1f KB\n", file.info(out_path)$size / 1024))

from __future__ import annotations

import json
from io import StringIO

import pandas as pd
import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner
from dashboard.lib.charts import ranked_bar
from dashboard.lib.loaders import load_trisk_grid, load_trisk_sector_tables, load_trisk_tables

DISCLAIMER = (
    "PD changes shown here are scenario-horizon shock summaries from the synthetic TRISK setup, "
    "not 1-year regulatory PDs or production credit model outputs."
)

CARBON_PRICE_LABELS = {
    "NGFS_NetZero2050": "Net Zero 2050 (strict)",
    "NGFS_Below2C": "Below 2\u00b0C (moderate)",
    "NGFS_Delayed": "Delayed transition (mild)",
}

DEFAULT_LEVERS = {
    "shock_year": 2028,
    "discount_rate": 0.08,
    "risk_free_rate": 0.03,
    "market_passthrough": 0.25,
    "carbon_price_family": "NGFS_NetZero2050",
}


def _build_scenario_id(
    shock_year: int, discount_rate: float, risk_free_rate: float,
    market_passthrough: float, carbon_price_family: str,
) -> str:
    return f"s{shock_year}_d{discount_rate}_rf{risk_free_rate}_mp{market_passthrough}_c{carbon_price_family}"


def _parse_scenario_id(scenario_id: str) -> dict:
    prefix, carbon_part = scenario_id.split("_c", 1)
    parts = prefix.split("_")
    return {
        "shock_year": int(parts[0][1:]),
        "discount_rate": float(parts[1][1:]),
        "risk_free_rate": float(parts[2][2:]),
        "market_passthrough": float(parts[3][2:]),
        "carbon_price_family": carbon_part,
    }


def _grid_label(scenario: pd.Series) -> str:
    return (
        f"Shock {scenario['shock_year']} | Disc {scenario['discount_rate']} | "
        f"RF {scenario['risk_free_rate']} | Pass {scenario['market_passthrough']} | "
        f"{CARBON_PRICE_LABELS.get(scenario['carbon_price_family'], scenario['carbon_price_family'])}"
    )


apply_page_frame("Scenario Builder", "Drive lever values and compare borrower stress outcomes side by side.")
public_demo_banner()
st.error(DISCLAIMER)

manifest = load_trisk_tables()["manifest"].copy()
grid_sectors = manifest[manifest["grid_available"] == True]["sector"].tolist()

if not grid_sectors:
    st.warning(
        "No sectors have precomputed scenario grids yet. "
        "Run the grid generator before using this page."
    )
    st.stop()

selected_sector = st.selectbox(
    "Sector",
    grid_sectors,
    index=0,
    key="scenario_sector",
    format_func=lambda v: manifest.loc[manifest["sector"] == v, "label"].iloc[0],
)

grid = load_trisk_grid(selected_sector)
scenarios = grid["scenarios"].copy()
borrower_results = grid["borrower_results"].copy()

sector_tables = load_trisk_sector_tables(selected_sector)
company_summary = sector_tables["company_summary"].copy()
company_summary["npv_change_pct"] = company_summary["npv_change"] * 100
company_summary["pd_change_bp"] = company_summary["pd_change"] * 10000

sensitivity = sector_tables["sensitivity_results"].copy()
baseline = sensitivity[sensitivity["parameter_name"] == "base"].copy()

lever_values = {
    "shock_year": sorted(scenarios["shock_year"].unique().tolist()),
    "discount_rate": sorted(scenarios["discount_rate"].unique().tolist()),
    "risk_free_rate": sorted(scenarios["risk_free_rate"].unique().tolist()),
    "market_passthrough": sorted(scenarios["market_passthrough"].unique().tolist()),
    "carbon_price_family": sorted(scenarios["carbon_price_family"].unique().tolist()),
}

query_params = st.query_params
restore_sid = query_params.get("scenario_id")
if restore_sid:
    try:
        parsed = _parse_scenario_id(restore_sid)
        for k, v in parsed.items():
            if k in lever_values and v in lever_values[k]:
                DEFAULT_LEVERS[k] = v
    except (ValueError, IndexError, KeyError):
        pass

st.markdown("### Lever controls")
lever_cols = st.columns([1, 1, 1, 1, 1.5])

with lever_cols[0]:
    shock_year = st.select_slider(
        "Shock year",
        options=lever_values["shock_year"],
        value=DEFAULT_LEVERS["shock_year"],
        key="sb_shock_year",
    )
with lever_cols[1]:
    discount_rate = st.select_slider(
        "Discount rate",
        options=lever_values["discount_rate"],
        value=DEFAULT_LEVERS["discount_rate"],
        key="sb_discount_rate",
    )
with lever_cols[2]:
    risk_free_rate = st.select_slider(
        "Risk-free rate",
        options=lever_values["risk_free_rate"],
        value=DEFAULT_LEVERS["risk_free_rate"],
        key="sb_risk_free_rate",
    )
with lever_cols[3]:
    market_passthrough = st.select_slider(
        "Market passthrough",
        options=lever_values["market_passthrough"],
        value=DEFAULT_LEVERS["market_passthrough"],
        key="sb_market_passthrough",
    )
with lever_cols[4]:
    carbon_price_family = st.selectbox(
        "Carbon price family",
        options=lever_values["carbon_price_family"],
        index=lever_values["carbon_price_family"].index(DEFAULT_LEVERS["carbon_price_family"]),
        format_func=lambda v: CARBON_PRICE_LABELS.get(v, v),
        key="sb_carbon_family",
    )

reset_clicked = st.button("Reset to baseline", type="secondary")
if reset_clicked:
    for k, v in DEFAULT_LEVERS.items():
        st.session_state[f"sb_{k}"] = v
    st.rerun()

current_sid = _build_scenario_id(
    shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family,
)
st.query_params["scenario_id"] = current_sid

scenario_row = scenarios[scenarios["scenario_id"] == current_sid]
if scenario_row.empty:
    st.error(f"Scenario {current_sid} not found in the grid.")
    st.stop()

scenario_data = borrower_results[borrower_results["scenario_id"] == current_sid].copy()
scenario_data = scenario_data[scenario_data["stress_priority_score"].notna()].copy()
scenario_data["npv_change_pct_display"] = scenario_data["npv_change_pct"] * 100
scenario_data["pd_change_bp"] = scenario_data["pd_change"] * 10000

st.info(f"**Active scenario:** {_grid_label(scenario_row.iloc[0])}")
st.caption(f"Scenario ID: `{current_sid}`")

st.subheader("Side-by-side: Baseline vs Scenario")
s1_left, s1_right = st.columns(2)

with s1_left:
    baseline_ranking = baseline.sort_values("stress_priority_score", ascending=False).head(10).copy()
    st.markdown("**Baseline (default stress)**")
    st.plotly_chart(
        ranked_bar(
            baseline_ranking,
            x="stress_priority_score",
            y="company_name",
            color="company_name",
            title="Baseline stress priority",
        ),
        use_container_width=True,
    )

with s1_right:
    scenario_ranking = scenario_data.sort_values("stress_priority_score", ascending=False).head(10).copy()
    st.markdown("**Scenario**")
    st.plotly_chart(
        ranked_bar(
            scenario_ranking,
            x="stress_priority_score",
            y="company_name",
            color="company_name",
            title=f"Scenario stress priority",
        ),
        use_container_width=True,
    )

st.subheader("Rank changes")
baseline_ranks = baseline[["company_id", "company_name", "stress_priority_score"]].copy()
baseline_ranks["baseline_rank"] = baseline_ranks["stress_priority_score"].rank(ascending=False, method="min").astype(int)

scenario_ranks = scenario_data[["company_id", "company_name", "stress_priority_score"]].copy()
scenario_ranks["scenario_rank"] = scenario_ranks["stress_priority_score"].rank(ascending=False, method="min").astype(int)

rank_delta = baseline_ranks.merge(
    scenario_ranks[["company_id", "scenario_rank"]],
    on="company_id",
    how="outer",
    suffixes=("_base", "_scenario"),
)
rank_delta["rank_delta"] = rank_delta["baseline_rank"] - rank_delta["scenario_rank"]
rank_delta["direction"] = rank_delta["rank_delta"].apply(
    lambda d: "" if d == 0 else ("\u25b2 moved up" if d > 0 else "\u25bc moved down")
)
rank_delta = rank_delta.sort_values("rank_delta", key=lambda s: s.abs(), ascending=False)

st.dataframe(
    rank_delta[["company_name", "baseline_rank", "scenario_rank", "rank_delta", "direction"]],
    use_container_width=True,
    hide_index=True,
    column_config={
        "company_name": "Company",
        "baseline_rank": st.column_config.NumberColumn("Base rank", format="%d"),
        "scenario_rank": st.column_config.NumberColumn("Scenario rank", format="%d"),
        "rank_delta": st.column_config.NumberColumn("\u0394 rank", format="%+d"),
        "direction": st.column_config.TextColumn("Move"),
    },
)

st.subheader("Top movers")
t1, t2 = st.columns(2)

with t1:
    st.markdown("**Top NPV movers**")
    npv_movers = scenario_data.reindex(scenario_data["delta_npv_change_vs_base"].abs().sort_values(ascending=False).index).head(5)
    npv_movers["delta_npv_change_vs_base_pct"] = npv_movers["delta_npv_change_vs_base"] * 100
    st.dataframe(
        npv_movers[["company_name", "delta_npv_change_vs_base_pct"]],
        use_container_width=True,
        hide_index=True,
        column_config={
            "company_name": "Company",
            "delta_npv_change_vs_base_pct": st.column_config.NumberColumn(
                "\u0394 NPV vs base (pp)", format="%+.2f"
            ),
        },
    )

with t2:
    st.markdown("**Top PD movers**")
    pd_movers = scenario_data.reindex(scenario_data["delta_pd_change_vs_base"].abs().sort_values(ascending=False).index).head(5)
    pd_movers["delta_pd_change_vs_base_bp"] = pd_movers["delta_pd_change_vs_base"] * 10000
    st.dataframe(
        pd_movers[["company_name", "delta_pd_change_vs_base_bp"]],
        use_container_width=True,
        hide_index=True,
        column_config={
            "company_name": "Company",
            "delta_pd_change_vs_base_bp": st.column_config.NumberColumn(
                "\u0394 PD vs base (bp)", format="%+.0f"
            ),
        },
    )

st.subheader("Save / Load")
save_col, load_col = st.columns(2)
with save_col:
    save_key = st.text_input("Label for this scenario", value=_grid_label(scenario_row.iloc[0]), key="sb_save_label")
    if st.button("Save current scenario", type="primary", key="sb_save_btn"):
        entry = {
            "label": save_key,
            "scenario_id": current_sid,
            "levers": {
                "shock_year": shock_year,
                "discount_rate": discount_rate,
                "risk_free_rate": risk_free_rate,
                "market_passthrough": market_passthrough,
                "carbon_price_family": carbon_price_family,
            },
        }
        saved = st.session_state.get("saved_scenarios", [])
        existing = [i for i, s in enumerate(saved) if s["scenario_id"] == current_sid]
        if existing:
            saved[existing[0]] = entry
        else:
            saved.append(entry)
        st.session_state["saved_scenarios"] = saved
        st.success(f"Saved as \"{save_key}\"")

with load_col:
    saved = st.session_state.get("saved_scenarios", [])
    if saved:
        load_options = {f"{s['label']} ({s['scenario_id']})": s for s in saved}
        selected_load = st.selectbox("Load saved scenario", list(load_options.keys()), key="sb_load_select")
        if st.button("Load", key="sb_load_btn"):
            entry = load_options[selected_load]
            for k, v in entry["levers"].items():
                st.session_state[f"sb_{k}"] = v
            st.rerun()
    else:
        st.info("No saved scenarios yet. Adjust the levers and click Save.")

st.subheader("Export")
e1, e2 = st.columns(2)
with e1:
    csv_buffer = StringIO()
    scenario_data.to_csv(csv_buffer, index=False)
    st.download_button(
        f"Download {selected_sector} scenario CSV",
        csv_buffer.getvalue().encode("utf-8"),
        file_name=f"scenario_{current_sid}.csv",
        mime="text/csv",
    )
with e2:
    scenario_json = {
        "scenario_id": current_sid,
        "sector": selected_sector,
        "levers": {
            "shock_year": shock_year,
            "discount_rate": discount_rate,
            "risk_free_rate": risk_free_rate,
            "market_passthrough": market_passthrough,
            "carbon_price_family": carbon_price_family,
        },
        "grid_label": _grid_label(scenario_row.iloc[0]),
    }
    st.download_button(
        "Download scenario JSON",
        json.dumps(scenario_json, indent=2).encode("utf-8"),
        file_name=f"scenario_{current_sid}.json",
        mime="application/json",
    )

footer_note()

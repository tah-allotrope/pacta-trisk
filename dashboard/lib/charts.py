from __future__ import annotations

import pandas as pd
import plotly.express as px


ALLotrope_COLORS = ["#00E5FF", "#39FF14", "#7CFFB2", "#2F81F7", "#FFB000", "#F85149"]


def _base_layout(fig, title: str | None = None):
    fig.update_layout(
        title=title,
        template="plotly_dark",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        colorway=ALLotrope_COLORS,
        margin=dict(l=16, r=16, t=52, b=16),
        legend_title_text="",
        height=360,
    )
    fig.update_xaxes(gridcolor="rgba(255,255,255,0.08)")
    fig.update_yaxes(gridcolor="rgba(255,255,255,0.08)")
    return fig


def alignment_bar(df: pd.DataFrame, x: str, y: str, color: str, title: str):
    fig = px.bar(df, x=x, y=y, color=color, text_auto=True)
    return _base_layout(fig, title)


def trajectory_line(df: pd.DataFrame, x: str, y: str, color: str, title: str):
    fig = px.line(df, x=x, y=y, color=color, markers=True)
    return _base_layout(fig, title)


def npv_var_scatter(df: pd.DataFrame, x: str, y: str, color: str, hover_name: str, title: str):
    fig = px.scatter(df, x=x, y=y, color=color, hover_name=hover_name, size_max=18)
    return _base_layout(fig, title)


def ranked_bar(df: pd.DataFrame, x: str, y: str, color: str, title: str):
    fig = px.bar(df, x=x, y=y, color=color, orientation="h")
    return _base_layout(fig, title)


def pd_change_heatmap(df: pd.DataFrame, x: str, y: str, z: str, title: str):
    pivot = df.pivot(index=y, columns=x, values=z)
    fig = px.imshow(pivot, text_auto=True, aspect="auto", color_continuous_scale="Tealgrn")
    return _base_layout(fig, title)

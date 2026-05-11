"""
Notivo Analytics Platform — Chart Builder

Reusable chart components with consistent styling.
All dashboards and notebooks import from here to ensure
visual consistency across the entire analytics platform.

Usage:
    from src.visualization.chart_builder import ChartBuilder
    cb = ChartBuilder()
    fig = cb.retention_heatmap(retention_matrix_df)
"""

from __future__ import annotations
from typing import Optional, List

import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots


# ─── Brand Colors ─────────────────────────────────────────────
NOTIVO_COLORS = {
    "primary":    "#3B82F6",   # blue
    "success":    "#10B981",   # green
    "warning":    "#F59E0B",   # amber
    "danger":     "#EF4444",   # red
    "neutral":    "#6B7280",   # gray
    "expansion":  "#059669",   # dark green
    "contraction": "#D97706",  # dark amber
    "churn":      "#DC2626",   # dark red
    "new":        "#2563EB",   # medium blue
}

PLOTLY_TEMPLATE = "plotly_white"


class ChartBuilder:
    """Factory for consistently styled Plotly charts."""

    def __init__(self, theme: str = PLOTLY_TEMPLATE) -> None:
        self.theme = theme

    def retention_heatmap(
        self,
        matrix: pd.DataFrame,
        title: str = "Cohort Retention Matrix",
    ) -> go.Figure:
        """
        Render a cohort retention heatmap.
        Rows = cohort months, columns = months since signup (M0-M12).
        """
        fig = go.Figure(
            go.Heatmap(
                z=matrix.values,
                x=matrix.columns.tolist(),
                y=matrix.index.tolist(),
                colorscale=[
                    [0.0,  "#EF4444"],   # red (0%)
                    [0.4,  "#F59E0B"],   # amber (40%)
                    [0.7,  "#10B981"],   # green (70%)
                    [1.0,  "#065F46"],   # dark green (100%)
                ],
                zmid=50,
                text=[[f"{v:.0f}%" if not pd.isna(v) else "" for v in row]
                      for row in matrix.values],
                texttemplate="%{text}",
                textfont={"size": 10},
                hoverongaps=False,
                colorbar=dict(
                    title="Retention %",
                    ticksuffix="%",
                ),
            )
        )
        fig.update_layout(
            title=dict(text=f"<b>{title}</b>", font=dict(size=16)),
            xaxis_title="Months Since Signup",
            yaxis_title="Cohort Month",
            template=self.theme,
            height=450,
        )
        return fig

    def mrr_waterfall(
        self,
        df: pd.DataFrame,
        month_col: str = "month",
        title: str = "MRR Waterfall",
    ) -> go.Figure:
        """
        Monthly MRR waterfall chart showing new, expansion,
        contraction, and churned MRR with total MRR overlay.
        """
        fig = make_subplots(specs=[[{"secondary_y": True}]])

        bars = [
            ("new_mrr",         "New MRR",     NOTIVO_COLORS["new"]),
            ("expansion_mrr",   "Expansion",   NOTIVO_COLORS["expansion"]),
            ("contraction_mrr", "Contraction", NOTIVO_COLORS["contraction"]),
            ("churned_mrr",     "Churned",     NOTIVO_COLORS["churn"]),
        ]

        for col, name, color in bars:
            if col in df.columns:
                fig.add_trace(
                    go.Bar(
                        name=name,
                        x=df[month_col],
                        y=df[col],
                        marker_color=color,
                        offsetgroup=0,
                    ),
                    secondary_y=False,
                )

        if "total_mrr" in df.columns:
            fig.add_trace(
                go.Scatter(
                    name="Total MRR",
                    x=df[month_col],
                    y=df["total_mrr"],
                    mode="lines+markers",
                    line=dict(color=NOTIVO_COLORS["primary"], width=3),
                    marker=dict(size=6),
                ),
                secondary_y=True,
            )

        fig.update_layout(
            title=dict(text=f"<b>{title}</b>", font=dict(size=16)),
            barmode="relative",
            template=self.theme,
            height=480,
            legend=dict(orientation="h", y=1.1),
            yaxis=dict(title="MRR Change ($)", tickformat="$,.0f"),
            yaxis2=dict(title="Total MRR ($)", tickformat="$,.0f", showgrid=False),
        )
        return fig

    def funnel_chart(
        self,
        steps: List[str],
        values: List[int],
        title: str = "Conversion Funnel",
    ) -> go.Figure:
        """Conversion funnel visualization."""
        pcts = [v / values[0] * 100 for v in values]
        step_pcts = [100.0] + [
            values[i] / values[i-1] * 100 for i in range(1, len(values))
        ]

        colors = [
            NOTIVO_COLORS["success"] if p >= 70
            else NOTIVO_COLORS["warning"] if p >= 40
            else NOTIVO_COLORS["danger"]
            for p in pcts
        ]

        fig = go.Figure(go.Funnel(
            y=steps,
            x=values,
            textinfo="value+percent initial",
            marker=dict(color=colors),
            connector=dict(line=dict(color="white", width=2)),
        ))

        fig.update_layout(
            title=dict(text=f"<b>{title}</b>", font=dict(size=16)),
            template=self.theme,
            height=450,
        )
        return fig

    def kpi_sparkline_card(
        self,
        title: str,
        current_value: float,
        prior_value: float,
        trend_data: pd.Series,
        value_format: str = ",.0f",
        good_direction: str = "up",
    ) -> go.Figure:
        """
        KPI card with sparkline for dashboard header.
        Used in the executive dashboard for ARR, MAU, etc.
        """
        delta = current_value - prior_value
        delta_pct = delta / abs(prior_value) * 100 if prior_value else 0
        is_positive = delta > 0
        is_good = is_positive if good_direction == "up" else not is_positive
        delta_color = NOTIVO_COLORS["success"] if is_good else NOTIVO_COLORS["danger"]

        fig = go.Figure()

        # Sparkline
        fig.add_trace(go.Scatter(
            x=list(range(len(trend_data))),
            y=trend_data.values,
            mode="lines",
            line=dict(
                color=delta_color,
                width=2,
            ),
            fill="tozeroy",
            fillcolor=f"rgba({','.join(str(int(c*255)) for c in px.colors.hex_to_rgb(delta_color))},0.1)",
        ))

        fig.update_layout(
            title=dict(
                text=(
                    f"<b>{title}</b><br>"
                    f"<span style='font-size:22px'>{format(current_value, value_format)}</span>"
                    f"<span style='color:{delta_color};font-size:14px'> "
                    f"{'▲' if delta > 0 else '▼'} {abs(delta_pct):.1f}%</span>"
                ),
                x=0.05,
            ),
            height=150,
            margin=dict(l=10, r=10, t=60, b=10),
            template=self.theme,
            xaxis=dict(visible=False),
            yaxis=dict(visible=False),
            showlegend=False,
        )
        return fig

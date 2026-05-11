"""
Notivo Analytics Platform — KPI Calculator

Canonical implementations of all business KPIs.
All metrics are defined once here — notebooks and dashboards
import from this module to ensure consistency.

Usage:
    from src.metrics.kpi_calculator import KPICalculator
    calc = KPICalculator(conn)
    mrr_df = calc.mrr_waterfall(months=12)
"""

from __future__ import annotations

from typing import Optional
import pandas as pd
import numpy as np
from loguru import logger


class KPICalculator:
    """
    Centralized KPI calculation engine.

    All metric definitions live here. If a definition changes,
    it changes everywhere automatically.
    """

    def __init__(self, conn) -> None:
        """
        Args:
            conn: DuckDB or SQLAlchemy connection object
        """
        self.conn = conn

    # ─── Revenue Metrics ─────────────────────────────────────

    def current_mrr(self) -> float:
        """
        Monthly Recurring Revenue: normalized monthly value of all
        active subscription contracts. Annual subscriptions are
        divided by 12 to get MRR (not recognized fully upfront).
        """
        query = """
            SELECT COALESCE(SUM(mrr), 0) AS mrr
            FROM subscriptions
            WHERE status = 'active'
        """
        result = self.conn.execute(query).fetchone()
        return float(result[0])

    def mrr_waterfall(self, months: int = 12) -> pd.DataFrame:
        """
        MRR waterfall: decompose net MRR change into new, expansion,
        contraction, and churn components.

        Returns:
            DataFrame with columns: month, new_mrr, expansion_mrr,
            contraction_mrr, churned_mrr, net_new_mrr, total_mrr
        """
        query = """
        WITH monthly_mrr AS (
            SELECT
                workspace_id,
                DATE_TRUNC('month', current_period_start)::DATE AS mrr_month,
                SUM(mrr) AS total_mrr
            FROM subscriptions
            WHERE status IN ('active', 'past_due')
            GROUP BY 1, 2
        ),
        mrr_with_lag AS (
            SELECT
                *,
                LAG(total_mrr) OVER (PARTITION BY workspace_id ORDER BY mrr_month) AS prev_mrr
            FROM monthly_mrr
        )
        SELECT
            mrr_month,
            SUM(CASE WHEN prev_mrr IS NULL THEN total_mrr ELSE 0 END) AS new_mrr,
            SUM(CASE WHEN prev_mrr IS NOT NULL AND total_mrr > prev_mrr
                     THEN total_mrr - prev_mrr ELSE 0 END) AS expansion_mrr,
            SUM(CASE WHEN prev_mrr IS NOT NULL AND total_mrr < prev_mrr
                     THEN total_mrr - prev_mrr ELSE 0 END) AS contraction_mrr,
            SUM(total_mrr) AS total_mrr
        FROM mrr_with_lag
        WHERE mrr_month >= CURRENT_DATE - INTERVAL '{months} months'
        GROUP BY mrr_month
        ORDER BY mrr_month
        """.format(months=months)

        df = self.conn.execute(query).df()
        df["net_new_mrr"] = (
            df["new_mrr"] + df["expansion_mrr"] + df["contraction_mrr"]
        )
        return df

    def net_revenue_retention(
        self,
        cohort_month: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Net Revenue Retention (NRR): 12-month revenue retained from
        existing customers including expansion and contraction.

        NRR > 100% means the cohort grows revenue without new logos.
        """
        query = """
        WITH cohort_baseline AS (
            SELECT
                w.workspace_id,
                DATE_TRUNC('month', w.created_at)::DATE AS cohort_month,
                SUM(s.mrr) AS baseline_mrr
            FROM workspaces w
            JOIN subscriptions s ON w.workspace_id = s.workspace_id
            WHERE DATE_TRUNC('month', s.started_at) = DATE_TRUNC('month', w.created_at)
            GROUP BY 1, 2
        ),
        cohort_12m AS (
            SELECT
                w.workspace_id,
                DATE_TRUNC('month', w.created_at)::DATE AS cohort_month,
                SUM(s.mrr) AS mrr_at_12m
            FROM workspaces w
            JOIN subscriptions s ON w.workspace_id = s.workspace_id
            WHERE DATE_TRUNC('month', s.current_period_start)
                  = DATE_TRUNC('month', w.created_at) + INTERVAL '12 months'
              AND s.status IN ('active', 'past_due')
            GROUP BY 1, 2
        )
        SELECT
            cb.cohort_month,
            SUM(cb.baseline_mrr) AS baseline_mrr,
            COALESCE(SUM(c12.mrr_at_12m), 0) AS mrr_at_12m,
            ROUND(
                COALESCE(SUM(c12.mrr_at_12m), 0) / NULLIF(SUM(cb.baseline_mrr), 0) * 100,
                1
            ) AS nrr_pct
        FROM cohort_baseline cb
        LEFT JOIN cohort_12m c12 ON cb.workspace_id = c12.workspace_id
        GROUP BY cb.cohort_month
        ORDER BY cb.cohort_month
        """
        return self.conn.execute(query).df()

    def ltv_by_channel(self) -> pd.DataFrame:
        """
        Customer Lifetime Value segmented by acquisition channel.
        LTV = ARPU × Gross Margin × Avg Lifetime Months
        Gross margin assumed at 70% (SaaS industry benchmark).
        """
        GROSS_MARGIN = 0.70

        query = """
        SELECT
            mc.channel_name,
            mc.channel_type,
            mc.cac_estimate,
            COUNT(DISTINCT w.workspace_id) AS workspaces,
            AVG(s.mrr) AS avg_mrr,
            AVG(CASE
                WHEN s.canceled_at IS NOT NULL
                THEN DATE_PART('month', AGE(s.canceled_at, s.started_at))
                ELSE DATE_PART('month', AGE(CURRENT_DATE, s.started_at))
            END) AS avg_lifetime_months
        FROM workspaces w
        JOIN marketing_channels mc ON w.channel_id = mc.channel_id
        JOIN subscriptions s ON w.workspace_id = s.workspace_id
        GROUP BY 1, 2, 3
        """
        df = self.conn.execute(query).df()
        df["ltv"] = (
            df["avg_mrr"] * df["avg_lifetime_months"] * GROSS_MARGIN
        ).round(0)
        df["ltv_cac_ratio"] = (
            df["ltv"] / df["cac_estimate"].replace(0, np.nan)
        ).round(2)
        df["payback_months"] = (
            df["cac_estimate"] / (df["avg_mrr"] * GROSS_MARGIN).replace(0, np.nan)
        ).round(1)
        return df.sort_values("ltv_cac_ratio", ascending=False)

    # ─── Engagement Metrics ───────────────────────────────────

    def dau_wau_mau(self, lookback_days: int = 90) -> pd.DataFrame:
        """
        Daily, Weekly, Monthly Active Users.
        An "active" user is one with at least one session in the period.
        """
        query = f"""
        WITH date_spine AS (
            SELECT UNNEST(
                generate_series(
                    CURRENT_DATE - INTERVAL '{lookback_days} days',
                    CURRENT_DATE,
                    INTERVAL '1 day'
                )
            )::DATE AS date
        )
        SELECT
            ds.date,
            COUNT(DISTINCT CASE WHEN s.started_at::DATE = ds.date
                THEN s.user_id END) AS dau,
            COUNT(DISTINCT CASE WHEN s.started_at::DATE BETWEEN ds.date - 6 AND ds.date
                THEN s.user_id END) AS wau,
            COUNT(DISTINCT CASE WHEN s.started_at::DATE BETWEEN ds.date - 29 AND ds.date
                THEN s.user_id END) AS mau
        FROM date_spine ds
        LEFT JOIN sessions s ON s.started_at::DATE <= ds.date
        GROUP BY ds.date
        ORDER BY ds.date
        """
        df = self.conn.execute(query).df()
        df["stickiness"] = (df["dau"] / df["mau"].replace(0, np.nan)).round(3)
        return df

    def stickiness(self, date: Optional[str] = None) -> float:
        """
        DAU/MAU ratio. Target: >0.30 for healthy B2B SaaS.
        Measures habit formation and product stickiness.
        """
        ref = date or "CURRENT_DATE"
        query = f"""
        SELECT
            COUNT(DISTINCT CASE WHEN started_at::DATE = {ref}
                THEN user_id END)::FLOAT /
            NULLIF(COUNT(DISTINCT CASE WHEN started_at::DATE >= {ref} - 29
                THEN user_id END), 0) AS stickiness
        FROM sessions
        """
        result = self.conn.execute(query).fetchone()
        return round(float(result[0] or 0), 4)

    # ─── Retention Metrics ────────────────────────────────────

    def cohort_retention_matrix(self, max_months: int = 12) -> pd.DataFrame:
        """
        Build the cohort retention matrix.

        Returns a pivot table: rows = cohort months,
        columns = months 0..N, values = retention rate %.
        """
        query = f"""
        WITH user_cohorts AS (
            SELECT user_id, DATE_TRUNC('month', created_at)::DATE AS cohort_month
            FROM users WHERE is_deleted = FALSE
        ),
        monthly_activity AS (
            SELECT DISTINCT user_id, DATE_TRUNC('month', started_at)::DATE AS activity_month
            FROM sessions
        ),
        cohort_activity AS (
            SELECT
                uc.cohort_month,
                uc.user_id,
                (DATE_PART('year', ma.activity_month) - DATE_PART('year', uc.cohort_month)) * 12
                + (DATE_PART('month', ma.activity_month) - DATE_PART('month', uc.cohort_month))
                    AS months_since_signup
            FROM user_cohorts uc
            JOIN monthly_activity ma ON uc.user_id = ma.user_id
        ),
        cohort_sizes AS (
            SELECT cohort_month, COUNT(DISTINCT user_id) AS cohort_size
            FROM user_cohorts GROUP BY 1
        ),
        retention AS (
            SELECT
                ca.cohort_month,
                ca.months_since_signup,
                COUNT(DISTINCT ca.user_id) AS retained
            FROM cohort_activity ca
            WHERE ca.months_since_signup BETWEEN 0 AND {max_months}
            GROUP BY 1, 2
        )
        SELECT
            r.cohort_month,
            cs.cohort_size,
            r.months_since_signup,
            ROUND(r.retained::NUMERIC / NULLIF(cs.cohort_size, 0) * 100, 1) AS retention_pct
        FROM retention r
        JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
        ORDER BY r.cohort_month, r.months_since_signup
        """
        long = self.conn.execute(query).df()

        # Pivot to matrix format
        matrix = long.pivot_table(
            index="cohort_month",
            columns="months_since_signup",
            values="retention_pct",
            aggfunc="mean",
        )
        matrix.columns = [f"M{int(c)}" for c in matrix.columns]
        matrix.index = pd.to_datetime(matrix.index).strftime("%Y-%m")
        return matrix

    # ─── Churn Metrics ────────────────────────────────────────

    def churn_rate(self, period: str = "monthly") -> pd.DataFrame:
        """
        Gross logo and revenue churn rates.
        Logo churn = % of paying workspaces that cancelled.
        Revenue churn = % of MRR lost to cancellations.
        """
        if period == "monthly":
            trunc = "month"
        else:
            trunc = "year"

        query = f"""
        WITH active_start AS (
            SELECT
                DATE_TRUNC('{trunc}', current_period_start)::DATE AS period,
                COUNT(DISTINCT workspace_id) AS active_workspaces,
                SUM(mrr) AS active_mrr
            FROM subscriptions
            WHERE status IN ('active', 'past_due')
            GROUP BY 1
        ),
        churn_events AS (
            SELECT
                DATE_TRUNC('{trunc}', canceled_at)::DATE AS period,
                COUNT(DISTINCT workspace_id) AS churned_workspaces,
                SUM(mrr_lost) AS churned_mrr
            FROM cancellations
            GROUP BY 1
        )
        SELECT
            a.period,
            a.active_workspaces,
            a.active_mrr,
            COALESCE(c.churned_workspaces, 0) AS churned_workspaces,
            COALESCE(c.churned_mrr, 0) AS churned_mrr,
            ROUND(
                COALESCE(c.churned_workspaces, 0)::NUMERIC
                / NULLIF(a.active_workspaces, 0) * 100, 2
            ) AS gross_logo_churn_pct,
            ROUND(
                COALESCE(c.churned_mrr, 0) / NULLIF(a.active_mrr, 0) * 100, 2
            ) AS gross_revenue_churn_pct
        FROM active_start a
        LEFT JOIN churn_events c ON a.period = c.period
        ORDER BY a.period
        """
        return self.conn.execute(query).df()

    def activation_rate(self, window_days: int = 7) -> pd.DataFrame:
        """
        Activation rate: % of new users who complete all 5 onboarding
        steps within `window_days` days of signup.

        Activation is the single most important leading indicator
        of long-term retention and paid conversion.
        """
        query = f"""
        WITH user_step_counts AS (
            SELECT
                u.user_id,
                u.created_at::DATE AS signup_date,
                COUNT(os.step_id) FILTER (
                    WHERE os.is_completed = TRUE
                    AND os.completed_at <= u.created_at + INTERVAL '{window_days} days'
                ) AS steps_completed_in_window
            FROM users u
            LEFT JOIN onboarding_steps os ON u.user_id = os.user_id
            WHERE u.is_deleted = FALSE
            GROUP BY 1, 2
        )
        SELECT
            DATE_TRUNC('week', signup_date)::DATE AS week,
            COUNT(*) AS new_users,
            SUM(CASE WHEN steps_completed_in_window >= 5 THEN 1 ELSE 0 END)
                AS fully_activated,
            ROUND(
                SUM(CASE WHEN steps_completed_in_window >= 5 THEN 1 ELSE 0 END)::NUMERIC
                / NULLIF(COUNT(*), 0) * 100,
                1
            ) AS activation_rate_pct
        FROM user_step_counts
        GROUP BY 1
        ORDER BY 1
        """
        return self.conn.execute(query).df()

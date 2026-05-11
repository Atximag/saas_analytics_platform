"""
Notivo Analytics Platform — RFM & Behavioral Segmentation

Segments workspaces and users into actionable groups for:
- CSM prioritization (at-risk intervention)
- Sales expansion targeting (upsell candidates)
- Marketing suppression (healthy = don't churn them with emails)
- Product feedback recruitment (power users)

Usage:
    from src.segmentation.rfm_segmentation import RFMSegmenter
    segmenter = RFMSegmenter(conn)
    segments = segmenter.workspace_rfm()
"""

from __future__ import annotations

from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from loguru import logger
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans


class RFMSegmenter:
    """
    RFM (Recency, Frequency, Monetary) segmentation engine.

    Workspace-level segmentation for B2B use cases.
    User-level segmentation for PLG and product teams.
    """

    # Segment labels and their strategic action
    SEGMENT_PLAYBOOK: Dict[str, Dict] = {
        "Champions": {
            "description": "Best customers. High engagement, high value, recent activity.",
            "action":      "Recruit for case studies, referral program, beta features.",
            "csm_priority": "Low (protect relationship)",
        },
        "Loyal": {
            "description": "Consistent users with strong retention track record.",
            "action":      "Identify upsell opportunities (seat expansion, plan upgrade).",
            "csm_priority": "Medium (expansion focus)",
        },
        "Promising": {
            "description": "Recent signups showing strong early engagement.",
            "action":      "Accelerate onboarding. Get them to the aha moment fast.",
            "csm_priority": "High (activation critical window)",
        },
        "At Risk": {
            "description": "Were engaged, showing declining activity. Pre-churn signal.",
            "action":      "Proactive CSM outreach. Win-back campaign. Health check call.",
            "csm_priority": "Critical (churn prevention)",
        },
        "Cant Lose Them": {
            "description": "High value accounts that have gone quiet.",
            "action":      "Executive escalation. Emergency health check. Custom offer.",
            "csm_priority": "Critical + exec escalation",
        },
        "Need Attention": {
            "description": "Average activity, at risk of drifting lower.",
            "action":      "Educational content. Feature adoption nudge emails.",
            "csm_priority": "Low (automated nurture)",
        },
        "Hibernating": {
            "description": "No recent activity. Likely churned or dormant.",
            "action":      "Win-back sequence or sunset. Don't waste CSM time.",
            "csm_priority": "None (automated)",
        },
        "Average": {
            "description": "Mid-tier engagement. No clear signal.",
            "action":      "Monitor. Trigger if engagement drops further.",
            "csm_priority": "Low",
        },
    }

    def __init__(self, conn) -> None:
        self.conn = conn

    def _classify_rfm(self, r: int, f: int, m: int) -> str:
        """Map RFM scores (1-5 each) to segment name."""
        if r >= 4 and f >= 4 and m >= 4:
            return "Champions"
        if r >= 3 and f >= 3 and m >= 3:
            return "Loyal"
        if r >= 4 and f <= 2:
            return "Promising"
        if r <= 2 and f >= 3 and m >= 3:
            return "At Risk"
        if r <= 2 and f <= 2 and m >= 3:
            return "Cant Lose Them"
        if r >= 3 and f <= 2 and m <= 2:
            return "Need Attention"
        if r <= 1:
            return "Hibernating"
        return "Average"

    def workspace_rfm(
        self,
        analysis_date: Optional[str] = None,
        n_tiles: int = 5,
    ) -> pd.DataFrame:
        """
        Compute RFM scores for every workspace.

        Args:
            analysis_date: Reference date (defaults to today)
            n_tiles: Number of scoring tiers (default 5)

        Returns:
            DataFrame with workspace RFM scores, segment labels,
            and strategic action recommendations.
        """
        ref_date = analysis_date or "CURRENT_DATE"

        query = f"""
        SELECT
            w.workspace_id,
            w.workspace_name,
            w.company_size,
            mc.channel_name,
            sub.plan_id,
            sub.mrr,
            sub.seat_count,
            -- Recency: days since any session
            DATE_PART('day', {ref_date}::TIMESTAMP - MAX(s.started_at))
                AS recency_days,
            -- Frequency: unique session days in last 30 days
            COUNT(DISTINCT s.started_at::DATE) FILTER (
                WHERE s.started_at >= {ref_date}::DATE - 30
            ) AS frequency_30d,
            -- Monetary: current MRR
            COALESCE(sub.mrr, 0) AS monetary_mrr
        FROM workspaces w
        LEFT JOIN sessions s ON w.workspace_id = s.workspace_id
        LEFT JOIN marketing_channels mc ON w.channel_id = mc.channel_id
        LEFT JOIN subscriptions sub
            ON w.workspace_id = sub.workspace_id
            AND sub.status = 'active'
        WHERE w.is_deleted = FALSE
        GROUP BY
            w.workspace_id, w.workspace_name, w.company_size,
            mc.channel_name, sub.plan_id, sub.mrr, sub.seat_count
        HAVING MAX(s.started_at) IS NOT NULL
        """

        df = self.conn.execute(query).df()

        if df.empty:
            logger.warning("No data returned for RFM analysis")
            return df

        # Score each dimension 1-5
        df["r_score"] = pd.qcut(
            df["recency_days"].rank(method="first"),
            q=n_tiles,
            labels=range(n_tiles, 0, -1),  # low days = high score
        ).astype(int)

        df["f_score"] = pd.qcut(
            df["frequency_30d"].rank(method="first"),
            q=n_tiles,
            labels=range(1, n_tiles + 1),
        ).astype(int)

        df["m_score"] = pd.qcut(
            df["monetary_mrr"].rank(method="first"),
            q=n_tiles,
            labels=range(1, n_tiles + 1),
        ).astype(int)

        df["rfm_score"] = (
            df["r_score"].astype(str)
            + df["f_score"].astype(str)
            + df["m_score"].astype(str)
        )

        df["rfm_avg"] = (
            (df["r_score"] + df["f_score"] + df["m_score"]) / 3
        ).round(2)

        df["segment"] = df.apply(
            lambda row: self._classify_rfm(
                row["r_score"], row["f_score"], row["m_score"]
            ),
            axis=1,
        )

        df["strategic_action"] = df["segment"].map(
            lambda s: self.SEGMENT_PLAYBOOK.get(s, {}).get("action", "")
        )

        df["csm_priority"] = df["segment"].map(
            lambda s: self.SEGMENT_PLAYBOOK.get(s, {}).get("csm_priority", "")
        )

        logger.info(f"RFM segmentation complete: {len(df):,} workspaces")
        logger.info("\nSegment distribution:\n"
                    + df["segment"].value_counts().to_string())

        return df.sort_values("rfm_avg", ascending=False)

    def segment_summary(self, rfm_df: pd.DataFrame) -> pd.DataFrame:
        """
        Aggregate segment metrics for executive reporting.
        Shows MRR concentration, churn risk by segment.
        """
        summary = (
            rfm_df.groupby("segment")
            .agg(
                workspace_count=("workspace_id", "count"),
                total_mrr=("monetary_mrr", "sum"),
                avg_mrr=("monetary_mrr", "mean"),
                avg_recency=("recency_days", "mean"),
                avg_frequency=("frequency_30d", "mean"),
            )
            .reset_index()
        )
        summary["mrr_share_pct"] = (
            summary["total_mrr"] / summary["total_mrr"].sum() * 100
        ).round(1)

        return summary.sort_values("total_mrr", ascending=False)

    def identify_expansion_candidates(
        self,
        rfm_df: pd.DataFrame,
        min_mrr: float = 0,
        target_plans: Optional[List[str]] = None,
    ) -> pd.DataFrame:
        """
        Filter RFM output to identify the best upsell/expansion targets.

        Expansion candidates are:
        - Loyal or Champions segments (healthy relationship)
        - Currently on a lower plan tier
        - High engagement signals
        """
        if target_plans is None:
            target_plans = ["free", "pro"]

        mask = (
            rfm_df["segment"].isin(["Champions", "Loyal", "Promising"])
            & rfm_df["plan_id"].isin(target_plans)
            & (rfm_df["monetary_mrr"] >= min_mrr)
        )

        candidates = rfm_df[mask].copy()
        candidates["expansion_priority"] = (
            candidates["rfm_avg"] * candidates["frequency_30d"]
        ).rank(ascending=False).astype(int)

        logger.info(f"Identified {len(candidates):,} expansion candidates")
        return candidates.sort_values("expansion_priority")

    def k_means_behavioral_clusters(
        self,
        n_clusters: int = 5,
    ) -> Tuple[pd.DataFrame, KMeans]:
        """
        Alternative to RFM: k-means clustering on behavioral features.
        Used when we want data-driven segments rather than rule-based.

        Features: session frequency, feature breadth, event diversity,
        collaboration score, creation score.
        """
        query = """
        SELECT
            u.user_id,
            u.workspace_id,
            COUNT(DISTINCT s.started_at::DATE)          AS active_days_30d,
            COUNT(DISTINCT fu.feature_name)             AS feature_breadth,
            COUNT(e.event_id) FILTER (
                WHERE e.occurred_at >= NOW() - INTERVAL '30 days'
            ) AS events_30d,
            COUNT(e.event_id) FILTER (
                WHERE e.event_name IN ('comment_added', 'doc_shared', 'teammate_invited')
                AND e.occurred_at >= NOW() - INTERVAL '30 days'
            ) AS collab_actions_30d,
            COUNT(e.event_id) FILTER (
                WHERE e.event_name IN ('doc_created', 'task_created', 'project_created')
                AND e.occurred_at >= NOW() - INTERVAL '30 days'
            ) AS creation_actions_30d
        FROM users u
        LEFT JOIN sessions s
            ON u.user_id = s.user_id
            AND s.started_at >= NOW() - INTERVAL '30 days'
        LEFT JOIN feature_usage fu ON u.user_id = fu.user_id
        LEFT JOIN events e ON u.user_id = e.user_id
        WHERE u.is_deleted = FALSE
        GROUP BY u.user_id, u.workspace_id
        """
        df = self.conn.execute(query).df()

        features = [
            "active_days_30d", "feature_breadth", "events_30d",
            "collab_actions_30d", "creation_actions_30d",
        ]

        X = df[features].fillna(0)
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)

        model = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        df["cluster"] = model.fit_predict(X_scaled)

        # Label clusters by engagement level
        cluster_means = df.groupby("cluster")[features].mean()
        engagement_scores = cluster_means.mean(axis=1).rank(ascending=False)
        cluster_labels = {
            int(k): label for k, label in zip(
                engagement_scores.index,
                ["Power Users", "Core Users", "Casual Users", "Light Users", "Dormant"][:n_clusters]
            )
        }
        df["cluster_label"] = df["cluster"].map(cluster_labels)

        logger.info(f"K-means clustering complete: {n_clusters} clusters")
        logger.info("\nCluster distribution:\n"
                    + df["cluster_label"].value_counts().to_string())

        return df, model

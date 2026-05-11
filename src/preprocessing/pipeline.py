"""
Notivo Analytics Platform — Data Preprocessing Pipeline

Transforms raw CSV data into clean, typed, analysis-ready DataFrames.
This runs after ingestion and before any analytics module.

Usage:
    from src.preprocessing.pipeline import PreprocessingPipeline
    pipeline = PreprocessingPipeline()
    clean_data = pipeline.run()
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict

import pandas as pd
import numpy as np
from loguru import logger


RAW_DIR = Path("data/raw")
STAGING_DIR = Path("data/staging")
STAGING_DIR.mkdir(parents=True, exist_ok=True)


class PreprocessingPipeline:
    """
    Cleans and standardizes raw data tables.
    Mirrors the logic in staging dbt models — this is the
    Python equivalent for use in notebooks and ML pipelines.
    """

    def run(self) -> Dict[str, pd.DataFrame]:
        """Run full preprocessing pipeline. Returns dict of clean DataFrames."""
        logger.info("Starting preprocessing pipeline...")
        results = {}
        results["users"]         = self._clean_users()
        results["workspaces"]    = self._clean_workspaces()
        results["subscriptions"] = self._clean_subscriptions()
        results["sessions"]      = self._clean_sessions()
        results["feature_usage"] = self._clean_feature_usage()

        for name, df in results.items():
            path = STAGING_DIR / f"{name}_clean.parquet"
            df.to_parquet(path, index=False)
            logger.success(f"  Saved {name}_clean.parquet — {len(df):,} rows")

        logger.info("Preprocessing complete.")
        return results

    def _clean_users(self) -> pd.DataFrame:
        df = pd.read_csv(RAW_DIR / "users.csv")
        df["created_at"] = pd.to_datetime(df["created_at"], utc=True)
        df["last_active_at"] = pd.to_datetime(df["last_active_at"], utc=True, errors="coerce")
        df["email"] = df["email"].str.lower().str.strip()
        df["user_role"] = df["user_role"].str.lower()
        df["signup_source"] = df["signup_source"].str.lower().fillna("unknown")
        df["country_code"] = df["country_code"].str.upper().fillna("XX")
        df = df.drop_duplicates(subset="user_id")
        df = df[df["user_id"].notna() & df["workspace_id"].notna()]
        # Filter internal/test accounts
        df = df[~df["email"].str.contains("@notivo.io|@test.com", na=False)]
        df["signup_month"] = df["created_at"].dt.to_period("M")
        logger.info(f"  Users cleaned: {len(df):,} rows")
        return df

    def _clean_workspaces(self) -> pd.DataFrame:
        df = pd.read_csv(RAW_DIR / "workspaces.csv")
        df["created_at"] = pd.to_datetime(df["created_at"], utc=True)
        df["trial_ends_at"] = pd.to_datetime(df["trial_ends_at"], utc=True, errors="coerce")
        df["workspace_name"] = df["workspace_name"].str.strip()
        df["company_size"] = df["company_size"].str.lower().fillna("unknown")
        df["industry"] = df["industry"].str.lower().fillna("unknown")
        df["country_code"] = df["country_code"].str.upper().fillna("XX")
        df = df.drop_duplicates(subset="workspace_id")
        df = df[df["is_deleted"] != True]
        logger.info(f"  Workspaces cleaned: {len(df):,} rows")
        return df

    def _clean_subscriptions(self) -> pd.DataFrame:
        df = pd.read_csv(RAW_DIR / "subscriptions.csv")
        df["started_at"] = pd.to_datetime(df["started_at"], utc=True)
        df["canceled_at"] = pd.to_datetime(df["canceled_at"], utc=True, errors="coerce")
        df["mrr"] = pd.to_numeric(df["mrr"], errors="coerce").clip(lower=0)
        df["seat_count"] = pd.to_numeric(df["seat_count"], errors="coerce").fillna(1).astype(int)
        df["status"] = df["status"].str.lower()
        df = df.drop_duplicates(subset="subscription_id")
        df = df[df["mrr"] <= 100_000]  # sanity check
        df["is_churned"] = df["canceled_at"].notna()
        df["tenure_months"] = np.where(
            df["canceled_at"].notna(),
            (df["canceled_at"] - df["started_at"]).dt.days / 30,
            (pd.Timestamp.now(tz="UTC") - df["started_at"]).dt.days / 30,
        ).round(1)
        logger.info(f"  Subscriptions cleaned: {len(df):,} rows")
        return df

    def _clean_sessions(self) -> pd.DataFrame:
        df = pd.read_csv(RAW_DIR / "sessions.csv")
        df["started_at"] = pd.to_datetime(df["started_at"], utc=True)
        df["ended_at"] = pd.to_datetime(df["ended_at"], utc=True, errors="coerce")
        df["duration_seconds"] = pd.to_numeric(df["duration_seconds"], errors="coerce").fillna(0)
        # Remove bot traffic (too short or too long sessions)
        df = df[(df["duration_seconds"] >= 5) & (df["duration_seconds"] <= 28_800)]
        # No future sessions
        df = df[df["started_at"] <= pd.Timestamp.now(tz="UTC")]
        df["session_date"] = df["started_at"].dt.date
        df["session_hour"] = df["started_at"].dt.hour
        df["day_of_week"] = df["started_at"].dt.dayofweek
        df["is_weekend"] = df["day_of_week"] >= 5
        logger.info(f"  Sessions cleaned: {len(df):,} rows")
        return df

    def _clean_feature_usage(self) -> pd.DataFrame:
        df = pd.read_csv(RAW_DIR / "feature_usage.csv")
        df["first_used_at"] = pd.to_datetime(df["first_used_at"], utc=True)
        df["last_used_at"] = pd.to_datetime(df["last_used_at"], utc=True)
        df["usage_count_30d"] = pd.to_numeric(df["usage_count_30d"], errors="coerce").fillna(0).astype(int)
        df["depth_score"] = pd.to_numeric(df["depth_score"], errors="coerce").clip(0, 100)
        df = df.drop_duplicates(subset=["user_id", "feature_name"])
        logger.info(f"  Feature usage cleaned: {len(df):,} rows")
        return df

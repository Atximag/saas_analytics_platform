"""
Notivo Analytics Platform — Synthetic Data Generator

Generates realistic SaaS data for all core tables.
Data distributions and behavioral patterns are calibrated to
reflect a real Series B B2B SaaS company.

Run:
    python src/ingestion/generate_data.py
"""

from __future__ import annotations

import os
import random
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from loguru import logger

# ─── Configuration ───────────────────────────────────────────
SEED = 42
random.seed(SEED)
np.random.seed(SEED)

OUTPUT_DIR = Path("data/raw")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Simulation window: 18 months of history
SIM_END   = datetime(2024, 12, 31)
SIM_START = SIM_END - timedelta(days=548)  # ~18 months

N_WORKSPACES = 5_000
N_USERS_PER_WS_MEAN = 4.2   # avg seats per workspace
CHURN_RATE_MONTHLY  = 0.031  # 3.1% gross logo churn
TRIAL_CONV_RATE     = 0.22   # 22% free→paid conversion

PLANS = {
    "free":       {"price": 0.00,  "max_seats": 3},
    "pro":        {"price": 12.00, "max_seats": 50},
    "business":   {"price": 25.00, "max_seats": 200},
    "enterprise": {"price": 80.00, "max_seats": None},
}

CHANNELS = [
    ("organic_search",  "organic",  420),
    ("paid_search",     "paid",     380),
    ("paid_social",     "paid",     550),
    ("referral",        "viral",    180),
    ("product_viral",   "viral",    90),
    ("direct",          "direct",   200),
    ("content",         "organic",  310),
    ("partner",         "organic",  450),
]

FEATURES = [
    "docs", "tasks", "kanban", "calendar",
    "integrations", "api", "automations", "search",
]

ONBOARDING_STEPS = [
    ("profile_setup",       1),
    ("invite_teammate",     2),
    ("create_doc",          3),
    ("connect_integration", 4),
    ("set_notifications",   5),
]

EVENTS = [
    ("page_viewed",          "navigation",    0.40),
    ("doc_created",          "creation",      0.12),
    ("task_created",         "creation",      0.10),
    ("comment_added",        "collaboration", 0.09),
    ("teammate_invited",     "collaboration", 0.03),
    ("integration_connected","settings",      0.02),
    ("search_performed",     "navigation",    0.08),
    ("doc_shared",           "collaboration", 0.04),
    ("project_created",      "creation",      0.03),
    ("template_used",        "creation",      0.05),
    ("notification_viewed",  "navigation",    0.04),
]


def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=seconds)


def generate_workspaces(n: int = N_WORKSPACES) -> pd.DataFrame:
    """Generate the workspaces (tenant) table."""
    logger.info(f"Generating {n} workspaces...")

    company_sizes = ["solo", "startup", "smb", "mid", "enterprise"]
    size_weights  = [0.15, 0.40, 0.30, 0.10, 0.05]

    industries = ["tech", "finance", "marketing", "design", "consulting",
                  "healthcare", "education", "ecommerce", "media", "other"]

    countries = ["US", "GB", "DE", "CA", "FR", "AU", "NL", "SE", "IN", "BR"]
    country_weights = [0.40, 0.12, 0.08, 0.07, 0.06, 0.05, 0.04, 0.04, 0.08, 0.06]

    channel_names = [c[0] for c in CHANNELS]
    channel_weights = [1/len(CHANNELS)] * len(CHANNELS)

    rows = []
    for _ in range(n):
        ws_id      = str(uuid.uuid4())
        created_at = random_date(SIM_START, SIM_END - timedelta(days=30))
        plan       = np.random.choice(
            ["free", "pro", "business", "enterprise"],
            p=[0.55, 0.28, 0.13, 0.04]
        )
        trial_ends = (
            created_at + timedelta(days=14)
            if plan == "free" else None
        )
        rows.append({
            "workspace_id":   ws_id,
            "workspace_name": f"Workspace_{ws_id[:8]}",
            "company_size":   np.random.choice(company_sizes, p=size_weights),
            "industry":       random.choice(industries),
            "country_code":   np.random.choice(countries, p=country_weights),
            "created_at":     created_at,
            "trial_ends_at":  trial_ends,
            "plan_id":        plan,
            "channel_id":     channel_names.index(
                np.random.choice(channel_names, p=channel_weights)
            ) + 1,
            "is_deleted":     False,
            "deleted_at":     None,
        })

    df = pd.DataFrame(rows)
    logger.info(f"  Plan distribution:\n{df['plan_id'].value_counts().to_string()}")
    return df


def generate_users(workspaces: pd.DataFrame) -> pd.DataFrame:
    """Generate users table with realistic seat counts per workspace."""
    logger.info("Generating users...")

    roles = ["owner", "admin", "member", "viewer"]
    role_weights = [0.10, 0.15, 0.60, 0.15]
    sources = ["direct", "invite", "sso", "oauth_google", "oauth_github"]
    source_weights = [0.25, 0.35, 0.10, 0.20, 0.10]

    rows = []
    for _, ws in workspaces.iterrows():
        # Seat count varies by plan
        if ws["plan_id"] == "free":
            n_seats = random.randint(1, 3)
        elif ws["plan_id"] == "pro":
            n_seats = np.random.negative_binomial(3, 0.3) + 3
        elif ws["plan_id"] == "business":
            n_seats = np.random.negative_binomial(5, 0.2) + 10
        else:
            n_seats = np.random.negative_binomial(10, 0.15) + 50

        n_seats = max(1, min(n_seats, 500))

        for i in range(n_seats):
            user_id = str(uuid.uuid4())
            signup_offset = timedelta(days=random.randint(0, 30))
            created_at = ws["created_at"] + signup_offset

            last_active_days_ago = np.random.exponential(7)
            last_active_at = SIM_END - timedelta(days=last_active_days_ago)

            rows.append({
                "user_id":      user_id,
                "workspace_id": ws["workspace_id"],
                "email":        f"user_{user_id[:8]}@example.com",
                "user_role":    "owner" if i == 0
                                else np.random.choice(roles[1:], p=[0.17, 0.67, 0.16]),
                "signup_source": np.random.choice(sources, p=source_weights),
                "country_code": ws["country_code"],
                "created_at":   created_at,
                "last_active_at": last_active_at,
                "is_deleted":   False,
                "deleted_at":   None,
            })

    df = pd.DataFrame(rows)
    logger.info(f"  Generated {len(df):,} users across {len(workspaces):,} workspaces")
    return df


def generate_subscriptions(workspaces: pd.DataFrame) -> pd.DataFrame:
    """Generate subscription records including upgrades, downgrades, cancellations."""
    logger.info("Generating subscriptions...")

    rows = []
    for _, ws in workspaces.iterrows():
        if ws["plan_id"] == "free":
            continue  # Free workspaces don't have a paid subscription record

        plan      = ws["plan_id"]
        seats     = max(1, int(np.random.negative_binomial(3, 0.3) + 2))
        price_psm = PLANS[plan]["price"]
        mrr       = round(seats * price_psm * (1 - random.uniform(0, 0.15)), 2)

        is_annual = random.random() < 0.30
        is_churn  = random.random() < (CHURN_RATE_MONTHLY * 6)  # ~18% churn over life

        sub_id = str(uuid.uuid4())
        started_at = ws["created_at"] + timedelta(days=random.randint(0, 45))
        canceled_at = None
        status = "active"

        if is_churn:
            churn_after_months = max(1, int(np.random.exponential(8)))
            canceled_at = started_at + timedelta(days=churn_after_months * 30)
            if canceled_at > SIM_END:
                canceled_at = None
            else:
                status = "canceled"

        rows.append({
            "subscription_id":      sub_id,
            "workspace_id":         ws["workspace_id"],
            "plan_id":              plan,
            "status":               status,
            "seat_count":           seats,
            "mrr":                  mrr,
            "started_at":           started_at,
            "trial_started_at":     started_at - timedelta(days=14),
            "trial_ended_at":       started_at,
            "canceled_at":          canceled_at,
            "cancel_reason":        random.choice([
                "price", "missing_feature", "competitor",
                "no_need", "budget_cut", "technical_issues"
            ]) if canceled_at else None,
            "current_period_start": SIM_END - timedelta(days=30),
            "current_period_end":   SIM_END,
            "is_annual":            is_annual,
            "discount_pct":         round(random.uniform(0, 20), 1) if is_annual else 0,
        })

    df = pd.DataFrame(rows)
    logger.info(f"  Generated {len(df):,} subscriptions | "
                f"active: {(df.status == 'active').sum():,} | "
                f"canceled: {(df.status == 'canceled').sum():,}")
    return df


def generate_sessions(users: pd.DataFrame, n_sessions: int = 800_000) -> pd.DataFrame:
    """Generate session data with realistic engagement patterns."""
    logger.info(f"Generating ~{n_sessions:,} sessions...")

    # Sample active users (power-law distribution: some users are much more active)
    user_ids    = users["user_id"].tolist()
    ws_map      = dict(zip(users["user_id"], users["workspace_id"]))
    created_map = dict(zip(users["user_id"], users["created_at"]))

    # Activity weights: power-law (some users are much more engaged)
    weights = np.random.pareto(1.5, len(user_ids)) + 1
    weights = weights / weights.sum()

    rows = []
    batch_size = 50_000

    for batch_start in range(0, n_sessions, batch_size):
        batch = min(batch_size, n_sessions - batch_start)
        sampled_users = np.random.choice(user_ids, size=batch, replace=True, p=weights)

        for uid in sampled_users:
            user_created = created_map[uid]
            if isinstance(user_created, str):
                user_created = datetime.fromisoformat(user_created)

            session_start = random_date(
                max(user_created, SIM_START),
                SIM_END
            )
            duration = max(30, int(np.random.lognormal(6, 1.5)))
            session_end = session_start + timedelta(seconds=duration)

            rows.append({
                "session_id":      str(uuid.uuid4()),
                "user_id":         uid,
                "workspace_id":    ws_map[uid],
                "started_at":      session_start,
                "ended_at":        session_end,
                "duration_seconds": duration,
                "device_type":     np.random.choice(
                    ["desktop", "mobile", "tablet"], p=[0.72, 0.22, 0.06]
                ),
                "browser":         np.random.choice(
                    ["chrome", "safari", "firefox", "edge"], p=[0.60, 0.22, 0.10, 0.08]
                ),
                "page_view_count": max(1, int(np.random.lognormal(2, 1))),
                "is_bounce":       random.random() < 0.18,
            })

    df = pd.DataFrame(rows)
    logger.info(f"  Generated {len(df):,} sessions")
    return df


def generate_feature_usage(users: pd.DataFrame) -> pd.DataFrame:
    """Generate feature usage per user with realistic adoption patterns."""
    logger.info("Generating feature usage...")

    # Feature adoption rates (not all users use all features)
    feature_adoption = {
        "docs":         0.85,
        "tasks":        0.72,
        "kanban":       0.55,
        "calendar":     0.40,
        "integrations": 0.28,
        "api":          0.12,
        "automations":  0.18,
        "search":       0.78,
    }

    rows = []
    for _, user in users.iterrows():
        user_created = user["created_at"]
        if isinstance(user_created, str):
            user_created = datetime.fromisoformat(user_created)

        for feature, adoption_rate in feature_adoption.items():
            if random.random() > adoption_rate:
                continue

            first_used = user_created + timedelta(days=random.randint(0, 30))
            if first_used > SIM_END:
                continue

            usage_total = max(1, int(np.random.lognormal(3, 1.5)))
            usage_30d   = min(usage_total, max(0, int(usage_total * random.uniform(0, 0.3))))
            usage_7d    = min(usage_30d, max(0, int(usage_30d * random.uniform(0, 0.5))))

            rows.append({
                "usage_id":         str(uuid.uuid4()),
                "user_id":          user["user_id"],
                "workspace_id":     user["workspace_id"],
                "feature_name":     feature,
                "first_used_at":    first_used,
                "last_used_at":     SIM_END - timedelta(days=random.randint(0, 30)),
                "usage_count_7d":   usage_7d,
                "usage_count_30d":  usage_30d,
                "usage_count_total": usage_total,
                "depth_score":      round(random.uniform(10, 95), 1),
            })

    df = pd.DataFrame(rows)
    logger.info(f"  Generated {len(df):,} feature usage records")
    return df


def save_all(dfs: dict[str, pd.DataFrame]) -> None:
    """Save all DataFrames to CSV in data/raw/."""
    for name, df in dfs.items():
        path = OUTPUT_DIR / f"{name}.csv"
        df.to_csv(path, index=False)
        logger.success(f"  Saved {name}.csv — {len(df):,} rows")


def main() -> None:
    logger.info("=" * 60)
    logger.info("Notivo Analytics Platform — Data Generation")
    logger.info("=" * 60)

    workspaces    = generate_workspaces()
    users         = generate_users(workspaces)
    subscriptions = generate_subscriptions(workspaces)
    sessions      = generate_sessions(users)
    feature_usage = generate_feature_usage(users)

    save_all({
        "workspaces":    workspaces,
        "users":         users,
        "subscriptions": subscriptions,
        "sessions":      sessions,
        "feature_usage": feature_usage,
    })

    logger.success("Data generation complete.")
    logger.info(f"Output directory: {OUTPUT_DIR.resolve()}")


if __name__ == "__main__":
    main()

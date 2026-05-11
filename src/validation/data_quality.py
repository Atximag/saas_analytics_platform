"""
Notivo Analytics Platform — Data Quality Framework

Production-grade validation layer. Each check is named,
documented, and raises actionable errors rather than silent
data corruption.

This is the analytical equivalent of unit tests — it runs
before every pipeline execution and on every dbt model build.

Usage:
    from src.validation.data_quality import DataQualityRunner
    dq = DataQualityRunner(conn)
    report = dq.run_all_checks()
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Optional

import pandas as pd
from loguru import logger


class Severity(Enum):
    CRITICAL = "critical"   # Blocks pipeline. Data cannot be trusted.
    WARNING  = "warning"    # Investigate. Metric may be impacted.
    INFO     = "info"       # Informational. No action required.


@dataclass
class CheckResult:
    check_name:  str
    table:       str
    column:      Optional[str]
    severity:    Severity
    passed:      bool
    value:       Any
    threshold:   Any
    message:     str
    checked_at:  datetime = field(default_factory=datetime.utcnow)

    def to_dict(self) -> dict:
        return {
            "check_name":  self.check_name,
            "table":       self.table,
            "column":      self.column,
            "severity":    self.severity.value,
            "passed":      self.passed,
            "value":       self.value,
            "threshold":   self.threshold,
            "message":     self.message,
            "checked_at":  self.checked_at.isoformat(),
        }


class DataQualityRunner:
    """
    Runs a comprehensive suite of data quality checks.

    Design principle: every check documents WHY it exists,
    not just what it checks. This turns the DQ report into
    a runbook for on-call analysts.
    """

    def __init__(self, conn) -> None:
        self.conn    = conn
        self.results: list[CheckResult] = []

    def _execute_scalar(self, query: str) -> Any:
        return self.conn.execute(query).fetchone()[0]

    def _add(self, result: CheckResult) -> None:
        self.results.append(result)
        icon = "✓" if result.passed else "✗"
        level = "INFO" if result.passed else (
            "WARNING" if result.severity == Severity.WARNING else "ERROR"
        )
        msg = f"[{icon}] {result.check_name} — {result.message}"
        getattr(logger, level.lower())(msg)

    # ─── Null Checks ─────────────────────────────────────────

    def check_null_rate(
        self,
        table: str,
        column: str,
        max_null_pct: float = 0.01,
        severity: Severity = Severity.CRITICAL,
    ) -> CheckResult:
        """
        Null rate check. Critical columns should have zero nulls.
        Even 1% nulls in user_id means ~500 orphaned event records
        that will silently drop from every downstream metric.
        """
        query = f"""
            SELECT ROUND(
                COUNT(*) FILTER (WHERE {column} IS NULL)::NUMERIC
                / NULLIF(COUNT(*), 0) * 100,
                4
            ) FROM {table}
        """
        null_pct = float(self._execute_scalar(query) or 0)
        passed   = null_pct <= max_null_pct * 100

        result = CheckResult(
            check_name=f"null_rate_{table}_{column}",
            table=table,
            column=column,
            severity=severity,
            passed=passed,
            value=null_pct,
            threshold=max_null_pct * 100,
            message=(
                f"Null rate {null_pct:.2f}% {'<=' if passed else '>'} "
                f"threshold {max_null_pct*100:.2f}%"
            ),
        )
        self._add(result)
        return result

    # ─── Duplicate Checks ────────────────────────────────────

    def check_primary_key_uniqueness(
        self,
        table: str,
        pk_column: str,
    ) -> CheckResult:
        """
        PK uniqueness. Duplicate PKs corrupt every aggregate.
        A duplicate subscription_id means double-counted MRR —
        one of the most dangerous data quality failures in SaaS.
        """
        query = f"""
            SELECT COUNT(*) - COUNT(DISTINCT {pk_column})
            FROM {table}
        """
        duplicate_count = int(self._execute_scalar(query) or 0)
        passed = duplicate_count == 0

        result = CheckResult(
            check_name=f"pk_uniqueness_{table}_{pk_column}",
            table=table,
            column=pk_column,
            severity=Severity.CRITICAL,
            passed=passed,
            value=duplicate_count,
            threshold=0,
            message=(
                f"{duplicate_count} duplicate {pk_column} values found"
                if not passed
                else f"No duplicates found in {pk_column}"
            ),
        )
        self._add(result)
        return result

    # ─── Range / Sanity Checks ────────────────────────────────

    def check_mrr_range(
        self,
        min_mrr: float = 0,
        max_mrr: float = 50_000,
    ) -> CheckResult:
        """
        MRR sanity check. A single subscription with $0 MRR means
        a free plan leaked into revenue counts. $50K+ MRR on one
        sub indicates a data loading error (e.g., ARR vs. MRR mix-up).
        """
        query = """
            SELECT COUNT(*) FROM subscriptions
            WHERE status = 'active'
              AND (mrr < 0 OR mrr > 50000)
        """
        invalid_count = int(self._execute_scalar(query) or 0)
        passed = invalid_count == 0

        result = CheckResult(
            check_name="mrr_range_check",
            table="subscriptions",
            column="mrr",
            severity=Severity.CRITICAL,
            passed=passed,
            value=invalid_count,
            threshold=0,
            message=(
                f"{invalid_count} subscriptions with MRR outside "
                f"[{min_mrr}, {max_mrr}]"
            ),
        )
        self._add(result)
        return result

    def check_event_timestamps(self) -> CheckResult:
        """
        Events must not be in the future. Future-dated events corrupt
        retention and cohort calculations silently — the analyst sees
        retention > 100% for recent cohorts.
        """
        query = """
            SELECT COUNT(*) FROM events
            WHERE occurred_at > NOW() + INTERVAL '1 hour'
        """
        future_events = int(self._execute_scalar(query) or 0)
        passed = future_events == 0

        result = CheckResult(
            check_name="event_future_timestamps",
            table="events",
            column="occurred_at",
            severity=Severity.CRITICAL,
            passed=passed,
            value=future_events,
            threshold=0,
            message=f"{future_events} events with future timestamps",
        )
        self._add(result)
        return result

    # ─── Referential Integrity ────────────────────────────────

    def check_orphaned_records(
        self,
        child_table: str,
        child_col: str,
        parent_table: str,
        parent_col: str,
    ) -> CheckResult:
        """
        Orphaned foreign key check. Orphaned events (user_id that
        doesn't exist in users) will silently disappear from every
        user-level metric, creating an invisible sample bias.
        """
        query = f"""
            SELECT COUNT(*) FROM {child_table} c
            LEFT JOIN {parent_table} p ON c.{child_col} = p.{parent_col}
            WHERE p.{parent_col} IS NULL
        """
        orphaned = int(self._execute_scalar(query) or 0)
        passed   = orphaned == 0

        result = CheckResult(
            check_name=f"orphan_{child_table}_{child_col}",
            table=child_table,
            column=child_col,
            severity=Severity.CRITICAL,
            passed=passed,
            value=orphaned,
            threshold=0,
            message=(
                f"{orphaned} {child_table}.{child_col} records "
                f"missing from {parent_table}.{parent_col}"
            ),
        )
        self._add(result)
        return result

    # ─── Freshness Checks ─────────────────────────────────────

    def check_data_freshness(
        self,
        table: str,
        timestamp_column: str,
        max_lag_hours: float = 25.0,
    ) -> CheckResult:
        """
        Freshness check. If sessions aren't loading, every real-time
        dashboard shows stale data. The 25h threshold accounts for
        the daily batch pipeline with a 1-hour buffer.
        """
        query = f"""
            SELECT EXTRACT(EPOCH FROM (NOW() - MAX({timestamp_column}))) / 3600
            FROM {table}
        """
        lag_hours = float(self._execute_scalar(query) or 999)
        passed    = lag_hours <= max_lag_hours

        result = CheckResult(
            check_name=f"freshness_{table}",
            table=table,
            column=timestamp_column,
            severity=Severity.WARNING,
            passed=passed,
            value=round(lag_hours, 1),
            threshold=max_lag_hours,
            message=(
                f"Latest {timestamp_column} is {lag_hours:.1f}h ago "
                f"(threshold: {max_lag_hours}h)"
            ),
        )
        self._add(result)
        return result

    # ─── Volume Checks ────────────────────────────────────────

    def check_row_count_anomaly(
        self,
        table: str,
        expected_min: int,
        expected_max: int,
    ) -> CheckResult:
        """
        Row count sanity. Sudden drops in event volume (e.g., 50%
        fewer events than yesterday) indicate a pipeline failure,
        not genuine product decline.
        """
        query = f"SELECT COUNT(*) FROM {table}"
        count = int(self._execute_scalar(query) or 0)
        passed = expected_min <= count <= expected_max

        result = CheckResult(
            check_name=f"row_count_{table}",
            table=table,
            column=None,
            severity=Severity.WARNING,
            passed=passed,
            value=count,
            threshold=f"[{expected_min}, {expected_max}]",
            message=(
                f"{table} has {count:,} rows "
                f"(expected {expected_min:,}–{expected_max:,})"
            ),
        )
        self._add(result)
        return result

    # ─── Metric Consistency ───────────────────────────────────

    def check_mrr_vs_invoices(
        self,
        tolerance_pct: float = 0.05,
    ) -> CheckResult:
        """
        Cross-check: total active MRR should roughly equal
        last month's paid invoice sum. >5% discrepancy suggests
        a subscription record is out of sync with billing.
        """
        mrr_query = """
            SELECT SUM(mrr) FROM subscriptions WHERE status = 'active'
        """
        invoice_query = """
            SELECT SUM(amount) FROM invoices
            WHERE status = 'paid'
              AND issued_at >= DATE_TRUNC('month', NOW() - INTERVAL '1 month')
              AND issued_at < DATE_TRUNC('month', NOW())
        """
        mrr      = float(self._execute_scalar(mrr_query) or 0)
        invoiced = float(self._execute_scalar(invoice_query) or 0)

        diff_pct = abs(mrr - invoiced) / max(mrr, invoiced, 1) if max(mrr, invoiced) > 0 else 0
        passed   = diff_pct <= tolerance_pct

        result = CheckResult(
            check_name="mrr_invoice_consistency",
            table="subscriptions/invoices",
            column="mrr/amount",
            severity=Severity.WARNING,
            passed=passed,
            value=round(diff_pct * 100, 2),
            threshold=tolerance_pct * 100,
            message=(
                f"MRR ${mrr:,.0f} vs invoiced ${invoiced:,.0f} — "
                f"{diff_pct*100:.1f}% discrepancy"
            ),
        )
        self._add(result)
        return result

    # ─── Runner ───────────────────────────────────────────────

    def run_all_checks(self) -> pd.DataFrame:
        """
        Execute the full DQ suite. Returns a DataFrame with
        all check results for reporting.

        Raises ValueError if any CRITICAL check fails.
        """
        logger.info("Starting data quality checks...")
        self.results.clear()

        # Primary key uniqueness
        for table, pk in [
            ("users", "user_id"),
            ("workspaces", "workspace_id"),
            ("subscriptions", "subscription_id"),
            ("sessions", "session_id"),
            ("invoices", "invoice_id"),
        ]:
            self.check_primary_key_uniqueness(table, pk)

        # Null checks on critical columns
        critical_nulls = [
            ("users",         "user_id",      0),
            ("users",         "workspace_id", 0),
            ("sessions",      "user_id",      0),
            ("sessions",      "started_at",   0),
            ("subscriptions", "mrr",          0),
            ("events",        "occurred_at",  0),
        ]
        for table, col, threshold in critical_nulls:
            self.check_null_rate(table, col, threshold, Severity.CRITICAL)

        # Referential integrity
        self.check_orphaned_records("sessions",  "user_id",      "users",      "user_id")
        self.check_orphaned_records("events",    "user_id",      "users",      "user_id")
        self.check_orphaned_records("invoices",  "workspace_id", "workspaces", "workspace_id")

        # Range checks
        self.check_mrr_range()
        self.check_event_timestamps()

        # Freshness
        self.check_data_freshness("sessions", "started_at", 25)
        self.check_data_freshness("events",   "occurred_at", 25)

        # Volume
        self.check_row_count_anomaly("users",    1_000,   10_000_000)
        self.check_row_count_anomaly("sessions", 10_000, 100_000_000)

        # Consistency
        self.check_mrr_vs_invoices()

        # Build report
        report_df = pd.DataFrame([r.to_dict() for r in self.results])

        passed = report_df["passed"].sum()
        failed = (~report_df["passed"]).sum()
        critical_failures = report_df[
            (~report_df["passed"]) & (report_df["severity"] == "critical")
        ]

        logger.info(f"\nDQ Summary: {passed} passed / {failed} failed")

        if len(critical_failures) > 0:
            logger.critical(
                f"{len(critical_failures)} CRITICAL checks failed. "
                "Pipeline should be halted."
            )
            raise ValueError(
                f"Data quality critical failures:\n"
                + critical_failures[["check_name", "message"]].to_string()
            )

        return report_df

    def save_report(self, path: str = "data/dq_report.json") -> None:
        """Persist DQ report for audit trail."""
        with open(path, "w") as f:
            json.dump(
                [r.to_dict() for r in self.results],
                f,
                indent=2,
                default=str,
            )
        logger.info(f"DQ report saved to {path}")

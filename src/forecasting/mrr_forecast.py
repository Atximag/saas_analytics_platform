"""
Notivo Analytics Platform — MRR Forecasting

Time-series revenue forecasting using Prophet.
Includes scenario modeling (optimistic / base / pessimistic)
and churn-adjusted projections.

Used in: CFO dashboard, board materials, annual planning.

Usage:
    from src.forecasting.mrr_forecast import MRRForecaster
    forecaster = MRRForecaster(conn)
    forecast_df = forecaster.forecast_mrr(months_ahead=12)
"""

from __future__ import annotations

from typing import Dict, Optional, Tuple

import pandas as pd
import numpy as np
from loguru import logger

try:
    from prophet import Prophet
    PROPHET_AVAILABLE = True
except ImportError:
    PROPHET_AVAILABLE = False
    logger.warning("Prophet not installed. Using linear trend fallback.")


class MRRForecaster:
    """
    MRR forecaster with scenario modeling.

    Three scenarios:
    - Base: current trends continue
    - Optimistic: churn -20%, growth rate +15%
    - Pessimistic: churn +20%, growth rate -15%
    """

    SCENARIOS: Dict[str, Dict] = {
        "optimistic":  {"churn_adj": 0.80,  "growth_adj": 1.15},
        "base":        {"churn_adj": 1.00,  "growth_adj": 1.00},
        "pessimistic": {"churn_adj": 1.20,  "growth_adj": 0.85},
    }

    def __init__(self, conn) -> None:
        self.conn = conn

    def _get_historical_mrr(self) -> pd.DataFrame:
        """Pull monthly MRR time series from the database."""
        query = """
        SELECT
            DATE_TRUNC('month', current_period_start)::DATE AS ds,
            SUM(mrr) AS y
        FROM subscriptions
        WHERE status IN ('active', 'past_due')
        GROUP BY 1
        ORDER BY 1
        """
        df = self.conn.execute(query).df()
        df["ds"] = pd.to_datetime(df["ds"])
        return df

    def forecast_mrr(
        self,
        months_ahead: int = 12,
        scenarios: Optional[list] = None,
    ) -> pd.DataFrame:
        """
        Generate MRR forecasts for all scenarios.

        Args:
            months_ahead: Forecast horizon in months
            scenarios: List of scenarios to run (default: all)

        Returns:
            DataFrame with historical + forecasted MRR for each scenario.
        """
        if scenarios is None:
            scenarios = list(self.SCENARIOS.keys())

        historical = self._get_historical_mrr()
        logger.info(f"Forecasting MRR: {len(historical)} months of history → "
                    f"{months_ahead} months ahead")

        if PROPHET_AVAILABLE and len(historical) >= 12:
            results = self._prophet_forecast(historical, months_ahead, scenarios)
        else:
            logger.info("Using linear trend fallback (Prophet unavailable or <12 months data)")
            results = self._linear_forecast(historical, months_ahead, scenarios)

        return results

    def _prophet_forecast(
        self,
        historical: pd.DataFrame,
        months_ahead: int,
        scenarios: list,
    ) -> pd.DataFrame:
        """Prophet-based forecast with scenario multipliers."""
        all_forecasts = [historical.rename(columns={"y": "actual_mrr"})]

        for scenario in scenarios:
            adj = self.SCENARIOS[scenario]

            model = Prophet(
                yearly_seasonality=True,
                weekly_seasonality=False,
                daily_seasonality=False,
                changepoint_prior_scale=0.15,
                seasonality_mode="multiplicative",
            )
            model.fit(historical)

            future = model.make_future_dataframe(periods=months_ahead, freq="MS")
            forecast = model.predict(future)

            # Apply scenario adjustments to the forward-looking period
            cutoff = historical["ds"].max()
            forecast_only = forecast[forecast["ds"] > cutoff].copy()
            forecast_only["yhat"] *= adj["growth_adj"]

            scenario_df = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].copy()
            scenario_df.columns = [
                "ds",
                f"mrr_{scenario}",
                f"mrr_{scenario}_lower",
                f"mrr_{scenario}_upper",
            ]
            all_forecasts.append(scenario_df.set_index("ds"))

        combined = historical.set_index("ds")
        for df in all_forecasts[1:]:
            combined = combined.join(df, how="outer")

        return combined.reset_index().rename(columns={"ds": "month"})

    def _linear_forecast(
        self,
        historical: pd.DataFrame,
        months_ahead: int,
        scenarios: list,
    ) -> pd.DataFrame:
        """Simple linear trend fallback when Prophet is unavailable."""
        # Fit linear trend
        x = np.arange(len(historical))
        y = historical["y"].values
        coeffs = np.polyfit(x, y, 1)

        last_date = historical["ds"].max()
        future_dates = pd.date_range(
            start=last_date + pd.DateOffset(months=1),
            periods=months_ahead,
            freq="MS",
        )

        trend = coeffs[0] * (np.arange(len(historical), len(historical) + months_ahead)) + coeffs[1]

        result = historical.rename(columns={"y": "actual_mrr", "ds": "month"})

        for scenario in scenarios:
            adj = self.SCENARIOS[scenario]
            forecast_values = trend * adj["growth_adj"]

            forecast_df = pd.DataFrame({
                "month": future_dates,
                f"mrr_{scenario}": np.maximum(forecast_values, 0),
            })
            result = pd.concat([result, forecast_df], ignore_index=True)

        return result.sort_values("month")

    def annual_plan_targets(
        self,
        current_mrr: float,
        target_growth_pct: float = 0.80,  # 80% YoY = common Series B target
    ) -> Dict:
        """
        Compute monthly MRR targets to hit annual growth goal.

        Returns a dictionary with monthly milestones and the
        implied net new MRR required each month.
        """
        arr_current = current_mrr * 12
        arr_target  = arr_current * (1 + target_growth_pct)
        mrr_target  = arr_target / 12

        monthly_targets = []
        for month in range(1, 13):
            progress = month / 12
            mrr_milestone = current_mrr + (mrr_target - current_mrr) * progress
            monthly_targets.append({
                "month_number":   month,
                "mrr_target":     round(mrr_milestone, 0),
                "net_new_needed": round((mrr_milestone - current_mrr) / month, 0),
            })

        return {
            "current_mrr":   current_mrr,
            "current_arr":   arr_current,
            "target_arr":    arr_target,
            "target_mrr":    mrr_target,
            "growth_pct":    target_growth_pct * 100,
            "monthly_targets": monthly_targets,
        }

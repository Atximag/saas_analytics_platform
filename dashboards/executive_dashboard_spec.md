# Executive Dashboard — Design Specification

**Audience:** CEO, CFO, Board Members
**Update cadence:** Daily (automated refresh)
**Primary purpose:** At-a-glance business health. Exception-based — should only require action when something is off.

---

## Dashboard Philosophy

The executive dashboard should answer one question in under 30 seconds: **"Is the business healthy?"**

Every element is either:
1. A KPI card showing current state + trend
2. A trend chart showing trajectory
3. An alert that something needs attention

There are no raw data tables. There is no methodology. There are no footnotes. Those belong in the analyst's notebook.

---

## Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Notivo Business Health  │  Last updated: 2024-10-01  │  MTD ▼  │
├──────────┬──────────┬──────────┬──────────┬──────────┬──────────┤
│   ARR    │   MRR    │   NRR    │   MAU    │  Churn   │  Stick.  │
│ $18.2M   │ $1.52M   │  108%    │ 124K     │  3.1%    │  31%     │
│ +8% YoY  │ +5.2% MoM│ ↓ -6pp  │ +8% MoM  │ ↑ +0.3pp │ ↓ -1pp   │
├──────────┴──────────┴──────────┴──────────┴──────────┴──────────┤
│                                                                  │
│  [MRR Waterfall — Last 6 months]          [ARR Trend — 13mo]    │
│                                                                  │
│  New ████ Expansion ██ Contraction ▌                             │
│  Churn ▌  Net ████████████                                       │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Cohort Retention Heatmap]       [MRR by Plan Mix]             │
│                                                                  │
│  Cohort  M0   M1   M3   M6  M12                                  │
│  Jan-24  100  68   55   44   —    Enterprise ██████ 42%          │
│  Feb-24  100  71   57   43   —    Business   ████   31%          │
│  Mar-24  100  69   52   —    —    Pro         ██    19%          │
│  Apr-24  100  66   —    —    —    Free         ▌    8%            │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  ⚠ ALERTS                                                       │
│  • NRR declined 6pp over 2 quarters — investigate expansion      │
│  • 3 high-value accounts flagged at-risk by churn model ($42K)   │
│  • Paid social LTV:CAC at 1.7x — below 3x threshold             │
└──────────────────────────────────────────────────────────────────┘
```

---

## KPI Cards Specification

### Card 1: ARR
- **Value:** Current ARR (MRR × 12)
- **Sub-metric:** YoY growth %
- **Trend indicator:** Arrow + color (green >10% YoY, yellow 5-10%, red <5%)
- **Sparkline:** 13-month ARR trend

### Card 2: MRR
- **Value:** Current MRR
- **Sub-metric:** MoM growth %, Net New MRR this month
- **Trend indicator:** Arrow + color (green >5% MoM, yellow 2-5%, red <2%)
- **Sparkline:** 13-month MRR trend
- **Drill-down:** Click opens MRR waterfall detail

### Card 3: Net Revenue Retention
- **Value:** NRR % (most recent complete month)
- **Sub-metric:** Change vs. prior quarter
- **Trend indicator:** Red if <110%, yellow 105-110%, green >110%
- **Sparkline:** 8-quarter NRR trend
- **Alert threshold:** Auto-alert to analytics channel if drops >2pp in one month

### Card 4: MAU
- **Value:** Monthly Active Users (prior calendar month)
- **Sub-metric:** MoM growth %
- **Exclusions:** Internal users, bots (defined in metric dictionary)

### Card 5: Gross Logo Churn
- **Value:** Logo churn rate % (monthly)
- **Sub-metric:** Change vs. prior month
- **Trend indicator:** Green <2.5%, yellow 2.5-3.5%, red >3.5%

### Card 6: Stickiness
- **Value:** DAU/MAU ratio
- **Sub-metric:** Change vs. prior month
- **Threshold note:** Tooltip explains: "0.30 = users visit ~9 days/month"

---

## MRR Waterfall Chart

**Chart type:** Waterfall (Plotly / Power BI waterfall visual)
**Frequency:** Monthly bars, trailing 6 months
**Colors:**
- New MRR: `#2ECC71` (green)
- Expansion: `#27AE60` (dark green)
- Contraction: `#E67E22` (orange)
- Churned: `#E74C3C` (red)
- Net: `#3498DB` (blue)

**Annotations:**
- Show absolute $ amounts on each bar
- Show % of total MRR for each component

**Stakeholder note:** "The waterfall is the most important executive chart. It forces the conversation from 'revenue grew' to 'how did it grow' — a meaningfully different question."

---

## Cohort Retention Heatmap

**Chart type:** Heatmap (Plotly `go.Heatmap`)
**X-axis:** Months since signup (M0 through M12)
**Y-axis:** Cohort month (Jan-24 through most recent complete month)
**Color scale:** Red (0%) → Yellow (50%) → Green (100%)
**Value in cell:** Retention rate %
**M0 always = 100%** (baseline)

**Drill-down:** Click on any cell → opens cohort detail view showing:
- Plan mix of the cohort
- Acquisition channel mix
- Top 3 features used by retained vs. churned users

---

## Alert Logic

Alerts are auto-generated and surfaced in the dashboard header. Triggered when:

| Condition | Severity | Alert text |
|---|---|---|
| MRR growth < 3% MoM | High | "MRR growth slowing: X% vs 5% target" |
| NRR drops >2pp in one month | Critical | "NRR decline: X% → Y%" |
| Logo churn > 3.5% | High | "Churn above threshold: X%" |
| Stickiness < 0.25 | High | "DAU/MAU below floor: X" |
| 3+ high-MRR accounts at risk | High | "N accounts at risk: $X MRR" |
| Data freshness > 30h | Critical | "Dashboard data may be stale" |

---

## Stakeholder Usage Notes

**CEO:** Reviews daily, 2 minutes. Looking for: "Is anything broken today?" Uses the alerts section first. Drills into MRR waterfall if net MRR is off.

**CFO:** Reviews weekly for board prep. Focuses on ARR, NRR, CAC payback. Downloads MRR waterfall data for the board deck.

**Board observers:** Access monthly summary email (auto-generated from this dashboard). Never logs into the dashboard directly.

---

## Power BI Implementation Notes

- Data source: DuckDB / PostgreSQL via DirectQuery
- Refresh: 6am daily (before standup)
- Row-level security: Board observers see only summary view, not account-level data
- Mobile layout: KPI cards only (6 cards, scrollable)
- Export: "Download board pack" button generates pre-formatted PDF with all charts

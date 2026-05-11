# Revenue & Finance Dashboard — Design Specification

**Audience:** CFO, Finance Team, RevOps
**Update cadence:** Daily (MRR), real-time (invoices)
**Primary purpose:** Revenue health, billing operations, unit economics

---

## Page 1: Revenue Overview

**KPI Cards (top row):**
- Current MRR | vs. prior month | vs. plan
- ARR | YoY growth %
- Net Revenue Retention | trend arrow + threshold indicator
- Gross Revenue Retention | separate from NRR
- ARPU (per workspace) | MoM change
- Active Paying Workspaces | net change

**Charts:**
- MRR Waterfall (12 months)
- ARR Trend + forecast cone (base / optimistic / pessimistic)
- MRR Composition: plan mix over time (stacked area)

---

## Page 2: Unit Economics

**Charts:**
- LTV:CAC by channel (horizontal bar, threshold line at 3x)
- CAC Payback Period by channel
- LTV Distribution (histogram) — helps identify long-tail high-value customers
- ARPU by Plan over Time — are we pricing optimally?

**Analysis Panel:**
- "Blended LTV:CAC this quarter" KPI
- "Avg CAC payback period" KPI
- Alert: channels below 3x threshold (with $ impact if reallocated)

---

## Page 3: Billing Operations

**Charts:**
- Failed payment rate by month (line chart + threshold)
- Invoice status distribution (paid/failed/pending) — pie + trend
- Dunning recovery rate (how many failed → eventually paid)
- Invoice aging table (which accounts have unpaid invoices 30+ days)

**Operational Table:**
- Accounts with outstanding invoices > 14 days
- Columns: workspace, plan, MRR, invoice amount, days overdue, last payment attempt
- Actions: "Mark for dunning outreach" button

---

## Page 4: Revenue Cohort Analysis

**Charts:**
- Revenue retention heatmap by signup cohort (rows: cohort month, cols: 0-12 months, values: NRR %)
- NRR trend over 8 quarters (line chart, benchmark line at 110%)
- GRR vs NRR comparison (two lines, shows expansion contribution)
- Revenue by cohort vintage (stacked bar — how much revenue from each cohort year)

---

## Alert Logic

| Trigger | Severity | Action |
|---|---|---|
| MRR misses plan by >5% | Critical | Email CFO + analytics |
| Failed payment rate > 3% | High | Notify finance ops |
| NRR drops >2pp in one month | High | Notify CFO + analytics |
| Invoice unpaid for 15+ days | Medium | Auto-add to dunning queue |
| Large account (MRR > $2K) churns | Critical | Alert CEO + CS + analytics |

---

## Power BI Implementation Notes

- Separate row-level security for finance vs. management roles
- Finance can see individual account MRR; management sees aggregated only
- "Revenue at Risk" widget connects to the churn model output
- Currency: default USD; toggle to local currency for international reporting

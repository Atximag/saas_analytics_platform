# Notivo Analytics Platform — Metric Dictionary

> **Purpose:** Every metric has exactly one canonical definition. This document is the authoritative source. Any dashboard, report, or analysis that references a metric must use the definition here. Inconsistent metric definitions are the #1 cause of stakeholder distrust in analytics.

---

## How to Read This Document

Each metric entry contains:
- **Definition**: Precise, unambiguous calculation
- **Business purpose**: Why we track this
- **Owner**: Which team is accountable for this metric
- **Cadence**: How often it's reviewed
- **Numerator / Denominator**: Makes the math explicit
- **Caveats**: Known limitations and edge cases
- **Threshold**: What good looks like

---

## Revenue Metrics

### MRR — Monthly Recurring Revenue

| Field | Value |
|---|---|
| **Definition** | Normalized monthly revenue from all active paid subscriptions |
| **Formula** | `SUM(subscription.mrr)` where `status = 'active'` |
| **Annual handling** | Annual contracts are divided by 12 — never recognized as full-year upfront |
| **Exclusions** | One-time fees, professional services, setup fees, refunds |
| **Owner** | Finance + RevOps |
| **Cadence** | Daily (automated) / Monthly (board pack) |
| **Threshold** | Target: $1.8M by Q4 2024. Alert if MoM growth < 3% |
| **Caveat** | Multi-year deals at discounted rates: use contracted MRR, not invoiced |

---

### ARR — Annual Recurring Revenue

| Field | Value |
|---|---|
| **Definition** | `MRR × 12` — the annualized run rate of recurring revenue |
| **Formula** | `current_mrr * 12` |
| **Exclusions** | Same as MRR |
| **Owner** | Finance |
| **Cadence** | Monthly |
| **Threshold** | Target: $18M ARR end of 2024 |
| **Caveat** | ARR is a snapshot metric, not cumulative. "ARR grew 50%" means the current run rate is 50% higher — not that we collected 50% more cash |

---

### Net Revenue Retention (NRR)

| Field | Value |
|---|---|
| **Definition** | Revenue retained from a cohort after 12 months, including expansion and contraction, as a % of starting revenue |
| **Formula** | `(Starting MRR + Expansion MRR - Contraction MRR - Churned MRR) / Starting MRR × 100` |
| **Measurement window** | 12 months after cohort's first paid month |
| **Owner** | Growth + Finance |
| **Cadence** | Monthly |
| **Threshold** | Target: >110%. Warning: <105%. Crisis: <100% |
| **Caveat** | NRR <100% means the business shrinks even without acquiring new customers. Current NRR of 108% is declining — key focus area |

---

### Gross Revenue Retention (GRR)

| Field | Value |
|---|---|
| **Definition** | MRR retained from existing customers excluding expansion. Measures pure churn impact. |
| **Formula** | `(Starting MRR - Churned MRR - Contraction MRR) / Starting MRR × 100` |
| **Ceiling** | Always ≤ 100% (cannot exceed starting revenue without expansion) |
| **Owner** | Finance |
| **Threshold** | Target: >90%. SMB benchmark: 85-90%. Enterprise: 90-95% |

---

### LTV — Customer Lifetime Value

| Field | Value |
|---|---|
| **Definition** | Expected revenue from a customer over their entire relationship |
| **Formula** | `ARPU × Gross Margin % × Average Lifetime Months` |
| **Gross margin** | 70% (SaaS industry standard; verify with Finance annually) |
| **Average lifetime** | `1 / Monthly Churn Rate` |
| **Owner** | Growth |
| **Cadence** | Quarterly |
| **Caveat** | Forward-looking. Varies significantly by plan and channel. Report LTV by segment, not as a single blended number |

---

### CAC — Customer Acquisition Cost

| Field | Value |
|---|---|
| **Definition** | Fully-loaded cost to acquire one new paying customer |
| **Formula** | `(Sales + Marketing Spend) / New Paying Customers Acquired` |
| **Fully-loaded** | Includes salaries, tools, ad spend, events, allocated overhead |
| **Owner** | Marketing + Finance |
| **Cadence** | Monthly |
| **Threshold** | Alert: LTV:CAC < 3x |

---

### CAC Payback Period

| Field | Value |
|---|---|
| **Definition** | Months to recover CAC from gross profit |
| **Formula** | `CAC / (ARPU × Gross Margin)` |
| **Owner** | Finance |
| **Threshold** | Target: <18 months. Risk: >24 months. Current: ~14 months |

---

## Product Metrics

### MAU — Monthly Active Users

| Field | Value |
|---|---|
| **Definition** | Distinct users who had at least one session in the calendar month |
| **Formula** | `COUNT(DISTINCT user_id)` where `session.started_at` in month |
| **Exclusions** | Internal Notivo employees, bot accounts, test users |
| **Owner** | Product |
| **Threshold** | Target: 150K MAU by Q4 2024 |

---

### DAU — Daily Active Users

| Field | Value |
|---|---|
| **Definition** | Distinct users with at least one session on a given calendar day |
| **Smoothing** | Report as 7-day rolling average to reduce weekday/weekend noise |
| **Owner** | Product |

---

### Stickiness (DAU/MAU)

| Field | Value |
|---|---|
| **Definition** | The ratio of daily to monthly active users. Measures habit formation. |
| **Formula** | `DAU / MAU` (using same-month comparisons) |
| **Interpretation** | 0.30 = users visit ~9 days/month. Top B2B SaaS: 0.25-0.45 |
| **Owner** | Product |
| **Threshold** | Target: >0.30. Current: 0.31 (declining — alert) |
| **Caveat** | Weekend-heavy products naturally have lower stickiness. Context-adjust |

---

### Activation Rate

| Field | Value |
|---|---|
| **Definition** | % of new users who complete all 5 onboarding steps within 7 days of signup |
| **Formula** | `Users completing step 5 within D+7 / Total new signups in period` |
| **"Activated" definition** | All 5 steps: profile_setup, invite_teammate, create_doc, connect_integration, set_notifications |
| **Owner** | Growth / Onboarding team |
| **Threshold** | Target: 45%. Current: 38%. Every +1% ≈ ~$22K additional MRR/year |

---

### Feature Adoption Rate

| Field | Value |
|---|---|
| **Definition** | % of active users who used a specific feature at least once in the last 30 days |
| **Formula** | `Users with feature_usage.usage_count_30d > 0 / MAU` |
| **Owner** | Product (feature-specific PMs) |
| **Caveat** | "Used once" vs "deep usage" are different. Also report feature depth score |

---

## Churn & Retention

### Gross Logo Churn Rate

| Field | Value |
|---|---|
| **Definition** | % of paying workspaces that cancelled in the period |
| **Formula** | `Cancelled workspaces in month / Active workspaces at start of month` |
| **Owner** | Customer Success |
| **Threshold** | Alert: >3.5%/month. Current: 3.1% — tracking toward alert zone |

---

### Cohort Retention Rate (Month N)

| Field | Value |
|---|---|
| **Definition** | % of users from a signup cohort who are still active N months later |
| **"Active"** | At least one session in the Nth calendar month |
| **Cohort definition** | Grouped by signup month (not first payment month) |
| **Owner** | Product + Growth |

---

## Funnel Metrics

### Trial-to-Paid Conversion Rate

| Field | Value |
|---|---|
| **Definition** | % of free trial workspaces that convert to any paid plan within 30 days |
| **Formula** | `Workspaces on paid plan within 30 days of trial start / Trial starts in period` |
| **Owner** | Growth |
| **Threshold** | Target: 25%. Current: 22% |

---

*Last updated: 2024-12-31 | Maintained by: Analytics Team*
*Change requests: Open a PR against this file with business justification*

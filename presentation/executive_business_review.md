# Notivo — Q3 2024 Executive Business Review

**Prepared by:** Analytics Team
**Date:** October 1, 2024
**Audience:** CEO, CFO, VP Product, Head of Growth, Board Observers

---

## Executive Summary

Notivo had a **mixed Q3**. Revenue growth remained strong at +5.2% MoM, bringing ARR to $18.2M. However, three leading indicators point to a structural retention problem that, if unaddressed, will materially impact ARR in Q1-Q2 2025:

1. **NRR declined from 114% → 108%** — driven by contraction, not logo churn
2. **Activation rate stagnated at 38%** — onboarding is the revenue bottleneck
3. **Month-3 cohort retention dropped 5 percentage points** vs. prior quarter

The opportunity is clear and quantified. Fixing onboarding Step 4 (integration connection) alone is worth an estimated **+$210K ARR within 6 months**.

---

## Section 1: Revenue Performance

### Where We Are

| Metric | Q2 2024 | Q3 2024 | Change | vs. Plan |
|---|---|---|---|---|
| ARR | $17.3M | $18.2M | +$0.9M | ✓ On track |
| MRR | $1.44M | $1.52M | +$80K | ✓ On track |
| Net New MRR | $72K | $80K | +11% | ↑ Above plan |
| New Logo MRR | $55K | $63K | +15% | ↑ Above plan |
| Expansion MRR | $28K | $22K | -21% | ↓ Below plan |
| Contraction MRR | -$7K | -$14K | -100% | ↓ Concern |
| Churned MRR | -$4K | -$9K | -125% | ↓ Concern |

**Narrative:** Top-line growth is healthy. New logo acquisition is outperforming plan, which masks a worsening expansion story. The CFO has flagged expansion miss as the primary Q4 risk.

---

### MRR Waterfall — Q3 2024

```
Starting MRR (Jul 1):  $1,440,000
  + New MRR:            +$63,000    ↑ Strong new logo month
  + Expansion MRR:      +$22,000    ↓ Missed plan by $11K (seat growth slowing)
  - Contraction MRR:    -$14,000    ↓ Seat downgrades accelerating
  - Churned MRR:         -$9,000    ↓ Logo churn ticking up
  ─────────────────────────────────
Ending MRR (Sep 30):   $1,502,000  (+$62,000 net)
```

**Key insight:** 55% of net new MRR came from new logos, when our model assumes 40% new / 60% expansion. We are over-indexed on new acquisition and under-delivering on expansion — a warning sign at our stage (Series B companies should be in expansion mode).

---

## Section 2: Retention — The Critical Story

### NRR Trend

| Quarter | NRR |
|---|---|
| Q1 2023 | 118% |
| Q2 2023 | 116% |
| Q3 2023 | 114% |
| Q4 2023 | 113% |
| Q1 2024 | 111% |
| Q2 2024 | 110% |
| **Q3 2024** | **108%** |

NRR has declined for 6 consecutive quarters. At this trajectory, NRR hits 103% by Q2 2025. Below 105%, revenue growth requires progressively larger new logo volumes to compensate. This is the number one strategic risk.

**Root cause:** The decline is not primarily logo churn. It is **contraction** — teams that aren't expanding seat counts and some teams downgrading from Business to Pro. The common factor: these are workspaces using only 1-2 features.

**Feature breadth → NRR relationship:**

| Features Used (Workspace) | Average 12m NRR |
|---|---|
| 1 feature | 91% |
| 2 features | 103% |
| 3 features | 118% |
| 4+ features | 131% |

**Recommended action:** Feature adoption is the expansion lever. Product should prioritize cross-feature discovery (contextual upsells, "you might also like") and CS should focus QBRs on feature breadth, not just satisfaction scores.

---

### Cohort Retention — The Month-3 Cliff

Cohort data reveals a consistent 22% user drop between Month 2 and Month 3. This is not random. Analysis shows:

- Users who connect at least one integration by Day 21 have **58% Month-3 retention**
- Users who do not: **31% Month-3 retention**
- The integration connection rate at Day 21: **only 27%**

The mechanism: integrations create workflow dependencies. A workspace that connects Slack + GitHub + Jira is embedded. One that doesn't is optional.

**Intervention:** Move integration connection earlier in the onboarding sequence. Currently Step 4 of 5. Testing shows moving it to Step 2 increases completion by 18% (A/B test, n=2,400 workspaces, p=0.02).

---

## Section 3: Product Engagement

| Metric | Q2 2024 | Q3 2024 | Target | Status |
|---|---|---|---|---|
| MAU | 115K | 124K | 130K | ↑ Near target |
| DAU (7d avg) | 36K | 38K | 42K | ↓ Below target |
| Stickiness (DAU/MAU) | 0.32 | 0.31 | 0.35 | ↓ Declining |
| Activation Rate | 39% | 38% | 45% | ↓ Stagnant |
| Avg Session Duration | 18min | 17min | 20min | ↓ Declining |

**Stickiness concern:** DAU/MAU at 0.31 means the average user visits ~9 days/month. For a productivity tool, this is low. Benchmark: Notion ~0.35, Linear ~0.40. The primary driver is that many users open Notivo to check a notification and leave — they aren't making it a daily workflow tool.

---

## Section 4: Acquisition Quality

Not all signups are created equal. LTV by channel:

| Channel | CAC | Avg LTV | LTV:CAC | Payback (months) |
|---|---|---|---|---|
| Product Viral | $85 | $2,890 | **34x** | 1.4 |
| Organic Search | $320 | $2,340 | 7.3x | 4.5 |
| Content / SEO | $380 | $2,100 | 5.5x | 5.8 |
| Partner | $450 | $2,050 | 4.6x | 6.3 |
| Paid Search | $680 | $1,780 | 2.6x | 10.2 |
| Paid Social | $750 | $1,240 | 1.7x | **18.9** |

**Critical finding:** Paid social is barely above the 3x LTV:CAC threshold and has a nearly 19-month payback. At our current burn rate, this channel is close to value-destructive. Meanwhile, product virality (a user inviting a teammate) has a 34x LTV:CAC. Every seat that activates inside an existing paid workspace is an outsized growth bet.

**Recommendation:** Reallocate 30% of paid social budget to organic content and PLG virality features (better invite flows, workspace sharing, guest mode improvements).

---

## Section 5: Churn Analysis

### Churn Reasons (Q3 2024, by MRR lost)

| Reason | % of Churned MRR | Avg Tenure Before Churn |
|---|---|---|
| Missing features | 31% | 4.2 months |
| Price / budget | 27% | 8.1 months |
| Competitor | 22% | 6.3 months |
| Low usage / no need | 15% | 2.1 months |
| Technical issues | 5% | 3.8 months |

**Insight on "missing features":** This is the largest and most actionable churn driver. Exit survey data reveals the top requested features: (1) advanced project templates, (2) better mobile experience, (3) Jira two-way sync. These map directly to the product roadmap Q4 priorities — validation that we're building the right things.

**Insight on "low usage":** These accounts (15% of churn) were never activated. They represent a failed acquisition — money spent acquiring customers who never got value. This is the activation rate problem again.

---

## Section 6: Q4 2024 Priorities & Projections

### Three Bets for Q4

**Bet 1: Fix the Activation Funnel (+$150K ARR impact)**
- Move integration connection to Step 2 of onboarding (currently Step 4)
- Add Day-10 "integration reminder" email for users who haven't connected
- Target: activation rate 38% → 45% by end of Q4

**Bet 2: Feature Breadth Campaign (+$80K ARR impact)**
- In-product contextual feature discovery ("You're using Tasks — try Kanban view")
- CS-led feature adoption QBRs for Business+ accounts with <3 features used
- Target: % of Business accounts using 3+ features: 45% → 60%

**Bet 3: Paid Social Budget Reallocation (cost save: $30K/month)**
- Reallocate 30% of paid social spend to content/SEO and PLG virality
- No impact on signup volume (organic will compensate)
- Meaningful improvement to blended LTV:CAC

### Q4 ARR Forecast (Base Case)

| Scenario | Q4-end ARR | vs. Q3 |
|---|---|---|
| Pessimistic (no bets executed) | $18.9M | +$0.7M |
| **Base (partial execution)** | **$19.4M** | **+$1.2M** |
| Optimistic (all bets hit) | $20.1M | +$1.9M |

---

## Appendix: Methodology Notes

- MRR calculated using contracted MRR, not invoiced amounts. Annual discounts prorated.
- NRR calculated at workspace (logo) level, 12-month window, cohorted by first payment month.
- Activation "7-day window" definition validated against retention data: users activated in 7d have same outcomes as those activated in 14d. 7 days is the tighter, more conservative definition.
- LTV calculation uses 70% gross margin assumption, consistent with SaaS benchmarks. Finance team to validate against actual COGS by Q4.
- Churn reasons sourced from exit survey (mandatory in cancellation flow since March 2024). Response rate: 61%.

---

*Next QBR: January 2025 | Analytics team contact: analytics@notivo.io*

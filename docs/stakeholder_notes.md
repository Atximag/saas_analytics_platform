# Notivo Analytics Platform — Stakeholder Notes

> This document captures what each stakeholder team needs from analytics, their analytical maturity level, and how to communicate findings effectively. Good analysis delivered poorly is wasted analysis.

---

## Stakeholder Map

### CFO / Finance Team

**What they need:**
- MRR/ARR accuracy above all else — revenue recognition, not activity metrics
- Forward-looking: forecast, plan vs. actual, variance explanations
- Risk quantification: how much MRR is at risk from at-risk accounts?
- Unit economics: LTV:CAC trends, CAC payback evolution, gross margin trends

**Communication style:**
- Numbers first, narrative second
- Every chart needs a "so what" annotation
- Variance needs explanation: "MRR missed by $12K because churn was 15% higher than modeled, driven by 3 mid-market accounts canceling in the same week"
- Preferred format: executive table + sparklines. Never raw data.

**Red flags to always surface immediately:**
- MRR deviation > ±5% from plan
- NRR dropping below 105%
- CAC payback extending beyond 18 months
- Failed payment rate > 3%

---

### VP Product

**What they need:**
- Activation funnel — where do users drop and why?
- Feature adoption curves — which features are growing vs. stagnating?
- Engagement cohorts — which user segments are most engaged?
- Experiment results — did the new onboarding flow move the needle?

**Communication style:**
- Prefers visual exploration over summary tables
- Wants hypotheses tested, not just described
- Ask: "If we fix this, what's the expected impact?"
- Connect every product metric to a revenue outcome

**Key questions they always ask:**
- "Is this statistically significant?"
- "What's the counterfactual?" (i.e., what would have happened without the change)
- "Which user segment is driving this?" (don't show blended averages)

---

### Head of Growth / Marketing

**What they need:**
- Channel attribution: which channels produce highest LTV, not just highest volume
- Funnel efficiency by source: where do different acquisition channels drop off?
- Cohort quality: do cohorts from last quarter's campaign show good retention?
- Activation by channel: do users from paid social activate at lower rates?

**Communication style:**
- Metrics over time (trend > snapshot)
- Benchmarks help: "Our organic conversion rate is 2.1x higher than paid social"
- Always include confidence intervals on trend data
- Avoid jargon: "LTV:CAC" needs brief explanation in reports going to junior marketers

**Pitfalls to avoid:**
- Never attribute 100% of conversion to last-touch channel
- Viral/referral attribution is tricky — always flag assumptions
- Campaign spend data is usually 2 weeks delayed — note this in reports

---

### Customer Success / CS Team

**What they need:**
- At-risk accounts: daily/weekly updated list with MRR at stake
- Expansion candidates: accounts ready for upsell conversation
- Health score per account: simple 1-10 score they can act on
- Churn post-mortem: when an account churns, why, and were there early signals?

**Communication style:**
- Actionable over analytical — they need a list to call, not a methodology
- Sort by MRR at risk, not by score
- Include next recommended action for each account
- False positive tolerance: it's better to surface 20 at-risk accounts and have 5 actually churn than to miss any

**Data they produce that analytics needs:**
- Cancellation exit survey responses (churn reason enrichment)
- QBR notes (product feedback + expansion signals)
- Win-back outcomes (helps calibrate intervention effectiveness)

---

### CEO / Board

**What they need:**
- Top 5 metrics per quarter: MRR, ARR, NRR, logo count, activation rate
- Narrative: "Here's what happened, here's why, here's what we're doing about it"
- Competitive context where available
- Forward guidance: are we on track for annual plan?

**Communication style:**
- No methodology, no footnotes in the deck itself (put them in appendix)
- Tell the story in 3 slides: "What is our health?", "What's the problem?", "What's the plan?"
- Use comparisons: "We were at 114% NRR a year ago, now 108% — here's the root cause"
- Risks must be named: hiding a concerning metric is worse than surfacing it with a plan

---

## Analytics Meeting Cadence

| Meeting | Participants | Frequency | Key Deliverable |
|---|---|---|---|
| Revenue Review | CFO, Finance, Analytics | Weekly | MRR dashboard update |
| Product Analytics Review | VP Product, Growth, Analytics | Bi-weekly | Feature + funnel deep-dive |
| Churn Review | CS Lead, VP Product, Analytics | Monthly | At-risk accounts + churn post-mortems |
| Quarterly Business Review | CEO, CFO, VPs, Analytics | Quarterly | Full KPI pack + narrative |
| Experiment Readout | Growth, Product, Analytics | Ad hoc | A/B test results + recommendations |

---

## How to Write an Analytical Insight

**Bad:** "Retention declined in Q3."

**Good:** "Month-3 retention dropped from 42% to 35% for the September cohort — a 17% relative decline. The primary driver is users who didn't complete the integration step (Step 4) during onboarding. Users who skipped Step 4 have 28% Month-3 retention vs. 54% for those who completed it. Recommended action: make the integration step mandatory in the onboarding flow and add a proactive reminder at Day 10 for users who haven't connected at least one integration."

The formula: **observation → root cause → mechanism → quantified impact → recommended action**.

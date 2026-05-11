# Notivo Analytics Platform — Business Glossary

> Consistent terminology prevents stakeholder confusion. Every term here has an exact meaning at Notivo. When in doubt, use the term from this glossary — not an industry synonym.

---

## Core Concepts

**Workspace:** The primary organizational unit at Notivo. A company (or team within a company) creates one workspace. Billing, subscriptions, and analytics are tracked at the workspace level.

**Seat:** One paying user slot within a workspace subscription. A Business plan workspace with 25 seats pays for 25 users.

**Owner:** The workspace creator and primary account holder. Has billing access. One per workspace.

**Active User:** A user who completed at least one session in the measurement period. Does NOT include users who only received email notifications.

**Activated User:** A user who has completed all 5 onboarding steps. "Activation" is our primary measure of whether a user has experienced the core value proposition.

**Power User:** A user in the top 10th percentile of engagement score (session frequency × feature breadth × event count). These are our most engaged users and are usually the internal champions.

---

## Revenue Terms

**MRR (Monthly Recurring Revenue):** The normalized monthly value of all active subscription contracts. Annual subscriptions are divided by 12.

**New MRR:** MRR from workspaces making their first payment in a given month.

**Expansion MRR:** MRR increase from existing customers (additional seats or plan upgrades).

**Contraction MRR:** MRR decrease from existing customers (seat reduction or plan downgrade). Always negative.

**Churned MRR:** MRR lost when a workspace cancels entirely. Always negative.

**Net New MRR:** New + Expansion + Contraction + Churned MRR. The single number that captures total MRR movement.

**ARR (Annual Recurring Revenue):** MRR × 12. A point-in-time annualized run rate, not the total revenue collected in a year.

**ACV (Annual Contract Value):** The annual value of a specific customer contract. Used in sales for deal sizing.

**LTV (Lifetime Value):** Expected total revenue from a customer over their entire relationship. Calculated as ARPU × Gross Margin × Average Lifetime.

**CAC (Customer Acquisition Cost):** Fully-loaded cost to acquire one paying customer. Includes all sales and marketing costs divided by new customers in the period.

---

## Churn Terms

**Logo Churn:** A workspace canceling its subscription. One logo = one workspace.

**Gross Logo Churn Rate:** % of paying workspaces that canceled in a period.

**Net Logo Churn Rate:** Gross churn minus reactivations. Can be negative if reactivations exceed new cancellations.

**Involuntary Churn:** Churn caused by payment failure (expired card, etc.), not by customer decision.

**Voluntary Churn:** Churn where the customer actively chose to cancel.

**At-Risk Account:** A workspace flagged by our churn model with a risk score ≥ 40. Requires CSM attention.

**Win-Back:** A previously churned workspace that reactivates a paid subscription.

---

## Product Terms

**Stickiness:** DAU/MAU ratio. Measures how frequently monthly users visit daily. Higher = more habitual.

**Activation:** Completion of all 5 onboarding steps. Our definition of "the user got value."

**Aha Moment:** The first action that correlates strongly with long-term retention. For Notivo: completing the integration step. This is when the product becomes embedded in the user's workflow.

**Feature Breadth:** The number of distinct product features a user or workspace actively uses. Correlated with NRR.

**Feature Depth:** A 0-100 score measuring how advanced a user's usage of a specific feature is. High depth = power user of that feature.

**Session:** A continuous period of user activity. Sessions are considered ended after 30 minutes of inactivity.

**Time to Value (TTV):** Hours/days from signup to first meaningful action. Lower is better.

---

## Experimentation Terms

**Control:** The existing, unchanged experience in an A/B test.

**Treatment / Variant:** The new experience being tested.

**Primary Metric:** The single metric we're trying to move with the experiment. Defined before the experiment starts.

**Statistical Significance:** We use 95% confidence (p < 0.05) as the threshold for declaring a winner.

**Minimum Detectable Effect (MDE):** The smallest improvement we've designed the experiment to be able to detect. Our standard MDE is 5% relative lift.

**Sample Size:** Calculated before starting the experiment based on current baseline metric, MDE, and confidence level. We do not stop experiments early based on early signals.

---

*Last updated: 2024-12-31 | Maintained by: Analytics Team*

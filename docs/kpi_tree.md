# Notivo Analytics Platform — KPI Tree

> A metric without a parent is a metric without a purpose. Every KPI here is connected to business outcomes. This tree is used to align Product, Growth, Finance, and CS teams around a common analytical framework.

---

## The Business Equation

```
Net Revenue Growth = New Revenue + Expansion Revenue - Churn Revenue
```

All metrics in the system ultimately connect to one of these three levers.

---

## Full KPI Tree

```
BUSINESS HEALTH
│
├── REVENUE GROWTH
│   ├── ARR / MRR (top-line)
│   │   ├── New MRR
│   │   │   ├── New Logo Acquisition
│   │   │   │   ├── Signup Volume (channel-attributed)
│   │   │   │   ├── Trial-to-Paid Conversion Rate
│   │   │   │   │   ├── Activation Rate (% completing onboarding)
│   │   │   │   │   │   ├── Step 1 Completion: Profile Setup
│   │   │   │   │   │   ├── Step 2 Completion: Invite Teammate
│   │   │   │   │   │   ├── Step 3 Completion: Create Doc
│   │   │   │   │   │   ├── Step 4 Completion: Connect Integration ← highest leverage
│   │   │   │   │   │   └── Step 5 Completion: Set Notifications
│   │   │   │   │   └── Time to Value (hours to first meaningful action)
│   │   │   │   └── CAC by Channel
│   │   │   │       ├── Paid Search CAC
│   │   │   │       ├── Organic CAC
│   │   │   │       └── Viral/Referral CAC (lowest)
│   │   │   │
│   │   ├── Expansion MRR
│   │   │   ├── Seat Expansion (user invitations within paid workspaces)
│   │   │   │   ├── Collaboration Feature Usage (invites, sharing)
│   │   │   │   └── Workspace Growth (employee headcount proxy)
│   │   │   └── Plan Upgrades (Pro → Business → Enterprise)
│   │   │       ├── Feature Gate Hits (user hits plan limit)
│   │   │       └── Power User Density (% users at high engagement)
│   │   │
│   │   └── Retained MRR (MRR kept from existing base)
│   │       └── See Retention branch below
│   │
│   └── Net Revenue Retention (NRR)
│       ├── Gross Revenue Retention (GRR)
│       │   └── See Churn branch below
│       └── Expansion Rate
│           ├── Feature Adoption Breadth (# of features used)
│           └── Seat Growth Rate Within Workspaces
│
├── RETENTION
│   ├── Cohort Retention Curves
│   │   ├── Month 1 Retention (most sensitive to activation quality)
│   │   ├── Month 3 Retention (the "cliff" — key product problem)
│   │   ├── Month 6 Retention
│   │   └── Month 12 Retention (leading indicator of LTV)
│   │
│   ├── Engagement Signals (leading indicators for retention)
│   │   ├── Stickiness (DAU/MAU) — habit formation
│   │   │   ├── DAU (7-day rolling average)
│   │   │   ├── WAU
│   │   │   └── MAU
│   │   ├── Feature Breadth (# distinct features used in 30d)
│   │   ├── Collaboration Intensity (invites + comments + shares)
│   │   └── Session Frequency Trend (MoM change in sessions/user)
│   │
│   └── At-Risk Signals (churn predictors)
│       ├── Session Frequency Drop (>50% decline in 14 days)
│       ├── Feature Usage Absence (0 usage in 14 days)
│       ├── Support Ticket Sentiment (negative in last 30 days)
│       └── Failed Payment (any invoice failure in 30 days)
│
└── CHURN
    ├── Gross Logo Churn Rate
    │   ├── Voluntary Churn
    │   │   ├── Churn by Reason (price, feature gap, competitor)
    │   │   ├── Churn by Cohort Age (Month 3 cliff = highest risk)
    │   │   ├── Churn by Plan (Free → highest, Enterprise → lowest)
    │   │   └── Churn by Channel (paid social → highest churn rate)
    │   └── Involuntary Churn (payment failures)
    │       ├── Failed Payment Rate
    │       └── Dunning Recovery Rate
    │
    └── Churn Revenue Impact
        ├── MRR Lost to Churn (monthly)
        ├── Average MRR per Churned Account
        └── Churn by Customer Segment (Champions vs. Hibernating)
```

---

## Metric Relationships — What Drives What

### Activation → Everything

Activation is the most upstream product metric. It directly causes:
- Higher trial-to-paid conversion (activated users convert 4.2x more)
- Higher Month-1 retention (activated users have 3.1x better retention)
- Faster seat expansion (teams that activate together grow together)

**The math:** Moving activation from 38% → 45% generates approximately $180K additional MRR within 90 days, assuming current conversion rates hold.

### Feature Breadth → NRR

The number of features a workspace actively uses is the strongest predictor of NRR. Single-feature workspaces have 91% NRR. 3+ feature workspaces have 127% NRR.

**Why:** Feature depth creates switching costs. A workspace that runs docs + tasks + integrations + automations has high exit friction. One that only uses docs does not.

### Stickiness → Survival

DAU/MAU below 0.20 is a strong 90-day leading indicator of churn. The mechanism: low stickiness means the product hasn't formed a habit. Without a habit, the value proposition feels optional. Optional tools get canceled in the next budget review.

### Channel → LTV

Not all signups are equal. Viral/referral users have 3.6x LTV vs. paid social users. The mechanism: viral users join because a trusted teammate invited them — they have a built-in use case and social accountability. Paid social users sign up on impulse with lower intent.

**The implication:** Optimizing for signup volume (impressions/clicks) misaligns incentives. The right optimization is signup quality (LTV-predicted score at signup).

---

## Metric Accountability Matrix

| Metric | Primary Owner | Secondary Owner | Review Cadence |
|---|---|---|---|
| ARR / MRR | Finance | RevOps | Weekly |
| NRR | Growth | Finance | Monthly |
| Activation Rate | Product (Onboarding) | Growth | Weekly |
| DAU/MAU | Product | — | Daily |
| Trial Conversion | Growth | Sales | Weekly |
| Logo Churn | Customer Success | Finance | Monthly |
| LTV:CAC by Channel | Marketing | Finance | Quarterly |
| Feature Adoption | Product | — | Monthly |
| Churn Risk Score | Customer Success | Analytics | Weekly |

---

*KPI Tree maintained by Analytics. Changes require sign-off from Product + Finance.*

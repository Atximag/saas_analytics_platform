# Product Analytics Dashboard — Design Specification

**Audience:** VP Product, Product Managers, Growth Team
**Update cadence:** Daily
**Primary purpose:** Understanding user behavior, feature adoption, activation health, and engagement trends to inform product decisions.

---

## Dashboard Philosophy

Product dashboards answer: **"What are users actually doing, and what should we build next?"**

Unlike the executive dashboard (which shows business outcomes), the product dashboard shows **leading indicators** — behaviors that predict future business outcomes. It's forward-looking and exploratory.

Every chart should have a "so what" implication for the roadmap.

---

## Page 1: Engagement Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Engagement Overview  │  Period: Last 30 days ▼  │  All Plans ▼  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DAU (7d avg)   WAU      MAU     Stickiness    New Users        │
│    38,200      72,400   124K       31%          4,800           │
│   +4% WoW     +2% WoW  +8% MoM  ↓ -1pp       -3% WoW          │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [DAU/WAU/MAU Time Series — 90 days]                            │
│                                                                  │
│  Users  ─── MAU  - - WAU  ·····DAU                              │
│  160K │                                    ─────────            │
│  120K │                          ──────────                      │
│   80K │                ──────────                                │
│   40K │  ─────────────                                           │
│    0  └──────────────────────────────────── time                │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  [Session Distribution]        [Device Type Mix]                │
│   Duration heatmap (hour/day)  Desktop 72%, Mobile 22%, Tab 6% │
└──────────────────────────────────────────────────────────────────┘
```

---

## Page 2: Activation Funnel

```
┌─────────────────────────────────────────────────────────────────┐
│  Activation Funnel  │  Cohort: Last 30 days  │  Source: All ▼   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Funnel Visualization]                  [Activation Rate Trend] │
│                                                                  │
│  Signed Up        12,400  100%                                   │
│  ────────────────────────────                                    │
│  Step 1: Profile   10,890   88%  ✓                              │
│  ────────────────────────────                                    │
│  Step 2: Invite     7,440   60%  ↓ largest drop                 │
│  ─── ← BIG DROP ────────────────                                │
│  Step 3: Create Doc 5,920   48%  ↓                              │
│  ────────────────────────────                                    │
│  Step 4: Integrate  3,100   25%  ↓ critical step                │
│  ────────────────────────────                                    │
│  Step 5: Activated  2,480   20%  ← activation rate              │
│                                                                  │
│  [Drop Analysis Table]                                           │
│  Step 2 drop: 28% of users skip invite. Reason: solo users.     │
│  Step 4 drop: 58% drop. Highest-leverage fix.                   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  Activation Rate by Channel (30-day cohort)                     │
│                                                                  │
│  Viral         ██████████████████ 54%                           │
│  Organic       █████████████  42%                               │
│  Content       ████████████  39%                                │
│  Paid Search   ████████     27%                                 │
│  Paid Social   ██████       22%                                 │
└──────────────────────────────────────────────────────────────────┘
```

**Drill-downs:**
- Click any funnel step → see drop-off users by company size, plan, channel
- Click "Step 4 drop" → see what users do instead (what event fires next after Step 3?)
- Filter by acquisition channel to see which channels produce the most activatable users

---

## Page 3: Feature Adoption

```
┌─────────────────────────────────────────────────────────────────┐
│  Feature Adoption  │  MAU as base  │  30-day window             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Feature Adoption Bar Chart — sorted by adoption %]            │
│                                                                  │
│  Search          ████████████████████████  79%                  │
│  Docs            ████████████████████████  78%                  │
│  Tasks           ██████████████████████    72%                  │
│  Kanban          █████████████████         55%                  │
│  Calendar        █████████████             42%                  │
│  Automations     ██████                    19%                  │
│  Integrations    █████████                 28%                  │
│  API             ████                      12%                  │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  [Feature Adoption Curves — monthly trend, each feature]        │
│                                                                  │
│  [Feature Correlation with 90-day Retention]                    │
│                                                                  │
│  Integrations     3.2x retention lift  ← highest leverage       │
│  Automations      2.8x                                           │
│  Kanban           2.1x                                           │
│  Calendar         1.8x                                           │
│  Tasks            1.4x                                           │
│  Docs             1.1x (baseline — everyone uses it)            │
└──────────────────────────────────────────────────────────────────┘
```

**Analytical note on feature correlation:**
The retention lift column shows how much better 90-day retention is for users who adopted the feature in their first 7 days vs. those who didn't. This is correlation, not causation. Users who go deeper into the product naturally use more features. But it's the best signal we have for which features create embedded value vs. which are incidental.

**Action implication:** Integrations have the highest retention lift AND the lowest adoption rate. This is the highest-ROI product investment — make integrations easier to discover and connect.

---

## Page 4: Cohort Engagement

```
┌─────────────────────────────────────────────────────────────────┐
│  User Engagement by Segment                                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Power User Distribution]      [Engagement Pyramid]            │
│                                                                  │
│  Power Users     8%             Power (8%)   ████               │
│  Core Users     23%             Core (23%)   █████████████      │
│  Casual Users   31%             Casual (31%) ████████████████   │
│  Light Users    28%             Light (28%)  ████████████████   │
│  Inactive       10%             Inactive(10%)█████              │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  [Session Frequency Distribution — histogram]                   │
│  [Feature Usage Depth Scatter — x:breadth, y:depth, size:MRR]  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Page 5: Experiment Tracker

| Experiment | Status | Metric | Control | Treatment | Lift | p-value | Decision |
|---|---|---|---|---|---|---|---|
| New Onboarding Step Order | Running | Activation rate | 38% | 42% | +10.5% | 0.03 | ✓ Ship |
| Integration Reminder Email | Concluded | Step 4 completion | 25% | 31% | +24% | 0.001 | ✓ Shipped |
| Kanban Feature Gate Prompt | Running | Kanban adoption | 55% | — | TBD | — | Pending |

**Statistical note:** All experiments use 95% confidence threshold. Minimum detectable effect: 5% relative lift. Minimum sample: 1,000 per variant.

---

## Stakeholder Usage Notes

**VP Product:** Reviews weekly before sprint planning. Uses activation funnel to prioritize onboarding improvements. Uses feature adoption chart to identify stagnating features.

**Growth PM:** Reviews daily. Monitors activation rate trend as primary KPI. Tracks experiment outcomes.

**Feature PMs:** Filter by their feature area. Track adoption curve weekly.

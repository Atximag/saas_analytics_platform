# Notivo Analytics Platform

**End-to-End Product & Revenue Intelligence System for a B2B SaaS Company**

---

> *"This is the analytics infrastructure layer that connects product decisions to business outcomes."*

---

## Overview

This repository contains a **production-grade SaaS analytics platform** built for **Notivo** — a fictional B2B project management and knowledge-base SaaS (think Notion meets Linear). The platform covers the full analytics stack: raw data ingestion → dbt transformation → KPI calculation → executive dashboards → churn prediction → growth forecasting.

The platform is designed to answer the questions that actually drive business decisions at a Series B SaaS company:

- **Why are users churning** — and which cohorts are at highest risk?
- **Which acquisition channels** produce the highest LTV customers?
- **Where does the onboarding funnel break** — and what is the revenue cost of that drop-off?
- **Which features** are correlated with long-term retention?
- **What is our true MRR motion** — new, expansion, contraction, churn?
- **Which customer segments** should we prioritize for enterprise sales?

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DATA SOURCES                                │
│  Product Events  │  CRM / Billing  │  Marketing  │  Support    │
└────────┬────────────────┬───────────────┬──────────────┬────────┘
         │                │               │              │
         ▼                ▼               ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  INGESTION LAYER (Python)                       │
│          src/ingestion/  →  data/raw/                           │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              TRANSFORMATION LAYER (dbt + SQL)                   │
│   Staging → Intermediate → Marts                                │
│   data quality checks, schema validation, freshness alerts      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ANALYTICS LAYER (Python)                       │
│   Retention │ Cohorts │ LTV │ Churn │ Segmentation │ Forecast   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│               PRESENTATION LAYER (Plotly / Power BI)            │
│   Executive Dashboard │ Product Dashboard │ Revenue Dashboard   │
└─────────────────────────────────────────────────────────────────┘
```

**Core Stack:**

| Layer | Technology |
|---|---|
| Language | Python 3.11 |
| Data Wrangling | Pandas, NumPy |
| Database | DuckDB (local dev) / PostgreSQL (prod) |
| Transformations | dbt Core |
| Notebooks | Jupyter Lab |
| Visualization | Plotly Express + Plotly Graph Objects |
| BI Dashboards | Power BI / Streamlit |
| Containerization | Docker + Docker Compose |
| Data Quality | Great Expectations + custom validation layer |
| Orchestration | Apache Airflow (DAGs defined) |

---

## Company Context: Notivo

Notivo is a **B2B SaaS** platform for modern teams. Core product:
- **Workspace**: shared project management + documentation hub
- **Monetization**: Freemium → Pro ($12/seat/mo) → Business ($25/seat/mo) → Enterprise (custom)
- **Stage**: Series B | ~50,000 active workspaces | ARR ~$18M
- **GTM**: Product-led growth (PLG) with a sales-assist motion above $5K ACV

Understanding this context shapes every analytical decision — from how we define "activation" to how we attribute revenue.

---

## Key Business Metrics

| Metric | Value (Simulated) | Trend |
|---|---|---|
| Monthly Active Users | ~124,000 | ↑ +8% MoM |
| Monthly Recurring Revenue | ~$1.52M | ↑ +5.2% MoM |
| Annual Recurring Revenue | ~$18.2M | |
| Net Revenue Retention | 108% | ↓ concern at 108 (was 114%) |
| Gross Logo Churn | 3.1% / month | ↑ risk |
| DAU/MAU (Stickiness) | 31% | ↓ declining |
| Avg. Payback Period | 14 months | |
| LTV:CAC | 3.4x | below 3x threshold for some channels |

---

## Repository Structure

```
saas_analytics_platform/
│
├── README.md                          # This file
├── requirements.txt                   # Python dependencies
├── .gitignore
├── docker-compose.yml                 # Local dev environment
│
├── data/
│   ├── raw/                           # Simulated source data (CSV)
│   ├── staging/                       # Cleaned, typed, validated
│   └── mart/                          # Business-ready aggregated tables
│
├── notebooks/
│   ├── 01_data_validation.ipynb       # Data quality audit
│   ├── 02_cleaning_and_preprocessing.ipynb
│   ├── 03_eda.ipynb                   # Exploratory deep-dive
│   ├── 04_product_analytics.ipynb     # DAU/WAU/MAU, stickiness, features
│   ├── 05_revenue_analytics.ipynb     # MRR waterfall, ARR, LTV, CAC
│   ├── 06_retention_analysis.ipynb    # Cohort retention, survival curves
│   ├── 07_cohort_analysis.ipynb       # Revenue cohorts, behavioral cohorts
│   ├── 08_segmentation.ipynb          # RFM, power users, at-risk users
│   ├── 09_churn_analysis.ipynb        # Churn drivers, predictive signals
│   └── 10_executive_summary.ipynb     # Board-ready summary narrative
│
├── sql/
│   ├── schema.sql                     # Full data model DDL
│   ├── staging_models.sql             # Staging transformations
│   ├── marts.sql                      # Business mart tables
│   ├── retention.sql                  # Retention matrix queries
│   ├── cohorts.sql                    # Cohort analysis SQL
│   ├── ltv.sql                        # LTV / CAC calculations
│   ├── funnel.sql                     # Conversion funnel analysis
│   ├── segmentation.sql               # User segmentation logic
│   └── executive_metrics.sql          # Board-level KPIs
│
├── src/
│   ├── ingestion/                     # Data loading & simulation
│   ├── preprocessing/                 # Cleaning pipelines
│   ├── metrics/                       # KPI calculation modules
│   ├── validation/                    # Data quality framework
│   ├── visualization/                 # Chart builders
│   ├── forecasting/                   # MRR & churn forecasting
│   └── segmentation/                  # Clustering & RFM
│
├── dashboards/
│   ├── executive_dashboard_spec.md    # CFO/CEO view spec
│   ├── product_dashboard_spec.md      # PM/Growth view spec
│   └── revenue_dashboard_spec.md      # Finance/RevOps view spec
│
├── dbt/
│   ├── staging/                       # stg_* models
│   ├── intermediate/                  # int_* models
│   ├── marts/                         # fct_*, dim_* models
│   └── tests/                         # dbt tests YAML
│
├── docs/
│   ├── architecture.md                # System design decisions
│   ├── metric_dictionary.md           # Canonical metric definitions
│   ├── stakeholder_notes.md           # PM/Finance/Growth notes
│   ├── kpi_tree.md                    # Metric dependency tree
│   └── business_glossary.md           # Company-specific terminology
│
└── presentation/
    └── executive_business_review.md   # QBR-style narrative
```

---

## Analytical Modules

### Product Analytics
- **Engagement metrics**: DAU, WAU, MAU, stickiness (DAU/MAU), L7/L28
- **Feature adoption**: adoption curves, depth of usage, feature correlation with retention
- **Session analysis**: session frequency, duration, feature touchpoints per session
- **Activation**: time-to-value, onboarding completion rate, aha-moment identification

### Revenue Analytics
- **MRR Waterfall**: new MRR, expansion, contraction, churn, net new MRR
- **Unit economics**: ARPU, LTV, CAC, payback period, LTV:CAC by channel
- **ARR decomposition**: logo growth vs. seat expansion vs. price changes
- **Billing health**: failed payment rate, dunning recovery, invoice aging

### Retention & Cohort Analytics
- **Retention matrices**: by signup cohort, plan type, acquisition channel
- **Survival analysis**: time-to-churn curves, median survival by segment
- **Leading indicators**: early signals of churn 30/60/90 days ahead
- **NRR / GRR decomposition**: expansion vs. logo churn contribution

### Segmentation
- **RFM segmentation**: Recency, Frequency, Monetary value tiers
- **Behavioral clustering**: usage pattern groups (Power / Casual / Dormant / At-Risk)
- **Revenue segmentation**: whale accounts, mid-market growth, SMB churn pool
- **ICP scoring**: Ideal Customer Profile match scoring for sales prioritization

### Churn Analysis
- **Voluntary vs. involuntary churn**: payment failure attribution
- **Churn driver analysis**: feature usage, support tickets, plan changes as signals
- **Predictive churn scoring**: logistic regression + feature importance
- **Win-back analysis**: reactivation rates and economics

---

## Setup Instructions

### Prerequisites

```bash
Python 3.11+
Docker Desktop
DuckDB (auto-installed via pip)
dbt-core + dbt-duckdb
```

### Quick Start

```bash
# Clone and setup environment
git clone https://github.com/yourname/saas_analytics_platform.git
cd saas_analytics_platform

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Launch local database + services
docker-compose up -d

# Generate synthetic data
python src/ingestion/generate_data.py

# Run dbt transformations
cd dbt && dbt run && dbt test

# Launch notebooks
jupyter lab
```

### Docker Environment

The `docker-compose.yml` spins up:
- **PostgreSQL**: production-equivalent database
- **Jupyter Lab**: notebook server at `localhost:8888`
- **Streamlit**: analytics dashboard at `localhost:8501`
- **Airflow** (optional): orchestration UI at `localhost:8080`

---

## Key Business Insights

> The following represents the kind of findings this platform surfaces — written for a VP Product or CFO audience.

**1. Activation gap is the #1 revenue leak**
Only 38% of free users complete onboarding within 7 days. Users who complete all 5 onboarding steps convert to paid at 4.2x the rate of those who don't. Closing this gap to 60% completion would yield ~$180K in additional MRR within 90 days.

**2. NRR degradation is a silent crisis**
Net Revenue Retention dropped from 114% to 108% over two quarters — driven not by churn but by contraction (seat downgrades). Teams using >3 core features show 127% NRR vs. 91% for single-feature teams. Feature adoption is the expansion lever.

**3. The "Month 3 cliff"**
Cohort retention data shows a consistent 22% user drop-off between Month 2 and Month 3. This coincides with the end of the free trial for the Business plan. Users who haven't integrated at least one external tool (Slack, GitHub, Jira) by Day 21 almost never convert.

**4. Channel LTV divergence**
Organic search users have 2.8x higher LTV than paid social users, but PLG viral users (invited by a paid teammate) have the highest LTV at 3.6x. CAC for viral is near-zero. The growth implication: every seat that activates inside an existing paid workspace is an outsized growth bet.

**5. Churn is predictable**
A 3-factor churn signal (session frequency drop + no feature usage in 14 days + support ticket in last 30 days) correctly identifies 71% of churning accounts 45 days before cancellation. A CSM intervention at that trigger point recovers ~18% of at-risk accounts.

---

## Analytics Engineering Decisions

**Why DuckDB for local dev?**
In-process OLAP database. No server, no Docker dependency for SQL work. Runs the full data model in <10 seconds locally. Swappable for Snowflake/BigQuery in production with dbt profile change.

**Why dbt for transformations?**
Version-controlled SQL. Built-in testing. Documentation generation. Column-level lineage. This is the industry standard for analytics engineering. The project structure mirrors real dbt projects at modern companies.

**Why modular Python over a single notebook?**
Production analytics must be reproducible and testable. Monolithic notebooks break at scale. Modules in `src/` can be unit tested, reused across notebooks, and scheduled in Airflow without refactoring.

**Metric definitions are centralized**
All KPIs are defined once in `docs/metric_dictionary.md` and implemented in `src/metrics/`. This prevents the #1 analytics failure mode: inconsistent metrics across teams.

---

## Future Improvements

- [ ] Integrate real Stripe webhook data pipeline
- [ ] Add Segment/Mixpanel event stream simulation
- [ ] Build ML churn model with SHAP explanations
- [ ] Deploy Streamlit dashboard to Streamlit Cloud
- [ ] Add dbt Semantic Layer integration
- [ ] Implement alerting for KPI threshold breaches
- [ ] Build experiment analysis framework (A/B test evaluator)
- [ ] Add data lineage visualization

---

## Author

Built as a portfolio demonstration of senior-level analytics engineering capabilities. Every metric, model, and insight reflects real decision-making frameworks used at modern SaaS companies.

---

*Technologies: Python · Pandas · NumPy · DuckDB · dbt · SQL · Plotly · Power BI · Docker · Jupyter · Great Expectations*

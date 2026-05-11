# Notivo Analytics Platform — Architecture Documentation

## Design Principles

1. **Metric definitions are code.** All KPIs live in `src/metrics/kpi_calculator.py` and `docs/metric_dictionary.md`. Never define a metric in a notebook without first defining it in code.

2. **Data quality is not optional.** The validation layer runs before every pipeline execution. No downstream model should consume data that hasn't passed quality checks.

3. **The transformation layer owns business logic.** SQL in dbt handles `WHERE`, `JOIN`, and aggregation logic. Python handles calculation, visualization, and ML. Never mix these.

4. **Staging → Intermediate → Mart.** Raw data is never queried directly in dashboards. Every dashboard query runs against a mart model.

5. **Every analysis is reproducible.** Notebooks, SQL files, and Python modules are version-controlled. Any analysis can be reproduced exactly by re-running from source.

---

## Data Flow

```
Source Systems                  Pipeline                    Consumers
──────────────                  ────────                    ─────────
Product DB ──────┐
                 │
Billing (Stripe) ─┤──► Ingestion ──► DuckDB/PG ──► dbt ──► Notebooks
                 │    (Python)        (Raw)         (SQL)    Dashboards
Marketing ───────┤                                           APIs
                 │                                           Alerts
Support ─────────┘

                              │
                         Validation
                         (DQ checks)
                              │
                         ┌────▼────┐
                         │ Staging │ ← cleaned, typed, filtered
                         └────┬────┘
                              │
                         ┌────▼──────────┐
                         │ Intermediate  │ ← business logic joins
                         └────┬──────────┘
                              │
                         ┌────▼────┐
                         │  Marts  │ ← aggregated, ready for use
                         └─────────┘
```

---

## Technology Decisions

### DuckDB for Local Development

**Why:** In-process OLAP database. No server setup. Runs SQL on CSV files directly. Fast enough for 10M+ row datasets on a laptop. Swappable for Snowflake/BigQuery with one dbt profile change.

**When to upgrade:** When raw data exceeds 50GB or requires concurrent multi-user access.

### dbt for Transformations

**Why:** SQL version control. Built-in testing (not_null, unique, referential integrity). Documentation auto-generation. Column-level lineage. The industry standard at modern data companies.

**Alternative considered:** SQLMesh. Rejected: smaller ecosystem, higher learning curve for new analysts joining.

### Modular Python over Monolithic Notebooks

**Why:** Production analytics must be testable and schedulable. A function in `src/metrics/` can be:
- Unit tested
- Imported by multiple notebooks
- Scheduled in Airflow
- Called by a Streamlit dashboard

A monolithic notebook can do none of these without refactoring.

---

## Scalability Path

| Current (Local Dev) | Scale-Out (Production) |
|---|---|
| DuckDB | Snowflake or BigQuery |
| CSV files in data/ | S3 / GCS with Parquet |
| Manual notebook runs | Airflow DAG scheduled runs |
| Streamlit local | Streamlit Cloud or internal VPC |
| dbt Core | dbt Cloud with CI/CD |
| No lineage | dbt + Atlan or DataHub |

The code is structured so that moving from local to production requires only:
1. Update `dbt/profiles.yml` to point to Snowflake/BigQuery
2. Update `src/ingestion/` to pull from S3/GCS instead of local CSV
3. Deploy Airflow DAGs (already defined in `dags/` structure)

No application code changes required.

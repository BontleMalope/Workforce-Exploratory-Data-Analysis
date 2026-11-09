# Mega Supermart | Workforce EDA

An end-to-end analysis of an anonymised employee dataset for a fictional retail chain. The project covers data cleaning in PostgreSQL, an EDA report, and an interactive Power BI dashboard, focused on **workforce composition, tenure and 2025 absence patterns**.

![Power BI dashboard](images/dashboard_preview.png)

## Dataset

- 1,200 employee records (1,198 distinct IDs), 17 columns
- 11 stores, 11 cities, 4 provinces
- 2,224,144 scheduled hours and 55,984 absent hours in 2025

## Tools

PostgreSQL (cleaning view, helper function, statistical queries), Power BI (data model, DAX, dashboard)

## Method

Raw data was cleaned in a PostgreSQL view (`employee_data_clean`): whitespace trimmed, blanks set to `NULL`, department labels standardised, and the text-based absence rate converted to numeric.

Absence is reported as a **weighted rate**, which weights each record by its scheduled hours instead of averaging percentages:

```
weighted absence rate = SUM(absent_hours) / SUM(scheduled_hours_2025)
```

```DAX
Overall Absence Rate =
DIVIDE(SUM(employee_clean[AbsentHours]), SUM(employee_clean[ScheduledHours2025]), 0)
```

## Key Findings

- **Overall weighted absence rate: 2.52%**
- **Customer Service** has the highest department rate (3.38%); **Sales** is the largest department (445 records)
- **ST10 (Regina)** has the highest store rate (5.09%); the lowest is ST01 (Calgary) at 2.22%
- **Part-time** absence (3.75%) is higher than **full-time** (2.22%)
- Average age is 38.6 and average tenure is 4.54 years; 247 records have under one year of service

These are signals for further review. The data is a single snapshot and does not explain *why* absence differs.

## Data Quality

- 2 Employee IDs appear on 4 rows (flagged, not deleted)
- Missing values: 3 gender, 2 absent hours, 2 supplied absence rate
- Inconsistent department labels (e.g. `sales` vs `Sales`)
- Maximum absent hours of 720 flagged for validation

## Repository Structure

```
├── README.md
├── data/        # source CSV
├── sql/         # table, cleaning view, EDA queries
├── report/      # EDA report (PDF)
├── powerbi/     # dashboard (.pbix)
└── images/      # dashboard preview
```

## Author

**Bontle Malope**, Data Analyst, Johannesburg
[LinkedIn](https://www.linkedin.com/) | [GitHub](https://github.com/)

# HCC Recapture Gap Analysis (SQL)

## Overview
This project analyzes patient claims data to identify **HCC (Hierarchical Condition Category) recapture gaps** — chronic conditions documented in one year but missing from the patient's claims in the following year. This is a real risk-adjustment problem: chronic conditions don't disappear, so a missing diagnosis code the next year usually means the condition wasn't re-documented, which understates the patient's risk score.

Built using PostgreSQL, on a small hand-built synthetic dataset (10 patients, 3 chronic/non-chronic conditions, 22 claims across 2024-2025), designed to demonstrate the query logic end to end.

> **Note:** This uses synthetic, self-generated data for demonstration purposes only — not real patient data.

## Business Question
Which patients had a chronic condition (diabetes, hyperlipidemia) documented in 2024, but no matching diagnosis code for that same condition in 2025?

## Schema

**`patients`**
| Column | Type | Description |
|---|---|---|
| patient_id | VARCHAR | Primary key (P01, P02...) |
| name | TEXT | Patient name |
| age | INTEGER | Patient age |
| gender | TEXT | M / F |

**`diagnosis_reference`**
| Column | Type | Description |
|---|---|---|
| diagnosis_code | VARCHAR | ICD-10 code |
| diagnosis_name | TEXT | Description |
| chronic_flag | INTEGER | 1 = chronic (expected to recur yearly), 0 = not tracked as chronic |

**`claims`**
| Column | Type | Description |
|---|---|---|
| claims_id | VARCHAR | Primary key |
| patient_id | VARCHAR | Foreign key -> patients |
| diagnosis_code | TEXT | Foreign key -> diagnosis_reference |
| claims_year | INTEGER | 2024 or 2025 |

## Approach

1. **Join claims to diagnosis reference** to tag each claim as chronic or not.
2. **Filter to chronic conditions** (`chronic_flag = 1`) and split into two sets: patients with the condition in 2024, and patients with the condition in 2025.
3. **LEFT JOIN 2024 set to 2025 set** on `patient_id` + `diagnosis_code`. A `NULL` match in the 2025 side means the patient did not recapture that condition — a gap.
4. **CASE WHEN** converts the NULL into a clean `gap` flag (1 = gap, 0 = recaptured).
5. **Aggregate** to count gaps per diagnosis, and join back to `patients` to bring in demographic context for reporting.

## Key Query (gap detection)

```sql
CREATE VIEW patient_gaps AS
SELECT
  y1.patient_id,
  y1.diagnosis_code,
  CASE WHEN y2.patient_id IS NULL THEN 1 ELSE 0 END AS gap
FROM
  (SELECT DISTINCT c.patient_id, c.diagnosis_code
   FROM claims c
   JOIN diagnosis_reference d ON c.diagnosis_code = d.diagnosis_code
   WHERE d.chronic_flag = 1 AND c.claims_year = 2024) AS y1
LEFT JOIN
  (SELECT DISTINCT c.patient_id, c.diagnosis_code
   FROM claims c
   JOIN diagnosis_reference d ON c.diagnosis_code = d.diagnosis_code
   WHERE d.chronic_flag = 1 AND c.claims_year = 2025) AS y2
  ON y1.patient_id = y2.patient_id AND y1.diagnosis_code = y2.diagnosis_code;
```

Full SQL (table creation, inserts, and all queries) is in [`hcc_gap_analysis.sql`](./hcc_gap_analysis.sql).

## Findings (on this demo dataset)

- Out of 9 patient-condition pairs tracked across 2024, **2 showed a recapture gap** (~22%) — one for Hyperlipidemia (E78.5), one for Diabetes (E11.9).
- The remaining patients had their chronic condition properly recaptured in 2025.
- At this scale the result is illustrative; the same query structure scales directly to real claims volumes, where even small gap rates translate into meaningful under-documented risk.

## Tools
- PostgreSQL (psql)
- SQL: JOIN, LEFT JOIN, CASE WHEN, DISTINCT, GROUP BY, VIEW

## Background
Built by a certified HCC medical coder (ICD-10-CM, CMS risk adjustment) transitioning into healthcare data analytics — the business logic here mirrors real recapture-gap analysis used by risk adjustment teams.

## Next Steps
- Expand dataset volume and condition variety
- Build a Power BI dashboard on top of `patient_gaps`
- Extend into a predictive model (logistic regression / random forest) to flag patients likely to have a gap *before* it occurs, using features like age, condition count, and claim frequency

-- =========================================================
-- HCC Recapture Gap Analysis
-- Synthetic demo dataset — not real patient data
-- =========================================================

-- ---------------------------------------------------------
-- 1. TABLE CREATION
-- ---------------------------------------------------------

CREATE TABLE patients (
  patient_id VARCHAR PRIMARY KEY,
  name TEXT,
  age INTEGER,
  gender TEXT
);

CREATE TABLE diagnosis_reference (
  diagnosis_code VARCHAR,
  diagnosis_name TEXT,
  chronic_flag INTEGER
);

CREATE TABLE claims (
  claims_id VARCHAR PRIMARY KEY,
  patient_id VARCHAR,
  diagnosis_code VARCHAR,
  claims_year INTEGER
);

-- ---------------------------------------------------------
-- 2. DATA
-- ---------------------------------------------------------

INSERT INTO patients VALUES
('P01', 'Ravikumar',   55, 'M'),
('P02', 'Saravanan',   45, 'M'),
('P03', 'Raja',        44, 'M'),
('P04', 'Pavalamalli', 66, 'F'),
('P05', 'Santhosh',    55, 'M'),
('P06', 'Sankaran',    65, 'M'),
('P07', 'Kandhi',      35, 'M'),
('P08', 'Devika',      55, 'F'),
('P09', 'Savithri',    26, 'F'),
('P10', 'Kearan Page', 66, 'F');

INSERT INTO diagnosis_reference VALUES
('E11.9', 'Diabetes Mellitus', 1),
('I10',   'Hypertension',      0),
('E78.5', 'Hyperlipidemia',    1);

INSERT INTO claims VALUES
('100', 'P01', 'E11.9', 2024),
('101', 'P01', 'E11.9', 2025),
('103', 'P01', 'I10',   2024),
('104', 'P02', 'E78.5', 2024),
('105', 'P02', 'E11.9', 2025),
('106', 'P03', 'E11.9', 2024),
('107', 'P03', 'E11.9', 2025),
('108', 'P03', 'I10',   2025),
('109', 'P04', 'E78.5', 2024),
('110', 'P04', 'E78.5', 2025),
('111', 'P06', 'E78.5', 2025),
('112', 'P06', 'E11.9', 2024),
('113', 'P06', 'E11.9', 2025),
('114', 'P07', 'E11.9', 2024),
('115', 'P07', 'E78.5', 2024),
('116', 'P07', 'E11.9', 2025),
('117', 'P07', 'E11.9', 2024),
('118', 'P07', 'E78.5', 2025),
('119', 'P08', 'E11.9', 2024),
('120', 'P08', 'E11.9', 2025),
('121', 'P08', 'I10',   2024),
('122', 'P09', 'I10',   2024);

-- ---------------------------------------------------------
-- 3. STEP 1 — Tag claims with chronic_flag
-- ---------------------------------------------------------

SELECT c.patient_id, c.diagnosis_code, c.claims_year, d.chronic_flag
FROM claims c
JOIN diagnosis_reference d ON c.diagnosis_code = d.diagnosis_code;

-- ---------------------------------------------------------
-- 4. STEP 2 — Chronic conditions by year (building blocks)
-- ---------------------------------------------------------

-- Patients with a chronic condition in 2024
SELECT DISTINCT c.patient_id, c.diagnosis_code
FROM claims c
JOIN diagnosis_reference d ON c.diagnosis_code = d.diagnosis_code
WHERE d.chronic_flag = 1 AND c.claims_year = 2024;

-- Patients with a chronic condition in 2025
SELECT DISTINCT c.patient_id, c.diagnosis_code
FROM claims c
JOIN diagnosis_reference d ON c.diagnosis_code = d.diagnosis_code
WHERE d.chronic_flag = 1 AND c.claims_year = 2025;

-- ---------------------------------------------------------
-- 5. STEP 3 — Gap detection query (LEFT JOIN + CASE WHEN)
-- ---------------------------------------------------------

SELECT
  y1.patient_id,
  y1.diagnosis_code,
  CASE
    WHEN y2.patient_id IS NULL THEN 1
    ELSE 0
  END AS gap
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

-- ---------------------------------------------------------
-- 6. STEP 4 — Save as a reusable view
-- ---------------------------------------------------------

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

-- ---------------------------------------------------------
-- 7. STEP 5 — Aggregate: gap count per diagnosis
-- ---------------------------------------------------------

SELECT
  y1.diagnosis_code,
  COUNT(*) FILTER (WHERE y2.patient_id IS NULL) AS gap_count,
  COUNT(*) AS total_patients_2024
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
  ON y1.patient_id = y2.patient_id AND y1.diagnosis_code = y2.diagnosis_code
GROUP BY y1.diagnosis_code
ORDER BY gap_count DESC;

-- ---------------------------------------------------------
-- 8. STEP 6 — Join gaps back to patient demographics
-- ---------------------------------------------------------

SELECT p.patient_id, p.name, p.age, p.gender, g.diagnosis_code, g.gap
FROM patient_gaps g
JOIN patients p ON g.patient_id = p.patient_id
ORDER BY g.gap DESC;

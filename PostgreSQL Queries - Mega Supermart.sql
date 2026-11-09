CREATE TABLE employee_data_recovery (
    employeeid VARCHAR(20),
    storeid VARCHAR(10),
    city VARCHAR(100),
    province VARCHAR(100),
    businessunit VARCHAR(100),
    division VARCHAR(100),
    department VARCHAR(100),
    jobtitle VARCHAR(150),
    gender VARCHAR(30),
    birthdate DATE,
    hiredate DATE,
    ageyears INTEGER,
    lengthofserviceyears NUMERIC(5,2),
    employmenttype VARCHAR(50),
    scheduledhours2025 INTEGER,
    absenthours NUMERIC(10,2),
    absencerate VARCHAR(10)
);


--Checking any missing values or rows
SELECT COUNT(*) AS source_rows
FROM employee_data_recovery;

SELECT COUNT(*) 
FROM employee_data_recovery


--Checking duplicates using the employeeid
SELECT 
     employeeid,
     COUNT(*) AS duplicate_count
FROM employee_data_recovery
GROUP BY employeeid
HAVING COUNT(*) > 1;

	 
SELECT *
FROM employee_data_recovery
WHERE employeeid IN ('ACE01142', 'ACE01153');


SELECT
  COUNT(*) - COUNT(DISTINCT employeeid) AS duplicate_id_excess_rows,
  COUNT(DISTINCT employeeid) AS distinct_employee_ids
FROM employee_data_recovery;

--Checking if there are exact duplicates
SELECT COUNT(*) AS exact_duplicate_rows
FROM (
  SELECT *, COUNT(*) OVER (
    PARTITION BY employeeid, storeid, city, province, businessunit, division,
                 department, jobtitle, gender, birthdate, hiredate, ageyears,
                 lengthofserviceyears, employmenttype, scheduledhours2025,
                 absenthours, absencerate
  ) AS copies
  FROM employee_data_recovery
) d
WHERE copies > 1;




--Checking missing values from the data
SELECT
    COUNT(*) FILTER (
        WHERE employeeid IS NULL OR BTRIM(employeeid::text) = ''
    ) AS missing_employee_id,
    
    COUNT(*) FILTER (
        WHERE gender IS NULL OR BTRIM(gender) = ''
    ) AS missing_gender,
    
    COUNT(*) FILTER (
        WHERE absenthours IS NULL
    ) AS missing_absent_hours,
    
    COUNT(*) FILTER (
        WHERE absencerate IS NULL
    ) AS missing_absence_rate
FROM employee_data_recovery;
CREATE OR REPLACE FUNCTION safe_num(t text) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN NULLIF(REPLACE(REPLACE(BTRIM(t), '%', ''), ',', '.'), '')::numeric;
EXCEPTION WHEN others THEN RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION safe_date(t text) RETURNS date
LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN TO_DATE(NULLIF(REGEXP_REPLACE(BTRIM(t), 'sept', 'Sep', 'i'), ''), 'DD Mon YYYY');
EXCEPTION WHEN others THEN RETURN NULL;
END $$;

-- The view
--creating the safe_num function
CREATE OR REPLACE FUNCTION safe_num(t text) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN NULLIF(REPLACE(REPLACE(BTRIM(t), '%', ''), ',', '.'), '')::numeric;
EXCEPTION WHEN others THEN RETURN NULL;
END $$;



CREATE OR REPLACE VIEW employee_data_clean AS
SELECT
  NULLIF(BTRIM(employeeid), '')           AS employee_id,
  NULLIF(BTRIM(storeid), '')              AS store_id,
  NULLIF(BTRIM(city), '')                 AS city,
  NULLIF(BTRIM(province), '')             AS province,
  NULLIF(BTRIM(businessunit), '')         AS business_unit,
  NULLIF(BTRIM(division), '')             AS division,
  INITCAP(NULLIF(BTRIM(department), ''))  AS department,
  NULLIF(BTRIM(jobtitle), '')             AS job_title,
  NULLIF(BTRIM(gender), '')               AS gender,
  birthdate                               AS birth_date,
  hiredate                                AS hire_date,
  ageyears                                AS age_years,
  lengthofserviceyears                    AS length_of_service_years,
  NULLIF(BTRIM(employmenttype), '')       AS employment_type,
  scheduledhours2025                      AS scheduled_hours_2025,
  absenthours                             AS absent_hours,
  safe_num(absencerate)                   AS supplied_absence_rate_pct,
  100.0 * absenthours / NULLIF(scheduledhours2025, 0) AS calculated_absence_rate_pct
FROM employee_data_recovery;

SELECT absencerate
FROM employee_data_recovery
WHERE NULLIF(BTRIM(absencerate), '') IS NOT NULL
  AND safe_num(absencerate) IS NULL;



-- 4. Descriptive statistics- Thisc code calculates the average, the middle value (median), the lowest and the highest
SELECT
  COUNT(*) AS records,
  ROUND(AVG(age_years), 2) AS mean_age,
  ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY age_years))::numeric, 2) AS median_age,
  MIN(age_years) AS min_age,
  MAX(age_years) AS max_age,
  ROUND(AVG(length_of_service_years), 2) AS mean_tenure,
  ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY length_of_service_years))::numeric, 2) AS median_tenure,
  MIN(length_of_service_years) AS min_tenure,
  MAX(length_of_service_years) AS max_tenure,
  ROUND(AVG(scheduled_hours_2025), 2) AS mean_scheduled_hours,
  ROUND(AVG(absent_hours), 2) AS mean_absent_hours,
  ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY absent_hours))::numeric, 2) AS median_absent_hours,
  MIN(absent_hours) AS min_absent_hours,
  MAX(absent_hours) AS max_absent_hours
FROM public.employee_data_clean;


-- Overall weighted absence rate
SELECT
  SUM(absent_hours) AS total_absent_hours,
  SUM(scheduled_hours_2025) AS total_scheduled_hours,
  ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
    AS weighted_absence_rate_pct
FROM public.employee_data_clean;


-- 5. Workforce composition: run each query for bar charts / frequency tables
SELECT department, COUNT(*) AS employees
FROM public.employee_data_clean GROUP BY department ORDER BY employees DESC;

SELECT job_title, COUNT(*) AS employees
FROM public.employee_data_clean GROUP BY job_title ORDER BY employees DESC;

SELECT city, store_id, COUNT(*) AS employees
FROM public.employee_data_clean GROUP BY city, store_id ORDER BY employees DESC;

SELECT business_unit, COUNT(*) AS employees
FROM public.employee_data_clean GROUP BY business_unit ORDER BY employees DESC;

SELECT division, COUNT(*) AS employees
FROM public.employee_data_clean GROUP BY division ORDER BY employees DESC;

SELECT gender, COUNT(*) AS employees
FROM public.employee_data_clean GROUP BY gender ORDER BY employees DESC NULLS LAST;

SELECT employment_type, COUNT(*) AS employees
FROM public.employee_data_clean GROUP BY employment_type ORDER BY employees DESC;




-- 6. Age and tenure profile
SELECT
  CASE
    WHEN age_years < 30 THEN '18–29'
    WHEN age_years < 40 THEN '30–39'
    WHEN age_years < 50 THEN '40–49'
    WHEN age_years < 60 THEN '50–59'
    ELSE '60+'
  END AS age_band,
  COUNT(*) AS employees,
  ROUND(AVG(age_years), 1) AS average_age,
  ROUND(AVG(length_of_service_years), 2) AS average_tenure
FROM public.employee_data_clean
GROUP BY age_band
ORDER BY MIN(age_years);


SELECT
  CASE
    WHEN length_of_service_years < 1 THEN '<1 year'
    WHEN length_of_service_years < 3 THEN '1–3 years'
    WHEN length_of_service_years < 5 THEN '3–5 years'
    WHEN length_of_service_years < 10 THEN '5–10 years'
    ELSE '10+ years'
  END AS tenure_band,
  COUNT(*) AS employees,
  ROUND(AVG(age_years), 1) AS average_age,
  ROUND(AVG(absent_hours), 1) AS average_absent_hours,
  ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
    AS weighted_absence_rate_pct
FROM public.employee_data_clean
GROUP BY tenure_band
ORDER BY MIN(length_of_service_years);

SELECT department, COUNT(*) AS employees,
       ROUND(AVG(age_years), 1) AS average_age,
       ROUND(AVG(length_of_service_years), 2) AS average_tenure
FROM public.employee_data_clean
GROUP BY department ORDER BY average_tenure DESC;


-- Planning cohorts (not retirement predictions)
SELECT
  COUNT(*) FILTER (WHERE age_years >= 55) AS employees_age_55_plus,
  COUNT(*) FILTER (WHERE length_of_service_years < 1) AS employees_under_1_year
FROM public.employee_data_clean;




-- 7. Absenteeism comparisons (use weighted rates for fairer group comparisons)
SELECT department, COUNT(*) AS employees,
       ROUND(AVG(absent_hours), 1) AS mean_absent_hours,
       ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
         AS weighted_absence_rate_pct
FROM public.employee_data_clean
GROUP BY department ORDER BY weighted_absence_rate_pct DESC;

SELECT store_id, city, COUNT(*) AS employees,
       ROUND(SUM(absent_hours), 1) AS absent_hours,
       ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
         AS weighted_absence_rate_pct
FROM public.employee_data_clean
GROUP BY store_id, city ORDER BY weighted_absence_rate_pct DESC;

SELECT job_title, COUNT(*) AS employees,
       ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
         AS weighted_absence_rate_pct
FROM public.employee_data_clean
GROUP BY job_title
HAVING COUNT(*) >= 5
ORDER BY weighted_absence_rate_pct DESC;

SELECT gender, COUNT(*) AS employees,
       ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
         AS weighted_absence_rate_pct
FROM public.employee_data_clean
GROUP BY gender ORDER BY weighted_absence_rate_pct DESC NULLS LAST;

SELECT employment_type, COUNT(*) AS employees,
       ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
         AS weighted_absence_rate_pct
FROM public.employee_data_clean
GROUP BY employment_type ORDER BY weighted_absence_rate_pct DESC;


-- Absence by age band
SELECT
  CASE
    WHEN age_years < 30 THEN '18–29'
    WHEN age_years < 40 THEN '30–39'
    WHEN age_years < 50 THEN '40–49'
    WHEN age_years < 60 THEN '50–59'
    ELSE '60+'
  END AS age_band,
  COUNT(*) AS employees,
  ROUND(100.0 * SUM(absent_hours) / NULLIF(SUM(scheduled_hours_2025), 0), 2)
    AS weighted_absence_rate_pct
FROM public.employee_data_clean
GROUP BY age_band ORDER BY MIN(age_years);



-- 8. Outliers / anomalies
SELECT employee_id, store_id, city, department, job_title,
       absent_hours, scheduled_hours_2025, calculated_absence_rate_pct
FROM public.employee_data_clean
WHERE absent_hours > 200
   OR calculated_absence_rate_pct > 10
ORDER BY absent_hours DESC NULLS LAST;

SELECT *
FROM public.employee_data_clean
WHERE scheduled_hours_2025 < 0 OR absent_hours < 0
   OR absent_hours > scheduled_hours_2025
   OR age_years < 16 OR age_years > 100
   OR length_of_service_years < 0;


-- Compare supplied absence rate with calculated rate (rounding / source discrepancies)

SELECT
  employee_id,
  supplied_absence_rate_pct,
  ROUND(calculated_absence_rate_pct, 2) AS calculated_absence_rate_pct,
  ROUND(ABS(supplied_absence_rate_pct - calculated_absence_rate_pct), 2) AS difference_pct_points
FROM public.employee_data_clean
WHERE supplied_absence_rate_pct IS NOT NULL
  AND calculated_absence_rate_pct IS NOT NULL
  AND ABS(supplied_absence_rate_pct - calculated_absence_rate_pct) > 0.15
ORDER BY difference_pct_points DESC;


SELECT
  COUNT(*)                          AS total_rows,
  COUNT(supplied_absence_rate_pct)  AS with_supplied_rate,
  COUNT(calculated_absence_rate_pct) AS with_calculated_rate,
  ROUND(MAX(ABS(supplied_absence_rate_pct - calculated_absence_rate_pct)), 3) AS max_difference
FROM public.employee_data_clean;



SELECT COUNT(*) AS total,
       COUNT(supplied_absence_rate_pct) AS with_supplied_rate
FROM public.employee_data_clean;


-- 9. Correlations (Pearson; descriptive only)
-- PostgreSQL does not include CORR in every hosted configuration, but standard PostgreSQL supports it.
SELECT
  CORR(age_years, absent_hours) AS corr_age_absent_hours,
  CORR(length_of_service_years, absent_hours) AS corr_tenure_absent_hours,
  CORR(age_years, length_of_service_years) AS corr_age_tenure,
  CORR(scheduled_hours_2025, absent_hours) AS corr_scheduled_absent
FROM public.employee_data_clean;





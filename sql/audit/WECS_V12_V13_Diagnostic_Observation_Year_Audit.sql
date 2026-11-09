-- Read-only V12/V13 diagnostic test coverage by calendar year.
-- Runs in Supabase SQL editor. Aggregate only; no animal-level export.
-- This counts test rows and tested capture events, not infection prevalence.
-- Uses raw research tests; no conflation of negative with missing/not tested.
WITH culture_year AS (
 SELECT EXTRACT(YEAR FROM c.capture_date)::int AS year,
        count(*) AS n_culture_rows,
        count(DISTINCT cu.capture_id) AS capture_events_with_culture,
        count(*) FILTER (WHERE upper(trim(cu.culture_result))='M.BOVIS') AS m_bovis_rows,
        count(*) FILTER (WHERE upper(trim(cu.culture_result))='NEGATIVE') AS negative_rows,
        count(*) FILTER (WHERE cu.culture_result IS NULL OR
                               upper(trim(cu.culture_result)) NOT IN ('M.BOVIS','NEGATIVE')) AS other_unresolved_rows
 FROM research.cultures cu
 JOIN research.captures c ON c.capture_id=cu.capture_id
 WHERE c.capture_date IS NOT NULL
 GROUP BY 1
), dpp_year AS (
 SELECT EXTRACT(YEAR FROM c.capture_date)::int AS year,
        count(*) AS n_dpp_rows,
        count(DISTINCT dpp.capture_id) AS capture_events_with_dpp,
        count(*) FILTER (WHERE dpp.test_result IS NULL) AS dpp_missing_results
 FROM research.dpp_tests dpp
 JOIN research.captures c ON c.capture_id=dpp.capture_id
 WHERE c.capture_date IS NOT NULL
 GROUP BY 1
), capture_year AS (
 SELECT EXTRACT(YEAR FROM capture_date)::int AS year,
        count(*) AS all_capture_pm_rows,
        count(*) FILTER (WHERE is_pm = false) AS non_pm_capture_rows,
        count(*) FILTER (WHERE is_pm = true) AS pm_rows
 FROM research.captures
 WHERE capture_date IS NOT NULL
 GROUP BY 1
)
SELECT c.year,c.all_capture_pm_rows,c.non_pm_capture_rows,c.pm_rows,
       coalesce(cu.n_culture_rows,0) AS n_culture_rows,
       coalesce(cu.capture_events_with_culture,0) AS capture_events_with_culture,
       coalesce(cu.m_bovis_rows,0) AS m_bovis_culture_rows,
       coalesce(cu.negative_rows,0) AS negative_culture_rows,
       coalesce(cu.other_unresolved_rows,0) AS other_unresolved_culture_rows,
       coalesce(dp.n_dpp_rows,0) AS n_dpp_rows,
       coalesce(dp.capture_events_with_dpp,0) AS capture_events_with_dpp,
       coalesce(dp.dpp_missing_results,0) AS dpp_missing_results
FROM capture_year c
LEFT JOIN culture_year cu USING (year)
LEFT JOIN dpp_year dp USING (year)
ORDER BY c.year;
-- Interpretation: repeated cultures can belong to one capture event.
-- A row can be PM; culture-positive is NOT equal to animal infectiousness.
-- DPP result strings are not automatically classified positive/negative.
-- Diagnostic testing availability may vary by year; positive-only histories
-- cannot establish capture effort or annual pathogen persistence by themselves.

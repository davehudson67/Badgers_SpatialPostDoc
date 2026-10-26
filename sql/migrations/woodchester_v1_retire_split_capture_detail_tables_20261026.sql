-- Drop former 1:1 capture-detail tables after rebuilding and testing dependent analysis.capture_history.
-- All historical observation values were previously consolidated in research.captures;
-- raw originals continue to live in access_raw.tbl_captures.
DROP TABLE research.capture_sampling;
DROP TABLE research.capture_assessments;
DROP TABLE research.capture_collars;
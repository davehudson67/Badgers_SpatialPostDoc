-- Woodchester tattoo 040l / 040L reconciliation; 2026-10-28
-- NON-DESTRUCTIVE. Preserves access_raw original strings.
-- Four access_raw.tbl_culture records (raw_row_id 11480-11483), all on
-- 2011-01-25, contain 040l; other records use 040L. They already
-- link via research.cultures.capture_id -> research.captures to
-- research.individuals.individual_id=792, tattoo='040L'.
-- This script asserts the mapping rather than rewriting raw records.
DO $$
DECLARE n_raw integer; n_linked integer; n_bad_id integer;
BEGIN
 SELECT count(*) INTO n_raw FROM access_raw.tbl_culture
 WHERE tattoo='040l' AND raw_row_id IN (11480,11481,11482,11483);
 IF n_raw <> 4 THEN RAISE EXCEPTION 'Expected four original 040l culture rows, got %',n_raw; END IF;
 SELECT count(*) INTO n_linked
 FROM research.cultures cu
 JOIN research.captures c ON c.capture_id=cu.capture_id
 JOIN research.individuals i ON i.individual_id=c.individual_id
 WHERE i.tattoo='040L' AND c.capture_date=DATE '2011-01-25';
 IF n_linked <> 4 THEN RAISE EXCEPTION 'Expected four linked cultures for 040L on 2011-01-25, got %',n_linked; END IF;
 SELECT count(*) INTO n_bad_id FROM research.individuals
 WHERE lower(tattoo)='040l' AND tattoo <> '040L';
 IF n_bad_id <> 0 THEN RAISE EXCEPTION 'Unexpected unstandardised individual tattoo count %',n_bad_id; END IF;
END $$;
-- When using original raw tattoo text for joins, apply
-- upper(trim(tattoo)) = '040L' (case-only equivalence) and retain original text.
-- Do NOT remove the leading zero, rewrite access_raw, or merge other IDs.

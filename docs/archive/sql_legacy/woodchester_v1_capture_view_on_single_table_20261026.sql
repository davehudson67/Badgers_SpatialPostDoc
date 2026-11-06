-- Replace obsolete 1:1 capture detail joins with columns stored on research.captures.
DO $$
DECLARE v text;
BEGIN
v:=pg_get_viewdef('analysis.capture_history'::regclass,true);
v:=replace(v,'cs.notes AS sampling_notes','c.sampling_notes AS sampling_notes');
v:=replace(v,'cc.transmitter AS collar_transmitter','c.collar_transmitter AS collar_transmitter');
v:=replace(v,'cs.','c.');
v:=replace(v,'ca.','c.');
v:=replace(v,'cc.','c.');
v:=replace(v,'LEFT JOIN research.capture_sampling cs ON c.capture_id = c.capture_id','');
v:=replace(v,'LEFT JOIN research.capture_assessments ca ON c.capture_id = c.capture_id','');
v:=replace(v,'LEFT JOIN research.capture_collars cc ON c.capture_id = c.capture_id','');
EXECUTE 'CREATE OR REPLACE VIEW analysis.capture_history AS ' || v;
END $$;
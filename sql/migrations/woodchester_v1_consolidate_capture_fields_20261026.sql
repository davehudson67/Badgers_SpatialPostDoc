-- Restore Access-like capture columns while retaining compatibility tables.
DO $$
DECLARE src text; col record; target_col text; source_expr text;
BEGIN
 FOREACH src IN ARRAY ARRAY['capture_sampling','capture_assessments','capture_collars'] LOOP
  FOR col IN SELECT column_name,data_type,udt_name FROM information_schema.columns
   WHERE table_schema='research' AND table_name=src
     AND column_name NOT IN ('capture_id','created_at','capture_sampling_id','capture_assessment_id','capture_collar_id')
   ORDER BY ordinal_position LOOP
   target_col := CASE WHEN src='capture_sampling' AND col.column_name='notes' THEN 'sampling_notes'
                      WHEN src='capture_collars' AND col.column_name='transmitter' THEN 'collar_transmitter'
                      ELSE col.column_name END;
   IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='research' AND table_name='captures' AND column_name=target_col) THEN
     EXECUTE format('ALTER TABLE research.captures ADD COLUMN %I %s',target_col,
       CASE WHEN col.data_type='USER-DEFINED' THEN format('%I',col.udt_name)
       WHEN col.data_type='ARRAY' THEN format('%I[]',trim(leading '_' from col.udt_name))
       ELSE col.data_type END);
   END IF;
   EXECUTE format('UPDATE research.captures c SET %I=s.%I FROM research.%I s WHERE c.capture_id=s.capture_id AND c.%I IS DISTINCT FROM s.%I',
      target_col,col.column_name,src,target_col,col.column_name);
  END LOOP;
 END LOOP;
END $$;
comment on table research.captures is 'V1 Access-like single capture table: original encounter fields, sampling/assessment/collar fields restored from one-to-one source-linked legacy research tables, plus documented *_clean fields. Historical split tables retained internally for compatibility until dependency audit.';

-- WECS collaborator read-only access, applied 2026-11-04.
-- AFTER 20261104_wecs_curated_v1_snapshot.sql. Curated analysis views expose
-- selected fields through view-owner rights, without requiring collaborators
-- to have direct access to the original Access-derived records.
grant usage on schema analysis to badger_readonly,badger_research_readonly;
alter view analysis.encounters_clean_v1 set (security_invoker=false);
alter view analysis.mortality_events_review_v1 set (security_invoker=false);
alter view analysis.wecs_review_flags_v1 set (security_invoker=false);
alter view analysis.capture_sett_alias_audit_v1 set (security_invoker=false);
grant select on analysis.encounters_clean_v1,analysis.mortality_events_review_v1,
analysis.wecs_review_flags_v1,analysis.capture_sett_alias_audit_v1
to badger_readonly,badger_research_readonly;
revoke insert,update,delete,truncate,references,trigger on
analysis.encounters_clean_v1,analysis.mortality_events_review_v1,
analysis.wecs_review_flags_v1,analysis.capture_sett_alias_audit_v1
from badger_readonly,badger_research_readonly;

grant usage on schema research to badger_research_readonly;
grant select on research.encounter_episode_decisions,
research.encounter_pair_nonlinks,research.encounter_classification_decisions,
research.capture_sett_alias_decisions,research.wecs_review_flags
to badger_research_readonly;
do $$
declare t text;
begin
 foreach t in array array['encounter_episode_decisions','encounter_pair_nonlinks',
 'encounter_classification_decisions','capture_sett_alias_decisions','wecs_review_flags']
 loop
 execute format('drop policy if exists badger_research_readonly_select on research.%I',t);
 execute format('create policy badger_research_readonly_select on research.%I for select to badger_research_readonly using (true)',t);
 end loop;
end $$;
-- Verify with has_table_privilege and a real collaborator-session SELECT.

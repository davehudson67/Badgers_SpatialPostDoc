-- Applied 2026-10-16 to the Woodchester Supabase project.
-- Advanced read-only role for canonical research tables.
-- Staging/import tables are deliberately excluded.

create role badger_research_readonly nologin;

grant connect on database postgres to badger_research_readonly;
grant usage on schema analysis to badger_research_readonly;
grant usage on schema research to badger_research_readonly;

grant select on
  analysis.capture_history,
  analysis.capture_infection_probabilities,
  analysis.diagnostic_results,
  analysis.historical_sett_candidates,
  analysis.infection_probabilities,
  analysis.infection_quarterly_probabilities,
  analysis.sett_social_group_observed
to badger_research_readonly;

grant select on
  research.individuals,
  research.individual_names,
  research.captures,
  research.capture_sampling,
  research.capture_assessments,
  research.capture_collars,
  research.wounds,
  research.cultures,
  research.ifn_gamma_elisa,
  research.dpp_tests,
  research.dpp_sample_types,
  research.dpp_visual_line_results,
  research.stat_pak_tests,
  research.stat_pak_results,
  research.elisa_tests,
  research.brock_tests,
  research.disease_statuses,
  research.setts,
  research.social_groups,
  research.supergroups,
  research.sett_social_group_history,
  research.social_group_supergroup_history,
  research.infection_probabilities,
  research.infection_quarterly_probabilities
to badger_research_readonly;

-- RLS SELECT policy is required because research tables have RLS enabled.
-- Apply the following pattern to each approved canonical table:
--
-- create policy badger_research_readonly_select
-- on research.<table>
-- for select
-- to badger_research_readonly
-- using (true);
--
-- Do not create this policy on staging/import tables.

revoke all on
  research.infection_probabilities_import,
  research.infection_quarterly_import
from badger_research_readonly;

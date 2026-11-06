-- WOODCHESTER: RECORDED APPLIED MIGRATIONS
-- Exported from Supabase migration history.
-- Source: supabase_migrations.schema_migrations
-- Project: klpvihubzlyzubyyubtw
-- Migrations: 73
-- IMPORTANT: AUDIT HISTORY, NOT A LIVE-DB UPDATE SCRIPT.
-- Do not replay against the existing production database.


-- ================================================
-- MIGRATION VERSION: 20261014114315
-- MIGRATION NAME: create_badger_readonly_role_v2
-- ================================================


create role badger_readonly nologin;

grant connect on database postgres to badger_readonly;
grant usage on schema analysis to badger_readonly;

grant select on
  analysis.capture_history,
  analysis.capture_infection_probabilities,
  analysis.diagnostic_results,
  analysis.historical_sett_candidates,
  analysis.infection_probabilities,
  analysis.infection_quarterly_probabilities,
  analysis.sett_social_group_observed
to badger_readonly;


-- ================================================
-- MIGRATION VERSION: 20261023122607
-- MIGRATION NAME: woodchester_standardisation_v1_20261023
-- ================================================

-- Versioned, non-destructive canonical interpretation v1.
-- Maintains raw Access records and typed canonical research records unchanged.
create or replace view analysis.individual_traits_standardised as
select i.tattoo, i.elect_tag,
       i.age_first_capture as age_first_capture_recorded,
       case when upper(btrim(coalesce(i.age_first_capture,''))) in ('CUB','YEARLING','ADULT')
            then upper(btrim(i.age_first_capture)) else 'UNKNOWN' end as age_first_capture_standardised,
       (i.age_first_capture is null) as age_first_capture_missing,
       i.year_first_capture,
       i.sex as sex_recorded,
       case when upper(btrim(coalesce(i.sex,''))) in ('MALE','FEMALE')
            then upper(btrim(i.sex)) else 'UNKNOWN' end as sex_standardised,
       (i.sex is null) as sex_missing
from research.individuals i;

create or replace view analysis.culture_results_standardised as
select i.tattoo, c.capture_id, cu.culture_id,
       c.capture_date, c.is_pm, cu.sample_type as sample_type_recorded,
       case when upper(btrim(coalesce(cu.sample_type,''))) in ('OA','TA','URINE','FAECES')
            then upper(btrim(cu.sample_type)) else 'OTHER' end as sample_group,
       cu.culture_result as culture_result_recorded,
       case
         when upper(btrim(coalesce(cu.culture_result,''))) = 'M.BOVIS' then 'M_BOVIS_DETECTED'
         when upper(btrim(coalesce(cu.culture_result,''))) = 'NEGATIVE' then 'NEGATIVE'
         when upper(btrim(coalesce(cu.culture_result,''))) in ('M.AVIUM','M.OTHER') then 'OTHER_ORGANISM'
         when upper(btrim(coalesce(cu.culture_result,''))) in ('FAILED','CONTAMINATED') then 'INVALID'
         when upper(btrim(coalesce(cu.culture_result,''))) = 'PENDING' then 'PENDING'
         when upper(btrim(coalesce(cu.culture_result,''))) = 'NOT TESTED' then 'NOT_TESTED'
         when nullif(btrim(coalesce(cu.culture_result,'')),'') is null then 'MISSING'
         else 'UNRECOGNISED'
       end as culture_result_status,
       case when upper(btrim(coalesce(cu.culture_result,'')))='M.BOVIS' then true
            when upper(btrim(coalesce(cu.culture_result,'')))='NEGATIVE' then false
            else null end as is_m_bovis_detected,
       cu.afno,cu.spoligo,cu.spolprime,cu.wgs_clade
from research.cultures cu
join research.captures c on c.capture_id=cu.capture_id
join research.individuals i on i.individual_id=c.individual_id;

grant select on analysis.individual_traits_standardised,analysis.culture_results_standardised to badger_readonly,badger_research_readonly;
comment on view analysis.individual_traits_standardised is 'Version 1: non-destructive age/sex standardisation. UNKNOWN includes canonical NULL and nonstandard codes; explicit missing flags distinguish NULL. Not an age correction.';
comment on view analysis.culture_results_standardised is 'Version 1: culture result categories. Only M.BOVIS and NEGATIVE yield non-null binary evidence; other organism/invalid/pending/missing results are not treated as negative.';

-- ================================================
-- MIGRATION VERSION: 20261023123005
-- MIGRATION NAME: woodchester_diagnostic_interpretation_v2_20261023
-- ================================================

-- Versioned diagnostic interpretation v2, 2026-10-23.
-- Source and research base rows preserved; NULL means indeterminate, not negative.
create or replace view analysis.diagnostic_interpretation_standardised as
with classified as (
select d.capture_id,'DPP'::text test_family,d.dpp_test_id source_record_id,
       concat_ws('/',d.visual_line_1,d.visual_line_2) recorded_result,
       case when upper(btrim(coalesce(d.visual_line_1,''))) in ('P','PX') or upper(btrim(coalesce(d.visual_line_2,''))) in ('P','PX') then 'POSITIVE'
            when upper(btrim(coalesce(d.visual_line_1,''))) in ('N','NX') and
                 (upper(btrim(coalesce(d.visual_line_2,''))) in ('N','NX') or nullif(btrim(coalesce(d.visual_line_2,'')),'') is null) then 'NEGATIVE'
            else 'INDETERMINATE' end interpreted_status
from research.dpp_tests d
union all
select x.capture_id,'IFN_GAMMA',x.ifn_test_id,x.test_result,
       case when nullif(btrim(coalesce(x.test_failed,'')),'') is not null then 'INVALID'
            when upper(btrim(coalesce(x.test_result,'')))='POSITIVE' then 'POSITIVE'
            when upper(btrim(coalesce(x.test_result,'')))='NEGATIVE' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.ifn_gamma_elisa x
union all
select e.capture_id,'ELISA',e.elisa_test_id,e.test_result,
       case when upper(btrim(coalesce(e.test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(e.test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.elisa_tests e
union all
select b.capture_id,'BROCK',b.brock_test_id,b.test_result,
       case when b.no_clotted is true then 'INVALID'
            when upper(btrim(coalesce(b.test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(b.test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.brock_tests b
)
select i.tattoo,c.capture_id,c.capture_date,c.is_pm,
       x.test_family,x.source_record_id,x.recorded_result,x.interpreted_status,
       case when x.interpreted_status='POSITIVE' then true
            when x.interpreted_status='NEGATIVE' then false else null end as test_positive
from classified x join research.captures c on c.capture_id=x.capture_id
join research.individuals i on i.individual_id=c.individual_id;

create or replace view analysis.capture_diagnostic_summary_standardised as
select c.capture_id,i.tattoo,c.capture_date,c.is_pm,
       count(d.source_record_id) diagnostic_test_count,
       count(d.source_record_id) filter(where d.test_positive is true) positive_test_count,
       count(d.source_record_id) filter(where d.test_positive is false) negative_test_count,
       count(d.source_record_id) filter(where d.test_positive is null) uninterpretable_test_count,
       bool_or(d.test_positive is true) any_positive_test
from research.captures c join research.individuals i on i.individual_id=c.individual_id
left join analysis.diagnostic_interpretation_standardised d on c.capture_id=d.capture_id
group by c.capture_id,i.tattoo,c.capture_date,c.is_pm;
grant select on analysis.diagnostic_interpretation_standardised,analysis.capture_diagnostic_summary_standardised to badger_readonly,badger_research_readonly;
comment on view analysis.diagnostic_interpretation_standardised is 'v2 diagnostic interpretations, reversible derived values. DPP P/Px and N/Nx codes, explicit invalid IFN no-sample and Brock no-clot. Interpret with test-specific scientific constraints; INDETERMINATE is not negative.';
comment on view analysis.capture_diagnostic_summary_standardised is 'v2 convenience by capture, counts of interpretable and indeterminate tests; any_positive_test is descriptive evidence, not latent infection diagnosis.';


-- ================================================
-- MIGRATION VERSION: 20261023123056
-- MIGRATION NAME: woodchester_diagnostic_include_culture_v3_20261023
-- ================================================

-- Include existing v1 culture interpretation in the unified test-level view
create or replace view analysis.diagnostic_interpretation_standardised as
with x as (
select capture_id,'DPP'::text test_family,dpp_test_id source_record_id,
       concat_ws('/',visual_line_1,visual_line_2) recorded_result,
       case when upper(btrim(coalesce(visual_line_1,''))) in ('P','PX') or upper(btrim(coalesce(visual_line_2,''))) in ('P','PX') then 'POSITIVE'
            when upper(btrim(coalesce(visual_line_1,''))) in ('N','NX') and
                 (upper(btrim(coalesce(visual_line_2,''))) in ('N','NX') or nullif(btrim(coalesce(visual_line_2,'')),'') is null) then 'NEGATIVE'
            else 'INDETERMINATE' end interpreted_status
from research.dpp_tests
union all
select capture_id,'IFN_GAMMA',ifn_test_id,test_result,
       case when nullif(btrim(coalesce(test_failed,'')),'') is not null then 'INVALID'
            when upper(btrim(coalesce(test_result,'')))='POSITIVE' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='NEGATIVE' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.ifn_gamma_elisa
union all
select capture_id,'ELISA',elisa_test_id,test_result,
       case when upper(btrim(coalesce(test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.elisa_tests
union all
select capture_id,'BROCK',brock_test_id,test_result,
       case when no_clotted is true then 'INVALID'
            when upper(btrim(coalesce(test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.brock_tests
union all
select capture_id,'CULTURE',culture_id,culture_result_recorded,
       case culture_result_status
         when 'M_BOVIS_DETECTED' then 'POSITIVE'
         when 'NEGATIVE' then 'NEGATIVE'
         when 'INVALID' then 'INVALID'
         else 'INDETERMINATE' end
from analysis.culture_results_standardised
)
select i.tattoo,c.capture_id,c.capture_date,c.is_pm,
       x.test_family,x.source_record_id,x.recorded_result,x.interpreted_status,
       case when x.interpreted_status='POSITIVE' then true
            when x.interpreted_status='NEGATIVE' then false else null end as test_positive
from x join research.captures c on c.capture_id=x.capture_id
join research.individuals i on i.individual_id=c.individual_id;
comment on view analysis.diagnostic_interpretation_standardised is 'v3: five assay families including culture; original results preserved and nullable positivity excludes missing/invalid/pending and other organisms.';


-- ================================================
-- MIGRATION VERSION: 20261023123446
-- MIGRATION NAME: woodchester_v1_baseline_extension_20261023
-- ================================================

-- WOODCHESTER DATABASE v1 baseline extension, idempotent presentation-layer migration.
-- Existing prior migrations v1/v2/v3 retained as historical history.
create or replace view analysis.stat_pak_results_standardised as
select i.tattoo,s.capture_id,s.stat_pak_test_id,c.capture_date,
s.stat_pak_id as original_result_code,s.test_result as original_result_text,
case when upper(btrim(s.stat_pak_id))='P' then 'POSITIVE'
when upper(btrim(s.stat_pak_id))='N' then 'NEGATIVE'
when upper(btrim(s.stat_pak_id))='C' then 'INVALID'
else 'INDETERMINATE' end result_status,
case when upper(btrim(s.stat_pak_id))='P' then true
when upper(btrim(s.stat_pak_id))='N' then false else null end test_positive
from research.stat_pak_tests s join research.captures c using(capture_id)
join research.individuals i using(individual_id);

create or replace view analysis.capture_traits_standardised as
select c.capture_id,i.tattoo,c.capture_date,
extract(year from c.capture_date)::integer capture_year,
extract(quarter from c.capture_date)::integer capture_quarter,
c.is_pm,c.sett_id,c.recorded_sett_name,c.recorded_social_group_id,
c.recorded_social_group_name,
t.sex_recorded,t.sex_standardised,t.sex_missing,
t.age_first_capture_recorded,t.age_first_capture_standardised,
t.year_first_capture,
case when t.year_first_capture is not null and c.capture_date is not null
then extract(year from c.capture_date)::integer-t.year_first_capture else null end
as years_since_first_capture,
case when t.age_first_capture_standardised='CUB' and t.year_first_capture is not null
then extract(year from c.capture_date)::integer-t.year_first_capture
else null end as approximate_age_if_first_captured_as_cub
from research.captures c join research.individuals i using(individual_id)
join analysis.individual_traits_standardised t on t.tattoo=i.tattoo;

grant select on analysis.stat_pak_results_standardised,analysis.capture_traits_standardised to badger_readonly,badger_research_readonly;
comment on view analysis.capture_traits_standardised is 'V1: year/quarter and years since first capture; approximate age only for recorded CUB first captures, not validated exact age.';


-- ================================================
-- MIGRATION VERSION: 20261023123522
-- MIGRATION NAME: woodchester_v1_all_six_assays_20261023
-- ================================================

-- Include existing v1 culture interpretation in the unified test-level view
create or replace view analysis.diagnostic_interpretation_standardised as
with x as (
select capture_id,'DPP'::text test_family,dpp_test_id source_record_id,
       concat_ws('/',visual_line_1,visual_line_2) recorded_result,
       case when upper(btrim(coalesce(visual_line_1,''))) in ('P','PX') or upper(btrim(coalesce(visual_line_2,''))) in ('P','PX') then 'POSITIVE'
            when upper(btrim(coalesce(visual_line_1,''))) in ('N','NX') and
                 (upper(btrim(coalesce(visual_line_2,''))) in ('N','NX') or nullif(btrim(coalesce(visual_line_2,'')),'') is null) then 'NEGATIVE'
            else 'INDETERMINATE' end interpreted_status
from research.dpp_tests
union all
select capture_id,'IFN_GAMMA',ifn_test_id,test_result,
       case when nullif(btrim(coalesce(test_failed,'')),'') is not null then 'INVALID'
            when upper(btrim(coalesce(test_result,'')))='POSITIVE' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='NEGATIVE' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.ifn_gamma_elisa
union all
select capture_id,'ELISA',elisa_test_id,test_result,
       case when upper(btrim(coalesce(test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.elisa_tests
union all
select capture_id,'BROCK',brock_test_id,test_result,
       case when no_clotted is true then 'INVALID'
            when upper(btrim(coalesce(test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.brock_tests
union all
select capture_id,'STAT_PAK',stat_pak_test_id,original_result_text,result_status
from analysis.stat_pak_results_standardised
union all
select capture_id,'CULTURE',culture_id,culture_result_recorded,
       case culture_result_status
         when 'M_BOVIS_DETECTED' then 'POSITIVE'
         when 'NEGATIVE' then 'NEGATIVE'
         when 'INVALID' then 'INVALID'
         else 'INDETERMINATE' end
from analysis.culture_results_standardised
)
select i.tattoo,c.capture_id,c.capture_date,c.is_pm,
       x.test_family,x.source_record_id,x.recorded_result,x.interpreted_status,
       case when x.interpreted_status='POSITIVE' then true
            when x.interpreted_status='NEGATIVE' then false else null end as test_positive
from x join research.captures c on c.capture_id=x.capture_id
join research.individuals i on i.individual_id=c.individual_id;
comment on view analysis.diagnostic_interpretation_standardised is 'Version 1 baseline: six assay families including culture; original results preserved and nullable positivity excludes missing/invalid/pending and other organisms.';


-- ================================================
-- MIGRATION VERSION: 20261023123550
-- MIGRATION NAME: woodchester_v1_access_refresh_audit_infrastructure_20261023
-- ================================================

-- Version 1: audited Access refresh infrastructure (metadata only, no source rows changed).
create schema if not exists ingest;
create table if not exists ingest.access_refresh_batches (
 batch_id bigint generated always as identity primary key,
 source_filename text not null,
 source_sha256 text not null,
 source_exported_at timestamptz,
 registered_at timestamptz not null default now(),
 status text not null default 'REGISTERED'
  check (status in ('REGISTERED','STAGED','REVIEWED','APPLIED','REJECTED')),
 git_commit text,
 notes text,
 unique(source_filename,source_sha256)
);
create table if not exists ingest.access_refresh_table_audits (
 audit_id bigint generated always as identity primary key,
 batch_id bigint not null references ingest.access_refresh_batches(batch_id),
 source_table text not null,
 source_rows bigint,
 prior_rows bigint,
 inserted_rows bigint,
 changed_rows bigint,
 missing_rows bigint,
 ambiguous_rows bigint,
 audit_status text not null default 'PENDING'
  check(audit_status in ('PENDING','PASS','REVIEW','FAIL')),
 audit_detail jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 unique(batch_id,source_table)
);
create table if not exists ingest.canonical_cleaning_decisions (
 decision_id bigint generated always as identity primary key,
 rule_version text not null,
 domain text not null,
 source_table text,
 source_identifier text,
 recorded_value text,
 canonical_value text,
 evidence text not null,
 rationale text not null,
 decision_status text not null default 'PROPOSED'
  check(decision_status in ('PROPOSED','APPROVED','REJECTED','SUPERSEDED')),
 git_commit text,
 reviewed_by text,
 reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
revoke all on schema ingest from public,anon,authenticated,badger_readonly,badger_research_readonly;
revoke all on all tables in schema ingest from public,anon,authenticated,badger_readonly,badger_research_readonly;
comment on schema ingest is 'Private versioned Access refresh audit metadata; registration is not an import and does not modify research.';


-- ================================================
-- MIGRATION VERSION: 20261023124031
-- MIGRATION NAME: woodchester_v1_1_sett_location_review_20261023
-- ================================================

-- Woodchester V1.1: auditable sett coordinates and unresolved recorded-location review.
create table if not exists research.sett_location_evidence (
 evidence_id bigint generated always as identity primary key,
 sett_id bigint not null references research.setts(sett_id),
 easting numeric,
 northing numeric,
 coordinate_system text not null default 'EPSG:27700',
 accuracy_m numeric,
 evidence_type text not null check(evidence_type in ('FIELD_TEAM','HISTORIC_MAP','GPS','OTHER')),
 source_reference text not null,
 observed_on date,
 recorded_by text,
 review_status text not null default 'PROPOSED' check(review_status in ('PROPOSED','APPROVED','REJECTED','SUPERSEDED')),
 reviewed_by text,
 reviewed_at timestamptz,
 notes text,
 created_at timestamptz not null default now(),
 check ((easting is null and northing is null) or (easting is not null and northing is not null)),
 check (accuracy_m is null or accuracy_m >= 0)
);
create unique index if not exists one_approved_coordinate_per_sett on research.sett_location_evidence(sett_id) where review_status='APPROVED';
create or replace view analysis.sett_coordinates_approved as
select s.sett_name,e.easting,e.northing,e.coordinate_system,e.accuracy_m,e.source_reference,e.observed_on
from research.setts s join research.sett_location_evidence e on e.sett_id=s.sett_id
where e.review_status='APPROVED';
create or replace view analysis.sett_field_team_review as
select s.sett_name,
       count(c.capture_id) as canonical_capture_count,
       max(c.capture_date) as last_capture_date,
       bool_or(e.review_status='APPROVED') as has_approved_coordinate
from research.setts s left join research.captures c on c.sett_id=s.sett_id
left join research.sett_location_evidence e on e.sett_id=s.sett_id
group by s.sett_id,s.sett_name;
create or replace view analysis.unresolved_recorded_sett_names as
select recorded_sett_name,count(*) as n_captures,min(capture_date) first_recorded,max(capture_date) last_recorded
from research.captures where sett_id is null and nullif(btrim(recorded_sett_name),'') is not null
group by recorded_sett_name;
grant select on research.sett_location_evidence to badger_research_readonly;
grant select on analysis.sett_coordinates_approved,analysis.sett_field_team_review,analysis.unresolved_recorded_sett_names to badger_readonly,badger_research_readonly;


-- ================================================
-- MIGRATION VERSION: 20261023124221
-- MIGRATION NAME: woodchester_v1_1_sett_review_cardinality_fix_20261023
-- ================================================

create or replace view analysis.sett_field_team_review as
select s.sett_name,
       (select count(*) from research.captures c where c.sett_id=s.sett_id) as canonical_capture_count,
       (select max(c.capture_date) from research.captures c where c.sett_id=s.sett_id) as last_capture_date,
       exists (select 1 from research.sett_location_evidence e where e.sett_id=s.sett_id and e.review_status='APPROVED') as has_approved_coordinate
from research.setts s;

-- ================================================
-- MIGRATION VERSION: 20261023125403
-- MIGRATION NAME: woodchester_v1_2_revert_pm_inferred_setts_20261023
-- ================================================

-- Woodchester V1.2: source-supported reversal of inferred sett assignment
-- Scientific decision: Dave Hudson, 2026-10-23.
-- Source records: tblCaptures PM=Yes, original sett NULL; group text preserved.
-- Capture IDs verified against canonical tattoo,date,PM flag.
begin;
do $$
declare n integer;
begin
select count(*) into n from research.captures c
join research.individuals i on i.individual_id=c.individual_id
where (c.capture_id=17583 and i.tattoo='015S' and c.capture_date='2021-09-02' and c.is_pm)
or (c.capture_id=17584 and i.tattoo='053M' and c.capture_date='2021-09-02' and c.is_pm)
or (c.capture_id=17548 and i.tattoo='026H' and c.capture_date='2021-09-29' and c.is_pm);
if n<>3 then raise exception 'Expected exactly 3 checked PM records; got %',n; end if;
end $$;
update research.captures
set sett_id=null,
location_cleaning_note='V1.2 Dave Hudson: reverted inferred physical sett on PM BCP record. Original Access sett blank; CHESTNUT/HOLLOW TREE present only in recorded socg. Do not infer PM site or resident group.'
where capture_id in (17583,17584,17548)
and is_pm is true and recorded_sett_name is null
and location_cleaning_note='Original sett blank; value recorded in socg was not a valid social group but matched a known sett and was used as cleaned sett';
do $$
declare n integer;
begin
select count(*) into n from research.captures where capture_id in (17583,17584,17548) and sett_id is null and location_cleaning_note like 'V1.2 Dave Hudson:%';
if n<>3 then raise exception 'V1.2 migration did not update all three records; got %',n;end if;
end $$;
commit;

-- ================================================
-- MIGRATION VERSION: 20261023134340
-- MIGRATION NAME: woodchester_working_v1_sett_review_views_20261023
-- ================================================

-- Woodchester working Version 1: live sett inventories for field team review.
-- No changes to original recorded sett names or existing canonical assignments.
create or replace view analysis.capture_sett_coordinate_inventory as
select s.sett_name,
       count(c.capture_id)::bigint as n_captures,
       count(c.capture_id) filter(where c.is_pm)::bigint as n_pm_records,
       min(c.capture_date) as first_capture_date,
       max(c.capture_date) as last_capture_date,
       e.easting,e.northing,e.coordinate_system,e.accuracy_m,e.source_reference as coordinate_source,
       case when e.evidence_id is not null then 'COORDINATES_APPROVED'
            else 'COORDINATES_MISSING' end as coordinate_status
from research.setts s
left join research.captures c on c.sett_id=s.sett_id
left join research.sett_location_evidence e on e.sett_id=s.sett_id and e.review_status='APPROVED'
group by s.sett_id,s.sett_name,e.evidence_id,e.easting,e.northing,e.coordinate_system,e.accuracy_m,e.source_reference;

create or replace view analysis.unmatched_capture_sett_review as
select btrim(c.recorded_sett_name) as recorded_sett_name,
       count(*)::bigint n_captures,
       count(*) filter(where c.is_pm)::bigint n_pm_records,
       min(c.capture_date) first_capture_date,
       max(c.capture_date) last_capture_date,
       'UNREVIEWED'::text as name_review_status
from research.captures c
where c.sett_id is null and nullif(btrim(c.recorded_sett_name),'') is not null
group by btrim(c.recorded_sett_name);

grant select on analysis.capture_sett_coordinate_inventory,analysis.unmatched_capture_sett_review to badger_readonly,badger_research_readonly;
comment on view analysis.capture_sett_coordinate_inventory is 'Live working V1 inventory of every canonical sett, capture count and approved coordinates; includes setts with no assigned captures.';
comment on view analysis.unmatched_capture_sett_review is 'Live working V1 list of original capture sett labels not matched to canonical IDs; labels may be lanes, field locations, aliases, or setts and are not automatically cleaned.';


-- ================================================
-- MIGRATION VERSION: 20261023134917
-- MIGRATION NAME: woodchester_v1_coordinate_source_import_20261023
-- ================================================

create table if not exists research.sett_coordinate_source_20261023 (source_name text primary key, source_display_name text not null, easting numeric not null,northing numeric not null,source_file text not null default 'WoodchesterSettLocations (1).csv', coordinate_system text not null default 'EPSG:27700', imported_on date not null default '2026-10-23'); insert into research.sett_coordinate_source_20261023(source_name,source_display_name,easting,northing) values ('ARTHURS','Arthurs',380534,200550),('ASH.TREE','Ash.Tree',381604,201121),('ATCOMBE.CORNER','Atcombe.Corner',383696,201502),('ATCOMBE.WEST','Atcombe.West',383375,201417),('BAMBOO','Bamboo',383699,201850),('BANK','Bank',380563,200499),('BEASTY','Beasty',380961,201190),('BEECH','Beech',380931,201164),('BENCH','Bench',380417,201488),('BEND','Bend',381942,201770),('BLACKTHORN','Blackthorn',381573,200897),('BLUEBELL','Bluebell',382106,201001),('BLUEBOTTLE','Bluebottle',381761,200946),('BOG','Bog',382099,200773),('BORAX','Borax',384023,200756),('BOUNDARY','Boundary',380449,201388),('BOUNDARY.COURT','Boundary.Court',382916,202222),('BOWLAS','Bowlas',382396,199692),('BOX','Box',380621,201409),('BOXER','Boxer',380597,201427),('BOXWOOD','Boxwood',381241,201774),('BRACKEN','Bracken',381157,201365),('BRAMBLE','Bramble',380625,200466),('BREAKHEART','Breakheart',381370,201620),('BRICK.KILN','Brick.Kiln',381364,201480),('BUCKHOLT','Buckhole',379874,201435),('BULL.PEN','Bull.Pen',381230,201693),('BUNGALOW','Bungalow',383675,202710),('BUSH','Bush',380707,200454),('CARPARK','Carpark',379814,201477),('CARTON','Carton',380580,201391),('CEDAR','Cedar',381022,201589),('CHAIN','Chain',381946,201669),('CHERRIES','Cherries',381841,201313),('CHESTNUT','Chesnut',380834,201150),('CHICKEN.WIRE','Chicken.Wire',382168,201377),('CLAY','Clay',380590,200530),('CLEMATIS','Clematis',380402,200474),('CLIFF.FACE','Cliff.Face',380646,199943),('COLE.PARK','Cole.park',382049,201493),('COLLIERS.WOOD','Colliers.Wood',382931,200706),('COMPLEX','Complex',380649,201388),('CONVENT','Convent',383938,201266),('CORRAL','Corral',380279,201409),('COVERT','Covert',380714,199933),('CUL-DE-SAC','Cul-de-sac',382399,200920),('DAM','Dam',383126,200958),('DARK.WOOD','Darkwood',383135,202599),('DEN','Den',381314,201015),('DINGLE','Dingle',383237,202222),('DOLINE','Doline',382076,201048),('DRAIN','Drain',382277,201058),('DUMP','Dump',380662,200205),('DUMPER','Dumper',382529,201326),('EARTH','Earth',380906,200398),('EDGE','Edge',380531,200225),('ELBOW','Elbow',382811,200806),('ELEVEN.ROW','Eleven.Row',381824,201695),('FENCE.HOLE','Fence.Hole',380334,200645),('FERN','Fern',381314,201301),('FIELD.BANK','Field.Bank',380915,201219),('FIELD.FARM','Field.Farm',380936,199687),('FIELD.POLE','Field.Pole',381004,201268),('FINGER','Finger',380659,200133),('FOREST','Forest',381920,201658),('FORK','Fork',382786,200771),('FOX','Fox',381016,201635),('GIANT.BEECH','Giant.Beech',382420,201405),('GOLD.TOP','Gold.Top',382188,201414),('GRAVEL.PIT','Gravel.Pit',381184,201836),('GROUNDSTUMP','Groundstump',380583,201265),('GULLY','Gully',382734,202283),('HEDGE','Hedge',381350,200278),('HOGARTHS','Hogarths',382627,200053),('HOLLOW.TREE','Hollow.Tree',382930,201326),('HOLLY','Holly',383947,200713),('HOLLYWOOD','HollyWood',381353,199891),('HONEYWELL','Honeywell',381931,201706),('HOPPER','Hopper',383666,200473),('HORSE.FIELD','Horse.Field',381432,201406),('HUNTING.GATE','Hunting.Gate',381247,201345),('HURDLES','Hurdles',383082,201046),('INCHBROOK','Inchbrook',384013,200739),('JACKS','Jacks.Mirey',380678,200030),('JACOBS','Jacobs',380387,201401),('JUNCTION','Junction',380841,200432),('JUNGLE','Jungle',383314,200694),('KENNEL','Kennel',382464,200922),('LARCH','Larch',380541,201242),('LAURELS','Laurels',381180,201357),('LAY','Lay',380860,199736),('LEBANON','Lebanon',380690,201353),('LINSEED','Linseed',383011,201367),('LISTERS','Listers',383444,201738),('LITTLE.BEECH','Little.Beech',382359,201429),('MAID','Maid',382606,200941),('MANSION','Mansion',380901,201150),('MEAD','Mead',380390,200637),('MEADOW','Meadow',381112,199639),('MRS.MACKS','Mrs.Macks',380365,200369),('NEEDLES','Needles',382440,200974),('NETTLE','Nettle',383024,201142),('NEW.FENCE','New.Fence',380635,201191),('OAK.PILE','Oak.Pile',382183,201478),('OLD.COLEPARK','Old.Colepark',382142,201424),('OLD.OAK','Old.Oak',382624,201274),('OLD.POND.DRAIN','Old.Pond.Drain',381503,201484),('OPEN','Open',380812,200417),('PARK.MILL','Park.mill',383730,200924),('PEGLARS','Peglars',382355,200596),('PEN','Pen',382191,199820),('PEN.(NEEDS.RENAME)','Pen.(needs.rename)',382413,200651),('PLANTATION','Plantation',381649,201342),('POND','Pond',383026,200802),('PONTINS','Pontins',382122,200921),('POPLAR','Poplar',382132,201047),('PRIORY','Priory',384143,201139),('PUDDLES','Puddles',382779,200661),('PUFFBALL','Puffball',381532,201077),('PYLON','Pylon',381275,200279),('QUARRY','Quarry',383188,201092),('RABBIT','Rabbit',380856,201662),('RUSTY.TRAP','Rusty.Trap',381281,201324),('SANDY','Sandy',383812,200913),('SAPLING','Sapling',381716,201013),('SCOTLAND.BANK','Scotland.Bank',383412,200931),('SCRUB','Scrub',383045,200620),('SEDGE','Sedge',382706,200584),('SELSLEY','Selsley',383749,203824),('SEPTIC.TANK','Septic.Tank',381357,201285),('SINGLE','Single',380737,200025),('SLIP','Slip',380437,200628),('SPRING','Spring',382317,200560),('SPUR','Spur',379972,201378),('STEEP.BANK','Steep.Bank',381515,201745),('STINGER','Stinger',383066,201113),('STONE.DRAIN','Stone.Drain',380305,200631),('STONEY.TRACK','Stoney.Track',380742,201140),('STREAM','Stream',383608,202451),('STREAM.(NEEDS.NEW.NAME)','Stream.(needs.new.name)',380919,199926),('STUMP','Stump',382956,201126),('SYCAMORE','Sycamore',381103,201676),('TAXUS','Taxus',381737,201220),('THICKET','Thicket',380872,200010),('THIRD.ROW','Third.Row',381860,201755),('THISTLE.WOOD.BANK','Thistle.Wood.Bank',381109,200408),('TIP','Tip',380475,200580),('TODDS','Todds',380393,200413),('TOP','Top.Sett',381795,200962),('TOP.OAK','Top.Oak',382616,201525),('TRACKSIDE','Trackside',382281,201327),('TRIPWIRE','Tripwire',381813,200992),('UTES','Utes',381542,200954),('VILLIERS.CUT','Villiers.Cut',384110,203159),('VILLIERS.UPPER','Villiers.Upper',383397,203233),('VINE','Vine',381932,201624),('WALL','Wall',382201,200574),('WASP.NEST','Wasp.Nest',380866,199947),('WATERBUTT','Waterbutt',380662,201206),('WEST','West',380190,201400),('WINDFALL','Windfall',382124,200793),('WINDSOR.EDGE','Windsoredge',383635,200531),('WOOD.FARM','Wood.Farm',383337,200429),('WOODMANS','Woodmans',382542,201397),('WOODRUSH','Woodrush',382713,200607),('WYCH.ELM','Wych.Elm',382074,201085),('XMAS.TREE','Xmas.Tree',382680,201174),('YEW','Yew',381619,201268) on conflict(source_name) do update set source_display_name=excluded.source_display_name,easting=excluded.easting,northing=excluded.northing;

-- ================================================
-- MIGRATION VERSION: 20261023135025
-- MIGRATION NAME: woodchester_working_v1_definitive_sett_coordinate_matching_20261023
-- ================================================

-- Working Version 1: link the definitive source coordinates to unambiguous canonical setts.
-- Matching: punctuation-insensitive exact canonical name, plus four previously recorded coordinate aliases.
-- All unmatched coordinate-source rows are retained in research.sett_coordinate_source_20261023.
with matches as (
 select src.*,s.sett_id
 from research.sett_coordinate_source_20261023 src
 join research.setts s on regexp_replace(upper(src.source_name),'[^A-Z0-9]','','g') = regexp_replace(upper(s.sett_name),'[^A-Z0-9]','','g')
 union all
 select src.*,s.sett_id
 from research.sett_coordinate_source_20261023 src
 join research.setts s on
     (src.source_name='CLIFF.FACE' and s.sett_name='CLIFF')
  or (src.source_name='GULLY' and s.sett_name='GULLEY')
  or (src.source_name='STONEY.TRACK' and s.sett_name='STONY TRACK')
  or (src.source_name='ELEVEN.ROW' and s.sett_name='ELEVENTH ROW')
),
unique_matches as (
 select m.* from matches m
 where (select count(*) from matches d where d.source_name=m.source_name)=1
   and (select count(*) from matches d where d.sett_id=m.sett_id)=1
)
insert into research.sett_location_evidence
(sett_id,easting,northing,coordinate_system,evidence_type,source_reference,review_status,reviewed_by,reviewed_at,notes)
select m.sett_id,m.easting,m.northing,'EPSG:27700','OTHER',
       'WoodchesterSettLocations (1).csv; source Sett_Upper='||m.source_name,
       'APPROVED','Dave Hudson',now(),
       'Coordinate from supplied definitive sett source; display SETT='||m.source_display_name
from unique_matches m
where not exists(select 1 from research.sett_location_evidence e where e.sett_id=m.sett_id and e.review_status='APPROVED');

create or replace view analysis.sett_coordinate_source_name_review as
with matches as (
select src.source_name,s.sett_id from research.sett_coordinate_source_20261023 src
join research.setts s on regexp_replace(upper(src.source_name),'[^A-Z0-9]','','g')=regexp_replace(upper(s.sett_name),'[^A-Z0-9]','','g')
union all
select src.source_name,s.sett_id from research.sett_coordinate_source_20261023 src join research.setts s on
(src.source_name='CLIFF.FACE' and s.sett_name='CLIFF') or
(src.source_name='GULLY' and s.sett_name='GULLEY') or
(src.source_name='STONEY.TRACK' and s.sett_name='STONY TRACK') or
(src.source_name='ELEVEN.ROW' and s.sett_name='ELEVENTH ROW')
)
select src.source_name,src.source_display_name,src.easting,src.northing,
s.sett_name as matched_canonical_sett,
case when s.sett_id is null then 'REVIEW_NAME' else 'LINKED' end as match_status
from research.sett_coordinate_source_20261023 src
left join matches m on m.source_name=src.source_name
left join research.setts s on s.sett_id=m.sett_id;
grant select on analysis.sett_coordinate_source_name_review to badger_readonly,badger_research_readonly;
comment on view analysis.sett_coordinate_source_name_review is 'Definitive uploaded coordinate file compared against canonical sett names; unresolved source names remain visible with original easting/northing.';


-- ================================================
-- MIGRATION VERSION: 20261023135730
-- MIGRATION NAME: woodchester_v1_coordinate_alias_review_20261023
-- ================================================

-- Working Version 1: independent, non-destructive reconciliation of names and coordinate proximity.
create or replace view analysis.unmatched_coordinate_sett_candidates as
select src.source_name, src.source_display_name, src.easting,src.northing,
       near.sett_name as nearest_named_sett,
       round(sqrt(power(src.easting-near.easting,2)+power(src.northing-near.northing,2)))::integer nearest_distance_m,
       (select count(*) from research.captures c where regexp_replace(upper(coalesce(c.recorded_sett_name,'')),'[^A-Z0-9]','','g')=regexp_replace(upper(src.source_name),'[^A-Z0-9]','','g'))::bigint exact_normalised_capture_mentions,
       case when src.source_name='VILLIERS.UPPER' then 'MATCH_RECORDED_CAPTURE_NAME_REVIEW_IDENTITY'
            when src.source_name like '%NEEDS%' then 'SOURCE_RENAME_REQUIRED'
            else 'UNMATCHED_COORDINATE_NAME' end as review_category
from analysis.sett_coordinate_source_name_review src
cross join lateral (
 select s.sett_name,e.easting,e.northing from research.sett_location_evidence e
 join research.setts s using(sett_id)
 where e.review_status='APPROVED'
 order by power(src.easting-e.easting,2)+power(src.northing-e.northing,2)
 limit 1
) near
where src.match_status='REVIEW_NAME';
grant select on analysis.unmatched_coordinate_sett_candidates to badger_readonly,badger_research_readonly;
comment on view analysis.unmatched_coordinate_sett_candidates is 'Name/nearest-point review only; geographic distance is not evidence that points represent the same sett.';


-- ================================================
-- MIGRATION VERSION: 20261023142137
-- MIGRATION NAME: woodchester_v1_capture_pm_grid_ref_review_20261023
-- ================================================

create or replace view analysis.capture_pm_grid_reference_review as
with base as (
 select c.capture_id,c.capture_date,c.is_pm,c.sett_id,c.recorded_sett_name,c.capture_location_text,c.os_ref,
 upper(regexp_replace(coalesce(c.os_ref,''),'[[:space:].-]','','g')) as os_clean,
 upper(regexp_replace(coalesce(c.recorded_sett_name,''),'[[:space:].-]','','g')) as recorded_clean
 from research.captures c where c.is_pm
), codes as (
 select *,case when os_clean ~ '^(SO)?[0-9]{6}$' then regexp_replace(os_clean,'^SO','')
               when recorded_clean ~ '^(SO)?[0-9]{6}$' then regexp_replace(recorded_clean,'^SO','')
               else null end as so_six_digits,
 case when os_clean ~ '^(SO)?[0-9]{6}$' then 'os_ref'
      when recorded_clean ~ '^(SO)?[0-9]{6}$' then 'recorded_sett_name'
      else null end as grid_reference_source
 from base
)
select capture_id,capture_date,is_pm,sett_id,recorded_sett_name,capture_location_text,os_ref,
 so_six_digits,grid_reference_source,
 case when so_six_digits is not null then 300000+(substring(so_six_digits,1,3)::int*100) end as grid_cell_easting,
 case when so_six_digits is not null then 200000+(substring(so_six_digits,4,3)::int*100) end as grid_cell_northing,
 case when so_six_digits is not null then 100 end as grid_cell_width_m,
 case when so_six_digits is not null then 'EPSG:27700' end as inferred_crs,
 case when so_six_digits is not null then 'PARSED_SO_6_DIGIT_GRID_CELL_NEEDS_SOURCE_CONFIRMATION'
 else 'UNPARSED_OR_ABSENT' end as review_status
from codes;
grant select on analysis.capture_pm_grid_reference_review to badger_readonly,badger_research_readonly;
comment on view analysis.capture_pm_grid_reference_review is 'PM capture-location grid reference review. Only pure SO+six digit or six-digit fields are interpreted as 100-m SO grid squares. Coordinates mark cell SW corner, NOT a sett point or exact badger location. Original evidence and uncertainty retained. No change to sett_id.';


-- ================================================
-- MIGRATION VERSION: 20261023142448
-- MIGRATION NAME: woodchester_v1_capture_location_classified_20261023
-- ================================================

create or replace view analysis.capture_location_classified as
select h.capture_id,h.tattoo,h.capture_date,h.is_pm,
       h.recorded_sett_name as original_recorded_sett_name,
       h.sett_id,h.normalized_sett_name as canonical_sett_name,
       h.os_ref,h.capture_location_text,
       case
         when h.sett_id is not null then 'KNOWN_SETT'
         when g.so_six_digits is not null then 'GRID_REFERENCED_PM_LOCATION'
         when h.is_pm then 'PM_LOCATION_UNRESOLVED'
         when nullif(btrim(h.recorded_sett_name),'') is not null then 'UNMATCHED_RECORDED_SETT_NAME'
         else 'LOCATION_NOT_RECORDED'
       end as location_class,
       case when h.sett_id is not null then h.normalized_sett_name
            when g.so_six_digits is not null then 'GRID REFERENCE (NOT A SETT)'
            else null end as display_location_name,
       g.grid_reference_source,g.so_six_digits,
       g.grid_cell_easting,g.grid_cell_northing,g.grid_cell_width_m,
       g.inferred_crs,g.review_status as grid_reference_review_status
from analysis.capture_history h
left join analysis.capture_pm_grid_reference_review g on g.capture_id=h.capture_id;
grant select on analysis.capture_location_classified to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_classified is 'Researcher-facing location classification distinguishing known setts, grid-referenced PM locations (not setts), other unreviewed PM locations and unmatched capture sett text. Source values never overwritten; six-digit SO grid cells are provisional.';


-- ================================================
-- MIGRATION VERSION: 20261023142616
-- MIGRATION NAME: woodchester_v1_embedded_pm_grid_refs_20261023
-- ================================================

create or replace view analysis.capture_location_classified_v2 as
with pm as (
 select c.capture_id,c.tattoo,c.capture_date,c.is_pm,c.sett_id,c.recorded_sett_name,c.os_ref,c.capture_location_text,
 g.so_six_digits as existing_grid,
 upper(substring(coalesce(c.recorded_sett_name,'') from '(^|[^0-9])([0-9]{3}[[:space:]]?[0-9]{3})([^0-9]|$)')) as grid_text_raw,
 (regexp_match(coalesce(c.recorded_sett_name,''),'(^|[^0-9])([0-9]{3}[[:space:]]?[0-9]{3})([^0-9]|$)'))[2] as grid_text,
 g.grid_reference_source as existing_grid_source
 from analysis.capture_history c left join analysis.capture_pm_grid_reference_review g on g.capture_id=c.capture_id
), parsed as (
 select *,coalesce(existing_grid,regexp_replace(grid_text,'[[:space:]]','','g')) as six_digits,
 case when existing_grid is not null then existing_grid_source when is_pm and sett_id is null and grid_text is not null then 'recorded_sett_name_embedded' end as reference_source
 from pm
)
select capture_id,tattoo,capture_date,is_pm,sett_id,recorded_sett_name as original_recorded_sett_name,os_ref,capture_location_text,
 case when sett_id is not null then 'KNOWN_SETT'
 when is_pm and six_digits is not null and six_digits ~ '^[0-9]{6}$' then 'GRID_REFERENCED_PM_LOCATION'
 when is_pm then 'PM_LOCATION_UNRESOLVED'
 when nullif(btrim(recorded_sett_name),'') is not null then 'UNMATCHED_RECORDED_SETT_NAME'
 else 'LOCATION_NOT_RECORDED' end as location_class,
 case when is_pm and sett_id is null and six_digits ~ '^[0-9]{6}$' then 'GRID REFERENCE (NOT A SETT)' else null end as location_display_category,
 reference_source,six_digits as so_grid_six_digits,
 case when six_digits ~ '^[0-9]{6}$' then 300000+substring(six_digits,1,3)::int*100 end as grid_sw_easting,
 case when six_digits ~ '^[0-9]{6}$' then 200000+substring(six_digits,4,3)::int*100 end as grid_sw_northing,
 case when is_pm and sett_id is null and reference_source='recorded_sett_name_embedded'
 then nullif(btrim(regexp_replace(recorded_sett_name,'(^|[^0-9])[0-9]{3}[[:space:]]?[0-9]{3}([^0-9]|$)',' ')),'') end as accompanying_location_description,
 case when is_pm and sett_id is null and six_digits ~ '^[0-9]{6}$' then 'PROVISIONAL_SO_100M_GRID_SQUARE' end as positional_precision_note
from parsed;
grant select on analysis.capture_location_classified_v2 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_classified_v2 is 'Classifies PM grid references embedded in sett-name text with optional descriptive place names as non-sett recovery locations, without changing canonical records. SO 100m grid squares are provisional. Source text kept intact.';


-- ================================================
-- MIGRATION VERSION: 20261023143517
-- MIGRATION NAME: woodchester_v1_pm_so_st_gridrefs_20261023
-- ================================================

create or replace view analysis.capture_location_classified_v3 as
with src as (
select v.*,upper(regexp_replace(coalesce(v.os_ref,''),'[[:space:],.-]','','g')) as cleaned_os_ref
from analysis.capture_location_classified_v2 v
), parsed as (
select src.*,
case when cleaned_os_ref ~ '^(SO|ST)([0-9]{6}|[0-9]{8}|[0-9]{10})$' then substring(cleaned_os_ref,1,2) end as grid_prefix,
case when cleaned_os_ref ~ '^(SO|ST)([0-9]{6}|[0-9]{8}|[0-9]{10})$' then substring(cleaned_os_ref,3) end as grid_digits
from src
), converted as (
select parsed.*,
case when grid_digits is not null then power(10,5-length(grid_digits)/2)::integer end as additional_cell_width_m,
case when grid_digits is not null then 300000 + substring(grid_digits,1,length(grid_digits)/2)::integer * power(10,5-length(grid_digits)/2)::integer end as additional_easting,
case when grid_digits is not null then (case grid_prefix when 'SO' then 200000 when 'ST' then 100000 end) + substring(grid_digits,length(grid_digits)/2+1)::integer * power(10,5-length(grid_digits)/2)::integer end as additional_northing
from parsed
)
select capture_id,tattoo,capture_date,is_pm,sett_id,original_recorded_sett_name,os_ref,capture_location_text,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'GRID_REFERENCED_PM_LOCATION' else location_class end as location_class,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'GRID REFERENCE (NOT A SETT)' else location_display_category end as location_display_category,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'os_ref_explicit_prefix' else reference_source end as reference_source,
so_grid_six_digits,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then additional_easting else grid_sw_easting end as grid_sw_easting,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then additional_northing else grid_sw_northing end as grid_sw_northing,
accompanying_location_description,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'PARSED_'||grid_prefix||'_'||additional_cell_width_m||'M_GRID_SQUARE' else positional_precision_note end as positional_precision_note,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then grid_prefix||grid_digits end as newly_parsed_grid_reference,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then additional_cell_width_m end as newly_parsed_cell_width_m
from converted;
grant select on analysis.capture_location_classified_v3 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_classified_v3 is 'Adds only explicitly prefixed ST/SO OS grid references at 100m, 10m and 1m nominal grid precision to PM recovery classification. No sett identity changes, no unsupported prefixes or typo correction. ST is 300km E / 100km N, SO 300km E / 200km N; coordinates designate SW grid-square corner rather than exact point.';


-- ================================================
-- MIGRATION VERSION: 20261023144006
-- MIGRATION NAME: woodchester_v1_baseline_stable_interfaces_20261023
-- ================================================

-- Working Version 1 (2026-10-23): stable researcher-facing location interface.
-- Earlier v2/v3 audit views retained for technical provenance; no source records overwritten.
create or replace view analysis.capture_location_v1 with (security_invoker = true) as
select v.capture_id,v.tattoo,v.capture_date,v.is_pm,
       v.sett_id, v.original_recorded_sett_name,
       case when v.sett_id is not null then s.sett_name end as canonical_sett_name,
       v.location_class, v.location_display_category, v.capture_location_text,v.os_ref,
       v.reference_source,v.so_grid_six_digits,v.newly_parsed_grid_reference,
       v.grid_sw_easting,v.grid_sw_northing,v.newly_parsed_cell_width_m,
       v.accompanying_location_description,v.positional_precision_note,
       case when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'PROVISIONAL_GRID_CELL_NOT_SETT'
            when v.location_class='KNOWN_SETT' then 'CANONICAL_SETT'
            else 'REVIEW_OR_MISSING' end as spatial_interpretation
from analysis.capture_location_classified_v3 v
left join research.setts s on s.sett_id=v.sett_id;

create or replace view analysis.sett_inventory_v1 with (security_invoker = true) as
select s.sett_id,s.sett_name as canonical_sett_name,
       coalesce(i.n_captures,0)::bigint as capture_count,
       i.n_pm_records,i.first_capture_date,i.last_capture_date,
       i.easting,i.northing,i.coordinate_system,i.accuracy_m,
       i.coordinate_source,i.coordinate_status
from research.setts s join analysis.capture_sett_coordinate_inventory i on i.sett_name=s.sett_name;

create or replace view analysis.sett_coordinate_unmatched_v1 with (security_invoker = true) as
select source_name,source_display_name,easting,northing,match_status
from analysis.sett_coordinate_source_name_review where match_status='REVIEW_NAME';

grant select on analysis.capture_location_v1,analysis.sett_inventory_v1,analysis.sett_coordinate_unmatched_v1 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_v1 is 'Woodchester working V1 stable capture-location interface. Historical field unmodified. Grid references are provisional locations and never sett points.';
comment on view analysis.sett_inventory_v1 is 'Woodchester working V1 stable canonical sett inventory with linked coordinate evidence and capture counts.';
comment on view analysis.sett_coordinate_unmatched_v1 is 'Woodchester working V1 coordinate source names not yet matched to canonical sett identities.';
create table if not exists ingest.woodchester_data_baseline_versions (
version_label text primary key,
baseline_date date not null,
status text not null,
scope text not null,
scientific_rules text not null,
outstanding_work text not null,
recorded_by text not null,
recorded_at timestamptz not null default now()
);
insert into ingest.woodchester_data_baseline_versions
(version_label,baseline_date,status,scope,scientific_rules,outstanding_work,recorded_by)
values ('v1',date '2026-10-23','WORKING_BASELINE',
'Woodchester Access-derived research and analysis layers, sett coordinate source and PM recovery-location interpretation',
'Raw recorded names preserved. TOP SETT = TOP; GULLY coordinate alias = GULLEY. Canonical sett coordinates linked only where unambiguous or previously approved. SO/ST recovery grid squares not reclassified as setts; map coordinates provisional and original text retained.',
'Validate source CRS; spatial extent and historical ST/SO conventions; reconcile unmatched coordinate source names, historical unmatched names, descriptive PM recoveries and non-PM location names; complete source-table and field parity review.',
'Dave Hudson')
on conflict(version_label) do nothing;
revoke all on ingest.woodchester_data_baseline_versions from public,anon,authenticated;


-- ================================================
-- MIGRATION VERSION: 20261023144827
-- MIGRATION NAME: woodchester_v1_capture_location_consistent_research_views_20261023
-- ================================================

create or replace view analysis.capture_location_fields_v1 with (security_invoker=true) as
select v.capture_id,v.canonical_sett_name as sett_name,
case when v.location_class='KNOWN_SETT' then 'SETT'
when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'PM_GRID_REFERENCE'
when v.location_class='PM_LOCATION_UNRESOLVED' then 'PM_LOCATION_UNRESOLVED'
when v.location_class='UNMATCHED_RECORDED_SETT_NAME' then 'UNMATCHED_CAPTURE_LOCATION'
else 'NOT_RECORDED' end as location_type,
case when v.location_class='KNOWN_SETT' then i.easting when v.location_class='GRID_REFERENCED_PM_LOCATION' then v.grid_sw_easting::numeric end as location_easting,
case when v.location_class='KNOWN_SETT' then i.northing when v.location_class='GRID_REFERENCED_PM_LOCATION' then v.grid_sw_northing::numeric end as location_northing,
case when v.location_class='KNOWN_SETT' then i.coordinate_system when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'EPSG:27700' end as location_crs,
case when v.location_class='KNOWN_SETT' then 'SETT_SOURCE_COORDINATE'
when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'PROVISIONAL_GRID_SQUARE_SOUTHWEST_CORNER'
else 'NO_VALIDATED_COORDINATE' end as location_coordinate_basis,v.location_class
from analysis.capture_location_v1 v left join analysis.sett_inventory_v1 i on i.sett_id=v.sett_id;
create or replace view analysis.capture_history_v1 with (security_invoker=true) as
select h.*,l.sett_name,l.location_type,l.location_easting,l.location_northing,l.location_crs,l.location_coordinate_basis,l.location_class
from analysis.capture_history h left join analysis.capture_location_fields_v1 l using(capture_id);
create or replace view analysis.capture_traits_v1 with (security_invoker=true) as
select t.*,l.sett_name,l.location_type,l.location_easting,l.location_northing,l.location_crs,l.location_coordinate_basis,l.location_class
from analysis.capture_traits_standardised t left join analysis.capture_location_fields_v1 l using(capture_id);
grant select on analysis.capture_location_fields_v1,analysis.capture_history_v1,analysis.capture_traits_v1 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_history_v1 is 'V1 standard capture-history table with sett_name NULL unless confirmed canonical sett. PM recovery grid locations are separate.';
comment on view analysis.capture_traits_v1 is 'V1 standardised capture traits with consistent sett_name and location fields.';
comment on view analysis.capture_location_fields_v1 is 'Reusable V1 capture location semantic fields; interpreted grid corner never implies sett.';


-- ================================================
-- MIGRATION VERSION: 20261026100806
-- MIGRATION NAME: woodchester_v1_location_review_767_evidence_corrected
-- ================================================

create or replace view analysis.location_review_767_v1 with (security_invoker=true) as
with base as (
select c.capture_id,r.individual_id,i.tattoo,c.capture_date,c.is_pm,c.recorded_sett_name,c.capture_location_text,c.os_ref,c.comment,c.location_cleaning_note,c.recorded_social_group_name,c.recorded_supergroup_name,c.sett_id,s.sett_name canonical_sett_name,s.notes sett_notes,c.location_type,c.location_coordinate_basis,c.location_easting,c.location_northing,
case when c.sett_id is not null then '01_KNOWN_SETT_MISSING_COORDINATES' when c.is_pm then '03_PM_NO_MATCHED_SETT' else '02_ALIVE_UNMATCHED_CAPTURE' end review_group
from analysis.capture_history_v1 c
join research.captures r on r.capture_id=c.capture_id
join research.individuals i on i.individual_id=r.individual_id
left join research.setts s on s.sett_id=c.sett_id
left join analysis.sett_inventory_v1 si on si.sett_id=c.sett_id
where nullif(btrim(c.recorded_sett_name),'') is not null
and (c.sett_id is null or si.easting is null or si.northing is null)
), enriched as (
select b.*, lateral_prev.capture_date previous_capture_date,lateral_prev.sett_name previous_sett_name,lateral_prev.recorded_sett_name previous_recorded_sett_name,
lateral_next.capture_date next_capture_date,lateral_next.sett_name next_sett_name,lateral_next.recorded_sett_name next_recorded_sett_name
from base b
left join lateral(select h.capture_date,h.sett_name,h.recorded_sett_name from analysis.capture_history_v1 h where h.tattoo=b.tattoo and (h.capture_date,h.capture_id)<(b.capture_date,b.capture_id) order by h.capture_date desc,h.capture_id desc limit 1) lateral_prev on true
left join lateral(select h.capture_date,h.sett_name,h.recorded_sett_name from analysis.capture_history_v1 h where h.tattoo=b.tattoo and (h.capture_date,h.capture_id)>(b.capture_date,b.capture_id) order by h.capture_date,h.capture_id limit 1) lateral_next on true
)
select recorded_sett_name,capture_location_text,case when is_pm then 'PM' else 'ALIVE' end record_type,review_group,capture_id,tattoo,capture_date,canonical_sett_name,recorded_social_group_name,recorded_supergroup_name,os_ref,location_type,location_easting,location_northing,location_coordinate_basis,comment,location_cleaning_note,sett_notes,previous_capture_date,previous_sett_name,previous_recorded_sett_name,next_capture_date,next_sett_name,next_recorded_sett_name
from enriched;
grant select on analysis.location_review_767_v1 to badger_readonly,badger_research_readonly;
comment on view analysis.location_review_767_v1 is 'Working V1 review of 767 capture records with recorded location text but no coordinate-linked canonical sett. Adjacent captures are clues, not proof of residency. Do not substitute SG centroid for sett coordinates.';


-- ================================================
-- MIGRATION VERSION: 20261026102501
-- MIGRATION NAME: woodchester_v1_remove_redundant_review_views_20261026
-- ================================================

-- Non-destructive V1 coauthor cleanup: remove redundant stand-alone diagnostic/review views.
-- Source data, stable V1 interfaces and their dependency views are retained.
drop view if exists analysis.location_review_767_v1;
drop view if exists analysis.historical_sett_candidates;
drop view if exists analysis.sett_field_team_review;
drop view if exists analysis.unmatched_capture_sett_review;
drop view if exists analysis.unmatched_coordinate_sett_candidates;
drop view if exists analysis.unresolved_recorded_sett_names;
drop view if exists analysis.capture_location_classified;
comment on schema analysis is 'Woodchester analysis layer: V1 researcher-facing views and core diagnostic analysis; no temporary 767-record location review tables are retained.';


-- ================================================
-- MIGRATION VERSION: 20261026104727
-- MIGRATION NAME: woodchester_v1_coauthor_both_schemas_readonly_20261026
-- ================================================

-- Coauthor access contract: both read-only roles can read canonical research and analysis.
-- Exclude three import/source-staging tables; keep raw and ingest outside coauthor grants.
grant usage on schema research,analysis to badger_readonly,badger_research_readonly;
do $$
declare t record;
begin
for t in select table_name from information_schema.tables where table_schema='research' and table_type='BASE TABLE' and table_name not in ('infection_probabilities_import','infection_quarterly_import','sett_coordinate_source_20261023') loop
execute format('grant select on research.%I to badger_readonly,badger_research_readonly',t.table_name);
end loop;
end $$;
grant select on all tables in schema analysis to badger_readonly,badger_research_readonly;
revoke insert,update,delete,truncate,references,trigger on all tables in schema research from badger_readonly,badger_research_readonly;
revoke insert,update,delete,truncate,references,trigger on all tables in schema analysis from badger_readonly,badger_research_readonly;

-- ================================================
-- MIGRATION VERSION: 20261026111509
-- MIGRATION NAME: woodchester_v1_minimal_clean_columns_20261026
-- ================================================

-- V1 additive cleaned fields: original source columns untouched.
alter table research.individuals add column if not exists sex_clean text generated always as (case when upper(btrim(coalesce(sex,''))) in ('MALE','FEMALE') then upper(btrim(sex)) else 'UNKNOWN' end) stored;
alter table research.individuals add column if not exists age_first_capture_clean text generated always as (case when upper(btrim(coalesce(age_first_capture,''))) in ('CUB','YEARLING','ADULT') then upper(btrim(age_first_capture)) else 'UNKNOWN' end) stored;
alter table research.captures add column if not exists sett_name_clean text;
alter table research.captures add column if not exists social_group_name_clean text;
update research.captures c set sett_name_clean=s.sett_name from research.setts s where c.sett_id=s.sett_id and c.sett_name_clean is distinct from s.sett_name;
update research.captures set sett_name_clean=null where sett_id is null and sett_name_clean is not null;
update research.captures c set social_group_name_clean=s.social_group_name from research.social_groups s where c.recorded_social_group_id=s.social_group_id and c.social_group_name_clean is distinct from s.social_group_name;
comment on column research.individuals.sex_clean is 'V1 computed standardised sex: MALE, FEMALE, UNKNOWN. Original sex preserved; UNKNOWN includes nonstandard/missing.';
comment on column research.individuals.age_first_capture_clean is 'V1 computed age at first capture: CUB YEARLING ADULT UNKNOWN. Original retained; UNKNOWN includes missing.';
comment on column research.captures.sett_name_clean is 'V1 canonical sett label from sett_id only; NULL means no assigned sett, including PM recovery locations; do not infer from grid.';
comment on column research.captures.social_group_name_clean is 'V1 canonical label linked to recorded_social_group_id, distinct from recorded_social_group_name; not proof of residency.';


-- ================================================
-- MIGRATION VERSION: 20261026111554
-- MIGRATION NAME: woodchester_v1_clean_names_trigger_20261026
-- ================================================

create or replace function research.sync_capture_clean_names_v1()
returns trigger language plpgsql security invoker set search_path=pg_catalog,research as $$
begin
  select s.sett_name into new.sett_name_clean from research.setts s where s.sett_id=new.sett_id;
  select sg.social_group_name into new.social_group_name_clean from research.social_groups sg where sg.social_group_id=new.recorded_social_group_id;
  return new;
end $$;
drop trigger if exists trg_capture_clean_names_v1 on research.captures;
create trigger trg_capture_clean_names_v1 before insert or update of sett_id,recorded_social_group_id,sett_name_clean,social_group_name_clean on research.captures for each row execute function research.sync_capture_clean_names_v1();
comment on function research.sync_capture_clean_names_v1() is 'V1 keeps canonical cleaned names aligned with respective foreign keys on inserts or edits; original recorded strings untouched.';


-- ================================================
-- MIGRATION VERSION: 20261026113003
-- MIGRATION NAME: woodchester_v1_consolidate_capture_fields_20261026
-- ================================================

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


-- ================================================
-- MIGRATION VERSION: 20261026113639
-- MIGRATION NAME: woodchester_v1_capture_view_on_single_table_20261026
-- ================================================

DO $$
DECLARE v text;
BEGIN
v:=pg_get_viewdef('analysis.capture_history'::regclass,true);
v:=replace(v,'cs.notes AS sampling_notes','c.sampling_notes AS sampling_notes');
v:=replace(v,'cc.transmitter AS collar_transmitter','c.collar_transmitter AS collar_transmitter');
v:=regexp_replace(v,'\mcs\.', 'c.', 'g');
v:=regexp_replace(v,'\mca\.', 'c.', 'g');
v:=regexp_replace(v,'\mcc\.', 'c.', 'g');
v:=regexp_replace(v,'\s+LEFT JOIN research\.capture_sampling cs ON c\.capture_id = cs\.capture_id','','gi');
v:=regexp_replace(v,'\s+LEFT JOIN research\.capture_assessments ca ON c\.capture_id = ca\.capture_id','','gi');
v:=regexp_replace(v,'\s+LEFT JOIN research\.capture_collars cc ON c\.capture_id = cc\.capture_id','','gi');
EXECUTE 'CREATE OR REPLACE VIEW analysis.capture_history AS ' || v;
END $$;

-- ================================================
-- MIGRATION VERSION: 20261026113818
-- MIGRATION NAME: woodchester_v1_fix_capture_view_remove_legacy_joins_20261026
-- ================================================

do $$ declare v text; begin
v:=pg_get_viewdef('analysis.capture_history'::regclass,true);
v:=replace(v,'LEFT JOIN research.capture_sampling cs ON c.capture_id = c.capture_id','');
v:=replace(v,'LEFT JOIN research.capture_assessments ca ON c.capture_id = c.capture_id','');
v:=replace(v,'LEFT JOIN research.capture_collars cc ON c.capture_id = c.capture_id','');
execute 'create or replace view analysis.capture_history as '||v;
end $$;

-- ================================================
-- MIGRATION VERSION: 20261026113852
-- MIGRATION NAME: woodchester_v1_retire_split_capture_detail_tables_20261026
-- ================================================

drop table research.capture_sampling;
drop table research.capture_assessments;
drop table research.capture_collars;

-- ================================================
-- MIGRATION VERSION: 20261026115339
-- MIGRATION NAME: woodchester_v1_minimal_public_schemas_20261026
-- ================================================

create schema if not exists internal_v1;
comment on schema internal_v1 is 'V1 internal implementation and legacy SQL views. Do not use as coauthor entry points. Public analytical interfaces reside in analysis.';
grant usage on schema internal_v1 to badger_readonly,badger_research_readonly;
do $$
declare name text;
begin
foreach name in array array[
'capture_diagnostic_summary_standardised','capture_history','capture_traits_standardised',
'capture_traits_v1','individual_traits_standardised','capture_location_classified_v2',
'capture_location_classified_v3','capture_location_fields_v1','capture_pm_grid_reference_review',
'capture_sett_coordinate_inventory','culture_results_standardised','diagnostic_interpretation_standardised',
'infection_probabilities','infection_quarterly_probabilities','sett_coordinate_source_name_review',
'sett_coordinate_unmatched_v1','sett_coordinates_approved','sett_social_group_observed','stat_pak_results_standardised'
] loop
execute format('alter view analysis.%I set schema internal_v1',name);
end loop;
end $$;
grant select on all tables in schema internal_v1 to badger_readonly,badger_research_readonly;
-- archive import/source-only tables into ingestion, preserving contents and identifiers
alter table research.infection_probabilities_import set schema ingest;
alter table research.infection_quarterly_import set schema ingest;
alter table research.sett_coordinate_source_20261023 set schema ingest;
revoke all privileges on all tables in schema ingest from badger_readonly,badger_research_readonly;


-- ================================================
-- MIGRATION VERSION: 20261026121618
-- MIGRATION NAME: woodchester_v1_remove_redundant_code_lookups_20261026
-- ================================================

-- V1 minimal research cleanup. Code lists are documented in V1 cleaning audit.
-- DPP samples: Serum Fresh; WB Field; Whole Blood; Serum Frozen.
-- DPP line: N=Negative; Nx=NegativeX; P=Positive; Px=PositiveX.
-- Stat-Pak: N=Negative (1); P=Positive (2); C=No Clotted Sample (3).
-- Verified: no foreign keys, dependent views or other PostgreSQL dependencies.
drop table research.dpp_sample_types;
drop table research.dpp_visual_line_results;
drop table research.stat_pak_results;


-- ================================================
-- MIGRATION VERSION: 20261026122407
-- MIGRATION NAME: woodchester_v1_consolidate_historical_names_20261026
-- ================================================

alter table research.individuals add column if not exists historical_names text;
alter table research.individuals add column if not exists n_historical_names bigint not null default 0;
with names as (
 select individual_id,string_agg(distinct btrim(name),' | ' order by btrim(name)) as names,count(distinct btrim(name))::bigint n
 from research.individual_names where nullif(btrim(name),'') is not null group by individual_id
)
update research.individuals i set historical_names=n.names,n_historical_names=n.n from names n where n.individual_id=i.individual_id;
do $$
declare v text; a integer; b integer;
begin
v:=pg_get_viewdef('internal_v1.capture_history'::regclass,true);
a:=strpos(v,'WITH individual_name_summary AS (');
b:=strpos(v,'SELECT c.capture_id');
if a=0 or b<=a then raise exception 'Unexpected capture view SQL; abort'; end if;
v:=left(v,a-1) || 'WITH individual_name_summary AS (SELECT individual_id,historical_names,n_historical_names FROM research.individuals) ' || substr(v,b);
execute 'create or replace view internal_v1.capture_history as '||v;
end $$;
drop table research.individual_names;
comment on column research.individuals.historical_names is 'Original names from Access tblCaptures; multiple distinct recorded names separated by |, TR retained as recorded.';
comment on column research.individuals.n_historical_names is 'Count of distinct original names associated with individual, including TR placeholder.';


-- ================================================
-- MIGRATION VERSION: 20261026123558
-- MIGRATION NAME: woodchester_v1_remove_unverified_name_fields_20261026
-- ================================================

do $$ declare v text; begin
v:=pg_get_viewdef('internal_v1.capture_history'::regclass,true);
v:=replace(v,'individuals.historical_names','NULL::text AS historical_names');
v:=replace(v,'individuals.n_historical_names','NULL::bigint AS n_historical_names');
execute 'create or replace view internal_v1.capture_history as '||v;
end $$;
alter table research.individuals drop column historical_names;
alter table research.individuals drop column n_historical_names;


-- ================================================
-- MIGRATION VERSION: 20261026125524
-- MIGRATION NAME: woodchester_v1_standardise_condition_and_eartags_20261026
-- ================================================

alter table research.captures add column condition_clean text generated always as (case when condition is null then null when upper(btrim(condition)) in ('V.GOOD','VERY GOOD') then 'VERY GOOD' when upper(btrim(condition)) in ('GOOD','FAIR','POOR') then upper(btrim(condition)) else upper(btrim(condition)) end) stored;
alter table research.captures add column eartags_clean text generated always as (case when eartags is null then null when upper(btrim(eartags)) in ('NEITHER','NONE','NOT TAGGED','NOT TAGûGED') then 'NONE' when upper(btrim(eartags))='RETAGGEûD' then 'RETAGGED' else upper(btrim(eartags)) end) stored;
comment on column research.captures.condition_clean is 'Normalized condition categories: V.GOOD→VERY GOOD; GOOD, FAIR, POOR unchanged. NULL unchanged. Original condition preserved.';
comment on column research.captures.eartags_clean is 'Normalized recorded ear-tag descriptions: NEITHER/NONE/NOT TAGGED/NOT TAGûGED→NONE, RETAGGEûD→RETAGGED; original unchanged. Treat REMOVED as separate from NONE.';


-- ================================================
-- MIGRATION VERSION: 20261026130624
-- MIGRATION NAME: v1_collar_label_normalisation_20261026
-- ================================================

alter table research.captures add column collar_transmitter_clean text generated always as (case when collar_transmitter in ('FIT','FITTED') then 'FITTED' when collar_transmitter in ('PRES','PRESENT') then 'PRESENT' when collar_transmitter in ('REPL','REPLACED') then 'REPLACED' else collar_transmitter end) stored

-- ================================================
-- MIGRATION VERSION: 20261026130633
-- MIGRATION NAME: v1_elisa_result_label_normalisation_20261026
-- ================================================

alter table research.elisa_tests add column test_result_clean text generated always as (case when test_result in ('NO SERA','NO SERUM') then 'NO SERUM' else test_result end) stored

-- ================================================
-- MIGRATION VERSION: 20261026151732
-- MIGRATION NAME: v1_consolidate_sett_coordinates_and_rename_undated_links_20261026
-- ================================================

alter table research.setts add column easting numeric;
alter table research.setts add column northing numeric;
alter table research.setts add column coordinate_system text;
alter table research.setts add column accuracy_m numeric;
alter table research.setts add column coordinate_source text;
alter table research.setts add column coordinate_observed_on date;
update research.setts s set easting=e.easting,northing=e.northing,coordinate_system=e.coordinate_system,accuracy_m=e.accuracy_m,coordinate_source=e.source_reference,coordinate_observed_on=e.observed_on from research.sett_location_evidence e where e.sett_id=s.sett_id and e.review_status='APPROVED';
create or replace view internal_v1.sett_coordinates_approved as select sett_name,easting,northing,coordinate_system,accuracy_m,coordinate_source as source_reference,coordinate_observed_on as observed_on from research.setts where easting is not null and northing is not null;
create or replace view internal_v1.capture_sett_coordinate_inventory as
select s.sett_name,count(c.capture_id) as n_captures,count(c.capture_id) filter(where c.is_pm) as n_pm_records,min(c.capture_date) as first_capture_date,max(c.capture_date) as last_capture_date,s.easting,s.northing,s.coordinate_system,s.accuracy_m,s.coordinate_source,case when s.easting is not null and s.northing is not null then 'COORDINATES_APPROVED'::text else 'COORDINATES_MISSING'::text end as coordinate_status from research.setts s left join research.captures c on c.sett_id=s.sett_id group by s.sett_id,s.sett_name,s.easting,s.northing,s.coordinate_system,s.accuracy_m,s.coordinate_source;
drop table research.sett_location_evidence;
alter table research.sett_social_group_history rename to sett_social_group_links;
comment on table research.sett_social_group_links is 'Undated sett–social group associations imported from the original sett lookup, not annual membership or verified territory occupancy.';
comment on column research.setts.coordinate_source is 'Original named-sett CSV filename and source sett label; point is fixed, not year-specific.';


-- ================================================
-- MIGRATION VERSION: 20261026152422
-- MIGRATION NAME: v1_annual_sett_polygon_crosswalk_table_20261026
-- ================================================

create table if not exists research.sett_annual_territory_matches (
year integer not null check(year between 1977 and 2025),
sett_id bigint not null references research.setts(sett_id),
polygon_id text,
territory_name text,
match_status text not null check(match_status in ('ONE_POLYGON','MULTIPLE_POLYGONS','OUTSIDE_ALL','NO_COORDINATE','ON_BOUNDARY')),
polygon_source text not null,
coordinate_source text,
created_at timestamptz not null default now(),
primary key(year,sett_id,polygon_id),
constraint status_polygon_consistency check ((polygon_id is null and match_status in ('OUTSIDE_ALL','NO_COORDINATE')) or (polygon_id is not null and match_status in ('ONE_POLYGON','MULTIPLE_POLYGONS','ON_BOUNDARY')))
);
comment on table research.sett_annual_territory_matches is 'Annual polygon point-in-polygon crosswalk, not biologically verified social-group residency. Row per matching territory; NULL polygon where no coordinates or no containing polygon. Populated from audited 1977–2025 shapefiles using scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R.';


-- ================================================
-- MIGRATION VERSION: 20261026152435
-- MIGRATION NAME: v1_annual_sett_polygon_nullable_unmatched_keys_20261026
-- ================================================

alter table research.sett_annual_territory_matches drop constraint sett_annual_territory_matches_pkey; alter table research.sett_annual_territory_matches alter column polygon_id drop not null; alter table research.sett_annual_territory_matches add column match_id bigint generated always as identity primary key; create unique index sett_annual_territory_matches_year_sett_polygon_uq on research.sett_annual_territory_matches(year,sett_id,polygon_id) nulls not distinct;

-- ================================================
-- MIGRATION VERSION: 20261026152809
-- MIGRATION NAME: v1_annual_sett_crosswalk_readonly_grants_20261026
-- ================================================

grant select on research.sett_annual_territory_matches to badger_readonly,badger_research_readonly

-- ================================================
-- MIGRATION VERSION: 20261028110622
-- MIGRATION NAME: capture_sett_location_standardised_v1
-- ================================================

create or replace view analysis.capture_sett_location_standardised_v1 with (security_invoker=true) as
select c.capture_id,v.tattoo,c.capture_date,c.is_pm,c.sett_id,
 c.recorded_sett_name,
 case when c.sett_id is not null then upper(regexp_replace(s.sett_name,'[^A-Za-z0-9]','','g')) else 'OTHER' end as sett_clean,
 case when c.sett_id is null then coalesce(nullif(btrim(c.recorded_sett_name),''),
    nullif(btrim(c.capture_location_text),''),nullif(btrim(c.os_ref),'')) else null end as other_location_info,
 c.capture_location_text,c.os_ref,v.location_class,
 case when c.sett_id is not null and s.easting is not null and s.northing is not null then s.easting
      when v.location_class='GRID_REFERENCED_PM_LOCATION' then v.grid_sw_easting else null end as location_easting,
 case when c.sett_id is not null and s.easting is not null and s.northing is not null then s.northing
      when v.location_class='GRID_REFERENCED_PM_LOCATION' then v.grid_sw_northing else null end as location_northing,
 case when c.sett_id is not null and s.easting is not null and s.northing is not null then 'SETT_POINT'
      when v.location_class='GRID_REFERENCED_PM_LOCATION' and v.grid_sw_easting is not null and v.grid_sw_northing is not null then 'GRID_SQUARE_SOUTHWEST_CORNER'
      else 'NO_COORDINATE' end as coordinate_basis,
 case when (c.sett_id is not null and s.easting is not null and s.northing is not null) or
           (v.location_class='GRID_REFERENCED_PM_LOCATION' and v.grid_sw_easting is not null and v.grid_sw_northing is not null)
      then 'EPSG:27700' else null end as location_crs,
 case when v.location_class='GRID_REFERENCED_PM_LOCATION' then v.newly_parsed_cell_width_m else null end as grid_cell_width_m
from research.captures c
left join research.setts s on s.sett_id=c.sett_id
left join analysis.capture_location_v1 v on v.capture_id=c.capture_id;
grant select on analysis.capture_sett_location_standardised_v1 to badger_readonly,badger_research_readonly;

-- ================================================
-- MIGRATION VERSION: 20261103075121
-- MIGRATION NAME: wecs_v1_provisional_readonly_views
-- ================================================


create view analysis.encounters_standardised_v1 with (security_invoker = true) as
with base as (
 select c.capture_id, l.tattoo, c.capture_date, c.moc as original_moc, c.is_pm,
 c.recorded_sett_name as original_location_name, c.capture_location_text as original_location_text,
 c.os_ref as original_os_ref, c.comment as original_comment, c.pm_cause as original_pm_cause,
 l.location_class as prior_location_class, l.reference_source as prior_reference_source,
 l.grid_sw_easting, l.grid_sw_northing, l.newly_parsed_cell_width_m,
 l.spatial_interpretation, l.positional_precision_note, c.sett_id, s.sett_name,
 s.easting as sett_easting, s.northing as sett_northing
 from research.captures c
 join analysis.capture_location_v1 l using (capture_id)
 left join research.setts s on s.sett_id=c.sett_id
), classified as (
 select *,
 case
  when original_moc='TRAP' then 'LIVE_TRAP'
  when original_moc='NET' then 'NET'
  when original_moc='DART GUN' then 'DART'
  when original_moc='SNARE' then 'SNARE'
  when original_moc='RTA' then 'ROAD_TRAFFIC'
  when original_moc='FOUND DEAD' then 'FOUND_DEAD'
  when original_moc='SHOT (GP)' or original_moc='SHOT' then 'SHOT'
  when original_moc='REMOVAL' then 'REMOVAL'
  when original_moc='FOUND EXT' then 'FOUND_EXTERNAL'
  when original_moc='DEAD SN/TR' then 'DEAD_SNARE_TRAP'
  when original_moc='PUT DOWN' then 'PUT_DOWN'
  when original_moc='ON ROAD' then 'ON_ROAD'
  when original_moc='REPORTED BY MEMBER OF THE PUBLIC' then 'PUBLIC_REPORT'
  else 'UNKNOWN' end as encounter_type,
 case
  when original_moc in ('TRAP','NET','DART GUN') then 'ALIVE'
  when original_moc in ('FOUND DEAD','DEAD SN/TR') then 'DEAD'
  else 'UNKNOWN' end as alive_when_encountered,
 case
  when original_moc='TRAP' and (coalesce(original_comment,'') || ' ' || coalesce(original_pm_cause,'') || ' ' || coalesce(original_location_text,'')) ~* 'euthan|put down|put to sleep' then 'EUTHANISED'
  when original_moc='TRAP' and (coalesce(original_comment,'') || ' ' || coalesce(original_location_text,'')) ~* 'died in holding|died in cage' then 'DIED_AFTER_CAPTURE'
  when original_moc='FOUND DEAD' then 'FOUND_DEAD'
  else 'UNKNOWN' end as encounter_outcome,
 case
  when original_moc='TRAP' then 'CAPTURE_SITE'
  when original_moc in ('FOUND DEAD','RTA','FOUND EXT','ON ROAD','DEAD SN/TR') then 'RECOVERY_OR_DISCOVERY_SITE'
  else 'UNKNOWN' end as location_role,
 case
  when sett_id is not null then 'SETT'
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' and original_moc='RTA' then 'ROAD'
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' then 'RECOVERY_AREA'
  when original_moc='TRAP' and coalesce(original_location_text,'') ~* 'FIELD|BOUNDARY|WOOD|BUILDING' then 'REMOTE_OR_NON_SETT'
  else 'UNKNOWN' end as location_type,
 case
  when prior_location_class='KNOWN_SETT' and sett_easting is not null and sett_northing is not null then sett_easting
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' then grid_sw_easting
  else null end as location_easting,
 case
  when prior_location_class='KNOWN_SETT' and sett_easting is not null and sett_northing is not null then sett_northing
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' then grid_sw_northing
  else null end as location_northing,
 case
  when prior_location_class='KNOWN_SETT' and sett_easting is not null and sett_northing is not null then 'SETT_POINT'
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' and grid_sw_easting is not null then 'GRID_CELL_SW_CORNER'
  else 'NONE' end as coordinate_representation,
 case
  when prior_location_class='KNOWN_SETT' and sett_easting is not null and sett_northing is not null then 'SETT_LOOKUP'
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' and grid_sw_easting is not null then coalesce(prior_reference_source,'PARSED_GRID')
  else 'NONE' end as location_source,
 case
  when prior_location_class='KNOWN_SETT' and sett_easting is not null and sett_northing is not null then 'PROVISIONAL'
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' and grid_sw_easting is not null and grid_sw_northing is not null then 'PROVISIONAL'
  else 'UNRESOLVED' end as location_status
 from base
)
select *,
 case when location_easting is not null and location_northing is not null then true else false end as has_spatial_location,
 case when location_status='UNRESOLVED' then true else false end as needs_location_review,
 case when original_moc='TRAP' and is_pm=true then true else false end as review_trap_pm,
 case when original_moc='TRAP' and sett_id is null then true else false end as review_unlinked_trap,
 case when original_moc='TRAP' and sett_id is not null and (sett_easting is null or sett_northing is null) then true else false end as review_sett_missing_xy,
 case when is_pm and prior_location_class='KNOWN_SETT' then true else false end as review_pm_sett_role,
 case when is_pm and prior_location_class='GRID_REFERENCED_PM_LOCATION' and original_moc='TRAP' then true else false end as review_trap_pm_grid_role,
 'WECS_V1_PROVISIONAL'::text as rule_version
from classified;

comment on view analysis.encounters_standardised_v1 is 'Non-destructive provisional encounter crosswalk built on existing captures, setts and historical capture_location_v1 interpretations. Coordinates are NOT independently reverified. Grid-cell values are southwest corners, NOT exact points. No social group or residency inference.';

create view analysis.encounter_review_queue_v1 with (security_invoker = true) as
select capture_id,tattoo,capture_date,original_moc,is_pm,encounter_type,encounter_outcome,
original_location_name,original_location_text,original_os_ref,original_comment,
original_pm_cause,sett_id,sett_name,prior_location_class,spatial_interpretation,
location_easting,location_northing,coordinate_representation,location_status,
review_unlinked_trap,review_trap_pm,review_sett_missing_xy,review_pm_sett_role,
review_trap_pm_grid_role,
case
 when review_unlinked_trap then '01_UNLINKED_TRAP'
 when review_trap_pm then '02_TRAP_PM'
 when review_sett_missing_xy then '03_SETT_MISSING_XY'
 when review_trap_pm_grid_role then '04_TRAP_PM_GRID_ROLE'
 when needs_location_review then '05_UNRESOLVED_LOCATION'
 when review_pm_sett_role then '06_PM_SETT_ROLE'
 else 'OTHER' end as review_priority
from analysis.encounters_standardised_v1
where review_unlinked_trap or review_trap_pm or review_sett_missing_xy or review_trap_pm_grid_role or needs_location_review or review_pm_sett_role;
comment on view analysis.encounter_review_queue_v1 is 'Prioritised read-only audit queue. Not every record needs human review: batch-review recurring settled names and historical aliases first. Views do not change research captures.';


-- ================================================
-- MIGRATION VERSION: 20261103121448
-- MIGRATION NAME: wecs_v1_confirm_seven_capture_pm_episodes
-- ================================================


create table if not exists research.encounter_episode_decisions (
 live_capture_id bigint primary key references research.captures(capture_id),
 pm_capture_id bigint not null unique references research.captures(capture_id),
 episode_outcome text not null check (episode_outcome in ('EUTHANISED','DIED_AFTER_CAPTURE')),
 decision_status text not null default 'CONFIRMED' check (decision_status in ('CONFIRMED','PROVISIONAL')),
 field_location_basis text not null default 'LIVE_RECORD',
 decision_note text not null,
 review_flags text[] not null default '{}'::text[],
 decision_source text not null default 'Researcher-reviewed paired records, 2026-11-03',
 decided_at timestamptz not null default now(),
 constraint separate_records check (live_capture_id<>pm_capture_id)
);
alter table research.encounter_episode_decisions enable row level security;
comment on table research.encounter_episode_decisions is 'WECS v1: curated links between a field encounter record and its companion PM/death record. Neither source row is overwritten. Each entry retains evidence, review flags and decision provenance.';
comment on column research.encounter_episode_decisions.field_location_basis is 'LIVE_RECORD means reference field-encounter coordinates from the corresponding live record, not necessarily the place of death or PM examination. No missing coordinate is imputed.';
do $$
declare n integer;
begin
 select count(*) into n from (values
  (6508::bigint,17565::bigint),(12854,16903),(14193,16895),
  (14757,16878),(14571,17457),(14756,16879),(16896,16853)
 ) v(live_id,pm_id)
 join research.captures a on a.capture_id=v.live_id
 join research.captures b on b.capture_id=v.pm_id
 where a.individual_id=b.individual_id and a.capture_date=b.capture_date
   and a.is_pm=false and b.is_pm=true;
 if n<>7 then raise exception 'Pair validation failed: % / 7',n; end if;
end $$;
insert into research.encounter_episode_decisions
(live_capture_id,pm_capture_id,episode_outcome,decision_status,decision_note,review_flags)
values
(6508,17565,'EUTHANISED','CONFIRMED','Same individual/date; Inchbrook live capture, veterinarian euthanised before recovery from anaesthetic; separate PM record.',array[]::text[]),
(12854,16903,'EUTHANISED','CONFIRMED','Same individual/date; recaptured at Top to examine leg-cuff injuries, then euthanised; prior leg-cuff capture/release is a separate dated event.',array[]::text[]),
(14193,16895,'EUTHANISED','CONFIRMED','Same individual/date; live trapping at West and euthanasia; PM adds pathological observations.',array[]::text[]),
(14757,16878,'EUTHANISED','CONFIRMED','Same individual/date; trapped at Windsor Edge, euthanised at sampling facility following deterioration.',array[]::text[]),
(14571,17457,'DIED_AFTER_CAPTURE','CONFIRMED','Same individual/date; trapped at Windsor Edge, died during/after anaesthesia. PM record additionally reports RTA/ruptured diaphragm; separate PM OS reference is retained and must not replace trap-sett coordinate.',array['PM_RTA_CAUSE_TO_REVIEW','PM_OS_REFERENCE_DIFFERS_FROM_SETT']::text[]),
(14756,16879,'EUTHANISED','CONFIRMED','Same individual/date; captured at Windsor Edge, euthanised after trap-induced jaw injury. Weight discrepancy between source rows retained.',array['WEIGHT_DISCREPANCY']::text[]),
(16896,16853,'EUTHANISED','CONFIRMED','Same individual/date; found alive injured on track between Box and West, then euthanised; trap designation in live record is inconsistent with narrative. Actual field coordinates unresolved.',array['ENCOUNTER_METHOD_TO_REVIEW','FIELD_LOCATION_UNRESOLVED']::text[])
on conflict (live_capture_id) do nothing;

create or replace view analysis.encounter_episode_decisions_v1 with (security_invoker=true) as
select d.live_capture_id,d.pm_capture_id,d.episode_outcome,d.decision_status,
 d.field_location_basis,d.decision_note,d.review_flags,d.decision_source,d.decided_at,
 l.tattoo,l.capture_date,l.sett_id as field_sett_id,l.sett_name as field_sett_name,
 l.location_easting as field_easting,l.location_northing as field_northing,
 l.coordinate_representation as field_coordinate_representation,
 p.location_easting as original_pm_easting,p.location_northing as original_pm_northing,
 p.coordinate_representation as original_pm_coordinate_representation
from research.encounter_episode_decisions d
join analysis.encounters_standardised_v1 l on l.capture_id=d.live_capture_id
join analysis.encounters_standardised_v1 p on p.capture_id=d.pm_capture_id;

create or replace view analysis.encounters_with_episodes_v1 with (security_invoker=true) as
select e.*,
 coalesce(dl.live_capture_id,dp.live_capture_id) as episode_primary_capture_id,
 coalesce(dl.pm_capture_id,dp.pm_capture_id) as episode_pm_capture_id,
 case when dl.live_capture_id is not null then 'FIELD_RECORD'
      when dp.pm_capture_id is not null then 'PM_COMPANION'
      else 'STANDALONE' end as episode_record_role,
 coalesce(dl.episode_outcome,dp.episode_outcome,e.encounter_outcome) as resolved_episode_outcome,
 coalesce(dl.decision_status,dp.decision_status) as episode_decision_status,
 coalesce(dl.review_flags,dp.review_flags,array[]::text[]) as episode_review_flags,
 primary_field.location_easting as episode_field_easting,
 primary_field.location_northing as episode_field_northing,
 primary_field.coordinate_representation as episode_field_coordinate_representation
from analysis.encounters_standardised_v1 e
left join research.encounter_episode_decisions dl on dl.live_capture_id=e.capture_id
left join research.encounter_episode_decisions dp on dp.pm_capture_id=e.capture_id
left join analysis.encounters_standardised_v1 primary_field
 on primary_field.capture_id=coalesce(dl.live_capture_id,dp.live_capture_id);

comment on view analysis.encounters_with_episodes_v1 is 'WECS v1: all original capture and PM rows retained, with curated companion-record links and shared field-encounter coordinates. The original per-record location is unchanged.';


-- ================================================
-- MIGRATION VERSION: 20261103123508
-- MIGRATION NAME: wecs_v1_review_1977_1981_net_pm_pairs
-- ================================================


do $$
begin
 if not exists (
 select 1 from research.captures a join research.captures b on a.individual_id=b.individual_id
 where a.capture_id=9440 and b.capture_id=9439
 and a.moc='NET' and a.is_pm=false and b.moc='PUT DOWN' and b.is_pm=true
 and b.capture_date between a.capture_date and a.capture_date + 1
 ) then raise exception '1977 pair fails verification'; end if;
 if not exists (
 select 1 from research.captures a join research.captures b on a.individual_id=b.individual_id
 where a.capture_id=8939 and b.capture_id=405
 and a.moc='NET' and a.is_pm=false and b.moc='FOUND DEAD' and b.is_pm=true
 and b.capture_date=a.capture_date + 2
 ) then raise exception '1981 distinct encounter verification failed'; end if;
end $$;

insert into research.encounter_episode_decisions
 (live_capture_id,pm_capture_id,episode_outcome,decision_status,field_location_basis,decision_note,review_flags,decision_source)
values
 (9440,9439,'EUTHANISED','CONFIRMED','LIVE_RECORD',
 'G010 netted at Old Byre 1977-07-18 (poor condition), then put down 1977-07-19 with PM cause EUTH. Researcher-reviewed as one capture/euthanasia episode documented by two source records. The one-day later PM record is retained at its original date.',
 array['NEXT_DAY_PM_DATE']::text[],
 'Researcher decision 2026-11-03; original capture 9440 and PM 9439')
on conflict (live_capture_id) do nothing;

create table if not exists research.encounter_pair_nonlinks (
 first_capture_id bigint not null references research.captures(capture_id),
 second_capture_id bigint not null references research.captures(capture_id),
 decision text not null default 'SEPARATE_EVENTS' check (decision='SEPARATE_EVENTS'),
 decision_note text not null,
 decision_source text not null,
 decided_at timestamptz not null default now(),
 primary key (first_capture_id,second_capture_id),
 constraint different_event_ids check (first_capture_id<>second_capture_id)
);
alter table research.encounter_pair_nonlinks enable row level security;
comment on table research.encounter_pair_nonlinks is 'Documented negative pairing decisions; prevents independent live captures and later PM/dead recoveries from being accidentally merged during episode inference. Retain original source rows.';
insert into research.encounter_pair_nonlinks
 (first_capture_id,second_capture_id,decision,decision_note,decision_source)
values
 (8939,405,'SEPARATE_EVENTS',
 'Y030 netted at MEAD on 1981-07-14; separate recovery at ARTHURS on 1981-07-16 (FOUND DEAD, PM cause STARV). Researcher reviewed as two distinct encounter events, not duplicate capture/PM documentation. The initial NET record may be treated as PRESUMED_RELEASED under the operational default, never confirmed released; the death record retains independent recovery coordinates.',
 'Researcher decision 2026-11-03; source capture 8939 and recovery 405')
on conflict (first_capture_id,second_capture_id) do nothing;

create or replace view analysis.encounter_pair_nonlinks_v1 with (security_invoker=true) as
select n.first_capture_id,n.second_capture_id,n.decision,n.decision_note,n.decision_source,n.decided_at,
 a.tattoo,a.capture_date as first_date,a.original_moc as first_method,
 b.capture_date as second_date,b.original_moc as second_method
from research.encounter_pair_nonlinks n
join analysis.encounters_standardised_v1 a on a.capture_id=n.first_capture_id
join analysis.encounters_standardised_v1 b on b.capture_id=n.second_capture_id;


-- ================================================
-- MIGRATION VERSION: 20261103123825
-- MIGRATION NAME: wecs_six_field_researcher_view_v1
-- ================================================


create or replace view analysis.encounters_v1 with (security_invoker=true) as
with source as (
 select e.capture_id,e.tattoo,e.capture_date,e.is_pm,e.sett_id,e.original_moc,
 e.original_location_name,e.original_location_text,e.original_os_ref,
 e.prior_location_class,e.prior_reference_source,
 e.sett_name,e.location_easting as prior_easting,e.location_northing as prior_northing,
 e.coordinate_representation as prior_coordinate_representation,
 e.newly_parsed_cell_width_m,
 e.episode_primary_capture_id,e.episode_record_role,e.resolved_episode_outcome,
 e.episode_field_easting,e.episode_field_northing,e.episode_field_coordinate_representation,
 c.release_assessment,c.comment,c.pm_cause,
 coalesce(c.comment,'') || ' ' || coalesce(c.pm_cause,'') || ' ' || coalesce(c.capture_location_text,'') as narrative,
 case when upper(coalesce(trim(c.capture_location_text),'')) in ('FIELD','WOOD','HEDGE','BOUNDARY','BUILDING','GARDEN','OTHER','OUTSIDE WP','NOT WP') 
           and e.sett_id is not null
           and coalesce(c.moc,'') in ('TRAP','NET','SNARE','FOUND EXT','RTA')
      then true else false end as sett_point_context_conflict
 from analysis.encounters_with_episodes_v1 e
 join research.captures c using(capture_id)
), standardised as (
 select *,
 case
  when original_moc='TRAP' then 'TRAP'
  when original_moc='NET' then 'NET'
  when original_moc='SNARE' then 'SNARE'
  when original_moc='DART GUN' then 'DART'
  when original_moc='FOUND EXT' then 'FOUND_IN_EXTREMIS'
  when original_moc='FOUND DEAD' then 'FOUND_DEAD'
  when original_moc='RTA' then 'RTA'
  when original_moc='SHOT (GP)' or original_moc='SHOT' then 'SHOT'
  when original_moc='REMOVAL' then 'REMOVAL'
  when original_moc='PUT DOWN' then 'PUT_DOWN'
  when original_moc='DEAD SN/TR' then 'DEAD_SNARE_TRAP'
  when original_moc='ON ROAD' then 'ON_ROAD'
  when original_moc='REPORTED BY MEMBER OF THE PUBLIC' then 'PUBLIC_REPORT'
  else 'UNKNOWN' end as encounter_type_clean,
 case
  when episode_primary_capture_id is not null then
    case when resolved_episode_outcome='DIED_AFTER_CAPTURE' then 'DIED'
         else resolved_episode_outcome end
  when original_moc in ('TRAP','NET','SNARE','DART GUN','FOUND EXT','PUT DOWN') 
       and narrative ~* 'euthan|put down|put to sleep|humanely destroy' then 'EUTHANISED'
  when original_moc in ('TRAP','NET','SNARE','DART GUN','FOUND EXT')
       and (release_assessment='Death' or narrative ~* 'died under anaesth|died in holding|died overnight|did not recover from anaesth|dead on arrival') then 'DIED'
  when original_moc in ('FOUND DEAD','DEAD SN/TR') then 'FOUND_DEAD'
  when original_moc in ('RTA','ON ROAD') and is_pm then 'FOUND_DEAD'
  when original_moc in ('SHOT','SHOT (GP)') and is_pm then 'KILLED'
  when original_moc='REMOVAL' and is_pm and coalesce(pm_cause,'') ~* 'KILLED|SHOT' then 'KILLED'
  when original_moc='PUT DOWN' and is_pm then 'EUTHANISED'
  when original_moc in ('TRAP','NET','SNARE','DART GUN') and not is_pm then 'PRESUMED_RELEASED'
  else 'UNKNOWN' end as outcome_clean,
 case
  when episode_record_role='PM_COMPANION' then 'LINKED_FIELD_SITE'
  when upper(coalesce(trim(original_location_text),''))='SETT' and sett_id is not null then 'SETT'
  when original_moc='RTA' or original_moc='ON ROAD' then 'ROAD'
  when original_moc='FOUND DEAD' or original_moc='DEAD SN/TR' then 'RECOVERY_SITE'
  when upper(coalesce(trim(original_location_text),'')) in ('FIELD','WOOD','HEDGE','BOUNDARY','BUILDING','GARDEN') then upper(trim(original_location_text))
  when original_moc='NET' or original_moc='SNARE' then 'OTHER_CAPTURE_SITE'
  when sett_id is not null then 'SETT_ASSOCIATION'
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' then 'RECOVERY_SITE'
  else 'UNKNOWN' end as location_type_clean,
 case
  when episode_record_role='PM_COMPANION' then episode_field_easting
  when sett_point_context_conflict then null
  else prior_easting end as x_clean,
 case
  when episode_record_role='PM_COMPANION' then episode_field_northing
  when sett_point_context_conflict then null
  else prior_northing end as y_clean,
 case
  when episode_record_role='PM_COMPANION' and episode_field_easting is not null
       then 'LINKED_SETT_POINT_PROVISIONAL'
  when episode_record_role='PM_COMPANION' then 'UNRESOLVED'
  when sett_point_context_conflict then 'SETT_COORDINATE_CONFLICT'
  when prior_easting is null or prior_northing is null then 'UNRESOLVED'
  when prior_coordinate_representation='GRID_CELL_SW_CORNER'
       and newly_parsed_cell_width_m is not null then 'GRID_CELL'
  when prior_coordinate_representation='GRID_CELL_SW_CORNER' then 'GRID_CELL_PRECISION_UNCONFIRMED'
  when prior_coordinate_representation='SETT_POINT' and upper(coalesce(trim(original_location_text),''))='SETT' then 'SETT_POINT_PROVISIONAL'
  when prior_coordinate_representation='SETT_POINT' then 'SETT_ASSOCIATION_PROVISIONAL'
  else 'PROVISIONAL' end as quality_clean
 from source
)
select capture_id,tattoo,capture_date,is_pm,sett_id,
 episode_primary_capture_id,episode_record_role,
 encounter_type_clean as encounter_type,
 outcome_clean as outcome,
 location_type_clean as location_type,
 x_clean as location_easting,
 y_clean as location_northing,
 quality_clean as location_quality
from standardised;

comment on view analysis.encounters_v1 is
'WECS v1 six standardised fields: encounter_type, outcome, location_type, location_easting, location_northing, location_quality. Other fields are identifiers and original PM/sett/episode references. PRESUMED_RELEASED is an operational assumption for routine non-PM TRAP/NET/SNARE/DART records unless documentary death/euthanasia or a curated episode overrides. PM companions inherit field-site coordinates via episode decision without overwriting their original PM location. Grid locations remain southwest-corner coordinates, not exact sites. Existing research tables and historical parser remain unmodified. Location conflict values are suppressed from final coordinates and preserved in prior spatial views. No social-group inference.';

create or replace view analysis.encounters_review_v1 with (security_invoker=true) as
select f.capture_id,f.tattoo,f.capture_date,f.is_pm,f.encounter_type,f.outcome,f.location_type,
 f.location_easting,f.location_northing,f.location_quality,f.episode_primary_capture_id,
 c.moc as original_moc,c.recorded_sett_name,c.capture_location_text,c.os_ref,c.comment,c.pm_cause,
 case
  when f.location_quality='SETT_COORDINATE_CONFLICT' then 'SETT_VS_FIELD_LOCATION'
  when f.location_quality='UNRESOLVED' then 'NO_COORDINATES'
  when f.location_quality='GRID_CELL_PRECISION_UNCONFIRMED' then 'GRID_PRECISION_CHECK'
  when f.encounter_type='UNKNOWN' then 'ENCOUNTER_TYPE_UNKNOWN'
  when f.outcome='UNKNOWN' and f.encounter_type in ('REMOVAL','FOUND_IN_EXTREMIS','PUT_DOWN') then 'OUTCOME_UNKNOWN'
  else 'OTHER' end as review_reason
from analysis.encounters_v1 f join research.captures c using(capture_id)
where f.location_quality in ('SETT_COORDINATE_CONFLICT','UNRESOLVED','GRID_CELL_PRECISION_UNCONFIRMED')
 or f.encounter_type='UNKNOWN'
 or (f.outcome='UNKNOWN' and f.encounter_type in ('REMOVAL','FOUND_IN_EXTREMIS','PUT_DOWN'));
comment on view analysis.encounters_review_v1 is 'Investigation queue derived from simplified WECS v1. All original sources remain available; no unresolved case is silently imputed.';



-- ================================================
-- MIGRATION VERSION: 20261103133446
-- MIGRATION NAME: wecs_confirm_n070_rta_episode_with_original_pm_discovery
-- ================================================


do $$
begin
 if not exists (
 select 1 from research.captures a join research.captures b on a.individual_id=b.individual_id
 where a.capture_id=1672 and b.capture_id=1674 and a.moc='PUT DOWN' and b.moc='FOUND EXT'
 and a.is_pm=false and b.is_pm=true and a.capture_date=b.capture_date+1
 and a.weight=b.weight
 ) then raise exception 'N070 identity/date/weight validation failed'; end if;
end $$;
insert into research.encounter_episode_decisions
 (live_capture_id,pm_capture_id,episode_outcome,decision_status,field_location_basis,decision_note,review_flags,decision_source)
values
 (1672,1674,'EUTHANISED','CONFIRMED','PM_RECORD',
 'N070: 1987-06-01 found in extremis in Boundary Court field, PM field lists RTA cause; 1987-06-02 same badger (10.6kg) recorded PUT DOWN. Researcher confirms one RTA-associated episode spanning two record dates; outcome euthanised (PUT DOWN). The earlier FOUND EXT source is treated as the original field discovery, not the later PUT DOWN entry.',
 array['PM_RECORD_PRECEDES_PUT_DOWN','RTA_ASSOCIATED','FIELD_COORDINATE_NEEDS_VERIFICATION']::text[],
 'Researcher confirmation 2026-11-03, paired original records 1674 and 1672')
on conflict (live_capture_id) do nothing;

create or replace view analysis.encounter_episode_decisions_v1 with (security_invoker=true) as
select d.live_capture_id,d.pm_capture_id,d.episode_outcome,d.decision_status,
 d.field_location_basis,d.decision_note,d.review_flags,d.decision_source,d.decided_at,
 l.tattoo,l.capture_date,l.sett_id as field_sett_id,l.sett_name as field_sett_name,
 case when d.field_location_basis='PM_RECORD' then p.location_easting else l.location_easting end as field_easting,
 case when d.field_location_basis='PM_RECORD' then p.location_northing else l.location_northing end as field_northing,
 case when d.field_location_basis='PM_RECORD' then p.coordinate_representation else l.coordinate_representation end as field_coordinate_representation,
 p.location_easting as original_pm_easting,p.location_northing as original_pm_northing,
 p.coordinate_representation as original_pm_coordinate_representation
from research.encounter_episode_decisions d
join analysis.encounters_standardised_v1 l on l.capture_id=d.live_capture_id
join analysis.encounters_standardised_v1 p on p.capture_id=d.pm_capture_id;

create or replace view analysis.encounters_with_episodes_v1 with (security_invoker=true) as
select e.*,
 coalesce(dl.live_capture_id,dp.live_capture_id) as episode_primary_capture_id,
 coalesce(dl.pm_capture_id,dp.pm_capture_id) as episode_pm_capture_id,
 case when dl.live_capture_id is not null then 'FIELD_RECORD'
      when dp.pm_capture_id is not null then 'PM_COMPANION'
      else 'STANDALONE' end as episode_record_role,
 coalesce(dl.episode_outcome,dp.episode_outcome,e.encounter_outcome) as resolved_episode_outcome,
 coalesce(dl.decision_status,dp.decision_status) as episode_decision_status,
 coalesce(dl.review_flags,dp.review_flags,array[]::text[]) as episode_review_flags,
 chosen_field.location_easting as episode_field_easting,
 chosen_field.location_northing as episode_field_northing,
 chosen_field.coordinate_representation as episode_field_coordinate_representation
from analysis.encounters_standardised_v1 e
left join research.encounter_episode_decisions dl on dl.live_capture_id=e.capture_id
left join research.encounter_episode_decisions dp on dp.pm_capture_id=e.capture_id
left join analysis.encounters_standardised_v1 chosen_field
 on chosen_field.capture_id =
 case when coalesce(dl.field_location_basis,dp.field_location_basis)='PM_RECORD'
      then coalesce(dl.pm_capture_id,dp.pm_capture_id)
      else coalesce(dl.live_capture_id,dp.live_capture_id) end;


-- ================================================
-- MIGRATION VERSION: 20261103133551
-- MIGRATION NAME: wecs_reclassify_unknowns_with_recapture_evidence_and_pm_notes
-- ================================================


create or replace view analysis.encounters_v1 with (security_invoker=true) as
with source as (
 select e.capture_id,e.tattoo,e.capture_date,e.is_pm,e.sett_id,e.original_moc,
 e.original_location_name,e.original_location_text,e.original_os_ref,
 e.prior_location_class,e.prior_reference_source,
 e.sett_name,e.location_easting as prior_easting,e.location_northing as prior_northing,
 e.coordinate_representation as prior_coordinate_representation,
 e.newly_parsed_cell_width_m,
 e.episode_primary_capture_id,e.episode_record_role,e.resolved_episode_outcome,
 e.episode_field_easting,e.episode_field_northing,e.episode_field_coordinate_representation,
 c.individual_id,c.release_assessment,c.comment,c.pm_cause,
 coalesce(c.comment,'') || ' ' || coalesce(c.pm_cause,'') || ' ' || coalesce(c.capture_location_text,'') as narrative,
 case when upper(coalesce(trim(c.capture_location_text),'')) in ('FIELD','WOOD','HEDGE','BOUNDARY','BUILDING','GARDEN','OTHER','OUTSIDE WP','NOT WP')
           and e.sett_id is not null
           and coalesce(c.moc,'') in ('TRAP','NET','SNARE','FOUND EXT','RTA')
      then true else false end as sett_point_context_conflict,
 case when c.moc is null and c.is_pm=false
           and exists (select 1 from research.captures later
             where later.individual_id=c.individual_id
               and later.capture_date>c.capture_date
               and later.is_pm=false
               and (later.moc in ('TRAP','SNARE','NET','DART GUN')
                 or (later.moc is null and later.weight is not null and later.blood_sample_taken=true)))
      then true else false end as subsequent_live_sampling
 from analysis.encounters_with_episodes_v1 e
 join research.captures c using(capture_id)
), standardised as (
 select *,
 case
  when original_moc='TRAP' then 'TRAP'
  when original_moc='NET' then 'NET'
  when original_moc='SNARE' then 'SNARE'
  when original_moc='DART GUN' then 'DART'
  when original_moc='FOUND EXT' then 'FOUND_IN_EXTREMIS'
  when original_moc='FOUND DEAD' then 'FOUND_DEAD'
  when original_moc='RTA' then 'RTA'
  when original_moc in ('SHOT (GP)','SHOT') then 'SHOT'
  when original_moc='REMOVAL' then 'REMOVAL'
  when original_moc='PUT DOWN' then 'PUT_DOWN'
  when original_moc='DEAD SN/TR' then 'DEAD_SNARE_TRAP'
  when original_moc='ON ROAD' then 'ON_ROAD'
  when original_moc='REPORTED BY MEMBER OF THE PUBLIC' then 'PUBLIC_REPORT'
  when original_moc is null and not is_pm and narrative ~* 'found in a lean-to|found in garage|found under wood pile' then 'FOUND_ALIVE'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'SHOT|CULL' then 'SHOT'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'RTA|VEHICLE' then 'RTA'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN' then 'FOUND_DEAD'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'DIED IN HOLDING|DIED OVERNIGHT' then 'TRAP'
  when original_moc is null and subsequent_live_sampling then 'TRAP'
  else 'UNKNOWN' end as encounter_type_clean,
 case
  when episode_primary_capture_id is not null then
    case when resolved_episode_outcome='DIED_AFTER_CAPTURE' then 'DIED' else resolved_episode_outcome end
  when original_moc is null and not is_pm and narrative ~* 'sampled and released at night|sampled and released' then 'RELEASED'
  when original_moc='PUT DOWN' then 'EUTHANISED'
  when original_moc in ('TRAP','NET','SNARE','DART GUN','FOUND EXT')
       and (narrative ~* 'euthan|put down|put to sleep|humanely destroy'
            or upper(coalesce(pm_cause,''))='EUTH') then 'EUTHANISED'
  when original_moc='FOUND EXT' and upper(coalesce(pm_cause,''))='KILLED' then 'KILLED'
  when original_moc in ('TRAP','NET','SNARE','DART GUN','FOUND EXT')
       and (release_assessment='Death' or narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth') then 'DIED'
  when original_moc in ('FOUND DEAD','DEAD SN/TR') then 'FOUND_DEAD'
  when original_moc in ('RTA','ON ROAD') and is_pm then 'FOUND_DEAD'
  when original_moc in ('SHOT','SHOT (GP)') and is_pm then 'KILLED'
  when original_moc='REMOVAL' and is_pm and coalesce(pm_cause,'') ~* 'KILLED|SHOT' then 'KILLED'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'SHOT|CULL' then 'KILLED'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'RTA|VEHICLE' then 'FOUND_DEAD'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN' then 'FOUND_DEAD'
  when original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'DIED IN HOLDING|DIED OVERNIGHT' then 'DIED'
  when original_moc is null and is_pm and nullif(trim(coalesce(pm_cause,'')),'') is not null then 'DIED'
  when original_moc='FOUND EXT' and is_pm then 'DIED'
  when original_moc in ('TRAP','NET','SNARE','DART GUN') and not is_pm then 'PRESUMED_RELEASED'
  when original_moc is null and not is_pm and subsequent_live_sampling then 'PRESUMED_RELEASED'
  else 'UNKNOWN' end as outcome_clean,
 case
  when episode_record_role='PM_COMPANION' then 'LINKED_FIELD_SITE'
  when upper(coalesce(trim(original_location_text),''))='SETT' and sett_id is not null then 'SETT'
  when original_moc in ('RTA','ON ROAD') or (original_moc is null and is_pm and coalesce(pm_cause,'') ~* 'RTA|VEHICLE') then 'ROAD'
  when original_moc in ('FOUND DEAD','DEAD SN/TR') then 'RECOVERY_SITE'
  when upper(coalesce(trim(original_location_text),'')) in ('FIELD','WOOD','HEDGE','BOUNDARY','BUILDING','GARDEN') then upper(trim(original_location_text))
  when original_moc in ('NET','SNARE') then 'OTHER_CAPTURE_SITE'
  when sett_id is not null then 'SETT_ASSOCIATION'
  when prior_location_class='GRID_REFERENCED_PM_LOCATION' then 'RECOVERY_SITE'
  else 'UNKNOWN' end as location_type_clean,
 case
  when episode_record_role='PM_COMPANION' then episode_field_easting
  when sett_point_context_conflict then null
  else prior_easting end as x_clean,
 case
  when episode_record_role='PM_COMPANION' then episode_field_northing
  when sett_point_context_conflict then null
  else prior_northing end as y_clean,
 case
  when episode_record_role='PM_COMPANION' and episode_field_easting is not null then 'LINKED_SETT_POINT_PROVISIONAL'
  when episode_record_role='PM_COMPANION' then 'UNRESOLVED'
  when sett_point_context_conflict then 'SETT_COORDINATE_CONFLICT'
  when prior_easting is null or prior_northing is null then 'UNRESOLVED'
  when prior_coordinate_representation='GRID_CELL_SW_CORNER' and newly_parsed_cell_width_m is not null then 'GRID_CELL'
  when prior_coordinate_representation='GRID_CELL_SW_CORNER' then 'GRID_CELL_PRECISION_UNCONFIRMED'
  when prior_coordinate_representation='SETT_POINT' and upper(coalesce(trim(original_location_text),''))='SETT' then 'SETT_POINT_PROVISIONAL'
  when prior_coordinate_representation='SETT_POINT' then 'SETT_ASSOCIATION_PROVISIONAL'
  else 'PROVISIONAL' end as quality_clean
 from source
)
select capture_id,tattoo,capture_date,is_pm,sett_id,
 episode_primary_capture_id,episode_record_role,
 encounter_type_clean as encounter_type,
 outcome_clean as outcome,
 location_type_clean as location_type,
 x_clean as location_easting,
 y_clean as location_northing,
 quality_clean as location_quality
from standardised;
comment on view analysis.encounters_v1 is
'WECS six-field researcher view updated 2026-11-03. Original method may be inferred as TRAP where a blank-method non-PM sampled animal has a later independently recorded live/sampling encounter (same individual_id, later date); presumed release not directly witnessed. Capture 16953 recorded sampled and released explicitly. Exceptions and mortality inferred only from evidence in source PM causes, notes, and confirmed episode decisions. Ordinary non-PM REMOVAL retains outcome UNKNOWN, including 1979 series and 2001 removal. Grid cell coordinates are southwest corners. Original Access records and earlier spatial parsing/cleaning views remain unchanged. Classification rule is auditable via view definition and companion research decision tables.';


-- ================================================
-- MIGRATION VERSION: 20261103134108
-- MIGRATION NAME: wecs_v1_resolve_34_routine_missing_methods_as_presumed_released
-- ================================================

create or replace view analysis.encounters_v1 with (security_invoker=true) as  WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.capture_date >= DATE '1998-01-01' AND source.capture_date < DATE '2000-01-01' AND EXISTS (SELECT 1 FROM research.captures rc WHERE rc.capture_id=source.capture_id AND rc.blood_sample_taken=true AND rc.weight IS NOT NULL) AND NOT EXISTS (SELECT 1 FROM research.captures pm WHERE pm.individual_id=source.individual_id AND pm.is_pm=true AND pm.capture_date BETWEEN source.capture_date AND source.capture_date+7) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.capture_date >= DATE '1998-01-01' AND source.capture_date < DATE '2000-01-01' AND EXISTS (SELECT 1 FROM research.captures rc WHERE rc.capture_id=source.capture_id AND rc.blood_sample_taken=true AND rc.weight IS NOT NULL) AND NOT EXISTS (SELECT 1 FROM research.captures pm WHERE pm.individual_id=source.individual_id AND pm.is_pm=true AND pm.capture_date BETWEEN source.capture_date AND source.capture_date+7) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT capture_id,
    tattoo,
    capture_date,
    is_pm,
    sett_id,
    episode_primary_capture_id,
    episode_record_role,
    encounter_type_clean AS encounter_type,
    outcome_clean AS outcome,
    location_type_clean AS location_type,
    x_clean AS location_easting,
    y_clean AS location_northing,
    quality_clean AS location_quality
   FROM standardised;
comment on view analysis.encounters_v1 is 'WECS six standardised fields, revised 2026-11-03. For 1998-1999 original missing-method records with mapped sett ID, weight and blood sample and no same-week PM, infer routine TRAP / PRESUMED_RELEASED; 142 already supported by later live sampling, further 34 supported by routine field context. Presumed release is not an observed release. Preserve originals in research.captures and spatial parser views; research encounter episode decisions and nonlinks retain manual decisions. Weights and blood samples, sett linkage, no nearby PM and dates underpin last 34-case decision. Coordinates and quality statuses preserve limitations and conflicts.';

-- ================================================
-- MIGRATION VERSION: 20261103134203
-- MIGRATION NAME: wecs_v1_exclude_found_alive_from_routine_trap_presumptions
-- ================================================

create or replace view analysis.encounters_v1 with (security_invoker=true) as  WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile' AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile' AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT capture_id,
    tattoo,
    capture_date,
    is_pm,
    sett_id,
    episode_primary_capture_id,
    episode_record_role,
    encounter_type_clean AS encounter_type,
    outcome_clean AS outcome,
    location_type_clean AS location_type,
    x_clean AS location_easting,
    y_clean AS location_northing,
    quality_clean AS location_quality
   FROM standardised;
comment on view analysis.encounters_v1 is 'WECS six standardised fields 2026-11-03. 176 original non-PM missing-method routine samples inferred TRAP/PRESUMED_RELEASED: 142 evidenced by subsequent live sampling, 34 further records evidenced by sett linkage, blood draw, weight, 1998-1999 date and no PM in seven days. Exception explicit found-alive narrative (e.g. garage) is never overwritten by assumed trap/release. Preserve original records and historic spatial interpretations; presumed release not confirmed. Nine curated linked episodes remain separate original records.';

-- ================================================
-- MIGRATION VERSION: 20261103135256
-- MIGRATION NAME: wecs_finalise_1979_removal_and_ten_exception_decisions
-- ================================================


create table if not exists research.encounter_classification_decisions (
capture_id bigint primary key references research.captures(capture_id),
encounter_type text,
outcome text,
decision_note text not null,
decision_source text not null,
decided_at timestamptz not null default now(),
constraint has_override check (encounter_type is not null or outcome is not null)
);
alter table research.encounter_classification_decisions enable row level security;
comment on table research.encounter_classification_decisions is 'WECS audit: explicit curator-approved overrides to final six-field encounter_type and outcome only; originals never changed. Decision evidence retained. 1979 removals KILLED inferred from contemporary PM records. For some sparse PM records mortality is researcher-inferred.';
insert into research.encounter_classification_decisions (capture_id,encounter_type,outcome,decision_note,decision_source)
values (1099,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporary PM REMOVAL records at same dates/sites record KILLED; infer lethal removal. No individual PM.','Researcher review 2026-11-03'),
(1666,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporary PM REMOVAL records record KILLED; infer lethal removal. No individual PM.','Researcher review 2026-11-03'),
(1671,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(2744,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4177,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4178,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4298,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4345,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4348,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(5038,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(8109,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(6692,NULL,'DIED','Source TRAP PM, pm_cause=IATRO. Death established; mechanism/circumstances not inferred further.','Researcher review 2026-11-03'),
(14170,NULL,'DIED','Original RTA non-PM with blood sample and no PM; researcher groups this among dead encounters. Mortality is manually assigned rather than verified in source: review if death-specific evidence found.','Researcher review 2026-11-03'),
(16832,'UNKNOWN','FOUND_DEAD','PM record roadside Coaley Peak, no source MOC or PM cause; researcher interprets as dead recovery. Original encounter method remains unknown.','Researcher review 2026-11-03'),
(8810,'FOUND_ALIVE','PRESUMED_RELEASED','Found alive in garage, sampled; no documented release. Researcher authorises presumed release, not confirmed.','Researcher review 2026-11-03'),
(17284,NULL,'FOUND_DEAD','Public report along Tinkley Lane with PM flag; death inferred from PM inclusion, original reporting method retained.','Researcher review 2026-11-03'),
(17055,'UNKNOWN','FOUND_DEAD','Original PM location text explicitly reports decomposed carcass at Jacks sett; original MOC blank.','Researcher review 2026-11-03'),
(16920,NULL,'DIED','Original FOUND EXT, non-PM record with documented live sampling/bite wounds. Researcher treats as dead encounter; source does not independently establish death, so manual decision remains reviewable.','Researcher review 2026-11-03'),
(17250,'UNKNOWN','FOUND_DEAD','PM record from Glider field road; no source MOC. Dead recovery interpretation from PM inclusion, without inventing cause.','Researcher review 2026-11-03'),
(17251,'UNKNOWN','FOUND_DEAD','PM record from Glider field road; no source MOC. Dead recovery interpretation from PM inclusion, without inventing cause.','Researcher review 2026-11-03'),
(17224,'UNKNOWN','DIED','PM record only, original MOC/cause/location blank. Death inferred from PM designation; discovery method remains UNKNOWN.','Researcher review 2026-11-03'),
(17555,'FOUND_ALIVE',NULL,'Original REMOVAL 2001 is explicitly found alive under woodpile and taken for sampling. Not part of 1979 lethal removals; release not documented; retain UNKNOWN outcome.','Researcher review 2026-11-03')
on conflict (capture_id) do update
set encounter_type=excluded.encounter_type,outcome=excluded.outcome,
 decision_note=excluded.decision_note,decision_source=excluded.decision_source,
 decided_at=now();
create or replace view analysis.encounters_v1 with (security_invoker=true) as  WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT capture_id,
    tattoo,
    capture_date,
    is_pm,
    sett_id,
    episode_primary_capture_id,
    episode_record_role,
    coalesce(dec.encounter_type, encounter_type_clean) AS encounter_type,
    coalesce(dec.outcome, outcome_clean) AS outcome,
    location_type_clean AS location_type,
    x_clean AS location_easting,
    y_clean AS location_northing,
    quality_clean AS location_quality
   FROM standardised
   LEFT JOIN research.encounter_classification_decisions dec USING (capture_id);
comment on view analysis.encounters_v1 is 'Woodchester WECS researcher-ready, 6 classification fields plus identity/episode identifiers. Explicit researcher decisions from research.encounter_classification_decisions override inferred type/outcome; source data and spatial interpretations remain preserved. UNKNOWN is a valid encounter_type where source moc is absent; outcomes represent evidence or documented researcher inferences. Do not treat 1979 REMOVAL inferred deaths as individually PM-confirmed; 2001 FOUND_ALIVE removal is distinct. Coordinates provisional and grids are cell SW corners. See decision tables and full view SQL for all rules.';
create or replace view analysis.encounters_clean_v1 with (security_invoker=true) as
select capture_id,tattoo,capture_date,is_pm,sett_id,episode_primary_capture_id,episode_record_role,
 encounter_type,outcome,location_type,location_easting,location_northing,location_quality
from analysis.encounters_v1;
comment on view analysis.encounters_clean_v1 is 'Concise six-field Woodchester research encounter output, retaining identifiers and episode link so same-event PM companion rows are not independently counted. See underlying decisions and original research.captures.';


-- ================================================
-- MIGRATION VERSION: 20261104081532
-- MIGRATION NAME: wecs_v1_audited_mrs_macks_capture_name_alias
-- ================================================


create table if not exists research.capture_sett_alias_decisions (
 capture_id bigint primary key references research.captures(capture_id),
 original_recorded_name text not null,
 canonical_sett_id bigint not null references research.setts(sett_id),
 decision_note text not null,
 decision_source text not null,
 decided_at timestamptz not null default now()
);
alter table research.capture_sett_alias_decisions enable row level security;
comment on table research.capture_sett_alias_decisions is 'Capture-specific validated name aliases; preserves original recorded_sett_name/sett_id in research.captures. Name association does not establish exact physical capture point.';
do $$
begin
 if not exists (select 1 from research.captures c
  join research.setts s on s.sett_id=22
  where c.capture_id=9097 and c.sett_id is null and c.recorded_sett_name='MRS MACKS'
    and c.capture_location_text='BOUNDARY' and s.sett_name='MRS MACK''S')
 then raise exception 'MRS MACKS source/target evidence changed'; end if;
end $$;
insert into research.capture_sett_alias_decisions
 (capture_id,original_recorded_name,canonical_sett_id,decision_note,decision_source)
values
 (9097,'MRS MACKS',22,
  'Punctuation-only name harmonisation MRS MACKS => MRS MACK''S (canonical sett ID 22). Original location type BOUNDARY: retain as a boundary observation with sett association only; do not use the sett centre (380365,200369) as the encounter point.',
  'Researcher-approved name alias, 2026-11-04; source capture 9097')
on conflict(capture_id) do nothing;
create or replace view analysis.encounters_v1 with (security_invoker=true) as
 WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id,standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
    standardised.location_type_clean AS location_type,
    CASE WHEN alias.capture_id IS NOT NULL THEN NULL::numeric ELSE standardised.x_clean END AS location_easting,
    CASE WHEN alias.capture_id IS NOT NULL THEN NULL::numeric ELSE standardised.y_clean END AS location_northing,
    CASE WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text ELSE standardised.quality_clean END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id=standardised.capture_id;
comment on view analysis.encounters_v1 is 'WECS six-field clean encounter classification: original research.captures preserved; manual classification overrides and named sett alias decisions applied in analysis only. A named sett alias with non-sett BOUNDARY location gives the canonical sett_id but deliberately no XY, quality SETT_ASSOCIATION_ONLY. Other spatial precision and coordinate limitations remain provisional.';
create or replace view analysis.capture_sett_alias_audit_v1 with (security_invoker=true) as
select a.capture_id,c.capture_date,c.recorded_sett_name as original_name,
a.canonical_sett_id,s.sett_name as canonical_sett_name,
c.capture_location_text,e.location_type,e.location_quality,
a.decision_note,a.decision_source,a.decided_at
from research.capture_sett_alias_decisions a
join research.captures c using(capture_id)
join research.setts s on s.sett_id=a.canonical_sett_id
join analysis.encounters_v1 e using(capture_id);


-- ================================================
-- MIGRATION VERSION: 20261104081701
-- MIGRATION NAME: wecs_v1_confirm_stoney_track_alias_and_location_semantics
-- ================================================

do $$
begin
 if (select count(*) from research.captures c where c.capture_id in (12030,12031) and c.recorded_sett_name='STONEY TRACK' and c.sett_id is null) <> 2
 or not exists (select 1 from research.setts where sett_id=29 and sett_name='STONY TRACK' and easting=380742 and northing=201140)
 then raise exception 'Stoney Track validation failed'; end if;
end $$;
insert into research.capture_sett_alias_decisions
(capture_id,original_recorded_name,canonical_sett_id,decision_note,decision_source)
values
(12030,'STONEY TRACK',29,'Known spelling harmonisation STONEY TRACK => STONY TRACK; SNARE in WOOD, associate with sett 29 but do not copy sett-centre coordinates as capture point.','Researcher-approved name rule; 2026-11-04'),
(12031,'STONEY TRACK',29,'Known spelling harmonisation STONEY TRACK => STONY TRACK; TRAP at SETT, use canonical sett-point coordinates as provisional proxy (not an independently measured trap location).','Researcher-approved name rule; 2026-11-04')
on conflict (capture_id) do nothing;
create or replace view analysis.encounters_v1 with (security_invoker=true) as  WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
    standardised.location_type_clean AS location_type,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(coalesce(standardised.original_location_text,'')) = 'SETT' THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(coalesce(standardised.original_location_text,'')) = 'SETT' THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(coalesce(standardised.original_location_text,'')) = 'SETT' AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id=alias.canonical_sett_id;
comment on view analysis.encounters_v1 is 'WECS six-field encounter view. Audited aliases affect canonical sett association without overwriting source. If source explicitly states SETT, a mapped canonical sett coordinate may be represented as provisional sett point; BOUNDARY/WOOD/FIELD etc associated with sett only and XY withheld. Original capture and PM evidence preserved.';


-- ================================================
-- MIGRATION VERSION: 20261104081727
-- MIGRATION NAME: wecs_v1_label_mapped_sett_alias_as_sett_type
-- ================================================

create or replace view analysis.encounters_v1 with (security_invoker=true) as  WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
    CASE WHEN alias.capture_id IS NOT NULL AND upper(coalesce(standardised.original_location_text,''))='SETT' THEN 'SETT'::text ELSE standardised.location_type_clean END AS location_type,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id = alias.canonical_sett_id;

-- ================================================
-- MIGRATION VERSION: 20261104082838
-- MIGRATION NAME: wecs_v1_south_peglars_distinct_sett_and_west_main_alias
-- ================================================


do $$
begin
 if (select count(*) from research.captures where capture_id in (11607,11608,11609) and recorded_sett_name='S PEGLARS' and capture_location_text='SETT' and sett_id is null and recorded_social_group_name='HOGARTHS')<>3
 or (select count(*) from research.captures where capture_id in (14456,14457,14458) and recorded_sett_name='WEST MAIN' and capture_location_text='SETT' and sett_id is null and recorded_social_group_name='WYCH ELM')<>3
 or not exists(select 1 from research.setts where sett_id=35 and sett_name='WEST')
 then raise exception 'Capture evidence changed; abort alias mapping';end if;
end $$;
insert into research.setts(sett_name,notes)
select 'SOUTH PEGLARS',
'Separate historical named sett supported by three TRAP captures recorded as S PEGLARS on 1990-02-06, all recorded under HOGARTHS. Deliberately NOT merged with PEGLARS sett 135 (records have PEGLARS SG). XY unknown; original source capture names retained.'
where not exists(select 1 from research.setts where sett_name='SOUTH PEGLARS');

insert into research.capture_sett_alias_decisions
(capture_id,original_recorded_name,canonical_sett_id,decision_note,decision_source)
select c.capture_id,c.recorded_sett_name,s.sett_id,
'Investigator confirmed S PEGLARS means SOUTH PEGLARS; kept distinct from PEGLARS because 1990 captures are recorded in HOGARTHS while PEGLARS captures recorded in PEGLARS. Source SETT type, canonical South Peglars XY missing. Do not infer sett coordinates or social-group change.',
'Researcher approval 2026-11-04; WECS sett-name audit'
from research.captures c cross join research.setts s
where c.capture_id in (11607,11608,11609) and c.recorded_sett_name='S PEGLARS' and s.sett_name='SOUTH PEGLARS'
on conflict(capture_id) do nothing;

insert into research.capture_sett_alias_decisions
(capture_id,original_recorded_name,canonical_sett_id,decision_note,decision_source)
select c.capture_id,c.recorded_sett_name,35,
'Investigator confirmed WEST MAIN is canonical WEST sett 35. Source capture_location_text SETT. Use existing WEST sett XY as provisional sett point, not a trap-specific measurement. Keep recorded WYCH ELM social group unchanged, despite canonical WEST capture records typically having WEST social group.',
'Researcher approval 2026-11-04; WECS sett-name audit'
from research.captures c
where c.capture_id in (14456,14457,14458) and c.recorded_sett_name='WEST MAIN'
on conflict(capture_id) do nothing;


-- ================================================
-- MIGRATION VERSION: 20261104084832
-- MIGRATION NAME: wecs_024y_same_day_euthanasia_pm_episode_link
-- ================================================

do $$
begin
 if not exists (
 select 1 from research.captures live join research.captures pm
 on live.individual_id=pm.individual_id and live.capture_date=pm.capture_date
 where live.capture_id=16882 and pm.capture_id=16817
 and live.is_pm=false and pm.is_pm=true
 and live.moc='FOUND EXT' and pm.moc='FOUND EXT'
 and live.weight=pm.weight
 and live.comment ilike '%euthanas%'
 and pm.pm_cause ilike '%RTA%'
 ) then raise exception '024Y source evidence changed; do not auto-link';end if;
 if exists(select 1 from research.encounter_pair_nonlinks where first_capture_id in (16882,16817) or second_capture_id in (16882,16817))
 then raise exception 'Explicit nonlink exists';end if;
end $$;
insert into research.encounter_episode_decisions
(live_capture_id,pm_capture_id,episode_outcome,decision_status,field_location_basis,decision_note,review_flags,decision_source)
values (16882,16817,'EUTHANISED','CONFIRMED','PM_RECORD',
'024Y: same individual, same date 2014-08-14, identical 9.5kg, FOUND EXT primary and PM. Primary original says suspected RTA and explicitly euthanased; PM gives SO813006 and discovery text Tinkley Lane. One mortality event, not two. PM grid reference is coarse recovery/discovery evidence, NOT proof that original SETT field is exact or that last resident sett was at the discovery point.',
array['RTA_ASSOCIATED','PM_GRID_SQUARE_NOT_SETT','TWO_SOURCE_ROWS_SINGLE_DEATH','PRIMARY_SETT_NAME_ABSENT']::text[],
'2026-11-04 Woodchester six unnamed SETT audit: corroborating original capture/PM source data')
on conflict(live_capture_id) do nothing;


-- ================================================
-- MIGRATION VERSION: 20261104085013
-- MIGRATION NAME: wecs_fix_false_euthanasia_rta_outcomes_and_linked_pm_grid_quality
-- ================================================

do $$
begin
 if not exists(select 1 from research.captures where capture_id=8880 and release_assessment='Fit' and comment ilike '%both put down as trap 1%') then raise exception '014D original evidence changed'; end if;
 if not exists(select 1 from research.captures a join research.captures b on a.individual_id=b.individual_id where a.capture_id=14170 and b.capture_id=14171 and b.capture_date>a.capture_date and b.moc='TRAP') then raise exception 'D061 followup capture missing';end if;
end $$;
insert into research.encounter_classification_decisions(capture_id,encounter_type,outcome,decision_note,decision_source)
values
(8880,null,'PRESUMED_RELEASED','False-positive euthanasia removed: words "both put down as trap 1" describe trap numbering, NOT killing animal. Source 2025-05-20 says release_assessment Fit, anaesthetised/sampled; subsequently live TRAP 2026-06-10. Release not directly observed.','WECS longitudinal mortality contradiction review, 2026-11-04'),
(14170,null,'PRESUMED_RELEASED','Original RTA non-PM July 1998 does not prove death. Badger D061 repeatedly recaptured alive from Oct 1998 through June 2001. Researcher-death override superseded by later live evidence; retain RTA as original encounter_type. Actual release at this event not explicitly documented.','WECS longitudinal mortality contradiction review, 2026-11-04')
on conflict(capture_id) do update set outcome=excluded.outcome, decision_note=excluded.decision_note,decision_source=excluded.decision_source,decided_at=now();
create or replace view analysis.encounters_v1 with (security_invoker=true) as  WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_coordinate_representation='GRID_CELL_SW_CORNER'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN 'SETT'::text
            ELSE standardised.location_type_clean
        END AS location_type,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id = alias.canonical_sett_id;
comment on view analysis.encounters_v1 is 'WECS v1 six-field encounter view, curated episode and classification decisions, audited historical name aliases, source Access data untouched. PM companion point from grid-square receives LINKED_GRID_CELL_PRECISION_UNCONFIRMED, not false SETT label. RTA is an encounter type and does not alone establish death; PM death can be retained without map coordinates.';


-- ================================================
-- MIGRATION VERSION: 20261104085142
-- MIGRATION NAME: wecs_v1_mortality_event_review_protect_dead_without_location
-- ================================================

create or replace view analysis.mortality_events_review_v1 with (security_invoker=true) as
with deaths as (
 select e.capture_id,e.tattoo,e.capture_date as recorded_event_date,
 e.outcome as mortality_outcome,e.encounter_type,e.is_pm,
 e.location_easting,e.location_northing,e.location_quality,
 e.episode_primary_capture_id,e.episode_record_role,
 c.individual_id,c.moc as original_moc,c.pm_cause,
 ep.pm_capture_id as linked_pm_capture_id,
 pm.capture_date as linked_pm_date,
 case when e.location_easting is null and pm.location_easting is not null then pm.location_easting else e.location_easting end as best_available_easting,
 case when e.location_northing is null and pm.location_northing is not null then pm.location_northing else e.location_northing end as best_available_northing,
 case when e.location_easting is null and pm.location_easting is not null then pm.location_quality else e.location_quality end as best_available_location_quality
 from analysis.encounters_clean_v1 e
 join research.captures c using(capture_id)
 left join research.encounter_episode_decisions ep on ep.live_capture_id=e.capture_id
 left join analysis.encounters_clean_v1 pm on pm.capture_id=ep.pm_capture_id
 where e.outcome in ('FOUND_DEAD','DIED','KILLED','EUTHANISED')
 and e.episode_record_role<>'PM_COMPANION'
), tested as(
 select d.*,
 (select min(x.capture_date) from research.captures x
 where x.individual_id=d.individual_id and x.capture_date>d.recorded_event_date
 and x.is_pm=false and x.moc in ('TRAP','NET','SNARE','DART GUN')) as next_live_capture_date,
 (select min(e2.capture_date) from analysis.encounters_clean_v1 e2
 join research.captures c2 using(capture_id)
 where c2.individual_id=d.individual_id and e2.capture_date<d.recorded_event_date
 and e2.outcome in ('FOUND_DEAD','DIED','KILLED','EUTHANISED')
 and e2.episode_record_role<>'PM_COMPANION') as previous_death_record_date
 from deaths d
)
select capture_id,tattoo,recorded_event_date,mortality_outcome,encounter_type,
 is_pm as source_is_pm,original_moc,pm_cause,linked_pm_capture_id,linked_pm_date,
 best_available_easting as location_easting,best_available_northing as location_northing,
 best_available_location_quality as location_quality,
 next_live_capture_date,previous_death_record_date,
 case
 when next_live_capture_date is not null then 'REVIEW_TATTOO_IDENTITY_AFTER_DEATH'
 when previous_death_record_date is not null then 'REVIEW_POSSIBLE_DUPLICATE_DEATH'
 when is_pm or linked_pm_capture_id is not null then 'DEATH_RECORDED_PM_EVIDENCE'
 else 'DEATH_RECORDED_NON_PM_OR_INFERRED'
 end as mortality_review_status
from tested;
comment on view analysis.mortality_events_review_v1 is
'One row per recorded death event excluding curated PM companion rows. IMPORTANT: includes identity conflicts and possible repeat death entries, visibly flagged. Original mortality and date retained even if no usable XY; does not imply an RTA always killed the animal. Date is source event date, not an exact time of death. PM companion may supply coarse grid coordinates; quality field preserved. Not a final survival-event table until identity and duplicate reviews complete.';


-- ================================================
-- MIGRATION VERSION: 20261104091457
-- MIGRATION NAME: wecs_v1_master_review_flags_and_final_resolution_register
-- ================================================

create table if not exists research.wecs_review_flags (
flag_id text primary key,
category text not null,
capture_ids bigint[] not null,
tattoo text,
summary text not null,
evidence text not null,
current_interpretation text not null,
review_status text not null check (review_status in ('OPEN','RESOLVED','NEEDS_SOURCE_CHECK','WAITING_FIELD_TEAM')),
final_decision text,
final_decision_at timestamptz,
updated_at timestamptz not null default now(),
constraint final_decision_if_resolved check (review_status <> 'RESOLVED' or final_decision is not null)
);
alter table research.wecs_review_flags enable row level security;
comment on table research.wecs_review_flags is 'Human-readable, persistent WECS audit queue. current_interpretation may change; final_decision only after resolved. Source capture records never overwritten.';
insert into research.wecs_review_flags
(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status,final_decision,final_decision_at)
values
('DEATH-024Y','DUPLICATE_EPISODE',array[16882,16817]::bigint[],'024Y','Same-day found-in-extremis and PM; one euthanasia.','2014-08-14 same tattoo, date and 9.5kg; original euthanasia notes and PM Tinkley Lane SO813006.','One euthanasia episode; PM is companion, grid site is approximate.','RESOLVED','Confirmed same event. Link live 16882 to PM 16817; count one death and preserve both rows.',now()),
('DEATH-D061','FALSE_DEATH',array[14170,14171]::bigint[],'D061','RTA initially misclassified as death, with later live captures.','1998-07-28 non-PM RTA; subsequent TRAP from 1998-10-06 onwards.','Not confirmed fatal; RTA retained, outcome presumed released.','RESOLVED','Correct record 14170 to PRESUMED_RELEASED; do not censor at July 1998.',now()),
('DEATH-014D','FALSE_DEATH',array[8880,9767]::bigint[],'014D','Trap-numbering wording incorrectly interpreted as euthanasia.','2025-05-20 note says both put down as trap 1, release assessment Fit, live capture 2026-06-10.','Routine capture, presumed released.','RESOLVED','Outcome PRESUMED_RELEASED; words put down describe trap numbering, not killing.',now()),
('DEATH-U005','IDENTITY_CONFLICT',array[16968,15531]::bigint[],'U005','PM-found-dead in 2003 followed by live capture of same tattoo.','PM 2003-02-06; live TRAP 2003-09-02.','Keep PM mortality evidence; do not assume death belongs to later live animal until identity verified.','NEEDS_SOURCE_CHECK',null,null),
('DEATH-020D','IDENTITY_CONFLICT',array[17328,15335]::bigint[],'020D','RTA PM with major head injuries in 2020; live capture in 2022.','PM 2020-05-18; live TRAP 2022-10-18 and subsequent captures.','Preserve true PM record; tattoo/individual linkage unverified.','NEEDS_SOURCE_CHECK',null,null),
('DEATH-W023','POSSIBLE_DUPLICATE',array[4984,4987]::bigint[],'W023','Two death records 18 days apart at Giant Beech.','PM FOUND DEAD 1980-04-02; non-PM FOUND DEAD 1980-04-20, same individual.','Possible repeat record of same carcass; no live recapture.','OPEN',null,null),
('DEATH-Q082','POSSIBLE_DUPLICATE',array[17055,7311]::bigint[],'Q082','Two death records two days apart at Jacks.','PM 2000-05-15 decomposed carcass; 2000-05-17 FOUND DEAD notes too decomposed for PM.','Likely one carcass, retain records pending source confirmation.','OPEN',null,null),
('SPATIAL-SETT-XY','MISSING_COORDINATES',array[]::bigint[],null,'Named sett and outlier coordinates pending from field team.','Field-team request CSV in Git: 57 supplied names plus 2 descriptive SETT-related recovery locations.','Do not invent XY; keep unresolved and provenance flags.','WAITING_FIELD_TEAM',null,null),
('SPATIAL-GRID','GRID_PRECISION',array[]::bigint[],null,'594 grid precision warnings in current WECS clean view.','Grid references, 100m squares, SW corners and missing original OS references need verification.','Keep resolution flags; do not present grid cell as precise individual position.','OPEN',null,null),
('SPATIAL-CONFLICT','LOCATION_CONFLICT',array[]::bigint[],null,'107 sett-association versus non-sett physical encounter conflicts.','FIELD/WOOD/BOUNDARY/HEDGE/BUILDING/RTA etc in original location text.','Protect physical encounter-site semantics; do not copy nominal sett XY.','OPEN',null,null)
on conflict (flag_id) do update
set category=excluded.category,capture_ids=excluded.capture_ids,tattoo=excluded.tattoo,
summary=excluded.summary,evidence=excluded.evidence,current_interpretation=excluded.current_interpretation,
review_status=excluded.review_status,final_decision=coalesce(research.wecs_review_flags.final_decision,excluded.final_decision),
final_decision_at=coalesce(research.wecs_review_flags.final_decision_at,excluded.final_decision_at),updated_at=now();
create or replace view analysis.wecs_review_flags_v1 with (security_invoker=true) as
select flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status,final_decision,final_decision_at,updated_at
from research.wecs_review_flags;
comment on view analysis.wecs_review_flags_v1 is 'Public-facing (within authorised read-only analysis schema) current WECS flag status and final investigator decisions; research.wecs_review_flags is the editable source.';


-- ================================================
-- MIGRATION VERSION: 20261104092211
-- MIGRATION NAME: wecs_v1_collaborator_readonly_view_grants
-- ================================================

-- Make only curated WECS analysis views usable to both read-only collaborator roles.
-- security_invoker=false on curated views means collaborators need SELECT on the view,
-- not unrestricted access to original research.captures or curator decision tables.
-- Both roles have NO INSERT/UPDATE/DELETE grants on views or research curation tables.
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


-- ================================================
-- MIGRATION VERSION: 20261104094055
-- MIGRATION NAME: wecs_20261104_grid_square_correct_named_locality_and_withhold_ambiguous
-- ================================================

-- Reviewed British National Grid spatial QA; raw c.os_ref and historical fields unchanged.
create table if not exists research.capture_grid_coordinate_decisions(
capture_id bigint primary key references research.captures(capture_id),
original_grid_reference text,
source_easting numeric,
source_northing numeric,
corrected_easting numeric,
corrected_northing numeric,
decision_status text not null check(decision_status in ('CORRECTED','WITHHELD')),
decision_note text not null,
decision_source text not null,
reviewed_at timestamptz not null default now(),
constraint wecs_grid_pair check ((corrected_easting is null)=(corrected_northing is null)),
constraint wecs_grid_status check ((decision_status='CORRECTED' and corrected_easting is not null) or (decision_status='WITHHELD' and corrected_easting is null))
);
alter table research.capture_grid_coordinate_decisions enable row level security;
comment on table research.capture_grid_coordinate_decisions is 'Researcher-reviewed coordinate representations. Original source OS refs and preceding parsed coordinates always preserved. WITHHELD removes untrusted XY from clean analysis but never removes mortality evidence. Corrected points still describe grid squares, not exact carcass points.';
-- 50 explicit ST square references, coordinates around N100km, but textual recovery sites identify the Woodchester/Stroud locality around N200km. Provisional SO interpretation (100 km north).
insert into research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,decision_status,decision_note,decision_source)
select e.capture_id,c.os_ref,e.location_easting,e.location_northing,e.location_easting,e.location_northing+100000,
'CORRECTED','ST source prefix conflicts with a named Woodchester/Stroud-area place in capture_location_text; provisionally interpreted as SO (100km north). The original ST prefix is preserved, and the mapped coordinate remains a grid-square SW corner, not a precise recovery point.','WECS 2026-11-04 OS grid / named-location cross-check'
from analysis.encounters_clean_v1 e join research.captures c using(capture_id)
where c.os_ref ~* '^ST[0-9]{6}([0-9]{2}([0-9]{2})?)?$'
and e.location_northing between 100000 and 115000
and e.location_easting between 370000 and 395000
and c.capture_location_text ~* 'woodchester|tinkley|nympsfield|selsey|selsley|bown hill|glider|b4066|buckholt|frocester|jacks|wych elm|west sett|parkmill|park mill|wood farm|ebley|stroud|coaley|crawley|davids lane|david.s lane|cockadilly|peglars|hogarth|stanley wood|longwood|w.park|theescombe|amberly|elder field|lebanon cedar|bottom gates'
on conflict(capture_id) do nothing;
-- Embedded original prefixes in recorded_sett_name were lost by old hard-coded SO parser.
insert into research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,decision_status,decision_note,decision_source)
select e.capture_id,c.recorded_sett_name,e.location_easting,e.location_northing,
case when c.capture_id=12072 then 406200 else e.location_easting end,
e.location_northing-100000,'CORRECTED',
case when c.capture_id=12072 then 'Source embedded SU062988 gives BNG E406200,N198800, whereas original SO default falsely gave E306200,N298800. Source says NOT TRUE MOVE; do not assign a Woodchester settled capture from this distant site.'
else 'Source recorded_sett_name explicitly starts ST; old hard-coded SO assumption introduced +100km northing. Restore ST-square grid SW coordinate at N~199km. Preserve original text.' end,
'WECS 2026-11-04 original embedded OS-letter correction'
from analysis.encounters_clean_v1 e join research.captures c using(capture_id)
where c.capture_id in (12011,12012,12016,12072)
on conflict(capture_id) do nothing;
-- Unprefixed and explicit SO refs at N~299km that coincide with local-name references may be ST N~199km, but original evidence does not establish the actual square. Withhold from cleaned point output pending verification.
insert into research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,decision_status,decision_note,decision_source)
select e.capture_id,coalesce(c.os_ref,c.recorded_sett_name),e.location_easting,e.location_northing,
null,null,'WITHHELD',
'Grid interpretation ambiguous: old parser assumed SO, yielding N~299km, but geographic text is Woodchester/local area or lacks independent location proof. Do not automatically shift to ST N~199km. Preserve original reference and mortality, withhold XY pending historic source/map check.',
'WECS 2026-11-04 grid-square boundary audit'
from analysis.encounters_clean_v1 e join research.captures c using(capture_id)
where e.location_northing between 290000 and 300000
and e.location_easting between 365000 and 395000
and not exists (select 1 from research.capture_grid_coordinate_decisions g where g.capture_id=e.capture_id)
on conflict(capture_id) do nothing;
-- Additional strongly anomalous grids (SO at N~250km with local Leg of Mutton; remote SO 808 near Woodcock gate): withhold instead of guessing.
insert into research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,decision_status,decision_note,decision_source)
select e.capture_id,coalesce(c.os_ref,c.recorded_sett_name),e.location_easting,e.location_northing,
null,null,'WITHHELD',
'Literal grid coordinate is geographically inconsistent with the named local recovery site, but a uniquely supported replacement cannot be established. Retain PM death, withhold point pending map/source review.',
'WECS 2026-11-04 place/grid discrepancy review'
from analysis.encounters_clean_v1 e join research.captures c using(capture_id)
where e.capture_id in (16861,17477,17117)
and not exists (select 1 from research.capture_grid_coordinate_decisions g where g.capture_id=e.capture_id)
on conflict(capture_id) do nothing;

create or replace view analysis.encounters_v1 with (security_invoker=true) as
 WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN 'SETT'::text
            ELSE standardised.location_type_clean
        END AS location_type,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_easting
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_northing
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN grid.decision_status='WITHHELD' THEN 'GRID_REFERENCE_AMBIGUOUS_WITHHELD'::text
            WHEN grid.decision_status='CORRECTED' THEN 'GRID_REFERENCE_CORRECTED_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id = alias.canonical_sett_id
     LEFT JOIN research.capture_grid_coordinate_decisions grid ON grid.capture_id = standardised.capture_id;
comment on view analysis.encounters_v1 is 'WECS v1: capture fate independent of spatial availability. Reviewed source grid conversion decisions overlay parsed XY; CORRECTED grid squares remain provisional; WITHHELD coordinates null until reviewed. Original c.os_ref retained. See research.capture_grid_coordinate_decisions and analysis.grid_reference_audit_v1.';

create or replace view analysis.grid_reference_audit_v1 with (security_invoker=false) as
select e.capture_id,e.tattoo,e.capture_date,e.is_pm,c.os_ref,c.recorded_sett_name,c.capture_location_text,
g.original_grid_reference,g.source_easting,g.source_northing,g.corrected_easting,g.corrected_northing,
g.decision_status,g.decision_note,g.decision_source,g.reviewed_at,
e.location_easting as analysis_easting,e.location_northing as analysis_northing,e.location_quality
from analysis.encounters_clean_v1 e
join research.captures c using(capture_id)
join research.capture_grid_coordinate_decisions g using(capture_id);
comment on view analysis.grid_reference_audit_v1 is 'Read-only compact grid correction and withheld-coordinate audit; no original data overwritten. These corrections are BNG grid-square proxies with source uncertainty.';
grant select on analysis.grid_reference_audit_v1 to badger_readonly,badger_research_readonly;
grant select on research.capture_grid_coordinate_decisions to badger_research_readonly;
create policy badger_research_readonly_select on research.capture_grid_coordinate_decisions
for select to badger_research_readonly using(true);


-- ================================================
-- MIGRATION VERSION: 20261104094406
-- MIGRATION NAME: wecs_20261104_confirm_six_digit_precision_and_quarantine_five_grids
-- ================================================

insert into research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,decision_status,decision_note,decision_source)
select e.capture_id,coalesce(c.os_ref,c.recorded_sett_name),e.location_easting,e.location_northing,null,null,'WITHHELD',
'Grid yields remote N~230-290km but historical location text names Woodchester Park, Tinkley Lane, Watts Farm or Cockadilly; source cannot support unique correction. Death evidence preserved.',
'WECS 2026-11-04 source/grid audit'
from analysis.encounters_clean_v1 e join research.captures c using(capture_id)
where e.capture_id in (17376,16869,17285,17427,18)
and not exists (select 1 from research.capture_grid_coordinate_decisions g where g.capture_id=e.capture_id)
on conflict(capture_id) do nothing;
create or replace view analysis.encounters_v1 with (security_invoker=true) as  WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.episode_field_easting IS NOT NULL THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN 'SETT'::text
            ELSE standardised.location_type_clean
        END AS location_type,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_easting
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_northing
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN grid.decision_status = 'WITHHELD'::text THEN 'GRID_REFERENCE_AMBIGUOUS_WITHHELD'::text
            WHEN grid.decision_status = 'CORRECTED'::text THEN 'GRID_REFERENCE_CORRECTED_PROVISIONAL'::text
            WHEN standardised.quality_clean='GRID_CELL_PRECISION_UNCONFIRMED'::text
             AND regexp_replace(upper(coalesce(standardised.original_os_ref,'')),'[[:space:],.-]','','g') ~ '^SO[0-9]{6}$'
             THEN 'GRID_CELL_100M_RECORDED_SO'::text
            WHEN standardised.quality_clean='GRID_CELL_PRECISION_UNCONFIRMED'::text
             THEN 'GRID_CELL_100M_PREFIX_UNVERIFIED'::text
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id = alias.canonical_sett_id
     LEFT JOIN research.capture_grid_coordinate_decisions grid ON grid.capture_id = standardised.capture_id;
comment on view analysis.encounters_v1 is 'Original source and fatal outcomes preserved. 100m cell width independently established from six-digit references, while 100km grid-prefix uncertainty retained. Curator grid overrides and withheld non-local points applied to analysis XY only.';


-- ================================================
-- MIGRATION VERSION: 20261104094631
-- MIGRATION NAME: wecs_20261104_access_identity_checks_and_spatial_conflict_final_rules
-- ================================================

-- Source-backed identity QA and conservative spatial conflict disposition, 2026-11-04.
update research.wecs_review_flags
set evidence='Access source access_raw.tbl_badger: tattoo 020D sex FEMALE, age_fc CUB, year_fc 2022. Yet access_raw.tbl_captures raw_row_id 1798 assigns 2020-05-18 RTA PM death to 020D. 2022-2024 repeated live trapping is separately recorded. Death cannot be assigned to the 2022 cub if source age/year correct; actual dead individual unverified.',
current_interpretation='Preserve original 2020 RTA PM as genuine evidence, but exclude from terminal death assignment for the 2022-onwards 020D history. Possible tattoo reuse or incorrect historical PM identity; exact correction requires original PM/field record.',
updated_at=now()
where flag_id='DEATH-020D';
update research.wecs_review_flags
set evidence='Original Access rows 14749-14751 all explicitly use U005: live 2003-01-22; PM FOUND DEAD 2003-02-06 at Wood Farm (weight recorded 0); live TRAP 2003-09-02 with body length 82.5cm. No additional tag or PM identification fields confirm identity.',
current_interpretation='Preserve original PM death as recorded; do not treat it as terminal death of the subsequently trapped U005 until original carcass/tattoo evidence clarifies identity. No supported alternative tattoo yet.',
updated_at=now()
where flag_id='DEATH-U005';
update research.wecs_review_flags
set evidence='Source evidence: 107 records have original location context FIELD, WOOD, HEDGE, BOUNDARY, BUILDING, OTHER, OUTSIDE WP or NOT WP with a separate associated sett. Zero have independent os_ref and all 107 have null analysis XY. Includes 54 PM and 53 non-PM records.',
current_interpretation='Spatial absence is an accepted final state. Retain canonical sett ASSOCIATION when documented, but do not turn it into an exact field/road/recovery site coordinate. Keep SETT_COORDINATE_CONFLICT QA label for model selection.',
review_status='RESOLVED',
final_decision='Leave encounter XY null for all 107 records; preserve the associated sett separately. Exact field/recovery positions require independent evidence, not sett-centre imputation. Encounter fate and mortality unchanged.',
final_decision_at=now(),updated_at=now()
where flag_id='SPATIAL-CONFLICT';
update research.wecs_review_flags
set summary='OS grid conversions: 54 provisional corrections, 38 suspect coordinates withheld; six-digit 100m precision now explicit.',
evidence='Original grid parser defaulted to SO; many ST-labeled local Woodchester sites fell 100km south, and unprefixed refs ending 99x fell 100km north. 50 ST local-site interpretations + 4 original embedded ST/SU refs corrected. 38 ambiguous locations withheld. Remaining refs classified by 100m cell precision and recorded/assumed prefix. Original OS strings preserved.',
current_interpretation='Only corrected named-site grid-square proxies and explicitly supported original 100m cells may contribute spatial evidence; quality flags distinguish inferred prefix and source prefix. 38 withheld entries require original map/source confirmation; do not interpret southwest corner as exact death position.',
updated_at=now()
where flag_id='SPATIAL-GRID';
update research.wecs_review_flags
set evidence='Original Access: PM 2000-05-15 at Jacks carcase decomposed, then 2000-05-17 FOUND DEAD and text TOO DECOMPOSED - NOT SENT FOR POST MORTEM. Two records use same tattoo/site but PM flag and wording conflict.',
current_interpretation='Likely one dead badger with two records; first death is candidate event, later entry provisionally withheld as possible duplicate. Original PM flag disagreement requires source clarification.',
updated_at=now()
where flag_id='DEATH-Q082';
insert into research.wecs_review_flags(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status)
values ('SPATIAL-UNNAMED-SETT','MISSING_LOCATION',array[17560,17573,17557,17542,17561,16882]::bigint[],null,
'Six original SETT records with no recorded canonical sett name.',
'Four ordinary live trap records, one RTA PM, and one FOUND EXT euthanasia (024Y field source). Capture histories examined: no defensible same-episode exact sett for most. 024Y PM companion carries a 100m grid reference to a reported discovery site.',
'Leave physical encounter XY unknown absent original field evidence. Preserve separate fate/mortality; 024Y two source rows already confirmed one euthanasia.',
'OPEN')
on conflict(flag_id) do nothing;

create or replace view analysis.mortality_model_candidate_v1 with (security_invoker=false) as
select m.*,
case when m.capture_id in (16968,17328) then 'HOLD_IDENTITY_CONTRADICTION'
when m.capture_id in (4987,7311) then 'HOLD_POSSIBLE_REPEAT_DEATH'
else 'CANDIDATE_TERMINAL_DEATH' end as terminal_model_status,
case when m.capture_id in (16968,17328)
then 'Original Access death entry conflicts with later definite live tattoo history; PM remains in review table pending identification.'
when m.capture_id in (4987,7311)
then 'Additional dead entry at same place after previous death; not treated as independent terminal death pending record review.'
else 'Candidate recorded death event; identity and episode evidence still subject to global survival-history checks.'
end as terminal_model_note
from analysis.mortality_events_review_v1 m;
comment on view analysis.mortality_model_candidate_v1 is 'Candidate survival-model event review with explicit HOLD statuses for two identity-contradictory PM records and two repeat-death candidates. Does not discard records, nor certify all other deaths independently verified. Source mortality retained even when XY null. Not yet final signed-off survival extract.';
grant select on analysis.mortality_model_candidate_v1 to badger_readonly,badger_research_readonly;


-- ================================================
-- MIGRATION VERSION: 20261104095245
-- MIGRATION NAME: wecs_20261104_confirm_seven_additional_handling_pm_death_pairs
-- ================================================

-- Seven additional same-death primary/PM pairs confirmed against both canonical and original Access evidence.
-- Both source rows remain; one death event per linked episode.
do $$
declare n int;
begin
 select count(*) into n
 from (values (16891,17441,'EUTHANISED'),(8377,17427,'EUTHANISED'),(11061,17510,'EUTHANISED'),
 (3966,16832,'DIED_AFTER_CAPTURE'),(16884,16883,'EUTHANISED'),(16816,16815,'EUTHANISED'),
 (17183,17058,'EUTHANISED')) pairs(live_id,pm_id,fate)
 join research.captures a on a.capture_id=pairs.live_id
 join research.captures b on b.capture_id=pairs.pm_id
 where a.individual_id=b.individual_id and a.is_pm=false and b.is_pm=true
 and a.weight=b.weight and b.capture_date between a.capture_date and (a.capture_date+1);
 if n<>7 then raise exception 'Seven-pair same-event source check failed; got %',n;end if;
 if exists (select 1 from research.encounter_pair_nonlinks n
 join (values (16891,17441),(8377,17427),(11061,17510),(3966,16832),
              (16884,16883),(16816,16815),(17183,17058)) p(a,b)
  on (n.first_capture_id=p.a and n.second_capture_id=p.b)
  or (n.first_capture_id=p.b and n.second_capture_id=p.a))
 then raise exception 'Explicit nonlink prohibits proposed join';end if;
end $$;
insert into research.encounter_episode_decisions
(live_capture_id,pm_capture_id,episode_outcome,decision_status,field_location_basis,decision_note,review_flags,decision_source)
values
(16891,17441,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'001R: same tattoo 2004-03-15 FOUND EXT live euthanised at B4066 Buckholt Lodge gate; same-day PM says EUTHANASIA, both weigh 8.9kg. One death. PM independent SO795015 grid reference remains accessible in source; live event coordinates unresolved.',
array['PM_HAS_INDEPENDENT_GRID','FIELD_POINT_UNRESOLVED']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(8377,17427,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'017R: 2009-11-04 TRAP at LARCH and euthanised on welfare grounds, PM dated 2009-11-05 confirms euthanasia and same 5.9kg weight; one death. PM grid SO800285 is separately withheld as spatially inconsistent; retain supported LARCH sett-proxy for live trapping.',
array['NEXT_DAY_PM_DATE','PM_OS_GRID_WITHHELD']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(11061,17510,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'045W: 2005-07-29 FOUND EXT at PEGLARS, severe maggot-infested bite wound, animal euthanised; same-day PM repeats exact narrative and 2.3kg; one death.',
array[]::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(3966,16832,'DIED_AFTER_CAPTURE','CONFIRMED','LIVE_RECORD',
'D007: 1999-08-02 FOUND EXT by farmer at Coaley Peak, died under anaesthetic. The original primary comment explicitly says PM was same day but was entered as 1999-08-03 because historic Access could not store capture and PM on same date. Same tattoo and 3.9kg; one death. PM grid 715015 without prefix remains separately provisional.',
array['PM_DATE_ARTIFICIALLY_PLUS_ONE_DAY','CAUSE_DIED_UNDER_ANAESTHETIC','PM_GRID_PREFIX_UNVERIFIED']::text[],
'WECS original primary comment explicitly links PM; 2026-11-04'),
(16884,16883,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'I022: 2004-05-12 found in extremis below Wych Elm, euthanised using Dolethal. Same-day PM repeats case with identical 3.8kg; one death. Original PM ST grid has separate audited provisional interpretation.',
array['PM_GRID_PREFIX_CORRECTED_PROVISIONAL']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(16816,16815,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'M012: 2001-04-01 field note explicitly EUTHANASED SEE PM FORM; same-day PM documents convulsions/euthanasia, identical 6.9kg. One event. PM ST grid handled by separate spatial audit.',
array['PM_GRID_PREFIX_CORRECTED_PROVISIONAL']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(17183,17058,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'Q070: 2001-10-24 found alive at Tinkley Lane opposite Wood Farm, euthanised after sampling. Same-day RTA PM says still alive when found, euthanased, same 10.1kg. One euthanasia; RTA is suspected injury mechanism not another separate death.',
array['RTA_ASSOCIATED','PM_GRID_PREFIX_CORRECTED_PROVISIONAL']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04')
on conflict(live_capture_id) do nothing;

update research.encounter_classification_decisions set
outcome='DIED',
decision_note='D007 PM companion to primary 3966 (same encounter; historical PM date shifted one day as explicitly documented). Original primary record says died under anaesthetic. Single DIED episode; PM method originally blank and remains UNKNOWN. PM grid point distinct from last sett.',
decision_source='WECS confirmed source-described D007 pair 2026-11-04',
decided_at=now()
where capture_id=16832;

insert into research.wecs_review_flags
(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status,final_decision,final_decision_at)
values(
'DEATH-SEVEN-FURTHER-PAIRS','DUPLICATE_EPISODE',
array[16891,17441,8377,17427,11061,17510,3966,16832,16884,16883,16816,16815,17183,17058]::bigint[],
null,'Seven additional duplicate death-row pairs are one field-handling/PM episode each.',
'Pairs independently checked via same tattoo, date (or 1 day), same weight, and matching explicit euthanasia/died narratives. D007 primary expressly explains historical PM one-day date shift.',
'Seven more confirmed pairs, adding to previous 10; one death per episode and both historical source rows retained.',
'RESOLVED',
'Link seven exact pairs in research.encounter_episode_decisions. Six EUTHANISED and D007 DIED_AFTER_CAPTURE; PM companion not an independent mortality event. Date and spatial provenance preserved.',now())
on conflict(flag_id) do nothing;


-- ================================================
-- MIGRATION VERSION: 20261104095425
-- MIGRATION NAME: wecs_20261104_pm_companion_own_recovery_grid_not_nominal_sett
-- ================================================

-- Fix field/PM spatial provenance after seven newly discovered death-episode pairs.
-- A PM companion's own independent OS grid square is more informative than a nominal associated sett.
-- If PM has no independent grid, don't copy a sett centre or field point onto the PM row.
-- The primary field row retains its original/provisional point for event analyses; source PM text untouched.
create or replace view analysis.encounters_v1 with (security_invoker=true) as
 WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN 'RECOVERY_SITE'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN source.prior_easting
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_northing IS NOT NULL THEN source.prior_northing
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN 'SETT'::text
            ELSE standardised.location_type_clean
        END AS location_type,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_easting
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_northing
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN grid.decision_status = 'WITHHELD'::text THEN 'GRID_REFERENCE_AMBIGUOUS_WITHHELD'::text
            WHEN grid.decision_status = 'CORRECTED'::text THEN 'GRID_REFERENCE_CORRECTED_PROVISIONAL'::text
            WHEN standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text AND regexp_replace(upper(COALESCE(standardised.original_os_ref, ''::text)), '[[:space:],.-]'::text, ''::text, 'g'::text) ~ '^SO[0-9]{6}$'::text THEN 'GRID_CELL_100M_RECORDED_SO'::text
            WHEN standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text THEN 'GRID_CELL_100M_PREFIX_UNVERIFIED'::text
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id = alias.canonical_sett_id
     LEFT JOIN research.capture_grid_coordinate_decisions grid ON grid.capture_id = standardised.capture_id;
comment on view analysis.encounters_v1 is 'WECS six-field encounter output: primary source death handling and PM companions preserved; PM companion own OS grid square retained with correct 100m square precision, but no synthetic inherited sett point when PM has no independent OS evidence. All grid correction decisions overlay original parsed points, mortality stays independent of XY.';


-- ================================================
-- MIGRATION VERSION: 20261104141639
-- MIGRATION NAME: wecs_20261104_five_source_malformed_os_grid_salvage_and_spatial_queue
-- ================================================

-- Five original Access PM references manually reviewed against nearby Woodchester-area recovery descriptions.
-- Provisional SO-square readings; never exact GIS points; original strings remain unchanged.
do $$
declare actual int;
begin
select count(*) into actual from research.captures c join analysis.encounters_clean_v1 e using(capture_id)
join (values
(16859,'83188,00086'),
(16967,'S0826024'),
(16997,'OS822024'),
(17043,'82774 00203'),
(17500,'81500050')
) v(capture_id,os_ref) on c.capture_id=v.capture_id and c.os_ref=v.os_ref
where c.is_pm and e.location_easting is null and e.location_northing is null;
if actual <> 5 then raise exception 'Expected five exact source PM records with missing XY, got %',actual;end if;
end $$;
insert into research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,decision_status,decision_note,decision_source)
values
(16859,'83188,00086',null,null,383188,200086,'CORRECTED',
'Numeric 5+5 OS reference 83188 00086; assumed SO square because original recovery says RTA WOOD FARM. Six-figure precision NOT assumed: 10 digits give nominal 1m grid cell but source accuracy unverified. Original comma retained. Provisional until map confirmation.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(16967,'S0826024',null,null,382600,202400,'CORRECTED',
'Source S0 prefix contains digit zero where SO has letter O. Provisional SO826024 (100m grid square) supported by Selsley Common / Boundary Court Farm roadside description. Original source string retained.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(16997,'OS822024',null,null,382200,202400,'CORRECTED',
'Source OS822024 appears to use OS shorthand instead of explicit SO prefix. Infer SO822024 (100m grid square) from original Pen Wood / B4066 before cattle grid description. Prefix inference NOT independently verified.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(17043,'82774 00203',null,null,382774,200203,'CORRECTED',
'Original five+five digit numeric grid reference, no letter prefix. Provisional SO82774 00203 from Tinkley Lane (original source spells Line), Nailsworth–Nympsfield area; nominal 1m grid-square width does NOT mean observed metre accuracy.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(17500,'81500050',null,null,381500,200500,'CORRECTED',
'Eight numeric digits interpreted as 8150 0050 (10m square) with assumed SO prefix from Tinkley Lane recovery text. Source numeric splitting/prefix still provisional; neither 10m positioning accuracy nor exact death site verified.',
'WECS 2026-11-04 Access malformed-grid salvage')
on conflict(capture_id) do nothing;

update research.wecs_review_flags set
summary='OS grid QA: 59 provisional corrections, 38 withheld points; malformed source strings are separately audited.',
evidence='Original SO/ST and implicit prefix issues: 54 earlier verified provisional corrections plus 5 new manually reconstructed original Access PM refs (16859,16967,16997,17043,17500). Original source strings retained; 38 geographically ambiguous grid points remain withheld. 100m grid-square logic verified for six-digit references.',
current_interpretation='59 provisional corrected grid positions are usable with strong quality caveats and original provenance; five new source strings require map/source confirmation before precision-sensitive use. 38 withheld points remain without clean XY. No recorded fatal event was excluded.',
updated_at=now()
where flag_id='SPATIAL-GRID';

-- A narrow review view for outstanding missing-coordinate categories, preserving mortality and note context.
create or replace view analysis.spatial_missing_review_v1 with (security_invoker=false) as
select e.capture_id,e.tattoo,e.capture_date,e.is_pm,e.encounter_type,e.outcome,
e.sett_id,ss.sett_name as canonical_sett_name,c.recorded_sett_name,
c.capture_location_text,c.os_ref,c.moc as original_moc,c.comment,c.pm_cause,
e.episode_record_role,e.location_type,e.location_quality,
case
when e.episode_record_role='PM_COMPANION' then 'PM_COMPANION_NO_INDEPENDENT_POINT'
when e.location_quality='SETT_COORDINATE_CONFLICT' then 'ASSOCIATED_SETT_NOT_ACTUAL_SITE'
when e.location_quality='GRID_REFERENCE_AMBIGUOUS_WITHHELD' then 'ORIGINAL_GRID_VERIFY'
when e.sett_id is not null and ss.easting is null then 'SETT_XY_FIELD_TEAM'
when e.is_pm then 'MORTALITY_RECOVERY_LOCATION'
when nullif(btrim(coalesce(c.recorded_sett_name,'')),'') is not null then 'NAMED_NON_SETT_SITE'
else 'SOURCE_LOCATION_UNSPECIFIED'
end as spatial_review_priority
from analysis.encounters_clean_v1 e
join research.captures c using(capture_id)
left join research.setts ss on ss.sett_id=e.sett_id
where e.location_easting is null or e.location_northing is null;
comment on view analysis.spatial_missing_review_v1 is 'Current WECS missing XY audit queue by explanatory cause, not all missing points are errors. Outcomes including death are preserved. Sett association is not physical encounter location; no automatic imputation.';
grant select on analysis.spatial_missing_review_v1 to badger_readonly,badger_research_readonly;


-- ================================================
-- MIGRATION VERSION: 20261105102318
-- MIGRATION NAME: wecs_20261105_withhold_un260_f030_map_outliers
-- ================================================

do $$
begin
 if (select count(*) from research.capture_grid_coordinate_decisions where decision_status='CORRECTED' and capture_id in (12072,17254))<>2 then
   raise exception 'Precondition failed: two corrections not found';
 end if;
end $$;
update research.capture_grid_coordinate_decisions
set corrected_easting=null,corrected_northing=null,decision_status='WITHHELD',
 decision_note='Investigator rejected provisional location on interactive map 2026-11-05. ST900022 was interpreted as SO E390000 N202200 but inconsistent with original Stanley Wood roadside verge opposite glider field gate. Neither grid-square interpretation accepted pending field/map evidence. Original RTA PM/death retained.',
 decision_source='Researcher map review 2026-11-05; original Access row 15375'
where capture_id=17254;
update research.capture_grid_coordinate_decisions
set corrected_easting=null,corrected_northing=null,decision_status='WITHHELD',
 decision_note='Investigator rejected distant grid point during interactive-map review 2026-11-05. Source SU062988-NOT TRUE MOVE is a historical annotation, not a confirmed death location or long-distance movement. Do not replace with earlier Beech/Mansion sett. Original PM death/cause KILLED retained; source Access row 8144.',
 decision_source='Researcher map review 2026-11-05; original Access row 8144'
where capture_id=12072;
insert into research.wecs_review_flags(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status)
values
('SPATIAL-UN260-17254','GRID_LOCATION_REJECTED',array[17254]::bigint[],'UN260','Provisional position rejected for RTA recovery at Stanley Wood near glider field gate.','Source ST900022; original E390000 N102200, earlier SO reinterpretation E390000 N202200; both unverified against locality. Original Access PM RTA 2002-03-14.','XY withheld pending original source/map confirmation. Death outcome remains recorded.','NEEDS_SOURCE_CHECK'),
('SPATIAL-F030-12072','GRID_LOCATION_REJECTED',array[12072]::bigint[],'F030','Provisional SU reference rejected as verified death/movement coordinate.','Original SU062988-NOT TRUE MOVE, 1988-04-06 PM FOUND DEAD with cause KILLED; prior Beech/Mansion captures and Uley removal entry; original Access row 8144.','XY withheld. Literal SU grid should not be used to infer distant movement; preserve death pending historical map clarification.','NEEDS_SOURCE_CHECK')
on conflict(flag_id) do nothing;
update research.wecs_review_flags
set summary='Grid-reference audit: 57 corrected provisional, 40 withheld after map review.',
evidence='Original 59 corrected/38 withheld; researcher visually rejected 17254 UN260 and 12072 F030 on 2026-11-05. Both have retained original grid strings and PM deaths.',
current_interpretation='57 provisionally mapped grid points; 40 withheld. Review original field evidence before replacing either rejected point.',
updated_at=now()
where flag_id='SPATIAL-GRID';

-- ================================================
-- MIGRATION VERSION: 20261105102825
-- MIGRATION NAME: wecs_20261105_record_57_visual_grid_approvals
-- ================================================

alter table research.capture_grid_coordinate_decisions
add column if not exists map_review_status text not null default 'PENDING_REVIEW';
alter table research.capture_grid_coordinate_decisions
add column if not exists map_review_note text;
alter table research.capture_grid_coordinate_decisions
add column if not exists map_reviewed_at timestamptz;
do $$
begin
 if not exists (select 1 from pg_constraint where conname='wecs_grid_map_review_status_check') then
 alter table research.capture_grid_coordinate_decisions
 add constraint wecs_grid_map_review_status_check
 check (map_review_status in ('PENDING_REVIEW','VISUALLY_VERIFIED','REJECTED_BY_INVESTIGATOR'));
 end if;
 if (select count(*) from research.capture_grid_coordinate_decisions where decision_status='CORRECTED')<>57
 then raise exception 'Expected exactly 57 corrected grid points; inspect before recording review'; end if;
end $$;
update research.capture_grid_coordinate_decisions
set map_review_status='VISUALLY_VERIFIED',
map_review_note='Investigator reviewed interactive Woodchester and overview maps 2026-11-05; accepted geographical plausibility of plotted corrected positions. NOT independent verification of the source grid prefix, cell precision or exact physical carcass position. Preserve source original grid and provisional spatial flag.',
map_reviewed_at=now()
where decision_status='CORRECTED' and map_review_status='PENDING_REVIEW';
update research.capture_grid_coordinate_decisions
set map_review_status='REJECTED_BY_INVESTIGATOR',
map_review_note='Investigator explicitly rejected outlier on interactive overview map 2026-11-05; recovery XY remains withheld and mortality unchanged.',
map_reviewed_at=now()
where capture_id in (17254,12072) and decision_status='WITHHELD';
comment on column research.capture_grid_coordinate_decisions.map_review_status is
'Visual map acceptance only, not independently surveyed location accuracy. VISUALLY_VERIFIED retains provisional grid precision/uncertain prefix. Rejected sites keep NULL analysis coordinates.';
comment on column research.capture_grid_coordinate_decisions.map_review_note is
'Investigator visual map sign-off with scope and limitations, separate from provenance and original source.';


-- ================================================
-- MIGRATION VERSION: 20261105102945
-- MIGRATION NAME: wecs_20261105_withheld_grid_review_only_100km_candidates
-- ================================================

create or replace view analysis.grid_withheld_candidate_review_v1 with (security_invoker=false) as
select g.capture_id,e.tattoo,e.capture_date,e.is_pm,e.encounter_type,e.outcome,
g.original_grid_reference,c.capture_location_text as original_place_description,
g.source_easting,g.source_northing,g.corrected_easting as accepted_easting,
g.corrected_northing as accepted_northing,g.decision_status,g.map_review_status,
case
 when g.capture_id in (12072,17254) then 'INVESTIGATOR_REJECTED'
 when g.source_northing between 290000 and 300000 and g.source_easting between 370000 and 390000
 then 'TEST_100KM_NORTHING_SHIFT'
 when g.capture_id in (16861,17477) then 'LEG_OF_MUTTON_GRID_ANOMALY'
 else 'IRREGULAR_OR_REMOTE_GRID'
end as proposed_review_group,
case when g.decision_status='WITHHELD' and g.capture_id not in (12072,17254)
 and g.source_northing between 290000 and 300000 and g.source_easting between 370000 and 390000
then g.source_easting else null::numeric end as test_easting,
case when g.decision_status='WITHHELD' and g.capture_id not in (12072,17254)
 and g.source_northing between 290000 and 300000 and g.source_easting between 370000 and 390000
then g.source_northing - 100000 else null::numeric end as test_northing,
'REVIEW-ONLY: test coordinates NOT written to accepted encounter XY. Source map/grid-square identity and text must be checked before scientific acceptance.'::text as test_warning,
g.decision_note,g.map_review_note
from research.capture_grid_coordinate_decisions g
join analysis.encounters_clean_v1 e using(capture_id)
join research.captures c using(capture_id)
where g.decision_status='WITHHELD';
comment on view analysis.grid_withheld_candidate_review_v1 is
'ALL withheld historical grid sites, plus 30 test-only minus-100km northing candidates. No accepted locations assigned. Two researcher-rejected sites have no proposed replacement. Coordinates may be grid-square corners rather than actual observation positions.';
grant select on analysis.grid_withheld_candidate_review_v1 to badger_readonly,badger_research_readonly;


-- ================================================
-- MIGRATION VERSION: 20261105104300
-- MIGRATION NAME: wecs_20261105_accept_thirty_northing_shift_map_candidates
-- ================================================

-- 5 Nov 2026: investigator has visually accepted all thirty plotted hypothetical N-100km alternatives.
-- Preserve historical OS text and original parser positions, and keep 100m grid-cell/assumed prefix uncertainty.
do $$
declare n integer;
begin
 select count(*) into n
 from research.capture_grid_coordinate_decisions g
 join analysis.grid_withheld_candidate_review_v1 v using(capture_id)
 where g.decision_status='WITHHELD'
 and g.map_review_status='PENDING_REVIEW'
 and v.proposed_review_group='TEST_100KM_NORTHING_SHIFT'
 and v.test_easting=g.source_easting and v.test_northing=g.source_northing-100000
 and v.test_easting is not null and v.test_northing is not null;
 if n<>30 then
 raise exception 'Preflight expected 30 eligible, found %; no changes made.', n;
 end if;
end $$;

update research.capture_grid_coordinate_decisions g
set corrected_easting=v.test_easting,
corrected_northing=v.test_northing,
decision_status='CORRECTED',
map_review_status='VISUALLY_VERIFIED',
map_reviewed_at=now(),
map_review_note='Investigator inspected test-only -100km-northing map and approved all 30 alternatives 2026-11-05 as geographically plausible. Visual signoff is NOT a proof of exact original grid prefix, carcass recovery location or sub-cell accuracy.',
decision_note=g.decision_note || ' [2026-11-05 investigator map decision: accept test -100000m northing as PROVISIONAL grid-square proxy. Historical original ref and original parser XY remain unchanged. Never interpret as independent metre-accuracy survey.]',
decision_source='Original grid source + investigator interactive-map sign-off 2026-11-05'
from analysis.grid_withheld_candidate_review_v1 v
where v.capture_id=g.capture_id and g.decision_status='WITHHELD'
and g.map_review_status='PENDING_REVIEW'
and v.proposed_review_group='TEST_100KM_NORTHING_SHIFT'
and v.test_easting=g.source_easting and v.test_northing=g.source_northing-100000
and v.test_easting is not null and v.test_northing is not null;

update research.wecs_review_flags
set summary='87 corrected grid references visually approved; 10 remain withheld.',
evidence='5 Nov 2026: 57 previously corrected points plus 30 additional 100km northing-shift alternatives approved from interactive map. Original source refs unchanged, map acceptance only confirms plausible geography; source prefix and grid-square precision remain provisional. Two explicitly rejected grid points remain withheld.',
current_interpretation='87 corrected grid references carry VISUALLY_VERIFIED map-review status but remain provisional grid-square representations; 10 withheld await source evidence (including rejected UN260 and F030). Never discard mortality because XY is absent.',
updated_at=now()
where flag_id='SPATIAL-GRID';

do $$
begin
if (select count(*) from research.capture_grid_coordinate_decisions where decision_status='CORRECTED')<>87 or
   (select count(*) from research.capture_grid_coordinate_decisions where decision_status='WITHHELD')<>10 or
   (select count(*) from research.capture_grid_coordinate_decisions where map_review_status='VISUALLY_VERIFIED')<>87 or
   (select count(*) from research.capture_grid_coordinate_decisions where map_review_status='REJECTED_BY_INVESTIGATOR')<>2
then raise exception 'Post-update grid state failed, transaction rolled back'; end if;
end $$;


-- ================================================
-- MIGRATION VERSION: 20261105110514
-- MIGRATION NAME: wecs_20261105_west_gate_transposed_grid_un221
-- ================================================

do $$
begin
 if not exists (
 select 1 from research.capture_grid_coordinate_decisions g
 join research.captures c using(capture_id)
 where g.capture_id=17285 and g.original_grid_reference='014795'
 and g.decision_status='WITHHELD'
 and c.moc='RTA'
 and c.capture_location_text ilike '%west gate%'
 ) then raise exception 'UN221 original source not as expected: abort'; end if;
end $$;
update research.capture_grid_coordinate_decisions
set corrected_easting=379500,
corrected_northing=201400,
decision_status='CORRECTED',
map_review_status='PENDING_REVIEW',
map_review_note='Source cross-check with user-provided Woodchester Park west-gate latitude 51.711125 longitude -2.298038, transforms to BNG approximately E379504 N201419; independent listed historic gateway SO795014 (E379539 N201433). This establishes likely transposition of original six-digit reference 014795 to 795014. Geographically corroborated but exact RTA site within road corner not surveyed.',
decision_note='Original PM RTA source OS 014795 had three-digit easting/northing halves reversed. Location text explicitly corner of Woodchester Park west gate on Uley-Stroud road. Reconstructed SO795014, BNG E379500,N201400, representing a 100m OS grid square, with independent historic listed gateway at SO795014 and investigator WGS84 position within same grid cell. Original 014795 and prior parser E301400,N279500 preserved. Do not claim exact carcass point.',
decision_source='WECS original Access text + investigator map position 2026-11-05 + historic west gateway independently listed SO795014'
where capture_id=17285;

insert into research.wecs_review_flags
(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status,final_decision,final_decision_at)
values('SPATIAL-UN221-WEST-GATE','OS_GRID_HALVES_TRANSPOSED',array[17285]::bigint[],'UN221',
'West gate RTA original six-figure grid reference had reversed digit halves.',
'Capture 17285 2000-02-18 RTA, source 014795, recorded Woodchester Park west gate on Uley-Stroud road. Investigator location 51.711125,-2.298038 is BNG E379504,N201419; independently listed west gateway SO795014 E379539,N201433.',
'Reconstructed six-digit OS reference 795014. BNG grid-square SW corner E379500,N201400 is accepted as historically supported approximate recovery locality; not an exact carcass measurement.',
'RESOLVED',
'Original 014795 preserved; accepted corrected 100 m grid square SO795014 E379500,N201400 for spatial use with provisional quality. Mortality event unchanged.',now())
on conflict(flag_id) do nothing;

update research.wecs_review_flags
set summary='Grid QA: 88 corrected grid points, nine withheld, including two user-rejected.',
current_interpretation='87 earlier visually approved provisional grids plus UN221 west-gate six-figure transposition corroborated independently with user and listed gateway; now 88 corrected and 9 withheld. UN260 and F030 remain rejected. No mortality changes.',
updated_at=now()
where flag_id='SPATIAL-GRID';


-- ================================================
-- MIGRATION VERSION: 20261105110622
-- MIGRATION NAME: wecs_20261105_leg_of_mutton_and_cockadilly_spatial_review_flags
-- ================================================

insert into research.wecs_review_flags
(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status)
values
('SPATIAL-LEG-OF-MUTTON','HISTORICAL_FIELD_LOCATION',
array[8784,8783,16861,17012,17477,17495,17487,17334,16868,17319]::bigint[],null,
'Leg of Mutton is a named field/trapping locality, not a verified canonical sett.',
'1983 historical captures 8784 NET/FIELD LEG OF MUTTON MID and 8783 SNARE/HEDGE LEG OF MUTTON 35; 2019 SHOT (GP) PM records use Leg of Mutton, sometimes "above Peglars". No canonical matching research.setts name. Two PMs 16861 and 17477 both use SO820500 (N250000; inconsistent); other 2019 Leg of Mutton records use SO834020 and SO836003 and are not demonstrably the same exact location.',
'No new sett ID or sett coordinates assigned. Retain the historical field locality, two withheld SHOT PM XY and original death outcomes. If a map names the field or shot locations can be corroborated, correct individual capture XY, not automatically all Leg of Mutton records.',
'NEEDS_SOURCE_CHECK'),
('SPATIAL-COCKADILLY','NAMED_RECOVERY_LOCALITY',
array[18,12,3382]::bigint[],null,
'Cockadilly is a hamlet/RTA recovery locality rather than a confirmed badger sett.',
'No canonical sett named COCKADILLY; many source RTA records describe Cockadilly roads. Original capture 18 grid string 801791 COCKADILLY conflicts with named locality; another source capture 12 has 799002 COCKADILLY. Do not transfer coordinate between different RTA episodes.',
'Preserve capture 18 PM/RTA mortality and recorded Cockadilly place name but withhold XY until original grid can be corroborated. Do not add Cockadilly as canonical sett solely on these records.',
'NEEDS_SOURCE_CHECK')
on conflict (flag_id) do nothing;


-- ================================================
-- MIGRATION VERSION: 20261105111432
-- MIGRATION NAME: wecs_20261105_locality_cockadilly_and_two_independent_crosschecked_os_grids
-- ================================================

-- Targeted final spatial pass 2026-11-05.
-- Two independently corroborated reversed references, plus two approved Cockadilly centre proxies.
-- Only four capture IDs, preserving original Access and PM outcomes.
DO $$
DECLARE n int;
BEGIN
 SELECT COUNT(*) INTO n FROM research.capture_grid_coordinate_decisions g
 JOIN research.captures c USING(capture_id)
 WHERE g.decision_status='WITHHELD'
 AND ((g.capture_id=16869 AND c.os_ref='008802' AND c.moc='RTA')
 OR (g.capture_id=17117 AND c.os_ref='SO988808' AND c.moc='RTA')
 OR (g.capture_id=18 AND c.recorded_sett_name LIKE '%COCKADILLY%' AND c.moc='RTA'));
 IF n<>3 THEN RAISE EXCEPTION 'Expected exactly 3 withheld source records, got %',n; END IF;
 IF EXISTS (SELECT 1 FROM research.capture_grid_coordinate_decisions WHERE capture_id=3382)
 THEN RAISE EXCEPTION 'Cockadilly source 3382 already has a grid decision'; END IF;
END $$;

UPDATE research.capture_grid_coordinate_decisions
SET corrected_easting=380200,corrected_northing=200800,
decision_status='CORRECTED',map_review_status='PENDING_REVIEW',
decision_note='Original 008802 is a transposition of 802008, corroborated by two separate source RTAs at Tinkley Lane Nympsfield signpost/playing field: captures 16856 and 17002 have exact source 802008 E380200,N200800. Use 100m grid-square approximate locality, not exact layby/RTA point. Source original and formerly parsed E300800,N280200 retained.',
decision_source='WECS cross-record source grid and Tinkley Lane descriptions 2026-11-05',
map_review_note='Strong independent historic cross-record source corroboration; not individually surveyed. Accept as approximate location only.',
map_reviewed_at=now()
WHERE capture_id=16869;
UPDATE research.capture_grid_coordinate_decisions
SET corrected_easting=380800,corrected_northing=198800,
decision_status='CORRECTED',map_review_status='PENDING_REVIEW',
decision_note='Source SO988808 is an apparent transposition of 808988 AND mistaken SO square: corrected ST808988, E380800,N198800. Other independent Woodcock entrance original refs ST808989 (17077), ST807991 (16948/17146), SO807992 (17071). All point to this small roadside locality; this is a 100m grid square NOT exact carcass position. Original E398800,N280800 and SO988808 preserved. UN animal gets NO social-group assignment.',
decision_source='WECS cross-record original Woodcock OS reference audit 2026-11-05',
map_review_note='Corroborated by four original nearby Woodcock entrance records, retain grid-square approximation only; UN badger does not get SG.',
map_reviewed_at=now()
WHERE capture_id=17117;

UPDATE research.capture_grid_coordinate_decisions
SET corrected_easting=379800,corrected_northing=200200,
decision_status='CORRECTED',map_review_status='PENDING_REVIEW',
decision_note='Investigator explicitly approved assigning Cockadilly village-centre approximation instead of a spurious old 801791 grid. OSM node 412786736 Cockadilly hamlet centre 51.7004528,-2.2933255 converts to approx E379825,N200231. Rounded proxy E379800,N200200 (100m neighbourhood); this is locality CENTROID not exact RTA recovery grid or sett. Preserve original 801791 COCKADILLY and original misparsed E380100,N279100.',
decision_source='WECS_LOCALITY_CENTROID Cockadilly OSM hamlet node + user locality acceptance 2026-11-05',
map_review_note='APPROXIMATE hamlet centre only; not a site-specific accident coordinate and no sett/SG assignment.',
map_reviewed_at=now()
WHERE capture_id=18;

INSERT INTO research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,
decision_status,decision_note,decision_source,map_review_status,map_review_note,map_reviewed_at)
VALUES
(3382,'COCKADILLY',null,null,379800,200200,'CORRECTED',
'Original RTA locality is only Cockadilly (no source OS grid). Researcher accepted settlement centre as general location. OSM hamlet node 412786736 51.7004528,-2.2933255, rounded to E379800,N200200. Distinct from exact animal recovery location and not a canonical sett.',
'WECS_LOCALITY_CENTROID Cockadilly OSM hamlet node + user locality acceptance 2026-11-05',
'PENDING_REVIEW','Approximate village centre, not a surveyed capture/road-recovery point.',now());

CREATE OR REPLACE VIEW analysis.encounters_v1 WITH (security_invoker=true) AS
 WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN 'RECOVERY_SITE'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN source.prior_easting
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_northing IS NOT NULL THEN source.prior_northing
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN 'SETT'::text
            ELSE standardised.location_type_clean
        END AS location_type,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_easting
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_northing
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN grid.decision_status = 'WITHHELD'::text THEN 'GRID_REFERENCE_AMBIGUOUS_WITHHELD'::text
            WHEN grid.decision_status = 'CORRECTED'::text AND grid.decision_source LIKE 'WECS_LOCALITY_CENTROID%'::text THEN 'LOCALITY_CENTROID_APPROXIMATE'::text
            WHEN grid.decision_status = 'CORRECTED'::text THEN 'GRID_REFERENCE_CORRECTED_PROVISIONAL'::text
            WHEN standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text AND regexp_replace(upper(COALESCE(standardised.original_os_ref, ''::text)), '[[:space:],.-]'::text, ''::text, 'g'::text) ~ '^SO[0-9]{6}$'::text THEN 'GRID_CELL_100M_RECORDED_SO'::text
            WHEN standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text THEN 'GRID_CELL_100M_PREFIX_UNVERIFIED'::text
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id = alias.canonical_sett_id
     LEFT JOIN research.capture_grid_coordinate_decisions grid ON grid.capture_id = standardised.capture_id;

UPDATE research.wecs_review_flags
SET review_status='RESOLVED',final_decision='Cockadilly is an RTA recovery locality, not a sett. For capture IDs 18 and 3382 use an approved rounded hamlet-centre approximation E379800,N200200 with quality LOCALITY_CENTROID_APPROXIMATE; source text and original values unchanged. Do not use these centroids as exact capture/recovery coordinates.',final_decision_at=now(),
current_interpretation='Both unlocated Cockadilly PM RTAs now have a coarse locality-centre proxy, explicitly distinguished from grid-cell and exact field point.',updated_at=now()
WHERE flag_id='SPATIAL-COCKADILLY';

UPDATE research.wecs_review_flags
SET summary='Grid location audit: 92 interpreted points accepted, 6 withheld.',
current_interpretation='87 investigator-verified map points plus UN221 west-gate, two corroborated C016/UN492 road grids, and 2 Cockadilly hamlet-centre proxies. Of 92 CORRECTED decisions, 90 are grid/cell interpretations and 2 are LOCALITY_CENTROID_APPROXIMATE. Six WITHHELD points remain (2 investigator-rejected); no mortality events removed. Grid accuracy not overclaimed.',
updated_at=now() WHERE flag_id='SPATIAL-GRID';

DO $$
BEGIN
IF (SELECT COUNT(*) FROM research.capture_grid_coordinate_decisions WHERE decision_status='CORRECTED')<>92
OR (SELECT COUNT(*) FROM research.capture_grid_coordinate_decisions WHERE decision_status='WITHHELD')<>6
OR (SELECT COUNT(*) FROM analysis.encounters_clean_v1 WHERE location_quality='LOCALITY_CENTROID_APPROXIMATE')<>2
THEN RAISE EXCEPTION 'Spatial post-audit counts invalid; transaction rolled back'; END IF;
END $$;


-- ================================================
-- MIGRATION VERSION: 20261105150851
-- MIGRATION NAME: wecs_20261105_resolve_six_numeric_sett_fields_as_existing_grid_recoveries
-- ================================================

-- The six numeric strings appearing in the original SETT name field
-- are 6-digit British National Grid references, not named setts.
-- This migration is an audit classification only. Existing analysis XY,
-- source records, death fates and canonical sett IDs must NOT change.
DO $$
DECLARE n int;
BEGIN
 SELECT COUNT(*) INTO n
 FROM research.captures c
 JOIN analysis.encounters_clean_v1 e USING(capture_id)
 WHERE c.capture_id IN (30,32,57,62,73,77)
   AND c.capture_location_text='SETT'
   AND c.recorded_sett_name ~ '^[0-9]{6}$'
   AND c.sett_id IS NULL
   AND c.is_pm = TRUE
   AND e.location_easting IS NOT NULL AND e.location_northing IS NOT NULL
   AND e.location_type IN ('RECOVERY_SITE','ROAD');
 IF n<>6 THEN
   RAISE EXCEPTION 'Unexpected source/current analysis state for numeric SETT-field recoveries: %/6',n;
 END IF;
END $$;

UPDATE research.wecs_review_flags
SET category='NUMERIC_GRID_STORED_IN_SETT_NAME',
capture_ids=ARRAY[30,32,57,62,73,77]::bigint[],
summary='Six historical PM records have six-digit grid references in the SETT-name source field, not named setts.',
evidence='Source capture IDs 30=808011, 32=810997, 57=825008, 62=830028, 73=836008, 77=837009; all PM, no canonical sett_id, already decoded to 100m BNG squares in analysis.encounters_clean_v1. 810997 was already independently accepted as corrected provisional N199700. Mapped sett CHESTNUT lies inside the 808011 square, and PARK MILL inside the 837009 square; coincident square is not proof of capture at that sett. Nearest-sett comparisons for other records do not establish sett identity.',
current_interpretation='All six are grid-referenced PM recovery/road locations already represented by accepted approximate XY in analysis, not missing sett locations. Five retain GRID_CELL_100M_PREFIX_UNVERIFIED, one GRID_REFERENCE_CORRECTED_PROVISIONAL. No original source field rewrite, no new sett ID, no UN resident SG assignment.',
review_status='RESOLVED',
final_decision='Keep six 100m grid-square positions (capture 30 E380800/N201100; 32 E381000/N199700; 57 E382500/N200800; 62 E383000/N202800; 73 E383600/N200800; 77 E383700/N200900) as currently represented in cleaned analysis. Treat original numeric recorded_sett_name as misfiled grid reference, not a sett alias. Exact recovery sites and identity of nearby setts unproven. Original Access/research rows unchanged; death outcomes retained.',
final_decision_at=now(),
updated_at=now()
WHERE flag_id='SPATIAL-UNNAMED-SETT';

DO $$
BEGIN
IF (SELECT review_status FROM research.wecs_review_flags WHERE flag_id='SPATIAL-UNNAMED-SETT')<>'RESOLVED'
THEN RAISE EXCEPTION 'Expected existing numeric-SETT issue flag not found; aborted'; END IF;
END $$;

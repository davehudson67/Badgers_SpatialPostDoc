-- Woodchester WECS CURATED SNAPSHOT extracted from LIVE Supabase 2026-11-04.
-- Apply AFTER initial data imports and original capture/spatial standardisation migrations.
-- This is a REPLAYABLE baseline for curated decisions and eight current WECS views,
-- NOT a complete dump/rebuild of the historical Access/research base schema.
-- Source research.captures and access_raw are never overwritten.
-- On conflict DO NOTHING retains existing manual decisions; review differences manually.

begin;

create table if not exists research.encounter_episode_decisions (
live_capture_id bigint primary key references research.captures(capture_id),
pm_capture_id bigint unique not null references research.captures(capture_id),
episode_outcome text not null,
decision_status text not null,
field_location_basis text not null,
decision_note text not null,
review_flags text[] not null default '{}'::text[],
decision_source text not null,
decided_at timestamptz not null default now(),
constraint wecs_episodes_different_source_rows check (live_capture_id<>pm_capture_id)
);
create table if not exists research.encounter_pair_nonlinks(
first_capture_id bigint not null references research.captures(capture_id),
second_capture_id bigint not null references research.captures(capture_id),
decision text not null,decision_note text not null,decision_source text not null,
decided_at timestamptz not null default now(),
primary key(first_capture_id,second_capture_id)
);
create table if not exists research.encounter_classification_decisions(
capture_id bigint primary key references research.captures(capture_id),
encounter_type text,outcome text,
decision_note text not null,decision_source text not null,
decided_at timestamptz not null default now()
);
create table if not exists research.capture_sett_alias_decisions(
capture_id bigint primary key references research.captures(capture_id),
original_recorded_name text not null,
canonical_sett_id bigint not null references research.setts(sett_id),
decision_note text not null,decision_source text not null,
decided_at timestamptz not null default now()
);
create table if not exists research.wecs_review_flags(
flag_id text primary key,category text not null,capture_ids bigint[] not null,
tattoo text,summary text not null,evidence text not null,
current_interpretation text not null,
review_status text not null check(review_status in ('OPEN','RESOLVED','NEEDS_SOURCE_CHECK','WAITING_FIELD_TEAM')),
final_decision text,final_decision_at timestamptz,
updated_at timestamptz not null default now()
);
alter table research.encounter_episode_decisions enable row level security;
alter table research.encounter_pair_nonlinks enable row level security;
alter table research.encounter_classification_decisions enable row level security;
alter table research.capture_sett_alias_decisions enable row level security;
alter table research.wecs_review_flags enable row level security;

-- SOUTH PEGLARS is a separately named historical sett. Coordinates unknown.
insert into research.setts(sett_id,sett_name,notes)
values(555,'SOUTH PEGLARS','S PEGLARS: distinct historical sett, 3 captures 1990-02-06 under HOGARTHS; XY unknown; do not merge with PEGLARS (ID 135).')
on conflict(sett_id) do nothing;

insert into research.encounter_episode_decisions (live_capture_id,pm_capture_id,episode_outcome,decision_status,field_location_basis,decision_note,review_flags,decision_source) values
(1672,1674,'EUTHANISED','CONFIRMED','PM_RECORD','N070: 1987-06-01 found in extremis in Boundary Court field, PM field lists RTA cause; 1987-06-02 same badger (10.6kg) recorded PUT DOWN. Researcher confirms one RTA-associated episode spanning two record dates; outcome euthanised (PUT DOWN). The earlier FOUND EXT source is treated as the original field discovery, not the later PUT DOWN entry.',ARRAY['PM_RECORD_PRECEDES_PUT_DOWN','RTA_ASSOCIATED','FIELD_COORDINATE_NEEDS_VERIFICATION']::text[],'Researcher confirmation 2026-11-03, paired original records 1674 and 1672'),
(6508,17565,'EUTHANISED','CONFIRMED','LIVE_RECORD','Same individual/date; Inchbrook live capture, veterinarian euthanised before recovery from anaesthetic; separate PM record.',ARRAY[]::text[],'Researcher-reviewed paired records, 2026-11-03'),
(9440,9439,'EUTHANISED','CONFIRMED','LIVE_RECORD','G010 netted at Old Byre 1977-07-18 (poor condition), then put down 1977-07-19 with PM cause EUTH. Researcher-reviewed as one capture/euthanasia episode documented by two source records. The one-day later PM record is retained at its original date.',ARRAY['NEXT_DAY_PM_DATE']::text[],'Researcher decision 2026-11-03; original capture 9440 and PM 9439'),
(12854,16903,'EUTHANISED','CONFIRMED','LIVE_RECORD','Same individual/date; recaptured at Top to examine leg-cuff injuries, then euthanised; prior leg-cuff capture/release is a separate dated event.',ARRAY[]::text[],'Researcher-reviewed paired records, 2026-11-03'),
(14193,16895,'EUTHANISED','CONFIRMED','LIVE_RECORD','Same individual/date; live trapping at West and euthanasia; PM adds pathological observations.',ARRAY[]::text[],'Researcher-reviewed paired records, 2026-11-03'),
(14571,17457,'DIED_AFTER_CAPTURE','CONFIRMED','LIVE_RECORD','Same individual/date; trapped at Windsor Edge, died during/after anaesthesia. PM record additionally reports RTA/ruptured diaphragm; separate PM OS reference is retained and must not replace trap-sett coordinate.',ARRAY['PM_RTA_CAUSE_TO_REVIEW','PM_OS_REFERENCE_DIFFERS_FROM_SETT']::text[],'Researcher-reviewed paired records, 2026-11-03'),
(14756,16879,'EUTHANISED','CONFIRMED','LIVE_RECORD','Same individual/date; captured at Windsor Edge, euthanised after trap-induced jaw injury. Weight discrepancy between source rows retained.',ARRAY['WEIGHT_DISCREPANCY']::text[],'Researcher-reviewed paired records, 2026-11-03'),
(14757,16878,'EUTHANISED','CONFIRMED','LIVE_RECORD','Same individual/date; trapped at Windsor Edge, euthanised at sampling facility following deterioration.',ARRAY[]::text[],'Researcher-reviewed paired records, 2026-11-03'),
(16882,16817,'EUTHANISED','CONFIRMED','PM_RECORD','024Y: same individual, same date 2014-08-14, identical 9.5kg, FOUND EXT primary and PM. Primary original says suspected RTA and explicitly euthanased; PM gives SO813006 and discovery text Tinkley Lane. One mortality event, not two. PM grid reference is coarse recovery/discovery evidence, NOT proof that original SETT field is exact or that last resident sett was at the discovery point.',ARRAY['RTA_ASSOCIATED','PM_GRID_SQUARE_NOT_SETT','TWO_SOURCE_ROWS_SINGLE_DEATH','PRIMARY_SETT_NAME_ABSENT']::text[],'2026-11-04 Woodchester six unnamed SETT audit: corroborating original capture/PM source data'),
(16896,16853,'EUTHANISED','CONFIRMED','LIVE_RECORD','Same individual/date; found alive injured on track between Box and West, then euthanised; trap designation in live record is inconsistent with narrative. Actual field coordinates unresolved.',ARRAY['ENCOUNTER_METHOD_TO_REVIEW','FIELD_LOCATION_UNRESOLVED']::text[],'Researcher-reviewed paired records, 2026-11-03')
on conflict (live_capture_id) do nothing;

insert into research.encounter_pair_nonlinks (first_capture_id,second_capture_id,decision,decision_note,decision_source) values
(8939,405,'SEPARATE_EVENTS','Y030 netted at MEAD on 1981-07-14; separate recovery at ARTHURS on 1981-07-16 (FOUND DEAD, PM cause STARV). Researcher reviewed as two distinct encounter events, not duplicate capture/PM documentation. The initial NET record may be treated as PRESUMED_RELEASED under the operational default, never confirmed released; the death record retains independent recovery coordinates.','Researcher decision 2026-11-03; source capture 8939 and recovery 405')
on conflict (first_capture_id,second_capture_id) do nothing;

insert into research.encounter_classification_decisions (capture_id,encounter_type,outcome,decision_note,decision_source) values
(1099,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporary PM REMOVAL records at same dates/sites record KILLED; infer lethal removal. No individual PM.','Researcher review 2026-11-03'),
(1666,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporary PM REMOVAL records record KILLED; infer lethal removal. No individual PM.','Researcher review 2026-11-03'),
(1671,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(2744,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4177,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4178,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4298,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4345,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(4348,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(5038,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(6692,NULL,'DIED','Source TRAP PM, pm_cause=IATRO. Death established; mechanism/circumstances not inferred further.','Researcher review 2026-11-03'),
(8109,NULL,'KILLED','1979 coordinated REMOVAL operation; contemporaneous PM REMOVAL records record KILLED. No individual PM.','Researcher review 2026-11-03'),
(8810,'FOUND_ALIVE','PRESUMED_RELEASED','Found alive in garage, sampled; no documented release. Researcher authorises presumed release, not confirmed.','Researcher review 2026-11-03'),
(8880,NULL,'PRESUMED_RELEASED','False-positive euthanasia removed: words "both put down as trap 1" describe trap numbering, NOT killing animal. Source 2025-05-20 says release_assessment Fit, anaesthetised/sampled; subsequently live TRAP 2026-06-10. Release not directly observed.','WECS longitudinal mortality contradiction review, 2026-11-04'),
(14170,NULL,'PRESUMED_RELEASED','Original RTA non-PM July 1998 does not prove death. Badger D061 repeatedly recaptured alive from Oct 1998 through June 2001. Researcher-death override superseded by later live evidence; retain RTA as original encounter_type. Actual release at this event not explicitly documented.','WECS longitudinal mortality contradiction review, 2026-11-04'),
(16832,'UNKNOWN','FOUND_DEAD','PM record roadside Coaley Peak, no source MOC or PM cause; researcher interprets as dead recovery. Original encounter method remains unknown.','Researcher review 2026-11-03'),
(16920,NULL,'DIED','Original FOUND EXT, non-PM record with documented live sampling/bite wounds. Researcher treats as dead encounter; source does not independently establish death, so manual decision remains reviewable.','Researcher review 2026-11-03'),
(17055,'UNKNOWN','FOUND_DEAD','Original PM location text explicitly reports decomposed carcass at Jacks sett; original MOC blank.','Researcher review 2026-11-03'),
(17224,'UNKNOWN','DIED','PM record only, original MOC/cause/location blank. Death inferred from PM designation; discovery method remains UNKNOWN.','Researcher review 2026-11-03'),
(17250,'UNKNOWN','FOUND_DEAD','PM record from Glider field road; no source MOC. Dead recovery interpretation from PM inclusion, without inventing cause.','Researcher review 2026-11-03'),
(17251,'UNKNOWN','FOUND_DEAD','PM record from Glider field road; no source MOC. Dead recovery interpretation from PM inclusion, without inventing cause.','Researcher review 2026-11-03'),
(17284,NULL,'FOUND_DEAD','Public report along Tinkley Lane with PM flag; death inferred from PM inclusion, original reporting method retained.','Researcher review 2026-11-03'),
(17555,'FOUND_ALIVE',NULL,'Original REMOVAL 2001 is explicitly found alive under woodpile and taken for sampling. Not part of 1979 lethal removals; release not documented; retain UNKNOWN outcome.','Researcher review 2026-11-03')
on conflict (capture_id) do nothing;

insert into research.capture_sett_alias_decisions (capture_id,original_recorded_name,canonical_sett_id,decision_note,decision_source) values
(9097,'MRS MACKS',22,'Punctuation-only name harmonisation MRS MACKS => MRS MACK''S (canonical sett ID 22). Original location type BOUNDARY: retain as a boundary observation with sett association only; do not use the sett centre (380365,200369) as the encounter point.','Researcher-approved name alias, 2026-11-04; source capture 9097'),
(11607,'S PEGLARS',555,'Investigator confirmed S PEGLARS means SOUTH PEGLARS; kept distinct from PEGLARS because 1990 captures are recorded in HOGARTHS while PEGLARS captures recorded in PEGLARS. Source SETT type, canonical South Peglars XY missing. Do not infer sett coordinates or social-group change.','Researcher approval 2026-11-04; WECS sett-name audit'),
(11608,'S PEGLARS',555,'Investigator confirmed S PEGLARS means SOUTH PEGLARS; kept distinct from PEGLARS because 1990 captures are recorded in HOGARTHS while PEGLARS captures recorded in PEGLARS. Source SETT type, canonical South Peglars XY missing. Do not infer sett coordinates or social-group change.','Researcher approval 2026-11-04; WECS sett-name audit'),
(11609,'S PEGLARS',555,'Investigator confirmed S PEGLARS means SOUTH PEGLARS; kept distinct from PEGLARS because 1990 captures are recorded in HOGARTHS while PEGLARS captures recorded in PEGLARS. Source SETT type, canonical South Peglars XY missing. Do not infer sett coordinates or social-group change.','Researcher approval 2026-11-04; WECS sett-name audit'),
(12030,'STONEY TRACK',29,'Known spelling harmonisation STONEY TRACK => STONY TRACK; SNARE in WOOD, associate with sett 29 but do not copy sett-centre coordinates as capture point.','Researcher-approved name rule; 2026-11-04'),
(12031,'STONEY TRACK',29,'Known spelling harmonisation STONEY TRACK => STONY TRACK; TRAP at SETT, use canonical sett-point coordinates as provisional proxy (not an independently measured trap location).','Researcher-approved name rule; 2026-11-04'),
(14456,'WEST MAIN',35,'Investigator confirmed WEST MAIN is canonical WEST sett 35. Source capture_location_text SETT. Use existing WEST sett XY as provisional sett point, not a trap-specific measurement. Keep recorded WYCH ELM social group unchanged, despite canonical WEST capture records typically having WEST social group.','Researcher approval 2026-11-04; WECS sett-name audit'),
(14457,'WEST MAIN',35,'Investigator confirmed WEST MAIN is canonical WEST sett 35. Source capture_location_text SETT. Use existing WEST sett XY as provisional sett point, not a trap-specific measurement. Keep recorded WYCH ELM social group unchanged, despite canonical WEST capture records typically having WEST social group.','Researcher approval 2026-11-04; WECS sett-name audit'),
(14458,'WEST MAIN',35,'Investigator confirmed WEST MAIN is canonical WEST sett 35. Source capture_location_text SETT. Use existing WEST sett XY as provisional sett point, not a trap-specific measurement. Keep recorded WYCH ELM social group unchanged, despite canonical WEST capture records typically having WEST social group.','Researcher approval 2026-11-04; WECS sett-name audit')
on conflict (capture_id) do nothing;

insert into research.wecs_review_flags (flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status,final_decision,final_decision_at) values
('DEATH-014D','FALSE_DEATH',ARRAY['8880','9767']::text[],'014D','Trap-numbering wording incorrectly interpreted as euthanasia.','2025-05-20 note says both put down as trap 1, release assessment Fit, live capture 2026-06-10.','Routine capture, presumed released.','RESOLVED','Outcome PRESUMED_RELEASED; words put down describe trap numbering, not killing.','2026-11-04 09:14:57.33434+00'),
('DEATH-020D','IDENTITY_CONFLICT',ARRAY['17328','15335']::text[],'020D','RTA PM with major head injuries in 2020; live capture in 2022.','PM 2020-05-18; live TRAP 2022-10-18 and subsequent captures.','Preserve true PM record; tattoo/individual linkage unverified.','NEEDS_SOURCE_CHECK',NULL,NULL),
('DEATH-024Y','DUPLICATE_EPISODE',ARRAY['16882','16817']::text[],'024Y','Same-day found-in-extremis and PM; one euthanasia.','2014-08-14 same tattoo, date and 9.5kg; original euthanasia notes and PM Tinkley Lane SO813006.','One euthanasia episode; PM is companion, grid site is approximate.','RESOLVED','Confirmed same event. Link live 16882 to PM 16817; count one death and preserve both rows.','2026-11-04 09:14:57.33434+00'),
('DEATH-D061','FALSE_DEATH',ARRAY['14170','14171']::text[],'D061','RTA initially misclassified as death, with later live captures.','1998-07-28 non-PM RTA; subsequent TRAP from 1998-10-06 onwards.','Not confirmed fatal; RTA retained, outcome presumed released.','RESOLVED','Correct record 14170 to PRESUMED_RELEASED; do not censor at July 1998.','2026-11-04 09:14:57.33434+00'),
('DEATH-Q082','POSSIBLE_DUPLICATE',ARRAY['17055','7311']::text[],'Q082','Two death records two days apart at Jacks.','PM 2000-05-15 decomposed carcass; 2000-05-17 FOUND DEAD notes too decomposed for PM.','Likely one carcass, retain records pending source confirmation.','OPEN',NULL,NULL),
('DEATH-U005','IDENTITY_CONFLICT',ARRAY['16968','15531']::text[],'U005','PM-found-dead in 2003 followed by live capture of same tattoo.','PM 2003-02-06; live TRAP 2003-09-02.','Keep PM mortality evidence; do not assume death belongs to later live animal until identity verified.','NEEDS_SOURCE_CHECK',NULL,NULL),
('DEATH-W023','POSSIBLE_DUPLICATE',ARRAY['4984','4987']::text[],'W023','Two death records 18 days apart at Giant Beech.','PM FOUND DEAD 1980-04-02; non-PM FOUND DEAD 1980-04-20, same individual.','Possible repeat record of same carcass; no live recapture.','OPEN',NULL,NULL),
('SPATIAL-CONFLICT','LOCATION_CONFLICT',ARRAY[]::text[],NULL,'107 sett-association versus non-sett physical encounter conflicts.','FIELD/WOOD/BOUNDARY/HEDGE/BUILDING/RTA etc in original location text.','Protect physical encounter-site semantics; do not copy nominal sett XY.','OPEN',NULL,NULL),
('SPATIAL-GRID','GRID_PRECISION',ARRAY[]::text[],NULL,'594 grid precision warnings in current WECS clean view.','Grid references, 100m squares, SW corners and missing original OS references need verification.','Keep resolution flags; do not present grid cell as precise individual position.','OPEN',NULL,NULL),
('SPATIAL-SETT-XY','MISSING_COORDINATES',ARRAY[]::text[],NULL,'Named sett and outlier coordinates pending from field team.','Field-team request CSV in Git: 57 supplied names plus 2 descriptive SETT-related recovery locations.','Do not invent XY; keep unresolved and provenance flags.','WAITING_FIELD_TEAM',NULL,NULL)
on conflict (flag_id) do nothing;

create or replace view analysis.encounter_episode_decisions_v1 with (security_invoker=true) as
SELECT d.live_capture_id,
    d.pm_capture_id,
    d.episode_outcome,
    d.decision_status,
    d.field_location_basis,
    d.decision_note,
    d.review_flags,
    d.decision_source,
    d.decided_at,
    l.tattoo,
    l.capture_date,
    l.sett_id AS field_sett_id,
    l.sett_name AS field_sett_name,
        CASE
            WHEN (d.field_location_basis = 'PM_RECORD'::text) THEN p.location_easting
            ELSE l.location_easting
        END AS field_easting,
        CASE
            WHEN (d.field_location_basis = 'PM_RECORD'::text) THEN p.location_northing
            ELSE l.location_northing
        END AS field_northing,
        CASE
            WHEN (d.field_location_basis = 'PM_RECORD'::text) THEN p.coordinate_representation
            ELSE l.coordinate_representation
        END AS field_coordinate_representation,
    p.location_easting AS original_pm_easting,
    p.location_northing AS original_pm_northing,
    p.coordinate_representation AS original_pm_coordinate_representation
   FROM ((research.encounter_episode_decisions d
     JOIN analysis.encounters_standardised_v1 l ON ((l.capture_id = d.live_capture_id)))
     JOIN analysis.encounters_standardised_v1 p ON ((p.capture_id = d.pm_capture_id)));

create or replace view analysis.encounter_pair_nonlinks_v1 with (security_invoker=true) as
SELECT n.first_capture_id,
    n.second_capture_id,
    n.decision,
    n.decision_note,
    n.decision_source,
    n.decided_at,
    a.tattoo,
    a.capture_date AS first_date,
    a.original_moc AS first_method,
    b.capture_date AS second_date,
    b.original_moc AS second_method
   FROM ((research.encounter_pair_nonlinks n
     JOIN analysis.encounters_standardised_v1 a ON ((a.capture_id = n.first_capture_id)))
     JOIN analysis.encounters_standardised_v1 b ON ((b.capture_id = n.second_capture_id)));

create or replace view analysis.encounters_with_episodes_v1 with (security_invoker=true) as
SELECT e.capture_id,
    e.tattoo,
    e.capture_date,
    e.original_moc,
    e.is_pm,
    e.original_location_name,
    e.original_location_text,
    e.original_os_ref,
    e.original_comment,
    e.original_pm_cause,
    e.prior_location_class,
    e.prior_reference_source,
    e.grid_sw_easting,
    e.grid_sw_northing,
    e.newly_parsed_cell_width_m,
    e.spatial_interpretation,
    e.positional_precision_note,
    e.sett_id,
    e.sett_name,
    e.sett_easting,
    e.sett_northing,
    e.encounter_type,
    e.alive_when_encountered,
    e.encounter_outcome,
    e.location_role,
    e.location_type,
    e.location_easting,
    e.location_northing,
    e.coordinate_representation,
    e.location_source,
    e.location_status,
    e.has_spatial_location,
    e.needs_location_review,
    e.review_trap_pm,
    e.review_unlinked_trap,
    e.review_sett_missing_xy,
    e.review_pm_sett_role,
    e.review_trap_pm_grid_role,
    e.rule_version,
    COALESCE(dl.live_capture_id, dp.live_capture_id) AS episode_primary_capture_id,
    COALESCE(dl.pm_capture_id, dp.pm_capture_id) AS episode_pm_capture_id,
        CASE
            WHEN (dl.live_capture_id IS NOT NULL) THEN 'FIELD_RECORD'::text
            WHEN (dp.pm_capture_id IS NOT NULL) THEN 'PM_COMPANION'::text
            ELSE 'STANDALONE'::text
        END AS episode_record_role,
    COALESCE(dl.episode_outcome, dp.episode_outcome, e.encounter_outcome) AS resolved_episode_outcome,
    COALESCE(dl.decision_status, dp.decision_status) AS episode_decision_status,
    COALESCE(dl.review_flags, dp.review_flags, ARRAY[]::text[]) AS episode_review_flags,
    chosen_field.location_easting AS episode_field_easting,
    chosen_field.location_northing AS episode_field_northing,
    chosen_field.coordinate_representation AS episode_field_coordinate_representation
   FROM (((analysis.encounters_standardised_v1 e
     LEFT JOIN research.encounter_episode_decisions dl ON ((dl.live_capture_id = e.capture_id)))
     LEFT JOIN research.encounter_episode_decisions dp ON ((dp.pm_capture_id = e.capture_id)))
     LEFT JOIN analysis.encounters_standardised_v1 chosen_field ON ((chosen_field.capture_id =
        CASE
            WHEN (COALESCE(dl.field_location_basis, dp.field_location_basis) = 'PM_RECORD'::text) THEN COALESCE(dl.pm_capture_id, dp.pm_capture_id)
            ELSE COALESCE(dl.live_capture_id, dp.live_capture_id)
        END)));

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
            ((((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text)) AS narrative,
                CASE
                    WHEN ((upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND (e.sett_id IS NOT NULL) AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text]))) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN ((c.moc IS NULL) AND (c.is_pm = false) AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE ((later.individual_id = c.individual_id) AND (later.capture_date > c.capture_date) AND (later.is_pm = false) AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR ((later.moc IS NULL) AND (later.weight IS NOT NULL) AND (later.blood_sample_taken = true))))))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM (analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id))
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
                    WHEN (source.original_moc = 'TRAP'::text) THEN 'TRAP'::text
                    WHEN (source.original_moc = 'NET'::text) THEN 'NET'::text
                    WHEN (source.original_moc = 'SNARE'::text) THEN 'SNARE'::text
                    WHEN (source.original_moc = 'DART GUN'::text) THEN 'DART'::text
                    WHEN (source.original_moc = 'FOUND EXT'::text) THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN (source.original_moc = 'FOUND DEAD'::text) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = 'RTA'::text) THEN 'RTA'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text])) THEN 'SHOT'::text
                    WHEN (source.original_moc = 'REMOVAL'::text) THEN 'REMOVAL'::text
                    WHEN (source.original_moc = 'PUT DOWN'::text) THEN 'PUT_DOWN'::text
                    WHEN (source.original_moc = 'DEAD SN/TR'::text) THEN 'DEAD_SNARE_TRAP'::text
                    WHEN (source.original_moc = 'ON ROAD'::text) THEN 'ON_ROAD'::text
                    WHEN (source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text) THEN 'PUBLIC_REPORT'::text
                    WHEN ((source.original_moc IS NULL) AND (NOT source.is_pm) AND (source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text)) THEN 'FOUND_ALIVE'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text)) THEN 'SHOT'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text)) THEN 'RTA'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text)) THEN 'FOUND_DEAD'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text)) THEN 'TRAP'::text
                    WHEN ((source.original_moc IS NULL) AND (NOT source.is_pm) AND (source.sett_id IS NOT NULL) AND (source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text) AND (source.capture_date >= '1998-01-01'::date) AND (source.capture_date < '2000-01-01'::date) AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE ((rc.capture_id = source.capture_id) AND (rc.blood_sample_taken = true) AND (rc.weight IS NOT NULL)))) AND (NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE ((pm.individual_id = source.individual_id) AND (pm.is_pm = true) AND (pm.capture_date >= source.capture_date) AND (pm.capture_date <= (source.capture_date + 7))))))) THEN 'TRAP'::text
                    WHEN ((source.original_moc IS NULL) AND source.subsequent_live_sampling) THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN (source.episode_primary_capture_id IS NOT NULL) THEN
                    CASE
                        WHEN (source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text) THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN ((source.original_moc IS NULL) AND (NOT source.is_pm) AND (source.narrative ~* 'sampled and released at night|sampled and released'::text)) THEN 'RELEASED'::text
                    WHEN (source.original_moc = 'PUT DOWN'::text) THEN 'EUTHANISED'::text
                    WHEN ((source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND ((source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text) OR (upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text))) THEN 'EUTHANISED'::text
                    WHEN ((source.original_moc = 'FOUND EXT'::text) AND (upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text)) THEN 'KILLED'::text
                    WHEN ((source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND ((source.release_assessment = 'Death'::text) OR (source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text))) THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text])) THEN 'FOUND_DEAD'::text
                    WHEN ((source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm) THEN 'FOUND_DEAD'::text
                    WHEN ((source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm) THEN 'KILLED'::text
                    WHEN ((source.original_moc = 'REMOVAL'::text) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text)) THEN 'KILLED'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text)) THEN 'KILLED'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text)) THEN 'FOUND_DEAD'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text)) THEN 'FOUND_DEAD'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text)) THEN 'DIED'::text
                    WHEN ((source.original_moc IS NULL) AND source.is_pm AND (NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL)) THEN 'DIED'::text
                    WHEN ((source.original_moc = 'FOUND EXT'::text) AND source.is_pm) THEN 'DIED'::text
                    WHEN ((source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND (NOT source.is_pm)) THEN 'PRESUMED_RELEASED'::text
                    WHEN ((source.original_moc IS NULL) AND (NOT source.is_pm) AND (source.sett_id IS NOT NULL) AND (source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text) AND (source.capture_date >= '1998-01-01'::date) AND (source.capture_date < '2000-01-01'::date) AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE ((rc.capture_id = source.capture_id) AND (rc.blood_sample_taken = true) AND (rc.weight IS NOT NULL)))) AND (NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE ((pm.individual_id = source.individual_id) AND (pm.is_pm = true) AND (pm.capture_date >= source.capture_date) AND (pm.capture_date <= (source.capture_date + 7))))))) THEN 'PRESUMED_RELEASED'::text
                    WHEN ((source.original_moc IS NULL) AND (NOT source.is_pm) AND source.subsequent_live_sampling) THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN (source.episode_record_role = 'PM_COMPANION'::text) THEN 'LINKED_FIELD_SITE'::text
                    WHEN ((upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text) AND (source.sett_id IS NOT NULL)) THEN 'SETT'::text
                    WHEN ((source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR ((source.original_moc IS NULL) AND source.is_pm AND (COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text))) THEN 'ROAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text])) THEN 'RECOVERY_SITE'::text
                    WHEN (upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text])) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN (source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text])) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN (source.sett_id IS NOT NULL) THEN 'SETT_ASSOCIATION'::text
                    WHEN (source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN (source.episode_record_role = 'PM_COMPANION'::text) THEN source.episode_field_easting
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN (source.episode_record_role = 'PM_COMPANION'::text) THEN source.episode_field_northing
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN ((source.episode_record_role = 'PM_COMPANION'::text) AND (source.episode_field_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) AND (source.episode_field_easting IS NOT NULL)) THEN 'LINKED_GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN ((source.episode_record_role = 'PM_COMPANION'::text) AND (source.episode_field_easting IS NOT NULL)) THEN 'LINKED_SETT_POINT_PROVISIONAL'::text
                    WHEN (source.episode_record_role = 'PM_COMPANION'::text) THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN ((source.prior_easting IS NULL) OR (source.prior_northing IS NULL)) THEN 'UNRESOLVED'::text
                    WHEN ((source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) AND (source.newly_parsed_cell_width_m IS NOT NULL)) THEN 'GRID_CELL'::text
                    WHEN (source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN ((source.prior_coordinate_representation = 'SETT_POINT'::text) AND (upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text)) THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN (source.prior_coordinate_representation = 'SETT_POINT'::text) THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
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
            WHEN ((alias.capture_id IS NOT NULL) AND (upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text)) THEN 'SETT'::text
            ELSE standardised.location_type_clean
        END AS location_type,
        CASE
            WHEN ((alias.capture_id IS NOT NULL) AND (upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text)) THEN mapped_sett.easting
            WHEN (alias.capture_id IS NOT NULL) THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN ((alias.capture_id IS NOT NULL) AND (upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text)) THEN mapped_sett.northing
            WHEN (alias.capture_id IS NOT NULL) THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN ((alias.capture_id IS NOT NULL) AND (upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text) AND (mapped_sett.easting IS NOT NULL) AND (mapped_sett.northing IS NOT NULL)) THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN (alias.capture_id IS NOT NULL) THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM (((standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id))
     LEFT JOIN research.capture_sett_alias_decisions alias ON ((alias.capture_id = standardised.capture_id)))
     LEFT JOIN research.setts mapped_sett ON ((mapped_sett.sett_id = alias.canonical_sett_id)));

create or replace view analysis.encounters_clean_v1 with (security_invoker=true) as
SELECT capture_id,
    tattoo,
    capture_date,
    is_pm,
    sett_id,
    episode_primary_capture_id,
    episode_record_role,
    encounter_type,
    outcome,
    location_type,
    location_easting,
    location_northing,
    location_quality
   FROM analysis.encounters_v1;

create or replace view analysis.capture_sett_alias_audit_v1 with (security_invoker=true) as
SELECT a.capture_id,
    c.capture_date,
    c.recorded_sett_name AS original_name,
    a.canonical_sett_id,
    s.sett_name AS canonical_sett_name,
    c.capture_location_text,
    e.location_type,
    e.location_quality,
    a.decision_note,
    a.decision_source,
    a.decided_at
   FROM (((research.capture_sett_alias_decisions a
     JOIN research.captures c USING (capture_id))
     JOIN research.setts s ON ((s.sett_id = a.canonical_sett_id)))
     JOIN analysis.encounters_v1 e USING (capture_id));

create or replace view analysis.mortality_events_review_v1 with (security_invoker=true) as
WITH deaths AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date AS recorded_event_date,
            e.outcome AS mortality_outcome,
            e.encounter_type,
            e.is_pm,
            e.location_easting,
            e.location_northing,
            e.location_quality,
            e.episode_primary_capture_id,
            e.episode_record_role,
            c.individual_id,
            c.moc AS original_moc,
            c.pm_cause,
            ep.pm_capture_id AS linked_pm_capture_id,
            pm.capture_date AS linked_pm_date,
                CASE
                    WHEN ((e.location_easting IS NULL) AND (pm.location_easting IS NOT NULL)) THEN pm.location_easting
                    ELSE e.location_easting
                END AS best_available_easting,
                CASE
                    WHEN ((e.location_northing IS NULL) AND (pm.location_northing IS NOT NULL)) THEN pm.location_northing
                    ELSE e.location_northing
                END AS best_available_northing,
                CASE
                    WHEN ((e.location_easting IS NULL) AND (pm.location_easting IS NOT NULL)) THEN pm.location_quality
                    ELSE e.location_quality
                END AS best_available_location_quality
           FROM (((analysis.encounters_clean_v1 e
             JOIN research.captures c USING (capture_id))
             LEFT JOIN research.encounter_episode_decisions ep ON ((ep.live_capture_id = e.capture_id)))
             LEFT JOIN analysis.encounters_clean_v1 pm ON ((pm.capture_id = ep.pm_capture_id)))
          WHERE ((e.outcome = ANY (ARRAY['FOUND_DEAD'::text, 'DIED'::text, 'KILLED'::text, 'EUTHANISED'::text])) AND (e.episode_record_role <> 'PM_COMPANION'::text))
        ), tested AS (
         SELECT d.capture_id,
            d.tattoo,
            d.recorded_event_date,
            d.mortality_outcome,
            d.encounter_type,
            d.is_pm,
            d.location_easting,
            d.location_northing,
            d.location_quality,
            d.episode_primary_capture_id,
            d.episode_record_role,
            d.individual_id,
            d.original_moc,
            d.pm_cause,
            d.linked_pm_capture_id,
            d.linked_pm_date,
            d.best_available_easting,
            d.best_available_northing,
            d.best_available_location_quality,
            ( SELECT min(x.capture_date) AS min
                   FROM research.captures x
                  WHERE ((x.individual_id = d.individual_id) AND (x.capture_date > d.recorded_event_date) AND (x.is_pm = false) AND (x.moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])))) AS next_live_capture_date,
            ( SELECT min(e2.capture_date) AS min
                   FROM (analysis.encounters_clean_v1 e2
                     JOIN research.captures c2 USING (capture_id))
                  WHERE ((c2.individual_id = d.individual_id) AND (e2.capture_date < d.recorded_event_date) AND (e2.outcome = ANY (ARRAY['FOUND_DEAD'::text, 'DIED'::text, 'KILLED'::text, 'EUTHANISED'::text])) AND (e2.episode_record_role <> 'PM_COMPANION'::text))) AS previous_death_record_date
           FROM deaths d
        )
 SELECT capture_id,
    tattoo,
    recorded_event_date,
    mortality_outcome,
    encounter_type,
    is_pm AS source_is_pm,
    original_moc,
    pm_cause,
    linked_pm_capture_id,
    linked_pm_date,
    best_available_easting AS location_easting,
    best_available_northing AS location_northing,
    best_available_location_quality AS location_quality,
    next_live_capture_date,
    previous_death_record_date,
        CASE
            WHEN (next_live_capture_date IS NOT NULL) THEN 'REVIEW_TATTOO_IDENTITY_AFTER_DEATH'::text
            WHEN (previous_death_record_date IS NOT NULL) THEN 'REVIEW_POSSIBLE_DUPLICATE_DEATH'::text
            WHEN (is_pm OR (linked_pm_capture_id IS NOT NULL)) THEN 'DEATH_RECORDED_PM_EVIDENCE'::text
            ELSE 'DEATH_RECORDED_NON_PM_OR_INFERRED'::text
        END AS mortality_review_status
   FROM tested;

create or replace view analysis.wecs_review_flags_v1 with (security_invoker=true) as
SELECT flag_id,
    category,
    capture_ids,
    tattoo,
    summary,
    evidence,
    current_interpretation,
    review_status,
    final_decision,
    final_decision_at,
    updated_at
   FROM research.wecs_review_flags;

commit;

-- VALIDATE after replay. Expect 17586 source rows, 10 paired episodes, 23 classification overrides,
-- 9 alias decisions, 10 review flags and one SOUTH PEGLARS sett with null XY.
select count(*), count(distinct capture_id) from analysis.encounters_clean_v1;
select count(*) from research.encounter_episode_decisions;
select outcome,count(*) from analysis.encounters_clean_v1 group by 1 order by 2 desc;
select flag_id,review_status,final_decision from analysis.wecs_review_flags_v1 order by flag_id;

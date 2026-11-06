--
-- PostgreSQL database dump
--

\restrict PgZwMGaT8cV8faDSMnVhjoAqTHzK8A4ViMH8YYyCDGUW8BKTya44U7DXtFUkAn9

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: access_raw; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA access_raw;


--
-- Name: analysis; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA analysis;


--
-- Name: SCHEMA analysis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA analysis IS 'Woodchester analysis layer: V1 researcher-facing views and core diagnostic analysis; no temporary 767-record location review tables are retained.';


--
-- Name: ingest; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ingest;


--
-- Name: SCHEMA ingest; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA ingest IS 'Private versioned Access refresh audit metadata; registration is not an import and does not modify research.';


--
-- Name: internal_v1; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA internal_v1;


--
-- Name: SCHEMA internal_v1; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA internal_v1 IS 'V1 internal implementation and legacy SQL views. Do not use as coauthor entry points. Public analytical interfaces reside in analysis.';


--
-- Name: research; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA research;


--
-- Name: sync_capture_clean_names_v1(); Type: FUNCTION; Schema: research; Owner: -
--

CREATE FUNCTION research.sync_capture_clean_names_v1() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'research'
    AS $$
begin
  select s.sett_name into new.sett_name_clean from research.setts s where s.sett_id=new.sett_id;
  select sg.social_group_name into new.social_group_name_clean from research.social_groups sg where sg.social_group_id=new.recorded_social_group_id;
  return new;
end $$;


--
-- Name: FUNCTION sync_capture_clean_names_v1(); Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON FUNCTION research.sync_capture_clean_names_v1() IS 'V1 keeps canonical cleaned names aligned with respective foreign keys on inserts or edits; original recorded strings untouched.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: social_groups; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.social_groups (
    raw_row_id bigint NOT NULL,
    social_group text,
    supergroup text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL,
    count text
);


--
-- Name: social_groups_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.social_groups ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.social_groups_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_badger; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_badger (
    raw_row_id bigint NOT NULL,
    tattoo text,
    elect_tag text,
    age_fc text,
    year_fc text,
    sex text,
    time_between_capture text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_badger_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_badger ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_badger_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_blood_sampler; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_blood_sampler (
    raw_row_id bigint NOT NULL,
    tattoo text,
    capture_date text,
    pm text,
    blood_sampler text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_blood_sampler_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_blood_sampler ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_blood_sampler_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_brock_test; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_brock_test (
    raw_row_id bigint NOT NULL,
    capture_date text,
    badger_id text,
    brock_test_od text,
    brock_test_result text,
    no_clotted text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_brock_test_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_brock_test ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_brock_test_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_captures; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_captures (
    raw_row_id bigint NOT NULL,
    tattoo text,
    capture_date text,
    pm text,
    name text,
    moc text,
    socg text,
    sett text,
    capture_year text,
    supergroup text,
    where_text text,
    weight text,
    eartags text,
    retag text,
    toothwear text,
    condition text,
    reproc text,
    testes text,
    collar_action_taken text,
    collar_action_taker text,
    collar_checked_by text,
    collar_scratch_no text,
    transmitter text,
    txno text,
    best_tune text,
    collar_impact_ass text,
    ppm text,
    comment text,
    body_length text,
    temp text,
    blood text,
    pmstat text,
    pm_cause text,
    os_ref text,
    recorder text,
    health_monitoring text,
    disease_status text,
    sampler text,
    time_blood_taken text,
    red_volume text,
    green_volume text,
    purple_volume text,
    yellow_volume text,
    peach_volume text,
    neck_diameter text,
    hair_sample text,
    furclip text,
    whisker_taken text,
    ho_supervisor text,
    severity_ass text,
    sev_initial text,
    release_ass text,
    rel_initial text,
    adverse_effects text,
    adverse_effect_sampler text,
    adverse_effect_comment text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_captures_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_captures ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_captures_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_culture; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_culture (
    raw_row_id bigint NOT NULL,
    tattoo text,
    capture_date text,
    pm text,
    sample text,
    afno text,
    result text,
    lesions text,
    abscesses text,
    spoligo text,
    spolprime text,
    wgs_clade text,
    sampler1 text,
    sampler2 text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_culture_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_culture ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_culture_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_dpp_test; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_dpp_test (
    raw_row_id bigint NOT NULL,
    capture_date text,
    badger_id text,
    test_type text,
    sample_type text,
    visual_line_1 text,
    optical_density_1 text,
    visual_line_2 text,
    optical_density_2 text,
    pm text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_dpp_test_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_dpp_test ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_dpp_test_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_elisa; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_elisa (
    raw_row_id bigint NOT NULL,
    tattoo text,
    capture_date text,
    pm text,
    elisa_type text,
    ref text,
    result text,
    mean_od text,
    blot_cf text,
    blotson text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_elisa_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_elisa ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_elisa_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ifn_gamma_elisa; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_ifn_gamma_elisa (
    raw_row_id bigint NOT NULL,
    plate_no text,
    badger_id text,
    capture_date text,
    import_filename text,
    import_datetime text,
    experiment_date text,
    blood_quality text,
    comments text,
    wellstage_96_pwm_1 text,
    wellstage_96_pwm_2 text,
    wellstage_96_ppda_1 text,
    wellstage_96_ppda_2 text,
    wellstage_96_ppdb_1 text,
    wellstage_96_ppdb_2 text,
    wellstage_96_nil_1 text,
    wellstage_96_nil_2 text,
    pwm_1 text,
    pwm_2 text,
    ppd_a_1 text,
    ppd_a_2 text,
    ppd_b_1 text,
    ppd_b_2 text,
    nil_1 text,
    nil_2 text,
    retest text,
    test_failed text,
    test_info text,
    result text,
    pm text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_ifn_gamma_elisa_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_ifn_gamma_elisa ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_ifn_gamma_elisa_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_sett; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_sett (
    raw_row_id bigint NOT NULL,
    social_group text,
    sett_name text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_sett_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_sett ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_sett_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_stat_pak; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_stat_pak (
    raw_row_id bigint NOT NULL,
    capture_date text,
    badger_id text,
    stat_pak_id text,
    pm text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_stat_pak_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_stat_pak ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_stat_pak_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_wounds; Type: TABLE; Schema: access_raw; Owner: -
--

CREATE TABLE access_raw.tbl_wounds (
    raw_row_id bigint NOT NULL,
    tattoo text,
    capture_date text,
    pm text,
    area text,
    amount text,
    wound_age text,
    size text,
    raw_imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tbl_wounds_raw_row_id_seq; Type: SEQUENCE; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_wounds ALTER COLUMN raw_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME access_raw.tbl_wounds_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: captures; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.captures (
    capture_id bigint NOT NULL,
    individual_id bigint NOT NULL,
    capture_date date NOT NULL,
    is_pm boolean DEFAULT false NOT NULL,
    sett_id bigint,
    recorded_social_group_id bigint,
    recorded_sett_name text,
    recorded_social_group_name text,
    recorded_supergroup_name text,
    moc text,
    capture_location_text text,
    weight numeric,
    body_length numeric,
    temperature numeric,
    toothwear numeric,
    neck_diameter numeric,
    condition text,
    reproductive_status text,
    testes text,
    eartags text,
    retag text,
    transmitter text,
    tx_number text,
    pm_status text,
    pm_cause text,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    location_cleaning_note text,
    disease_status_id integer,
    os_ref text,
    sett_name_clean text,
    social_group_name_clean text,
    sampler text,
    recorder text,
    blood_taken_time time without time zone,
    red_tube_volume numeric,
    green_tube_volume numeric,
    purple_tube_volume numeric,
    peach_tube_volume numeric,
    hair_sample_taken boolean,
    fur_clip_taken boolean,
    whisker_sample_taken boolean,
    sampling_notes text,
    blood_sampler text,
    yellow_tube_volume numeric,
    blood_sample_taken boolean,
    health_monitoring text,
    ho_supervisor text,
    severity_assessment text,
    severity_initials text,
    release_assessment text,
    release_initials text,
    adverse_effects text,
    adverse_effect_sampler text,
    adverse_effect_comment text,
    collar_action_taken text,
    collar_action_taker text,
    collar_checked_by text,
    collar_scratch_no integer,
    collar_transmitter text,
    best_tune text,
    collar_impact_assessment text,
    ppm text,
    condition_clean text GENERATED ALWAYS AS (
CASE
    WHEN (condition IS NULL) THEN NULL::text
    WHEN (upper(btrim(condition)) = ANY (ARRAY['V.GOOD'::text, 'VERY GOOD'::text])) THEN 'VERY GOOD'::text
    WHEN (upper(btrim(condition)) = ANY (ARRAY['GOOD'::text, 'FAIR'::text, 'POOR'::text])) THEN upper(btrim(condition))
    ELSE upper(btrim(condition))
END) STORED,
    eartags_clean text GENERATED ALWAYS AS (
CASE
    WHEN (eartags IS NULL) THEN NULL::text
    WHEN (upper(btrim(eartags)) = ANY (ARRAY['NEITHER'::text, 'NONE'::text, 'NOT TAGGED'::text, 'NOT TAGûGED'::text])) THEN 'NONE'::text
    WHEN (upper(btrim(eartags)) = 'RETAGGEûD'::text) THEN 'RETAGGED'::text
    ELSE upper(btrim(eartags))
END) STORED,
    collar_transmitter_clean text GENERATED ALWAYS AS (
CASE
    WHEN (collar_transmitter = ANY (ARRAY['FIT'::text, 'FITTED'::text])) THEN 'FITTED'::text
    WHEN (collar_transmitter = ANY (ARRAY['PRES'::text, 'PRESENT'::text])) THEN 'PRESENT'::text
    WHEN (collar_transmitter = ANY (ARRAY['REPL'::text, 'REPLACED'::text])) THEN 'REPLACED'::text
    ELSE collar_transmitter
END) STORED
);


--
-- Name: TABLE captures; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.captures IS 'V1 Access-like single capture table: original encounter fields, sampling/assessment/collar fields restored from one-to-one source-linked legacy research tables, plus documented *_clean fields. Historical split tables retained internally for compatibility until dependency audit.';


--
-- Name: COLUMN captures.sett_name_clean; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.captures.sett_name_clean IS 'V1 canonical sett label from sett_id only; NULL means no assigned sett, including PM recovery locations; do not infer from grid.';


--
-- Name: COLUMN captures.social_group_name_clean; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.captures.social_group_name_clean IS 'V1 canonical label linked to recorded_social_group_id, distinct from recorded_social_group_name; not proof of residency.';


--
-- Name: COLUMN captures.condition_clean; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.captures.condition_clean IS 'Normalized condition categories: V.GOOD→VERY GOOD; GOOD, FAIR, POOR unchanged. NULL unchanged. Original condition preserved.';


--
-- Name: COLUMN captures.eartags_clean; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.captures.eartags_clean IS 'Normalized recorded ear-tag descriptions: NEITHER/NONE/NOT TAGGED/NOT TAGûGED→NONE, RETAGGEûD→RETAGGED; original unchanged. Treat REMOVED as separate from NONE.';


--
-- Name: disease_statuses; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.disease_statuses (
    disease_status_id integer NOT NULL,
    disease_status text NOT NULL
);


--
-- Name: individuals; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.individuals (
    individual_id bigint NOT NULL,
    tattoo text NOT NULL,
    elect_tag text,
    age_first_capture text,
    year_first_capture integer,
    sex text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sex_clean text GENERATED ALWAYS AS (
CASE
    WHEN (upper(btrim(COALESCE(sex, ''::text))) = ANY (ARRAY['MALE'::text, 'FEMALE'::text])) THEN upper(btrim(sex))
    ELSE 'UNKNOWN'::text
END) STORED,
    age_first_capture_clean text GENERATED ALWAYS AS (
CASE
    WHEN (upper(btrim(COALESCE(age_first_capture, ''::text))) = ANY (ARRAY['CUB'::text, 'YEARLING'::text, 'ADULT'::text])) THEN upper(btrim(age_first_capture))
    ELSE 'UNKNOWN'::text
END) STORED
);


--
-- Name: COLUMN individuals.sex_clean; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.individuals.sex_clean IS 'V1 computed standardised sex: MALE, FEMALE, UNKNOWN. Original sex preserved; UNKNOWN includes nonstandard/missing.';


--
-- Name: COLUMN individuals.age_first_capture_clean; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.individuals.age_first_capture_clean IS 'V1 computed age at first capture: CUB YEARLING ADULT UNKNOWN. Original retained; UNKNOWN includes missing.';


--
-- Name: setts; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.setts (
    sett_id bigint NOT NULL,
    sett_name text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    easting numeric,
    northing numeric,
    coordinate_system text,
    accuracy_m numeric,
    coordinate_source text,
    coordinate_observed_on date
);


--
-- Name: COLUMN setts.coordinate_source; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.setts.coordinate_source IS 'Original named-sett CSV filename and source sett label; point is fixed, not year-specific.';


--
-- Name: social_groups; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.social_groups (
    social_group_id bigint NOT NULL,
    social_group_name text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: capture_history; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_history AS
 SELECT capture_id,
    tattoo,
    elect_tag,
    historical_names,
    n_historical_names,
    sex,
    age_first_capture,
    year_first_capture,
    capture_date,
    capture_year,
    capture_quarter,
    capture_occasion,
    is_pm,
    moc,
    recorded_sett_name,
    sett_id,
    normalized_sett_name,
    recorded_social_group_name,
    recorded_social_group_id,
    normalized_social_group_name,
    recorded_supergroup_name,
    capture_location_text,
    os_ref,
    location_cleaning_note,
    disease_status_id,
    disease_status,
    weight,
    body_length,
    temperature,
    toothwear,
    neck_diameter,
    condition,
    reproductive_status,
    testes,
    eartags,
    retag,
    transmitter,
    tx_number,
    pm_status,
    pm_cause,
    blood_sample_taken,
    blood_taken_time,
    red_tube_volume,
    green_tube_volume,
    purple_tube_volume,
    yellow_tube_volume,
    peach_tube_volume,
    hair_sample_taken,
    fur_clip_taken,
    whisker_sample_taken,
    sampler,
    blood_sampler,
    recorder,
    sampling_notes,
    health_monitoring,
    ho_supervisor,
    severity_assessment,
    severity_initials,
    release_assessment,
    release_initials,
    adverse_effects,
    adverse_effect_sampler,
    adverse_effect_comment,
    collar_action_taken,
    collar_action_taker,
    collar_checked_by,
    collar_scratch_no,
    collar_transmitter,
    best_tune,
    collar_impact_assessment,
    ppm,
    comment
   FROM ( WITH individual_name_summary AS (
                 SELECT individuals.individual_id,
                    NULL::text AS historical_names,
                    NULL::bigint AS n_historical_names
                   FROM research.individuals
                )
         SELECT c.capture_id,
            i.individual_id,
            i.tattoo,
            i.elect_tag,
            ins.historical_names,
            COALESCE(ins.n_historical_names, (0)::bigint) AS n_historical_names,
            i.sex,
            i.age_first_capture,
            i.year_first_capture,
            c.capture_date,
            (EXTRACT(year FROM c.capture_date))::integer AS capture_year,
            (EXTRACT(quarter FROM c.capture_date))::integer AS capture_quarter,
            concat((EXTRACT(year FROM c.capture_date))::integer, '_Q', (EXTRACT(quarter FROM c.capture_date))::integer) AS capture_occasion,
            c.is_pm,
            c.moc,
            c.recorded_sett_name,
            c.sett_id,
            s.sett_name AS normalized_sett_name,
            c.recorded_social_group_name,
            c.recorded_social_group_id,
            sg.social_group_name AS normalized_social_group_name,
            c.recorded_supergroup_name,
            c.capture_location_text,
            c.os_ref,
            c.location_cleaning_note,
            c.disease_status_id,
            ds.disease_status,
            c.weight,
            c.body_length,
            c.temperature,
            c.toothwear,
            c.neck_diameter,
            c.condition,
            c.reproductive_status,
            c.testes,
            c.eartags,
            c.retag,
            c.transmitter,
            c.tx_number,
            c.pm_status,
            c.pm_cause,
            c.blood_sample_taken,
            c.blood_taken_time,
            c.red_tube_volume,
            c.green_tube_volume,
            c.purple_tube_volume,
            c.yellow_tube_volume,
            c.peach_tube_volume,
            c.hair_sample_taken,
            c.fur_clip_taken,
            c.whisker_sample_taken,
            c.sampler,
            c.blood_sampler,
            c.recorder,
            c.sampling_notes,
            c.health_monitoring,
            c.ho_supervisor,
            c.severity_assessment,
            c.severity_initials,
            c.release_assessment,
            c.release_initials,
            c.adverse_effects,
            c.adverse_effect_sampler,
            c.adverse_effect_comment,
            c.collar_action_taken,
            c.collar_action_taker,
            c.collar_checked_by,
            c.collar_scratch_no,
            c.collar_transmitter,
            c.best_tune,
            c.collar_impact_assessment,
            c.ppm,
            c.comment
           FROM (((((research.captures c
             JOIN research.individuals i ON ((c.individual_id = i.individual_id)))
             LEFT JOIN individual_name_summary ins ON ((i.individual_id = ins.individual_id)))
             LEFT JOIN research.setts s ON ((c.sett_id = s.sett_id)))
             LEFT JOIN research.social_groups sg ON ((c.recorded_social_group_id = sg.social_group_id)))
             LEFT JOIN research.disease_statuses ds ON ((c.disease_status_id = ds.disease_status_id)))) x;


--
-- Name: capture_pm_grid_reference_review; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_pm_grid_reference_review AS
 WITH base AS (
         SELECT c.capture_id,
            c.capture_date,
            c.is_pm,
            c.sett_id,
            c.recorded_sett_name,
            c.capture_location_text,
            c.os_ref,
            upper(regexp_replace(COALESCE(c.os_ref, ''::text), '[[:space:].-]'::text, ''::text, 'g'::text)) AS os_clean,
            upper(regexp_replace(COALESCE(c.recorded_sett_name, ''::text), '[[:space:].-]'::text, ''::text, 'g'::text)) AS recorded_clean
           FROM research.captures c
          WHERE c.is_pm
        ), codes AS (
         SELECT base.capture_id,
            base.capture_date,
            base.is_pm,
            base.sett_id,
            base.recorded_sett_name,
            base.capture_location_text,
            base.os_ref,
            base.os_clean,
            base.recorded_clean,
                CASE
                    WHEN (base.os_clean ~ '^(SO)?[0-9]{6}$'::text) THEN regexp_replace(base.os_clean, '^SO'::text, ''::text)
                    WHEN (base.recorded_clean ~ '^(SO)?[0-9]{6}$'::text) THEN regexp_replace(base.recorded_clean, '^SO'::text, ''::text)
                    ELSE NULL::text
                END AS so_six_digits,
                CASE
                    WHEN (base.os_clean ~ '^(SO)?[0-9]{6}$'::text) THEN 'os_ref'::text
                    WHEN (base.recorded_clean ~ '^(SO)?[0-9]{6}$'::text) THEN 'recorded_sett_name'::text
                    ELSE NULL::text
                END AS grid_reference_source
           FROM base
        )
 SELECT capture_id,
    capture_date,
    is_pm,
    sett_id,
    recorded_sett_name,
    capture_location_text,
    os_ref,
    so_six_digits,
    grid_reference_source,
        CASE
            WHEN (so_six_digits IS NOT NULL) THEN (300000 + (("substring"(so_six_digits, 1, 3))::integer * 100))
            ELSE NULL::integer
        END AS grid_cell_easting,
        CASE
            WHEN (so_six_digits IS NOT NULL) THEN (200000 + (("substring"(so_six_digits, 4, 3))::integer * 100))
            ELSE NULL::integer
        END AS grid_cell_northing,
        CASE
            WHEN (so_six_digits IS NOT NULL) THEN 100
            ELSE NULL::integer
        END AS grid_cell_width_m,
        CASE
            WHEN (so_six_digits IS NOT NULL) THEN 'EPSG:27700'::text
            ELSE NULL::text
        END AS inferred_crs,
        CASE
            WHEN (so_six_digits IS NOT NULL) THEN 'PARSED_SO_6_DIGIT_GRID_CELL_NEEDS_SOURCE_CONFIRMATION'::text
            ELSE 'UNPARSED_OR_ABSENT'::text
        END AS review_status
   FROM codes;


--
-- Name: VIEW capture_pm_grid_reference_review; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_pm_grid_reference_review IS 'PM capture-location grid reference review. Only pure SO+six digit or six-digit fields are interpreted as 100-m SO grid squares. Coordinates mark cell SW corner, NOT a sett point or exact badger location. Original evidence and uncertainty retained. No change to sett_id.';


--
-- Name: capture_location_classified_v2; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_location_classified_v2 AS
 WITH pm AS (
         SELECT c.capture_id,
            c.tattoo,
            c.capture_date,
            c.is_pm,
            c.sett_id,
            c.recorded_sett_name,
            c.os_ref,
            c.capture_location_text,
            g.so_six_digits AS existing_grid,
            upper("substring"(COALESCE(c.recorded_sett_name, ''::text), '(^|[^0-9])([0-9]{3}[[:space:]]?[0-9]{3})([^0-9]|$)'::text)) AS grid_text_raw,
            (regexp_match(COALESCE(c.recorded_sett_name, ''::text), '(^|[^0-9])([0-9]{3}[[:space:]]?[0-9]{3})([^0-9]|$)'::text))[2] AS grid_text,
            g.grid_reference_source AS existing_grid_source
           FROM (internal_v1.capture_history c
             LEFT JOIN internal_v1.capture_pm_grid_reference_review g ON ((g.capture_id = c.capture_id)))
        ), parsed AS (
         SELECT pm.capture_id,
            pm.tattoo,
            pm.capture_date,
            pm.is_pm,
            pm.sett_id,
            pm.recorded_sett_name,
            pm.os_ref,
            pm.capture_location_text,
            pm.existing_grid,
            pm.grid_text_raw,
            pm.grid_text,
            pm.existing_grid_source,
            COALESCE(pm.existing_grid, regexp_replace(pm.grid_text, '[[:space:]]'::text, ''::text, 'g'::text)) AS six_digits,
                CASE
                    WHEN (pm.existing_grid IS NOT NULL) THEN pm.existing_grid_source
                    WHEN (pm.is_pm AND (pm.sett_id IS NULL) AND (pm.grid_text IS NOT NULL)) THEN 'recorded_sett_name_embedded'::text
                    ELSE NULL::text
                END AS reference_source
           FROM pm
        )
 SELECT capture_id,
    tattoo,
    capture_date,
    is_pm,
    sett_id,
    recorded_sett_name AS original_recorded_sett_name,
    os_ref,
    capture_location_text,
        CASE
            WHEN (sett_id IS NOT NULL) THEN 'KNOWN_SETT'::text
            WHEN (is_pm AND (six_digits IS NOT NULL) AND (six_digits ~ '^[0-9]{6}$'::text)) THEN 'GRID_REFERENCED_PM_LOCATION'::text
            WHEN is_pm THEN 'PM_LOCATION_UNRESOLVED'::text
            WHEN (NULLIF(btrim(recorded_sett_name), ''::text) IS NOT NULL) THEN 'UNMATCHED_RECORDED_SETT_NAME'::text
            ELSE 'LOCATION_NOT_RECORDED'::text
        END AS location_class,
        CASE
            WHEN (is_pm AND (sett_id IS NULL) AND (six_digits ~ '^[0-9]{6}$'::text)) THEN 'GRID REFERENCE (NOT A SETT)'::text
            ELSE NULL::text
        END AS location_display_category,
    reference_source,
    six_digits AS so_grid_six_digits,
        CASE
            WHEN (six_digits ~ '^[0-9]{6}$'::text) THEN (300000 + (("substring"(six_digits, 1, 3))::integer * 100))
            ELSE NULL::integer
        END AS grid_sw_easting,
        CASE
            WHEN (six_digits ~ '^[0-9]{6}$'::text) THEN (200000 + (("substring"(six_digits, 4, 3))::integer * 100))
            ELSE NULL::integer
        END AS grid_sw_northing,
        CASE
            WHEN (is_pm AND (sett_id IS NULL) AND (reference_source = 'recorded_sett_name_embedded'::text)) THEN NULLIF(btrim(regexp_replace(recorded_sett_name, '(^|[^0-9])[0-9]{3}[[:space:]]?[0-9]{3}([^0-9]|$)'::text, ' '::text)), ''::text)
            ELSE NULL::text
        END AS accompanying_location_description,
        CASE
            WHEN (is_pm AND (sett_id IS NULL) AND (six_digits ~ '^[0-9]{6}$'::text)) THEN 'PROVISIONAL_SO_100M_GRID_SQUARE'::text
            ELSE NULL::text
        END AS positional_precision_note
   FROM parsed;


--
-- Name: VIEW capture_location_classified_v2; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_location_classified_v2 IS 'Classifies PM grid references embedded in sett-name text with optional descriptive place names as non-sett recovery locations, without changing canonical records. SO 100m grid squares are provisional. Source text kept intact.';


--
-- Name: capture_location_classified_v3; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_location_classified_v3 AS
 WITH src AS (
         SELECT v.capture_id,
            v.tattoo,
            v.capture_date,
            v.is_pm,
            v.sett_id,
            v.original_recorded_sett_name,
            v.os_ref,
            v.capture_location_text,
            v.location_class,
            v.location_display_category,
            v.reference_source,
            v.so_grid_six_digits,
            v.grid_sw_easting,
            v.grid_sw_northing,
            v.accompanying_location_description,
            v.positional_precision_note,
            upper(regexp_replace(COALESCE(v.os_ref, ''::text), '[[:space:],.-]'::text, ''::text, 'g'::text)) AS cleaned_os_ref
           FROM internal_v1.capture_location_classified_v2 v
        ), parsed AS (
         SELECT src.capture_id,
            src.tattoo,
            src.capture_date,
            src.is_pm,
            src.sett_id,
            src.original_recorded_sett_name,
            src.os_ref,
            src.capture_location_text,
            src.location_class,
            src.location_display_category,
            src.reference_source,
            src.so_grid_six_digits,
            src.grid_sw_easting,
            src.grid_sw_northing,
            src.accompanying_location_description,
            src.positional_precision_note,
            src.cleaned_os_ref,
                CASE
                    WHEN (src.cleaned_os_ref ~ '^(SO|ST)([0-9]{6}|[0-9]{8}|[0-9]{10})$'::text) THEN "substring"(src.cleaned_os_ref, 1, 2)
                    ELSE NULL::text
                END AS grid_prefix,
                CASE
                    WHEN (src.cleaned_os_ref ~ '^(SO|ST)([0-9]{6}|[0-9]{8}|[0-9]{10})$'::text) THEN "substring"(src.cleaned_os_ref, 3)
                    ELSE NULL::text
                END AS grid_digits
           FROM src
        ), converted AS (
         SELECT parsed.capture_id,
            parsed.tattoo,
            parsed.capture_date,
            parsed.is_pm,
            parsed.sett_id,
            parsed.original_recorded_sett_name,
            parsed.os_ref,
            parsed.capture_location_text,
            parsed.location_class,
            parsed.location_display_category,
            parsed.reference_source,
            parsed.so_grid_six_digits,
            parsed.grid_sw_easting,
            parsed.grid_sw_northing,
            parsed.accompanying_location_description,
            parsed.positional_precision_note,
            parsed.cleaned_os_ref,
            parsed.grid_prefix,
            parsed.grid_digits,
                CASE
                    WHEN (parsed.grid_digits IS NOT NULL) THEN (power((10)::double precision, ((5 - (length(parsed.grid_digits) / 2)))::double precision))::integer
                    ELSE NULL::integer
                END AS additional_cell_width_m,
                CASE
                    WHEN (parsed.grid_digits IS NOT NULL) THEN (300000 + (("substring"(parsed.grid_digits, 1, (length(parsed.grid_digits) / 2)))::integer * (power((10)::double precision, ((5 - (length(parsed.grid_digits) / 2)))::double precision))::integer))
                    ELSE NULL::integer
                END AS additional_easting,
                CASE
                    WHEN (parsed.grid_digits IS NOT NULL) THEN (
                    CASE parsed.grid_prefix
                        WHEN 'SO'::text THEN 200000
                        WHEN 'ST'::text THEN 100000
                        ELSE NULL::integer
                    END + (("substring"(parsed.grid_digits, ((length(parsed.grid_digits) / 2) + 1)))::integer * (power((10)::double precision, ((5 - (length(parsed.grid_digits) / 2)))::double precision))::integer))
                    ELSE NULL::integer
                END AS additional_northing
           FROM parsed
        )
 SELECT capture_id,
    tattoo,
    capture_date,
    is_pm,
    sett_id,
    original_recorded_sett_name,
    os_ref,
    capture_location_text,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN 'GRID_REFERENCED_PM_LOCATION'::text
            ELSE location_class
        END AS location_class,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN 'GRID REFERENCE (NOT A SETT)'::text
            ELSE location_display_category
        END AS location_display_category,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN 'os_ref_explicit_prefix'::text
            ELSE reference_source
        END AS reference_source,
    so_grid_six_digits,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN additional_easting
            ELSE grid_sw_easting
        END AS grid_sw_easting,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN additional_northing
            ELSE grid_sw_northing
        END AS grid_sw_northing,
    accompanying_location_description,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN (((('PARSED_'::text || grid_prefix) || '_'::text) || additional_cell_width_m) || 'M_GRID_SQUARE'::text)
            ELSE positional_precision_note
        END AS positional_precision_note,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN (grid_prefix || grid_digits)
            ELSE NULL::text
        END AS newly_parsed_grid_reference,
        CASE
            WHEN ((location_class = 'PM_LOCATION_UNRESOLVED'::text) AND (grid_digits IS NOT NULL)) THEN additional_cell_width_m
            ELSE NULL::integer
        END AS newly_parsed_cell_width_m
   FROM converted;


--
-- Name: VIEW capture_location_classified_v3; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_location_classified_v3 IS 'Adds only explicitly prefixed ST/SO OS grid references at 100m, 10m and 1m nominal grid precision to PM recovery classification. No sett identity changes, no unsupported prefixes or typo correction. ST is 300km E / 100km N, SO 300km E / 200km N; coordinates designate SW grid-square corner rather than exact point.';


--
-- Name: capture_location_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.capture_location_v1 WITH (security_invoker='true') AS
 SELECT v.capture_id,
    v.tattoo,
    v.capture_date,
    v.is_pm,
    v.sett_id,
    v.original_recorded_sett_name,
        CASE
            WHEN (v.sett_id IS NOT NULL) THEN s.sett_name
            ELSE NULL::text
        END AS canonical_sett_name,
    v.location_class,
    v.location_display_category,
    v.capture_location_text,
    v.os_ref,
    v.reference_source,
    v.so_grid_six_digits,
    v.newly_parsed_grid_reference,
    v.grid_sw_easting,
    v.grid_sw_northing,
    v.newly_parsed_cell_width_m,
    v.accompanying_location_description,
    v.positional_precision_note,
        CASE
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN 'PROVISIONAL_GRID_CELL_NOT_SETT'::text
            WHEN (v.location_class = 'KNOWN_SETT'::text) THEN 'CANONICAL_SETT'::text
            ELSE 'REVIEW_OR_MISSING'::text
        END AS spatial_interpretation
   FROM (internal_v1.capture_location_classified_v3 v
     LEFT JOIN research.setts s ON ((s.sett_id = v.sett_id)));


--
-- Name: VIEW capture_location_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.capture_location_v1 IS 'Woodchester working V1 stable capture-location interface. Historical field unmodified. Grid references are provisional locations and never sett points.';


--
-- Name: capture_sett_coordinate_inventory; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_sett_coordinate_inventory AS
 SELECT s.sett_name,
    count(c.capture_id) AS n_captures,
    count(c.capture_id) FILTER (WHERE c.is_pm) AS n_pm_records,
    min(c.capture_date) AS first_capture_date,
    max(c.capture_date) AS last_capture_date,
    s.easting,
    s.northing,
    s.coordinate_system,
    s.accuracy_m,
    s.coordinate_source,
        CASE
            WHEN ((s.easting IS NOT NULL) AND (s.northing IS NOT NULL)) THEN 'COORDINATES_APPROVED'::text
            ELSE 'COORDINATES_MISSING'::text
        END AS coordinate_status
   FROM (research.setts s
     LEFT JOIN research.captures c ON ((c.sett_id = s.sett_id)))
  GROUP BY s.sett_id, s.sett_name, s.easting, s.northing, s.coordinate_system, s.accuracy_m, s.coordinate_source;


--
-- Name: VIEW capture_sett_coordinate_inventory; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_sett_coordinate_inventory IS 'Live working V1 inventory of every canonical sett, capture count and approved coordinates; includes setts with no assigned captures.';


--
-- Name: sett_inventory_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.sett_inventory_v1 WITH (security_invoker='true') AS
 SELECT s.sett_id,
    s.sett_name AS canonical_sett_name,
    COALESCE(i.n_captures, (0)::bigint) AS capture_count,
    i.n_pm_records,
    i.first_capture_date,
    i.last_capture_date,
    i.easting,
    i.northing,
    i.coordinate_system,
    i.accuracy_m,
    i.coordinate_source,
    i.coordinate_status
   FROM (research.setts s
     JOIN internal_v1.capture_sett_coordinate_inventory i ON ((i.sett_name = s.sett_name)));


--
-- Name: VIEW sett_inventory_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.sett_inventory_v1 IS 'Woodchester working V1 stable canonical sett inventory with linked coordinate evidence and capture counts.';


--
-- Name: capture_location_fields_v1; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_location_fields_v1 WITH (security_invoker='true') AS
 SELECT v.capture_id,
    v.canonical_sett_name AS sett_name,
        CASE
            WHEN (v.location_class = 'KNOWN_SETT'::text) THEN 'SETT'::text
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN 'PM_GRID_REFERENCE'::text
            WHEN (v.location_class = 'PM_LOCATION_UNRESOLVED'::text) THEN 'PM_LOCATION_UNRESOLVED'::text
            WHEN (v.location_class = 'UNMATCHED_RECORDED_SETT_NAME'::text) THEN 'UNMATCHED_CAPTURE_LOCATION'::text
            ELSE 'NOT_RECORDED'::text
        END AS location_type,
        CASE
            WHEN (v.location_class = 'KNOWN_SETT'::text) THEN i.easting
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN (v.grid_sw_easting)::numeric
            ELSE NULL::numeric
        END AS location_easting,
        CASE
            WHEN (v.location_class = 'KNOWN_SETT'::text) THEN i.northing
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN (v.grid_sw_northing)::numeric
            ELSE NULL::numeric
        END AS location_northing,
        CASE
            WHEN (v.location_class = 'KNOWN_SETT'::text) THEN i.coordinate_system
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN 'EPSG:27700'::text
            ELSE NULL::text
        END AS location_crs,
        CASE
            WHEN (v.location_class = 'KNOWN_SETT'::text) THEN 'SETT_SOURCE_COORDINATE'::text
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN 'PROVISIONAL_GRID_SQUARE_SOUTHWEST_CORNER'::text
            ELSE 'NO_VALIDATED_COORDINATE'::text
        END AS location_coordinate_basis,
    v.location_class
   FROM (analysis.capture_location_v1 v
     LEFT JOIN analysis.sett_inventory_v1 i ON ((i.sett_id = v.sett_id)));


--
-- Name: VIEW capture_location_fields_v1; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_location_fields_v1 IS 'Reusable V1 capture location semantic fields; interpreted grid corner never implies sett.';


--
-- Name: capture_history_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.capture_history_v1 WITH (security_invoker='true') AS
 SELECT h.capture_id,
    h.tattoo,
    h.elect_tag,
    h.historical_names,
    h.n_historical_names,
    h.sex,
    h.age_first_capture,
    h.year_first_capture,
    h.capture_date,
    h.capture_year,
    h.capture_quarter,
    h.capture_occasion,
    h.is_pm,
    h.moc,
    h.recorded_sett_name,
    h.sett_id,
    h.normalized_sett_name,
    h.recorded_social_group_name,
    h.recorded_social_group_id,
    h.normalized_social_group_name,
    h.recorded_supergroup_name,
    h.capture_location_text,
    h.os_ref,
    h.location_cleaning_note,
    h.disease_status_id,
    h.disease_status,
    h.weight,
    h.body_length,
    h.temperature,
    h.toothwear,
    h.neck_diameter,
    h.condition,
    h.reproductive_status,
    h.testes,
    h.eartags,
    h.retag,
    h.transmitter,
    h.tx_number,
    h.pm_status,
    h.pm_cause,
    h.blood_sample_taken,
    h.blood_taken_time,
    h.red_tube_volume,
    h.green_tube_volume,
    h.purple_tube_volume,
    h.yellow_tube_volume,
    h.peach_tube_volume,
    h.hair_sample_taken,
    h.fur_clip_taken,
    h.whisker_sample_taken,
    h.sampler,
    h.blood_sampler,
    h.recorder,
    h.sampling_notes,
    h.health_monitoring,
    h.ho_supervisor,
    h.severity_assessment,
    h.severity_initials,
    h.release_assessment,
    h.release_initials,
    h.adverse_effects,
    h.adverse_effect_sampler,
    h.adverse_effect_comment,
    h.collar_action_taken,
    h.collar_action_taker,
    h.collar_checked_by,
    h.collar_scratch_no,
    h.collar_transmitter,
    h.best_tune,
    h.collar_impact_assessment,
    h.ppm,
    h.comment,
    l.sett_name,
    l.location_type,
    l.location_easting,
    l.location_northing,
    l.location_crs,
    l.location_coordinate_basis,
    l.location_class
   FROM (internal_v1.capture_history h
     LEFT JOIN internal_v1.capture_location_fields_v1 l USING (capture_id));


--
-- Name: VIEW capture_history_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.capture_history_v1 IS 'V1 standard capture-history table with sett_name NULL unless confirmed canonical sett. PM recovery grid locations are separate.';


--
-- Name: infection_probabilities; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.infection_probabilities (
    infection_probability_id bigint NOT NULL,
    individual_id bigint NOT NULL,
    capture_id bigint,
    sample_date date NOT NULL,
    year smallint NOT NULL,
    quarter smallint NOT NULL,
    model_variant text NOT NULL,
    infection_probability double precision NOT NULL,
    model_run text NOT NULL,
    source_file text,
    imported_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT infection_probabilities_infection_probability_check CHECK (((infection_probability >= (0)::double precision) AND (infection_probability <= (1)::double precision))),
    CONSTRAINT infection_probabilities_quarter_check CHECK (((quarter >= 1) AND (quarter <= 4)))
);


--
-- Name: capture_infection_probabilities; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.capture_infection_probabilities AS
 SELECT capture_id,
    tattoo,
    sample_date,
    year,
    quarter,
    model_run,
    diagnostic_fixed_prevalence,
    diagnostic_annual_prevalence,
    diagnostic_adjusted_annual,
    all_tests_fixed,
    all_tests_inferred,
    culture_only_fixed
   FROM ( SELECT ip.capture_id,
            ip.individual_id,
            i.tattoo,
            ip.sample_date,
            ip.year,
            ip.quarter,
            ip.model_run,
            max(ip.infection_probability) FILTER (WHERE (ip.model_variant = 'diagnostic_fixed_prevalence'::text)) AS diagnostic_fixed_prevalence,
            max(ip.infection_probability) FILTER (WHERE (ip.model_variant = 'diagnostic_annual_prevalence'::text)) AS diagnostic_annual_prevalence,
            max(ip.infection_probability) FILTER (WHERE (ip.model_variant = 'diagnostic_adjusted_annual'::text)) AS diagnostic_adjusted_annual,
            max(ip.infection_probability) FILTER (WHERE (ip.model_variant = 'all_tests_fixed'::text)) AS all_tests_fixed,
            max(ip.infection_probability) FILTER (WHERE (ip.model_variant = 'all_tests_inferred'::text)) AS all_tests_inferred,
            max(ip.infection_probability) FILTER (WHERE (ip.model_variant = 'culture_only_fixed'::text)) AS culture_only_fixed
           FROM (research.infection_probabilities ip
             JOIN research.individuals i ON ((ip.individual_id = i.individual_id)))
          GROUP BY ip.capture_id, ip.individual_id, i.tattoo, ip.sample_date, ip.year, ip.quarter, ip.model_run) x;


--
-- Name: encounters_standardised_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounters_standardised_v1 WITH (security_invoker='true') AS
 WITH base AS (
         SELECT c.capture_id,
            l.tattoo,
            c.capture_date,
            c.moc AS original_moc,
            c.is_pm,
            c.recorded_sett_name AS original_location_name,
            c.capture_location_text AS original_location_text,
            c.os_ref AS original_os_ref,
            c.comment AS original_comment,
            c.pm_cause AS original_pm_cause,
            l.location_class AS prior_location_class,
            l.reference_source AS prior_reference_source,
            l.grid_sw_easting,
            l.grid_sw_northing,
            l.newly_parsed_cell_width_m,
            l.spatial_interpretation,
            l.positional_precision_note,
            c.sett_id,
            s.sett_name,
            s.easting AS sett_easting,
            s.northing AS sett_northing
           FROM ((research.captures c
             JOIN analysis.capture_location_v1 l USING (capture_id))
             LEFT JOIN research.setts s ON ((s.sett_id = c.sett_id)))
        ), classified AS (
         SELECT base.capture_id,
            base.tattoo,
            base.capture_date,
            base.original_moc,
            base.is_pm,
            base.original_location_name,
            base.original_location_text,
            base.original_os_ref,
            base.original_comment,
            base.original_pm_cause,
            base.prior_location_class,
            base.prior_reference_source,
            base.grid_sw_easting,
            base.grid_sw_northing,
            base.newly_parsed_cell_width_m,
            base.spatial_interpretation,
            base.positional_precision_note,
            base.sett_id,
            base.sett_name,
            base.sett_easting,
            base.sett_northing,
                CASE
                    WHEN (base.original_moc = 'TRAP'::text) THEN 'LIVE_TRAP'::text
                    WHEN (base.original_moc = 'NET'::text) THEN 'NET'::text
                    WHEN (base.original_moc = 'DART GUN'::text) THEN 'DART'::text
                    WHEN (base.original_moc = 'SNARE'::text) THEN 'SNARE'::text
                    WHEN (base.original_moc = 'RTA'::text) THEN 'ROAD_TRAFFIC'::text
                    WHEN (base.original_moc = 'FOUND DEAD'::text) THEN 'FOUND_DEAD'::text
                    WHEN ((base.original_moc = 'SHOT (GP)'::text) OR (base.original_moc = 'SHOT'::text)) THEN 'SHOT'::text
                    WHEN (base.original_moc = 'REMOVAL'::text) THEN 'REMOVAL'::text
                    WHEN (base.original_moc = 'FOUND EXT'::text) THEN 'FOUND_EXTERNAL'::text
                    WHEN (base.original_moc = 'DEAD SN/TR'::text) THEN 'DEAD_SNARE_TRAP'::text
                    WHEN (base.original_moc = 'PUT DOWN'::text) THEN 'PUT_DOWN'::text
                    WHEN (base.original_moc = 'ON ROAD'::text) THEN 'ON_ROAD'::text
                    WHEN (base.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text) THEN 'PUBLIC_REPORT'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type,
                CASE
                    WHEN (base.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'DART GUN'::text])) THEN 'ALIVE'::text
                    WHEN (base.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text])) THEN 'DEAD'::text
                    ELSE 'UNKNOWN'::text
                END AS alive_when_encountered,
                CASE
                    WHEN ((base.original_moc = 'TRAP'::text) AND (((((COALESCE(base.original_comment, ''::text) || ' '::text) || COALESCE(base.original_pm_cause, ''::text)) || ' '::text) || COALESCE(base.original_location_text, ''::text)) ~* 'euthan|put down|put to sleep'::text)) THEN 'EUTHANISED'::text
                    WHEN ((base.original_moc = 'TRAP'::text) AND (((COALESCE(base.original_comment, ''::text) || ' '::text) || COALESCE(base.original_location_text, ''::text)) ~* 'died in holding|died in cage'::text)) THEN 'DIED_AFTER_CAPTURE'::text
                    WHEN (base.original_moc = 'FOUND DEAD'::text) THEN 'FOUND_DEAD'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_outcome,
                CASE
                    WHEN (base.original_moc = 'TRAP'::text) THEN 'CAPTURE_SITE'::text
                    WHEN (base.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'RTA'::text, 'FOUND EXT'::text, 'ON ROAD'::text, 'DEAD SN/TR'::text])) THEN 'RECOVERY_OR_DISCOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_role,
                CASE
                    WHEN (base.sett_id IS NOT NULL) THEN 'SETT'::text
                    WHEN ((base.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) AND (base.original_moc = 'RTA'::text)) THEN 'ROAD'::text
                    WHEN (base.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN 'RECOVERY_AREA'::text
                    WHEN ((base.original_moc = 'TRAP'::text) AND (COALESCE(base.original_location_text, ''::text) ~* 'FIELD|BOUNDARY|WOOD|BUILDING'::text)) THEN 'REMOTE_OR_NON_SETT'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type,
                CASE
                    WHEN ((base.prior_location_class = 'KNOWN_SETT'::text) AND (base.sett_easting IS NOT NULL) AND (base.sett_northing IS NOT NULL)) THEN base.sett_easting
                    WHEN (base.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN (base.grid_sw_easting)::numeric
                    ELSE NULL::numeric
                END AS location_easting,
                CASE
                    WHEN ((base.prior_location_class = 'KNOWN_SETT'::text) AND (base.sett_easting IS NOT NULL) AND (base.sett_northing IS NOT NULL)) THEN base.sett_northing
                    WHEN (base.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN (base.grid_sw_northing)::numeric
                    ELSE NULL::numeric
                END AS location_northing,
                CASE
                    WHEN ((base.prior_location_class = 'KNOWN_SETT'::text) AND (base.sett_easting IS NOT NULL) AND (base.sett_northing IS NOT NULL)) THEN 'SETT_POINT'::text
                    WHEN ((base.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) AND (base.grid_sw_easting IS NOT NULL)) THEN 'GRID_CELL_SW_CORNER'::text
                    ELSE 'NONE'::text
                END AS coordinate_representation,
                CASE
                    WHEN ((base.prior_location_class = 'KNOWN_SETT'::text) AND (base.sett_easting IS NOT NULL) AND (base.sett_northing IS NOT NULL)) THEN 'SETT_LOOKUP'::text
                    WHEN ((base.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) AND (base.grid_sw_easting IS NOT NULL)) THEN COALESCE(base.prior_reference_source, 'PARSED_GRID'::text)
                    ELSE 'NONE'::text
                END AS location_source,
                CASE
                    WHEN ((base.prior_location_class = 'KNOWN_SETT'::text) AND (base.sett_easting IS NOT NULL) AND (base.sett_northing IS NOT NULL)) THEN 'PROVISIONAL'::text
                    WHEN ((base.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) AND (base.grid_sw_easting IS NOT NULL) AND (base.grid_sw_northing IS NOT NULL)) THEN 'PROVISIONAL'::text
                    ELSE 'UNRESOLVED'::text
                END AS location_status
           FROM base
        )
 SELECT capture_id,
    tattoo,
    capture_date,
    original_moc,
    is_pm,
    original_location_name,
    original_location_text,
    original_os_ref,
    original_comment,
    original_pm_cause,
    prior_location_class,
    prior_reference_source,
    grid_sw_easting,
    grid_sw_northing,
    newly_parsed_cell_width_m,
    spatial_interpretation,
    positional_precision_note,
    sett_id,
    sett_name,
    sett_easting,
    sett_northing,
    encounter_type,
    alive_when_encountered,
    encounter_outcome,
    location_role,
    location_type,
    location_easting,
    location_northing,
    coordinate_representation,
    location_source,
    location_status,
        CASE
            WHEN ((location_easting IS NOT NULL) AND (location_northing IS NOT NULL)) THEN true
            ELSE false
        END AS has_spatial_location,
        CASE
            WHEN (location_status = 'UNRESOLVED'::text) THEN true
            ELSE false
        END AS needs_location_review,
        CASE
            WHEN ((original_moc = 'TRAP'::text) AND (is_pm = true)) THEN true
            ELSE false
        END AS review_trap_pm,
        CASE
            WHEN ((original_moc = 'TRAP'::text) AND (sett_id IS NULL)) THEN true
            ELSE false
        END AS review_unlinked_trap,
        CASE
            WHEN ((original_moc = 'TRAP'::text) AND (sett_id IS NOT NULL) AND ((sett_easting IS NULL) OR (sett_northing IS NULL))) THEN true
            ELSE false
        END AS review_sett_missing_xy,
        CASE
            WHEN (is_pm AND (prior_location_class = 'KNOWN_SETT'::text)) THEN true
            ELSE false
        END AS review_pm_sett_role,
        CASE
            WHEN (is_pm AND (prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text) AND (original_moc = 'TRAP'::text)) THEN true
            ELSE false
        END AS review_trap_pm_grid_role,
    'WECS_V1_PROVISIONAL'::text AS rule_version
   FROM classified;


--
-- Name: VIEW encounters_standardised_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.encounters_standardised_v1 IS 'Non-destructive provisional encounter crosswalk built on existing captures, setts and historical capture_location_v1 interpretations. Coordinates are NOT independently reverified. Grid-cell values are southwest corners, NOT exact points. No social group or residency inference.';


--
-- Name: encounter_episode_decisions; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.encounter_episode_decisions (
    live_capture_id bigint NOT NULL,
    pm_capture_id bigint NOT NULL,
    episode_outcome text NOT NULL,
    decision_status text DEFAULT 'CONFIRMED'::text NOT NULL,
    field_location_basis text DEFAULT 'LIVE_RECORD'::text NOT NULL,
    decision_note text NOT NULL,
    review_flags text[] DEFAULT '{}'::text[] NOT NULL,
    decision_source text DEFAULT 'Researcher-reviewed paired records, 2026-11-03'::text NOT NULL,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT encounter_episode_decisions_decision_status_check CHECK ((decision_status = ANY (ARRAY['CONFIRMED'::text, 'PROVISIONAL'::text]))),
    CONSTRAINT encounter_episode_decisions_episode_outcome_check CHECK ((episode_outcome = ANY (ARRAY['EUTHANISED'::text, 'DIED_AFTER_CAPTURE'::text]))),
    CONSTRAINT separate_records CHECK ((live_capture_id <> pm_capture_id))
);


--
-- Name: TABLE encounter_episode_decisions; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.encounter_episode_decisions IS 'WECS v1: curated links between a field encounter record and its companion PM/death record. Neither source row is overwritten. Each entry retains evidence, review flags and decision provenance.';


--
-- Name: COLUMN encounter_episode_decisions.field_location_basis; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.encounter_episode_decisions.field_location_basis IS 'LIVE_RECORD means reference field-encounter coordinates from the corresponding live record, not necessarily the place of death or PM examination. No missing coordinate is imputed.';


--
-- Name: encounters_with_episodes_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounters_with_episodes_v1 WITH (security_invoker='true') AS
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


--
-- Name: VIEW encounters_with_episodes_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.encounters_with_episodes_v1 IS 'WECS v1: all original capture and PM rows retained, with curated companion-record links and shared field-encounter coordinates. The original per-record location is unchanged.';


--
-- Name: capture_grid_coordinate_decisions; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.capture_grid_coordinate_decisions (
    capture_id bigint NOT NULL,
    original_grid_reference text,
    source_easting numeric,
    source_northing numeric,
    corrected_easting numeric,
    corrected_northing numeric,
    decision_status text NOT NULL,
    decision_note text NOT NULL,
    decision_source text NOT NULL,
    reviewed_at timestamp with time zone DEFAULT now() NOT NULL,
    map_review_status text DEFAULT 'PENDING_REVIEW'::text NOT NULL,
    map_review_note text,
    map_reviewed_at timestamp with time zone,
    CONSTRAINT capture_grid_coordinate_decisions_decision_status_check CHECK ((decision_status = ANY (ARRAY['CORRECTED'::text, 'WITHHELD'::text]))),
    CONSTRAINT wecs_grid_map_review_status_check CHECK ((map_review_status = ANY (ARRAY['PENDING_REVIEW'::text, 'VISUALLY_VERIFIED'::text, 'REJECTED_BY_INVESTIGATOR'::text]))),
    CONSTRAINT wecs_grid_pair CHECK (((corrected_easting IS NULL) = (corrected_northing IS NULL))),
    CONSTRAINT wecs_grid_status CHECK ((((decision_status = 'CORRECTED'::text) AND (corrected_easting IS NOT NULL)) OR ((decision_status = 'WITHHELD'::text) AND (corrected_easting IS NULL))))
);


--
-- Name: TABLE capture_grid_coordinate_decisions; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.capture_grid_coordinate_decisions IS 'Researcher-reviewed coordinate representations. Original source OS refs and preceding parsed coordinates always preserved. WITHHELD removes untrusted XY from clean analysis but never removes mortality evidence. Corrected points still describe grid squares, not exact carcass points.';


--
-- Name: COLUMN capture_grid_coordinate_decisions.map_review_status; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.capture_grid_coordinate_decisions.map_review_status IS 'Visual map acceptance only, not independently surveyed location accuracy. VISUALLY_VERIFIED retains provisional grid precision/uncertain prefix. Rejected sites keep NULL analysis coordinates.';


--
-- Name: COLUMN capture_grid_coordinate_decisions.map_review_note; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON COLUMN research.capture_grid_coordinate_decisions.map_review_note IS 'Investigator visual map sign-off with scope and limitations, separate from provenance and original source.';


--
-- Name: capture_sett_alias_decisions; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.capture_sett_alias_decisions (
    capture_id bigint NOT NULL,
    original_recorded_name text NOT NULL,
    canonical_sett_id bigint NOT NULL,
    decision_note text NOT NULL,
    decision_source text NOT NULL,
    decided_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE capture_sett_alias_decisions; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.capture_sett_alias_decisions IS 'Capture-specific validated name aliases; preserves original recorded_sett_name/sett_id in research.captures. Name association does not establish exact physical capture point.';


--
-- Name: encounter_classification_decisions; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.encounter_classification_decisions (
    capture_id bigint NOT NULL,
    encounter_type text,
    outcome text,
    decision_note text NOT NULL,
    decision_source text NOT NULL,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT has_override CHECK (((encounter_type IS NOT NULL) OR (outcome IS NOT NULL)))
);


--
-- Name: TABLE encounter_classification_decisions; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.encounter_classification_decisions IS 'WECS audit: explicit curator-approved overrides to final six-field encounter_type and outcome only; originals never changed. Decision evidence retained. 1979 removals KILLED inferred from contemporary PM records. For some sparse PM records mortality is researcher-inferred.';


--
-- Name: encounters_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounters_v1 WITH (security_invoker='true') AS
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
                    WHEN ((source.episode_record_role = 'PM_COMPANION'::text) AND (source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) AND (source.prior_easting IS NOT NULL)) THEN 'RECOVERY_SITE'::text
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
                    WHEN ((source.episode_record_role = 'PM_COMPANION'::text) AND (source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) AND (source.prior_easting IS NOT NULL)) THEN source.prior_easting
                    WHEN (source.episode_record_role = 'PM_COMPANION'::text) THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN ((source.episode_record_role = 'PM_COMPANION'::text) AND (source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) AND (source.prior_northing IS NOT NULL)) THEN source.prior_northing
                    WHEN (source.episode_record_role = 'PM_COMPANION'::text) THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN ((source.episode_record_role = 'PM_COMPANION'::text) AND (source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) AND (source.prior_easting IS NOT NULL) AND (source.newly_parsed_cell_width_m IS NOT NULL)) THEN 'GRID_CELL'::text
                    WHEN ((source.episode_record_role = 'PM_COMPANION'::text) AND (source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text) AND (source.prior_easting IS NOT NULL)) THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
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
            WHEN (grid.capture_id IS NOT NULL) THEN grid.corrected_easting
            WHEN ((alias.capture_id IS NOT NULL) AND (upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text)) THEN mapped_sett.easting
            WHEN (alias.capture_id IS NOT NULL) THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN (grid.capture_id IS NOT NULL) THEN grid.corrected_northing
            WHEN ((alias.capture_id IS NOT NULL) AND (upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text)) THEN mapped_sett.northing
            WHEN (alias.capture_id IS NOT NULL) THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN (grid.decision_status = 'WITHHELD'::text) THEN 'GRID_REFERENCE_AMBIGUOUS_WITHHELD'::text
            WHEN ((grid.decision_status = 'CORRECTED'::text) AND (grid.decision_source ~~ 'WECS_LOCALITY_CENTROID%'::text)) THEN 'LOCALITY_CENTROID_APPROXIMATE'::text
            WHEN (grid.decision_status = 'CORRECTED'::text) THEN 'GRID_REFERENCE_CORRECTED_PROVISIONAL'::text
            WHEN ((standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text) AND (regexp_replace(upper(COALESCE(standardised.original_os_ref, ''::text)), '[[:space:],.-]'::text, ''::text, 'g'::text) ~ '^SO[0-9]{6}$'::text)) THEN 'GRID_CELL_100M_RECORDED_SO'::text
            WHEN (standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text) THEN 'GRID_CELL_100M_PREFIX_UNVERIFIED'::text
            WHEN ((alias.capture_id IS NOT NULL) AND (upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text) AND (mapped_sett.easting IS NOT NULL) AND (mapped_sett.northing IS NOT NULL)) THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN (alias.capture_id IS NOT NULL) THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM ((((standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id))
     LEFT JOIN research.capture_sett_alias_decisions alias ON ((alias.capture_id = standardised.capture_id)))
     LEFT JOIN research.setts mapped_sett ON ((mapped_sett.sett_id = alias.canonical_sett_id)))
     LEFT JOIN research.capture_grid_coordinate_decisions grid ON ((grid.capture_id = standardised.capture_id)));


--
-- Name: VIEW encounters_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.encounters_v1 IS 'WECS six-field encounter output: primary source death handling and PM companions preserved; PM companion own OS grid square retained with correct 100m square precision, but no synthetic inherited sett point when PM has no independent OS evidence. All grid correction decisions overlay original parsed points, mortality stays independent of XY.';


--
-- Name: capture_sett_alias_audit_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.capture_sett_alias_audit_v1 WITH (security_invoker='false') AS
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


--
-- Name: capture_sett_location_standardised_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.capture_sett_location_standardised_v1 WITH (security_invoker='true') AS
 SELECT c.capture_id,
    v.tattoo,
    c.capture_date,
    c.is_pm,
    c.sett_id,
    c.recorded_sett_name,
        CASE
            WHEN (c.sett_id IS NOT NULL) THEN upper(regexp_replace(s.sett_name, '[^A-Za-z0-9]'::text, ''::text, 'g'::text))
            ELSE 'OTHER'::text
        END AS sett_clean,
        CASE
            WHEN (c.sett_id IS NULL) THEN COALESCE(NULLIF(btrim(c.recorded_sett_name), ''::text), NULLIF(btrim(c.capture_location_text), ''::text), NULLIF(btrim(c.os_ref), ''::text))
            ELSE NULL::text
        END AS other_location_info,
    c.capture_location_text,
    c.os_ref,
    v.location_class,
        CASE
            WHEN ((c.sett_id IS NOT NULL) AND (s.easting IS NOT NULL) AND (s.northing IS NOT NULL)) THEN s.easting
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN (v.grid_sw_easting)::numeric
            ELSE NULL::numeric
        END AS location_easting,
        CASE
            WHEN ((c.sett_id IS NOT NULL) AND (s.easting IS NOT NULL) AND (s.northing IS NOT NULL)) THEN s.northing
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN (v.grid_sw_northing)::numeric
            ELSE NULL::numeric
        END AS location_northing,
        CASE
            WHEN ((c.sett_id IS NOT NULL) AND (s.easting IS NOT NULL) AND (s.northing IS NOT NULL)) THEN 'SETT_POINT'::text
            WHEN ((v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) AND (v.grid_sw_easting IS NOT NULL) AND (v.grid_sw_northing IS NOT NULL)) THEN 'GRID_SQUARE_SOUTHWEST_CORNER'::text
            ELSE 'NO_COORDINATE'::text
        END AS coordinate_basis,
        CASE
            WHEN (((c.sett_id IS NOT NULL) AND (s.easting IS NOT NULL) AND (s.northing IS NOT NULL)) OR ((v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) AND (v.grid_sw_easting IS NOT NULL) AND (v.grid_sw_northing IS NOT NULL))) THEN 'EPSG:27700'::text
            ELSE NULL::text
        END AS location_crs,
        CASE
            WHEN (v.location_class = 'GRID_REFERENCED_PM_LOCATION'::text) THEN v.newly_parsed_cell_width_m
            ELSE NULL::integer
        END AS grid_cell_width_m
   FROM ((research.captures c
     LEFT JOIN research.setts s ON ((s.sett_id = c.sett_id)))
     LEFT JOIN analysis.capture_location_v1 v ON ((v.capture_id = c.capture_id)));


--
-- Name: brock_tests; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.brock_tests (
    brock_test_id bigint NOT NULL,
    capture_id bigint NOT NULL,
    brock_test_od numeric,
    test_result text,
    no_clotted boolean,
    comments text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cultures; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.cultures (
    culture_id bigint NOT NULL,
    capture_id bigint NOT NULL,
    sample_type text,
    afno text,
    culture_result text,
    lesions text,
    abscesses text,
    spoligo text,
    spolprime text,
    wgs_clade text,
    sampler_1 text,
    sampler_2 text,
    comments text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: dpp_tests; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.dpp_tests (
    dpp_test_id bigint NOT NULL,
    capture_id bigint NOT NULL,
    test_result text,
    comments text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    test_type text,
    sample_type text,
    visual_line_1 text,
    optical_density_1 numeric,
    visual_line_2 text,
    optical_density_2 numeric,
    source_raw_row_id bigint,
    visual_line_1_result text,
    visual_line_2_result text
);


--
-- Name: elisa_tests; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.elisa_tests (
    elisa_test_id bigint NOT NULL,
    capture_id bigint NOT NULL,
    elisa_type text,
    reference numeric,
    test_result text,
    mean_od numeric,
    blot_cf text,
    blotson text,
    comments text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    test_result_clean text GENERATED ALWAYS AS (
CASE
    WHEN (test_result = ANY (ARRAY['NO SERA'::text, 'NO SERUM'::text])) THEN 'NO SERUM'::text
    ELSE test_result
END) STORED
);


--
-- Name: ifn_gamma_elisa; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.ifn_gamma_elisa (
    ifn_test_id bigint NOT NULL,
    capture_id bigint NOT NULL,
    plate_number text,
    experiment_date timestamp without time zone,
    import_filename text,
    imported_at timestamp without time zone,
    blood_quality text,
    nil_value numeric,
    avian_ppd_value numeric,
    bovine_ppd_value numeric,
    pwm_value numeric,
    bovine_minus_nil numeric,
    avian_minus_nil numeric,
    bovine_minus_avian numeric,
    test_info text,
    test_result text,
    comments text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    pwm_1 numeric,
    pwm_2 numeric,
    ppd_a_1 numeric,
    ppd_a_2 numeric,
    ppd_b_1 numeric,
    ppd_b_2 numeric,
    nil_1 numeric,
    nil_2 numeric,
    retest text,
    test_failed text,
    capture_datetime timestamp without time zone,
    wellstage_96_pwm_1 text,
    wellstage_96_pwm_2 text,
    wellstage_96_ppda_1 text,
    wellstage_96_ppda_2 text,
    wellstage_96_ppdb_1 text,
    wellstage_96_ppdb_2 text,
    wellstage_96_nil_1 text,
    wellstage_96_nil_2 text,
    qc_note text
);


--
-- Name: stat_pak_tests; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.stat_pak_tests (
    stat_pak_test_id bigint NOT NULL,
    capture_id bigint NOT NULL,
    test_result text,
    comments text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    stat_pak_id text
);


--
-- Name: diagnostic_results; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.diagnostic_results AS
 SELECT source_table,
    source_record_id,
    capture_id,
    tattoo,
    capture_date,
    is_pm,
    test_family,
    test_type,
    sample_type,
    result,
    result_code,
    visual_line_1,
    visual_line_1_result,
    optical_density_1,
    visual_line_2,
    visual_line_2_result,
    optical_density_2,
    reference_value,
    mean_od,
    blot_cf,
    blotson,
    brock_test_od,
    no_clotted,
    afno,
    lesions,
    abscesses,
    spoligo,
    spolprime,
    wgs_clade,
    plate_number,
    experiment_date,
    nil_value,
    avian_ppd_value,
    bovine_ppd_value,
    pwm_value,
    bovine_minus_nil,
    avian_minus_nil,
    bovine_minus_avian,
    pwm_1,
    pwm_2,
    ppd_a_1,
    ppd_a_2,
    ppd_b_1,
    ppd_b_2,
    nil_1,
    nil_2,
    retest,
    test_failed,
    test_info,
    blood_quality,
    qc_note,
    comments
   FROM ( WITH capture_base AS (
                 SELECT c.capture_id,
                    c.individual_id,
                    i.tattoo,
                    c.capture_date,
                    c.is_pm
                   FROM (research.captures c
                     JOIN research.individuals i ON ((c.individual_id = i.individual_id)))
                )
         SELECT 'culture'::text AS source_table,
            cu.culture_id AS source_record_id,
            cb.capture_id,
            cb.individual_id,
            cb.tattoo,
            cb.capture_date,
            cb.is_pm,
            'Culture'::text AS test_family,
            'Culture'::text AS test_type,
            cu.sample_type,
            cu.culture_result AS result,
            NULL::text AS result_code,
            NULL::text AS visual_line_1,
            NULL::text AS visual_line_1_result,
            NULL::numeric AS optical_density_1,
            NULL::text AS visual_line_2,
            NULL::text AS visual_line_2_result,
            NULL::numeric AS optical_density_2,
            NULL::numeric AS reference_value,
            NULL::numeric AS mean_od,
            NULL::text AS blot_cf,
            NULL::text AS blotson,
            NULL::numeric AS brock_test_od,
            NULL::boolean AS no_clotted,
            cu.afno,
            cu.lesions,
            cu.abscesses,
            cu.spoligo,
            cu.spolprime,
            cu.wgs_clade,
            NULL::text AS plate_number,
            NULL::timestamp without time zone AS experiment_date,
            NULL::numeric AS nil_value,
            NULL::numeric AS avian_ppd_value,
            NULL::numeric AS bovine_ppd_value,
            NULL::numeric AS pwm_value,
            NULL::numeric AS bovine_minus_nil,
            NULL::numeric AS avian_minus_nil,
            NULL::numeric AS bovine_minus_avian,
            NULL::numeric AS pwm_1,
            NULL::numeric AS pwm_2,
            NULL::numeric AS ppd_a_1,
            NULL::numeric AS ppd_a_2,
            NULL::numeric AS ppd_b_1,
            NULL::numeric AS ppd_b_2,
            NULL::numeric AS nil_1,
            NULL::numeric AS nil_2,
            NULL::text AS retest,
            NULL::text AS test_failed,
            NULL::text AS test_info,
            NULL::text AS blood_quality,
            NULL::text AS qc_note,
            cu.comments
           FROM (research.cultures cu
             JOIN capture_base cb ON ((cu.capture_id = cb.capture_id)))
        UNION ALL
         SELECT 'dpp_tests'::text AS source_table,
            d.dpp_test_id AS source_record_id,
            cb.capture_id,
            cb.individual_id,
            cb.tattoo,
            cb.capture_date,
            cb.is_pm,
            'DPP'::text AS test_family,
            d.test_type,
            d.sample_type,
            d.test_result AS result,
            NULL::text AS result_code,
            d.visual_line_1,
            d.visual_line_1_result,
            d.optical_density_1,
            d.visual_line_2,
            d.visual_line_2_result,
            d.optical_density_2,
            NULL::numeric AS reference_value,
            NULL::numeric AS mean_od,
            NULL::text AS blot_cf,
            NULL::text AS blotson,
            NULL::numeric AS brock_test_od,
            NULL::boolean AS no_clotted,
            NULL::text AS afno,
            NULL::text AS lesions,
            NULL::text AS abscesses,
            NULL::text AS spoligo,
            NULL::text AS spolprime,
            NULL::text AS wgs_clade,
            NULL::text AS plate_number,
            NULL::timestamp without time zone AS experiment_date,
            NULL::numeric AS nil_value,
            NULL::numeric AS avian_ppd_value,
            NULL::numeric AS bovine_ppd_value,
            NULL::numeric AS pwm_value,
            NULL::numeric AS bovine_minus_nil,
            NULL::numeric AS avian_minus_nil,
            NULL::numeric AS bovine_minus_avian,
            NULL::numeric AS pwm_1,
            NULL::numeric AS pwm_2,
            NULL::numeric AS ppd_a_1,
            NULL::numeric AS ppd_a_2,
            NULL::numeric AS ppd_b_1,
            NULL::numeric AS ppd_b_2,
            NULL::numeric AS nil_1,
            NULL::numeric AS nil_2,
            NULL::text AS retest,
            NULL::text AS test_failed,
            NULL::text AS test_info,
            NULL::text AS blood_quality,
            NULL::text AS qc_note,
            d.comments
           FROM (research.dpp_tests d
             JOIN capture_base cb ON ((d.capture_id = cb.capture_id)))
        UNION ALL
         SELECT 'stat_pak_tests'::text AS source_table,
            sp.stat_pak_test_id AS source_record_id,
            cb.capture_id,
            cb.individual_id,
            cb.tattoo,
            cb.capture_date,
            cb.is_pm,
            'Stat-Pak'::text AS test_family,
            'Stat-Pak'::text AS test_type,
            NULL::text AS sample_type,
            sp.test_result AS result,
            sp.stat_pak_id AS result_code,
            NULL::text AS visual_line_1,
            NULL::text AS visual_line_1_result,
            NULL::numeric AS optical_density_1,
            NULL::text AS visual_line_2,
            NULL::text AS visual_line_2_result,
            NULL::numeric AS optical_density_2,
            NULL::numeric AS reference_value,
            NULL::numeric AS mean_od,
            NULL::text AS blot_cf,
            NULL::text AS blotson,
            NULL::numeric AS brock_test_od,
            NULL::boolean AS no_clotted,
            NULL::text AS afno,
            NULL::text AS lesions,
            NULL::text AS abscesses,
            NULL::text AS spoligo,
            NULL::text AS spolprime,
            NULL::text AS wgs_clade,
            NULL::text AS plate_number,
            NULL::timestamp without time zone AS experiment_date,
            NULL::numeric AS nil_value,
            NULL::numeric AS avian_ppd_value,
            NULL::numeric AS bovine_ppd_value,
            NULL::numeric AS pwm_value,
            NULL::numeric AS bovine_minus_nil,
            NULL::numeric AS avian_minus_nil,
            NULL::numeric AS bovine_minus_avian,
            NULL::numeric AS pwm_1,
            NULL::numeric AS pwm_2,
            NULL::numeric AS ppd_a_1,
            NULL::numeric AS ppd_a_2,
            NULL::numeric AS ppd_b_1,
            NULL::numeric AS ppd_b_2,
            NULL::numeric AS nil_1,
            NULL::numeric AS nil_2,
            NULL::text AS retest,
            NULL::text AS test_failed,
            NULL::text AS test_info,
            NULL::text AS blood_quality,
            NULL::text AS qc_note,
            sp.comments
           FROM (research.stat_pak_tests sp
             JOIN capture_base cb ON ((sp.capture_id = cb.capture_id)))
        UNION ALL
         SELECT 'elisa_tests'::text AS source_table,
            e.elisa_test_id AS source_record_id,
            cb.capture_id,
            cb.individual_id,
            cb.tattoo,
            cb.capture_date,
            cb.is_pm,
            'ELISA'::text AS test_family,
            e.elisa_type AS test_type,
            NULL::text AS sample_type,
            e.test_result AS result,
            NULL::text AS result_code,
            NULL::text AS visual_line_1,
            NULL::text AS visual_line_1_result,
            NULL::numeric AS optical_density_1,
            NULL::text AS visual_line_2,
            NULL::text AS visual_line_2_result,
            NULL::numeric AS optical_density_2,
            e.reference AS reference_value,
            e.mean_od,
            e.blot_cf,
            e.blotson,
            NULL::numeric AS brock_test_od,
            NULL::boolean AS no_clotted,
            NULL::text AS afno,
            NULL::text AS lesions,
            NULL::text AS abscesses,
            NULL::text AS spoligo,
            NULL::text AS spolprime,
            NULL::text AS wgs_clade,
            NULL::text AS plate_number,
            NULL::timestamp without time zone AS experiment_date,
            NULL::numeric AS nil_value,
            NULL::numeric AS avian_ppd_value,
            NULL::numeric AS bovine_ppd_value,
            NULL::numeric AS pwm_value,
            NULL::numeric AS bovine_minus_nil,
            NULL::numeric AS avian_minus_nil,
            NULL::numeric AS bovine_minus_avian,
            NULL::numeric AS pwm_1,
            NULL::numeric AS pwm_2,
            NULL::numeric AS ppd_a_1,
            NULL::numeric AS ppd_a_2,
            NULL::numeric AS ppd_b_1,
            NULL::numeric AS ppd_b_2,
            NULL::numeric AS nil_1,
            NULL::numeric AS nil_2,
            NULL::text AS retest,
            NULL::text AS test_failed,
            NULL::text AS test_info,
            NULL::text AS blood_quality,
            NULL::text AS qc_note,
            e.comments
           FROM (research.elisa_tests e
             JOIN capture_base cb ON ((e.capture_id = cb.capture_id)))
        UNION ALL
         SELECT 'brock_tests'::text AS source_table,
            b.brock_test_id AS source_record_id,
            cb.capture_id,
            cb.individual_id,
            cb.tattoo,
            cb.capture_date,
            cb.is_pm,
            'Brock'::text AS test_family,
            'Brock'::text AS test_type,
            NULL::text AS sample_type,
            b.test_result AS result,
            NULL::text AS result_code,
            NULL::text AS visual_line_1,
            NULL::text AS visual_line_1_result,
            NULL::numeric AS optical_density_1,
            NULL::text AS visual_line_2,
            NULL::text AS visual_line_2_result,
            NULL::numeric AS optical_density_2,
            NULL::numeric AS reference_value,
            NULL::numeric AS mean_od,
            NULL::text AS blot_cf,
            NULL::text AS blotson,
            b.brock_test_od,
            b.no_clotted,
            NULL::text AS afno,
            NULL::text AS lesions,
            NULL::text AS abscesses,
            NULL::text AS spoligo,
            NULL::text AS spolprime,
            NULL::text AS wgs_clade,
            NULL::text AS plate_number,
            NULL::timestamp without time zone AS experiment_date,
            NULL::numeric AS nil_value,
            NULL::numeric AS avian_ppd_value,
            NULL::numeric AS bovine_ppd_value,
            NULL::numeric AS pwm_value,
            NULL::numeric AS bovine_minus_nil,
            NULL::numeric AS avian_minus_nil,
            NULL::numeric AS bovine_minus_avian,
            NULL::numeric AS pwm_1,
            NULL::numeric AS pwm_2,
            NULL::numeric AS ppd_a_1,
            NULL::numeric AS ppd_a_2,
            NULL::numeric AS ppd_b_1,
            NULL::numeric AS ppd_b_2,
            NULL::numeric AS nil_1,
            NULL::numeric AS nil_2,
            NULL::text AS retest,
            NULL::text AS test_failed,
            NULL::text AS test_info,
            NULL::text AS blood_quality,
            NULL::text AS qc_note,
            b.comments
           FROM (research.brock_tests b
             JOIN capture_base cb ON ((b.capture_id = cb.capture_id)))
        UNION ALL
         SELECT 'ifn_gamma_elisa'::text AS source_table,
            ig.ifn_test_id AS source_record_id,
            cb.capture_id,
            cb.individual_id,
            cb.tattoo,
            cb.capture_date,
            cb.is_pm,
            'IFN-gamma ELISA'::text AS test_family,
            'IFN-gamma ELISA'::text AS test_type,
            NULL::text AS sample_type,
            ig.test_result AS result,
            NULL::text AS result_code,
            NULL::text AS visual_line_1,
            NULL::text AS visual_line_1_result,
            NULL::numeric AS optical_density_1,
            NULL::text AS visual_line_2,
            NULL::text AS visual_line_2_result,
            NULL::numeric AS optical_density_2,
            NULL::numeric AS reference_value,
            NULL::numeric AS mean_od,
            NULL::text AS blot_cf,
            NULL::text AS blotson,
            NULL::numeric AS brock_test_od,
            NULL::boolean AS no_clotted,
            NULL::text AS afno,
            NULL::text AS lesions,
            NULL::text AS abscesses,
            NULL::text AS spoligo,
            NULL::text AS spolprime,
            NULL::text AS wgs_clade,
            ig.plate_number,
            ig.experiment_date,
            ig.nil_value,
            ig.avian_ppd_value,
            ig.bovine_ppd_value,
            ig.pwm_value,
            ig.bovine_minus_nil,
            ig.avian_minus_nil,
            ig.bovine_minus_avian,
            ig.pwm_1,
            ig.pwm_2,
            ig.ppd_a_1,
            ig.ppd_a_2,
            ig.ppd_b_1,
            ig.ppd_b_2,
            ig.nil_1,
            ig.nil_2,
            ig.retest,
            ig.test_failed,
            ig.test_info,
            ig.blood_quality,
            ig.qc_note,
            ig.comments
           FROM (research.ifn_gamma_elisa ig
             JOIN capture_base cb ON ((ig.capture_id = cb.capture_id)))) x;


--
-- Name: encounter_episode_decisions_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounter_episode_decisions_v1 WITH (security_invoker='true') AS
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


--
-- Name: encounter_pair_nonlinks; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.encounter_pair_nonlinks (
    first_capture_id bigint NOT NULL,
    second_capture_id bigint NOT NULL,
    decision text DEFAULT 'SEPARATE_EVENTS'::text NOT NULL,
    decision_note text NOT NULL,
    decision_source text NOT NULL,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT different_event_ids CHECK ((first_capture_id <> second_capture_id)),
    CONSTRAINT encounter_pair_nonlinks_decision_check CHECK ((decision = 'SEPARATE_EVENTS'::text))
);


--
-- Name: TABLE encounter_pair_nonlinks; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.encounter_pair_nonlinks IS 'Documented negative pairing decisions; prevents independent live captures and later PM/dead recoveries from being accidentally merged during episode inference. Retain original source rows.';


--
-- Name: encounter_pair_nonlinks_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounter_pair_nonlinks_v1 WITH (security_invoker='true') AS
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


--
-- Name: encounter_review_queue_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounter_review_queue_v1 WITH (security_invoker='true') AS
 SELECT capture_id,
    tattoo,
    capture_date,
    original_moc,
    is_pm,
    encounter_type,
    encounter_outcome,
    original_location_name,
    original_location_text,
    original_os_ref,
    original_comment,
    original_pm_cause,
    sett_id,
    sett_name,
    prior_location_class,
    spatial_interpretation,
    location_easting,
    location_northing,
    coordinate_representation,
    location_status,
    review_unlinked_trap,
    review_trap_pm,
    review_sett_missing_xy,
    review_pm_sett_role,
    review_trap_pm_grid_role,
        CASE
            WHEN review_unlinked_trap THEN '01_UNLINKED_TRAP'::text
            WHEN review_trap_pm THEN '02_TRAP_PM'::text
            WHEN review_sett_missing_xy THEN '03_SETT_MISSING_XY'::text
            WHEN review_trap_pm_grid_role THEN '04_TRAP_PM_GRID_ROLE'::text
            WHEN needs_location_review THEN '05_UNRESOLVED_LOCATION'::text
            WHEN review_pm_sett_role THEN '06_PM_SETT_ROLE'::text
            ELSE 'OTHER'::text
        END AS review_priority
   FROM analysis.encounters_standardised_v1
  WHERE (review_unlinked_trap OR review_trap_pm OR review_sett_missing_xy OR review_trap_pm_grid_role OR needs_location_review OR review_pm_sett_role);


--
-- Name: VIEW encounter_review_queue_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.encounter_review_queue_v1 IS 'Prioritised read-only audit queue. Not every record needs human review: batch-review recurring settled names and historical aliases first. Views do not change research captures.';


--
-- Name: encounters_clean_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounters_clean_v1 WITH (security_invoker='false') AS
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


--
-- Name: VIEW encounters_clean_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.encounters_clean_v1 IS 'Concise six-field Woodchester research encounter output, retaining identifiers and episode link so same-event PM companion rows are not independently counted. See underlying decisions and original research.captures.';


--
-- Name: encounters_review_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.encounters_review_v1 WITH (security_invoker='true') AS
 SELECT f.capture_id,
    f.tattoo,
    f.capture_date,
    f.is_pm,
    f.encounter_type,
    f.outcome,
    f.location_type,
    f.location_easting,
    f.location_northing,
    f.location_quality,
    f.episode_primary_capture_id,
    c.moc AS original_moc,
    c.recorded_sett_name,
    c.capture_location_text,
    c.os_ref,
    c.comment,
    c.pm_cause,
        CASE
            WHEN (f.location_quality = 'SETT_COORDINATE_CONFLICT'::text) THEN 'SETT_VS_FIELD_LOCATION'::text
            WHEN (f.location_quality = 'UNRESOLVED'::text) THEN 'NO_COORDINATES'::text
            WHEN (f.location_quality = 'GRID_CELL_PRECISION_UNCONFIRMED'::text) THEN 'GRID_PRECISION_CHECK'::text
            WHEN (f.encounter_type = 'UNKNOWN'::text) THEN 'ENCOUNTER_TYPE_UNKNOWN'::text
            WHEN ((f.outcome = 'UNKNOWN'::text) AND (f.encounter_type = ANY (ARRAY['REMOVAL'::text, 'FOUND_IN_EXTREMIS'::text, 'PUT_DOWN'::text]))) THEN 'OUTCOME_UNKNOWN'::text
            ELSE 'OTHER'::text
        END AS review_reason
   FROM (analysis.encounters_v1 f
     JOIN research.captures c USING (capture_id))
  WHERE ((f.location_quality = ANY (ARRAY['SETT_COORDINATE_CONFLICT'::text, 'UNRESOLVED'::text, 'GRID_CELL_PRECISION_UNCONFIRMED'::text])) OR (f.encounter_type = 'UNKNOWN'::text) OR ((f.outcome = 'UNKNOWN'::text) AND (f.encounter_type = ANY (ARRAY['REMOVAL'::text, 'FOUND_IN_EXTREMIS'::text, 'PUT_DOWN'::text]))));


--
-- Name: VIEW encounters_review_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.encounters_review_v1 IS 'Investigation queue derived from simplified WECS v1. All original sources remain available; no unresolved case is silently imputed.';


--
-- Name: grid_reference_audit_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.grid_reference_audit_v1 WITH (security_invoker='false') AS
 SELECT e.capture_id,
    e.tattoo,
    e.capture_date,
    e.is_pm,
    c.os_ref,
    c.recorded_sett_name,
    c.capture_location_text,
    g.original_grid_reference,
    g.source_easting,
    g.source_northing,
    g.corrected_easting,
    g.corrected_northing,
    g.decision_status,
    g.decision_note,
    g.decision_source,
    g.reviewed_at,
    e.location_easting AS analysis_easting,
    e.location_northing AS analysis_northing,
    e.location_quality
   FROM ((analysis.encounters_clean_v1 e
     JOIN research.captures c USING (capture_id))
     JOIN research.capture_grid_coordinate_decisions g USING (capture_id));


--
-- Name: VIEW grid_reference_audit_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.grid_reference_audit_v1 IS 'Read-only compact grid correction and withheld-coordinate audit; no original data overwritten. These corrections are BNG grid-square proxies with source uncertainty.';


--
-- Name: grid_withheld_candidate_review_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.grid_withheld_candidate_review_v1 WITH (security_invoker='false') AS
 SELECT g.capture_id,
    e.tattoo,
    e.capture_date,
    e.is_pm,
    e.encounter_type,
    e.outcome,
    g.original_grid_reference,
    c.capture_location_text AS original_place_description,
    g.source_easting,
    g.source_northing,
    g.corrected_easting AS accepted_easting,
    g.corrected_northing AS accepted_northing,
    g.decision_status,
    g.map_review_status,
        CASE
            WHEN (g.capture_id = ANY (ARRAY[(12072)::bigint, (17254)::bigint])) THEN 'INVESTIGATOR_REJECTED'::text
            WHEN (((g.source_northing >= (290000)::numeric) AND (g.source_northing <= (300000)::numeric)) AND ((g.source_easting >= (370000)::numeric) AND (g.source_easting <= (390000)::numeric))) THEN 'TEST_100KM_NORTHING_SHIFT'::text
            WHEN (g.capture_id = ANY (ARRAY[(16861)::bigint, (17477)::bigint])) THEN 'LEG_OF_MUTTON_GRID_ANOMALY'::text
            ELSE 'IRREGULAR_OR_REMOTE_GRID'::text
        END AS proposed_review_group,
        CASE
            WHEN ((g.decision_status = 'WITHHELD'::text) AND (g.capture_id <> ALL (ARRAY[(12072)::bigint, (17254)::bigint])) AND ((g.source_northing >= (290000)::numeric) AND (g.source_northing <= (300000)::numeric)) AND ((g.source_easting >= (370000)::numeric) AND (g.source_easting <= (390000)::numeric))) THEN g.source_easting
            ELSE NULL::numeric
        END AS test_easting,
        CASE
            WHEN ((g.decision_status = 'WITHHELD'::text) AND (g.capture_id <> ALL (ARRAY[(12072)::bigint, (17254)::bigint])) AND ((g.source_northing >= (290000)::numeric) AND (g.source_northing <= (300000)::numeric)) AND ((g.source_easting >= (370000)::numeric) AND (g.source_easting <= (390000)::numeric))) THEN (g.source_northing - (100000)::numeric)
            ELSE NULL::numeric
        END AS test_northing,
    'REVIEW-ONLY: test coordinates NOT written to accepted encounter XY. Source map/grid-square identity and text must be checked before scientific acceptance.'::text AS test_warning,
    g.decision_note,
    g.map_review_note
   FROM ((research.capture_grid_coordinate_decisions g
     JOIN analysis.encounters_clean_v1 e USING (capture_id))
     JOIN research.captures c USING (capture_id))
  WHERE (g.decision_status = 'WITHHELD'::text);


--
-- Name: VIEW grid_withheld_candidate_review_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.grid_withheld_candidate_review_v1 IS 'ALL withheld historical grid sites, plus 30 test-only minus-100km northing candidates. No accepted locations assigned. Two researcher-rejected sites have no proposed replacement. Coordinates may be grid-square corners rather than actual observation positions.';


--
-- Name: mortality_events_review_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.mortality_events_review_v1 WITH (security_invoker='false') AS
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


--
-- Name: VIEW mortality_events_review_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.mortality_events_review_v1 IS 'One row per recorded death event excluding curated PM companion rows. IMPORTANT: includes identity conflicts and possible repeat death entries, visibly flagged. Original mortality and date retained even if no usable XY; does not imply an RTA always killed the animal. Date is source event date, not an exact time of death. PM companion may supply coarse grid coordinates; quality field preserved. Not a final survival-event table until identity and duplicate reviews complete.';


--
-- Name: mortality_model_candidate_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.mortality_model_candidate_v1 WITH (security_invoker='false') AS
 SELECT capture_id,
    tattoo,
    recorded_event_date,
    mortality_outcome,
    encounter_type,
    source_is_pm,
    original_moc,
    pm_cause,
    linked_pm_capture_id,
    linked_pm_date,
    location_easting,
    location_northing,
    location_quality,
    next_live_capture_date,
    previous_death_record_date,
    mortality_review_status,
        CASE
            WHEN (capture_id = ANY (ARRAY[(16968)::bigint, (17328)::bigint])) THEN 'HOLD_IDENTITY_CONTRADICTION'::text
            WHEN (capture_id = ANY (ARRAY[(4987)::bigint, (7311)::bigint])) THEN 'HOLD_POSSIBLE_REPEAT_DEATH'::text
            ELSE 'CANDIDATE_TERMINAL_DEATH'::text
        END AS terminal_model_status,
        CASE
            WHEN (capture_id = ANY (ARRAY[(16968)::bigint, (17328)::bigint])) THEN 'Original Access death entry conflicts with later definite live tattoo history; PM remains in review table pending identification.'::text
            WHEN (capture_id = ANY (ARRAY[(4987)::bigint, (7311)::bigint])) THEN 'Additional dead entry at same place after previous death; not treated as independent terminal death pending record review.'::text
            ELSE 'Candidate recorded death event; identity and episode evidence still subject to global survival-history checks.'::text
        END AS terminal_model_note
   FROM analysis.mortality_events_review_v1 m;


--
-- Name: VIEW mortality_model_candidate_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.mortality_model_candidate_v1 IS 'Candidate survival-model event review with explicit HOLD statuses for two identity-contradictory PM records and two repeat-death candidates. Does not discard records, nor certify all other deaths independently verified. Source mortality retained even when XY null. Not yet final signed-off survival extract.';


--
-- Name: spatial_missing_review_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.spatial_missing_review_v1 WITH (security_invoker='false') AS
 SELECT e.capture_id,
    e.tattoo,
    e.capture_date,
    e.is_pm,
    e.encounter_type,
    e.outcome,
    e.sett_id,
    ss.sett_name AS canonical_sett_name,
    c.recorded_sett_name,
    c.capture_location_text,
    c.os_ref,
    c.moc AS original_moc,
    c.comment,
    c.pm_cause,
    e.episode_record_role,
    e.location_type,
    e.location_quality,
        CASE
            WHEN (e.episode_record_role = 'PM_COMPANION'::text) THEN 'PM_COMPANION_NO_INDEPENDENT_POINT'::text
            WHEN (e.location_quality = 'SETT_COORDINATE_CONFLICT'::text) THEN 'ASSOCIATED_SETT_NOT_ACTUAL_SITE'::text
            WHEN (e.location_quality = 'GRID_REFERENCE_AMBIGUOUS_WITHHELD'::text) THEN 'ORIGINAL_GRID_VERIFY'::text
            WHEN ((e.sett_id IS NOT NULL) AND (ss.easting IS NULL)) THEN 'SETT_XY_FIELD_TEAM'::text
            WHEN e.is_pm THEN 'MORTALITY_RECOVERY_LOCATION'::text
            WHEN (NULLIF(btrim(COALESCE(c.recorded_sett_name, ''::text)), ''::text) IS NOT NULL) THEN 'NAMED_NON_SETT_SITE'::text
            ELSE 'SOURCE_LOCATION_UNSPECIFIED'::text
        END AS spatial_review_priority
   FROM ((analysis.encounters_clean_v1 e
     JOIN research.captures c USING (capture_id))
     LEFT JOIN research.setts ss ON ((ss.sett_id = e.sett_id)))
  WHERE ((e.location_easting IS NULL) OR (e.location_northing IS NULL));


--
-- Name: VIEW spatial_missing_review_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.spatial_missing_review_v1 IS 'Current WECS missing XY audit queue by explanatory cause, not all missing points are errors. Outcomes including death are preserved. Sett association is not physical encounter location; no automatic imputation.';


--
-- Name: wecs_review_flags; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.wecs_review_flags (
    flag_id text NOT NULL,
    category text NOT NULL,
    capture_ids bigint[] NOT NULL,
    tattoo text,
    summary text NOT NULL,
    evidence text NOT NULL,
    current_interpretation text NOT NULL,
    review_status text NOT NULL,
    final_decision text,
    final_decision_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT final_decision_if_resolved CHECK (((review_status <> 'RESOLVED'::text) OR (final_decision IS NOT NULL))),
    CONSTRAINT wecs_review_flags_review_status_check CHECK ((review_status = ANY (ARRAY['OPEN'::text, 'RESOLVED'::text, 'NEEDS_SOURCE_CHECK'::text, 'WAITING_FIELD_TEAM'::text])))
);


--
-- Name: TABLE wecs_review_flags; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.wecs_review_flags IS 'Human-readable, persistent WECS audit queue. current_interpretation may change; final_decision only after resolved. Source capture records never overwritten.';


--
-- Name: wecs_review_flags_v1; Type: VIEW; Schema: analysis; Owner: -
--

CREATE VIEW analysis.wecs_review_flags_v1 WITH (security_invoker='false') AS
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


--
-- Name: VIEW wecs_review_flags_v1; Type: COMMENT; Schema: analysis; Owner: -
--

COMMENT ON VIEW analysis.wecs_review_flags_v1 IS 'Public-facing (within authorised read-only analysis schema) current WECS flag status and final investigator decisions; research.wecs_review_flags is the editable source.';


--
-- Name: access_refresh_batches; Type: TABLE; Schema: ingest; Owner: -
--

CREATE TABLE ingest.access_refresh_batches (
    batch_id bigint NOT NULL,
    source_filename text NOT NULL,
    source_sha256 text NOT NULL,
    source_exported_at timestamp with time zone,
    registered_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'REGISTERED'::text NOT NULL,
    git_commit text,
    notes text,
    CONSTRAINT access_refresh_batches_status_check CHECK ((status = ANY (ARRAY['REGISTERED'::text, 'STAGED'::text, 'REVIEWED'::text, 'APPLIED'::text, 'REJECTED'::text])))
);


--
-- Name: access_refresh_batches_batch_id_seq; Type: SEQUENCE; Schema: ingest; Owner: -
--

ALTER TABLE ingest.access_refresh_batches ALTER COLUMN batch_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest.access_refresh_batches_batch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: access_refresh_table_audits; Type: TABLE; Schema: ingest; Owner: -
--

CREATE TABLE ingest.access_refresh_table_audits (
    audit_id bigint NOT NULL,
    batch_id bigint NOT NULL,
    source_table text NOT NULL,
    source_rows bigint,
    prior_rows bigint,
    inserted_rows bigint,
    changed_rows bigint,
    missing_rows bigint,
    ambiguous_rows bigint,
    audit_status text DEFAULT 'PENDING'::text NOT NULL,
    audit_detail jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT access_refresh_table_audits_audit_status_check CHECK ((audit_status = ANY (ARRAY['PENDING'::text, 'PASS'::text, 'REVIEW'::text, 'FAIL'::text])))
);


--
-- Name: access_refresh_table_audits_audit_id_seq; Type: SEQUENCE; Schema: ingest; Owner: -
--

ALTER TABLE ingest.access_refresh_table_audits ALTER COLUMN audit_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest.access_refresh_table_audits_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: canonical_cleaning_decisions; Type: TABLE; Schema: ingest; Owner: -
--

CREATE TABLE ingest.canonical_cleaning_decisions (
    decision_id bigint NOT NULL,
    rule_version text NOT NULL,
    domain text NOT NULL,
    source_table text,
    source_identifier text,
    recorded_value text,
    canonical_value text,
    evidence text NOT NULL,
    rationale text NOT NULL,
    decision_status text DEFAULT 'PROPOSED'::text NOT NULL,
    git_commit text,
    reviewed_by text,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT canonical_cleaning_decisions_decision_status_check CHECK ((decision_status = ANY (ARRAY['PROPOSED'::text, 'APPROVED'::text, 'REJECTED'::text, 'SUPERSEDED'::text])))
);


--
-- Name: canonical_cleaning_decisions_decision_id_seq; Type: SEQUENCE; Schema: ingest; Owner: -
--

ALTER TABLE ingest.canonical_cleaning_decisions ALTER COLUMN decision_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest.canonical_cleaning_decisions_decision_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: infection_probabilities_import; Type: TABLE; Schema: ingest; Owner: -
--

CREATE TABLE ingest.infection_probabilities_import (
    tattoo text,
    date text,
    year integer,
    quarter integer,
    diagnostic_fixed_prevalence double precision,
    diagnostic_annual_prevalence double precision,
    diagnostic_adjusted_annual double precision,
    all_tests_fixed double precision,
    all_tests_inferred double precision,
    culture_only_fixed double precision
);


--
-- Name: infection_quarterly_import; Type: TABLE; Schema: ingest; Owner: -
--

CREATE TABLE ingest.infection_quarterly_import (
    tattoo text,
    quarter_date date,
    year integer,
    quarter integer,
    infection_probability double precision
);


--
-- Name: sett_coordinate_source_20261023; Type: TABLE; Schema: ingest; Owner: -
--

CREATE TABLE ingest.sett_coordinate_source_20261023 (
    source_name text NOT NULL,
    source_display_name text NOT NULL,
    easting numeric NOT NULL,
    northing numeric NOT NULL,
    source_file text DEFAULT 'WoodchesterSettLocations (1).csv'::text NOT NULL,
    coordinate_system text DEFAULT 'EPSG:27700'::text NOT NULL,
    imported_on date DEFAULT '2026-10-23'::date NOT NULL
);


--
-- Name: woodchester_data_baseline_versions; Type: TABLE; Schema: ingest; Owner: -
--

CREATE TABLE ingest.woodchester_data_baseline_versions (
    version_label text NOT NULL,
    baseline_date date NOT NULL,
    status text NOT NULL,
    scope text NOT NULL,
    scientific_rules text NOT NULL,
    outstanding_work text NOT NULL,
    recorded_by text NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: culture_results_standardised; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.culture_results_standardised AS
 SELECT i.tattoo,
    c.capture_id,
    cu.culture_id,
    c.capture_date,
    c.is_pm,
    cu.sample_type AS sample_type_recorded,
        CASE
            WHEN (upper(btrim(COALESCE(cu.sample_type, ''::text))) = ANY (ARRAY['OA'::text, 'TA'::text, 'URINE'::text, 'FAECES'::text])) THEN upper(btrim(cu.sample_type))
            ELSE 'OTHER'::text
        END AS sample_group,
    cu.culture_result AS culture_result_recorded,
        CASE
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = 'M.BOVIS'::text) THEN 'M_BOVIS_DETECTED'::text
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = 'NEGATIVE'::text) THEN 'NEGATIVE'::text
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = ANY (ARRAY['M.AVIUM'::text, 'M.OTHER'::text])) THEN 'OTHER_ORGANISM'::text
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = ANY (ARRAY['FAILED'::text, 'CONTAMINATED'::text])) THEN 'INVALID'::text
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = 'PENDING'::text) THEN 'PENDING'::text
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = 'NOT TESTED'::text) THEN 'NOT_TESTED'::text
            WHEN (NULLIF(btrim(COALESCE(cu.culture_result, ''::text)), ''::text) IS NULL) THEN 'MISSING'::text
            ELSE 'UNRECOGNISED'::text
        END AS culture_result_status,
        CASE
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = 'M.BOVIS'::text) THEN true
            WHEN (upper(btrim(COALESCE(cu.culture_result, ''::text))) = 'NEGATIVE'::text) THEN false
            ELSE NULL::boolean
        END AS is_m_bovis_detected,
    cu.afno,
    cu.spoligo,
    cu.spolprime,
    cu.wgs_clade
   FROM ((research.cultures cu
     JOIN research.captures c ON ((c.capture_id = cu.capture_id)))
     JOIN research.individuals i ON ((i.individual_id = c.individual_id)));


--
-- Name: VIEW culture_results_standardised; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.culture_results_standardised IS 'Version 1: culture result categories. Only M.BOVIS and NEGATIVE yield non-null binary evidence; other organism/invalid/pending/missing results are not treated as negative.';


--
-- Name: stat_pak_results_standardised; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.stat_pak_results_standardised AS
 SELECT i.tattoo,
    s.capture_id,
    s.stat_pak_test_id,
    c.capture_date,
    s.stat_pak_id AS original_result_code,
    s.test_result AS original_result_text,
        CASE
            WHEN (upper(btrim(s.stat_pak_id)) = 'P'::text) THEN 'POSITIVE'::text
            WHEN (upper(btrim(s.stat_pak_id)) = 'N'::text) THEN 'NEGATIVE'::text
            WHEN (upper(btrim(s.stat_pak_id)) = 'C'::text) THEN 'INVALID'::text
            ELSE 'INDETERMINATE'::text
        END AS result_status,
        CASE
            WHEN (upper(btrim(s.stat_pak_id)) = 'P'::text) THEN true
            WHEN (upper(btrim(s.stat_pak_id)) = 'N'::text) THEN false
            ELSE NULL::boolean
        END AS test_positive
   FROM ((research.stat_pak_tests s
     JOIN research.captures c USING (capture_id))
     JOIN research.individuals i USING (individual_id));


--
-- Name: diagnostic_interpretation_standardised; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.diagnostic_interpretation_standardised AS
 WITH x AS (
         SELECT dpp_tests.capture_id,
            'DPP'::text AS test_family,
            dpp_tests.dpp_test_id AS source_record_id,
            concat_ws('/'::text, dpp_tests.visual_line_1, dpp_tests.visual_line_2) AS recorded_result,
                CASE
                    WHEN ((upper(btrim(COALESCE(dpp_tests.visual_line_1, ''::text))) = ANY (ARRAY['P'::text, 'PX'::text])) OR (upper(btrim(COALESCE(dpp_tests.visual_line_2, ''::text))) = ANY (ARRAY['P'::text, 'PX'::text]))) THEN 'POSITIVE'::text
                    WHEN ((upper(btrim(COALESCE(dpp_tests.visual_line_1, ''::text))) = ANY (ARRAY['N'::text, 'NX'::text])) AND ((upper(btrim(COALESCE(dpp_tests.visual_line_2, ''::text))) = ANY (ARRAY['N'::text, 'NX'::text])) OR (NULLIF(btrim(COALESCE(dpp_tests.visual_line_2, ''::text)), ''::text) IS NULL))) THEN 'NEGATIVE'::text
                    ELSE 'INDETERMINATE'::text
                END AS interpreted_status
           FROM research.dpp_tests
        UNION ALL
         SELECT ifn_gamma_elisa.capture_id,
            'IFN_GAMMA'::text,
            ifn_gamma_elisa.ifn_test_id,
            ifn_gamma_elisa.test_result,
                CASE
                    WHEN (NULLIF(btrim(COALESCE(ifn_gamma_elisa.test_failed, ''::text)), ''::text) IS NOT NULL) THEN 'INVALID'::text
                    WHEN (upper(btrim(COALESCE(ifn_gamma_elisa.test_result, ''::text))) = 'POSITIVE'::text) THEN 'POSITIVE'::text
                    WHEN (upper(btrim(COALESCE(ifn_gamma_elisa.test_result, ''::text))) = 'NEGATIVE'::text) THEN 'NEGATIVE'::text
                    ELSE 'INDETERMINATE'::text
                END AS "case"
           FROM research.ifn_gamma_elisa
        UNION ALL
         SELECT elisa_tests.capture_id,
            'ELISA'::text,
            elisa_tests.elisa_test_id,
            elisa_tests.test_result,
                CASE
                    WHEN (upper(btrim(COALESCE(elisa_tests.test_result, ''::text))) = 'P'::text) THEN 'POSITIVE'::text
                    WHEN (upper(btrim(COALESCE(elisa_tests.test_result, ''::text))) = 'N'::text) THEN 'NEGATIVE'::text
                    ELSE 'INDETERMINATE'::text
                END AS "case"
           FROM research.elisa_tests
        UNION ALL
         SELECT brock_tests.capture_id,
            'BROCK'::text,
            brock_tests.brock_test_id,
            brock_tests.test_result,
                CASE
                    WHEN (brock_tests.no_clotted IS TRUE) THEN 'INVALID'::text
                    WHEN (upper(btrim(COALESCE(brock_tests.test_result, ''::text))) = 'P'::text) THEN 'POSITIVE'::text
                    WHEN (upper(btrim(COALESCE(brock_tests.test_result, ''::text))) = 'N'::text) THEN 'NEGATIVE'::text
                    ELSE 'INDETERMINATE'::text
                END AS "case"
           FROM research.brock_tests
        UNION ALL
         SELECT stat_pak_results_standardised.capture_id,
            'STAT_PAK'::text,
            stat_pak_results_standardised.stat_pak_test_id,
            stat_pak_results_standardised.original_result_text,
            stat_pak_results_standardised.result_status
           FROM internal_v1.stat_pak_results_standardised
        UNION ALL
         SELECT culture_results_standardised.capture_id,
            'CULTURE'::text,
            culture_results_standardised.culture_id,
            culture_results_standardised.culture_result_recorded,
                CASE culture_results_standardised.culture_result_status
                    WHEN 'M_BOVIS_DETECTED'::text THEN 'POSITIVE'::text
                    WHEN 'NEGATIVE'::text THEN 'NEGATIVE'::text
                    WHEN 'INVALID'::text THEN 'INVALID'::text
                    ELSE 'INDETERMINATE'::text
                END AS "case"
           FROM internal_v1.culture_results_standardised
        )
 SELECT i.tattoo,
    c.capture_id,
    c.capture_date,
    c.is_pm,
    x.test_family,
    x.source_record_id,
    x.recorded_result,
    x.interpreted_status,
        CASE
            WHEN (x.interpreted_status = 'POSITIVE'::text) THEN true
            WHEN (x.interpreted_status = 'NEGATIVE'::text) THEN false
            ELSE NULL::boolean
        END AS test_positive
   FROM ((x
     JOIN research.captures c ON ((c.capture_id = x.capture_id)))
     JOIN research.individuals i ON ((i.individual_id = c.individual_id)));


--
-- Name: VIEW diagnostic_interpretation_standardised; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.diagnostic_interpretation_standardised IS 'Version 1 baseline: six assay families including culture; original results preserved and nullable positivity excludes missing/invalid/pending and other organisms.';


--
-- Name: capture_diagnostic_summary_standardised; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_diagnostic_summary_standardised AS
 SELECT c.capture_id,
    i.tattoo,
    c.capture_date,
    c.is_pm,
    count(d.source_record_id) AS diagnostic_test_count,
    count(d.source_record_id) FILTER (WHERE (d.test_positive IS TRUE)) AS positive_test_count,
    count(d.source_record_id) FILTER (WHERE (d.test_positive IS FALSE)) AS negative_test_count,
    count(d.source_record_id) FILTER (WHERE (d.test_positive IS NULL)) AS uninterpretable_test_count,
    bool_or((d.test_positive IS TRUE)) AS any_positive_test
   FROM ((research.captures c
     JOIN research.individuals i ON ((i.individual_id = c.individual_id)))
     LEFT JOIN internal_v1.diagnostic_interpretation_standardised d ON ((c.capture_id = d.capture_id)))
  GROUP BY c.capture_id, i.tattoo, c.capture_date, c.is_pm;


--
-- Name: VIEW capture_diagnostic_summary_standardised; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_diagnostic_summary_standardised IS 'v2 convenience by capture, counts of interpretable and indeterminate tests; any_positive_test is descriptive evidence, not latent infection diagnosis.';


--
-- Name: individual_traits_standardised; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.individual_traits_standardised AS
 SELECT tattoo,
    elect_tag,
    age_first_capture AS age_first_capture_recorded,
        CASE
            WHEN (upper(btrim(COALESCE(age_first_capture, ''::text))) = ANY (ARRAY['CUB'::text, 'YEARLING'::text, 'ADULT'::text])) THEN upper(btrim(age_first_capture))
            ELSE 'UNKNOWN'::text
        END AS age_first_capture_standardised,
    (age_first_capture IS NULL) AS age_first_capture_missing,
    year_first_capture,
    sex AS sex_recorded,
        CASE
            WHEN (upper(btrim(COALESCE(sex, ''::text))) = ANY (ARRAY['MALE'::text, 'FEMALE'::text])) THEN upper(btrim(sex))
            ELSE 'UNKNOWN'::text
        END AS sex_standardised,
    (sex IS NULL) AS sex_missing
   FROM research.individuals i;


--
-- Name: VIEW individual_traits_standardised; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.individual_traits_standardised IS 'Version 1: non-destructive age/sex standardisation. UNKNOWN includes canonical NULL and nonstandard codes; explicit missing flags distinguish NULL. Not an age correction.';


--
-- Name: capture_traits_standardised; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_traits_standardised AS
 SELECT c.capture_id,
    i.tattoo,
    c.capture_date,
    (EXTRACT(year FROM c.capture_date))::integer AS capture_year,
    (EXTRACT(quarter FROM c.capture_date))::integer AS capture_quarter,
    c.is_pm,
    c.sett_id,
    c.recorded_sett_name,
    c.recorded_social_group_id,
    c.recorded_social_group_name,
    t.sex_recorded,
    t.sex_standardised,
    t.sex_missing,
    t.age_first_capture_recorded,
    t.age_first_capture_standardised,
    t.year_first_capture,
        CASE
            WHEN ((t.year_first_capture IS NOT NULL) AND (c.capture_date IS NOT NULL)) THEN ((EXTRACT(year FROM c.capture_date))::integer - t.year_first_capture)
            ELSE NULL::integer
        END AS years_since_first_capture,
        CASE
            WHEN ((t.age_first_capture_standardised = 'CUB'::text) AND (t.year_first_capture IS NOT NULL)) THEN ((EXTRACT(year FROM c.capture_date))::integer - t.year_first_capture)
            ELSE NULL::integer
        END AS approximate_age_if_first_captured_as_cub
   FROM ((research.captures c
     JOIN research.individuals i USING (individual_id))
     JOIN internal_v1.individual_traits_standardised t ON ((t.tattoo = i.tattoo)));


--
-- Name: VIEW capture_traits_standardised; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_traits_standardised IS 'V1: year/quarter and years since first capture; approximate age only for recorded CUB first captures, not validated exact age.';


--
-- Name: capture_traits_v1; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.capture_traits_v1 WITH (security_invoker='true') AS
 SELECT t.capture_id,
    t.tattoo,
    t.capture_date,
    t.capture_year,
    t.capture_quarter,
    t.is_pm,
    t.sett_id,
    t.recorded_sett_name,
    t.recorded_social_group_id,
    t.recorded_social_group_name,
    t.sex_recorded,
    t.sex_standardised,
    t.sex_missing,
    t.age_first_capture_recorded,
    t.age_first_capture_standardised,
    t.year_first_capture,
    t.years_since_first_capture,
    t.approximate_age_if_first_captured_as_cub,
    l.sett_name,
    l.location_type,
    l.location_easting,
    l.location_northing,
    l.location_crs,
    l.location_coordinate_basis,
    l.location_class
   FROM (internal_v1.capture_traits_standardised t
     LEFT JOIN internal_v1.capture_location_fields_v1 l USING (capture_id));


--
-- Name: VIEW capture_traits_v1; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.capture_traits_v1 IS 'V1 standardised capture traits with consistent sett_name and location fields.';


--
-- Name: infection_probabilities; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.infection_probabilities AS
 SELECT infection_probability_id,
    tattoo,
    capture_id,
    sample_date,
    year,
    quarter,
    model_variant,
    infection_probability,
    model_run,
    source_file,
    imported_at
   FROM ( SELECT ip.infection_probability_id,
            ip.individual_id,
            i.tattoo,
            ip.capture_id,
            ip.sample_date,
            ip.year,
            ip.quarter,
            ip.model_variant,
            ip.infection_probability,
            ip.model_run,
            ip.source_file,
            ip.imported_at
           FROM (research.infection_probabilities ip
             JOIN research.individuals i ON ((ip.individual_id = i.individual_id)))) x;


--
-- Name: infection_quarterly_probabilities; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.infection_quarterly_probabilities (
    infection_quarterly_id bigint NOT NULL,
    individual_id bigint NOT NULL,
    quarter_date date NOT NULL,
    year smallint NOT NULL,
    quarter smallint NOT NULL,
    model_variant text NOT NULL,
    infection_probability double precision NOT NULL,
    model_run text NOT NULL,
    source_file text,
    imported_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT infection_quarterly_probabilities_infection_probability_check CHECK (((infection_probability >= (0)::double precision) AND (infection_probability <= (1)::double precision))),
    CONSTRAINT infection_quarterly_probabilities_quarter_check CHECK (((quarter >= 1) AND (quarter <= 4)))
);


--
-- Name: infection_quarterly_probabilities; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.infection_quarterly_probabilities AS
 SELECT infection_quarterly_id,
    tattoo,
    quarter_date,
    year,
    quarter,
    model_variant,
    infection_probability,
    model_run,
    source_file,
    imported_at
   FROM ( SELECT q.infection_quarterly_id,
            q.individual_id,
            i.tattoo,
            q.quarter_date,
            q.year,
            q.quarter,
            q.model_variant,
            q.infection_probability,
            q.model_run,
            q.source_file,
            q.imported_at
           FROM (research.infection_quarterly_probabilities q
             JOIN research.individuals i ON ((q.individual_id = i.individual_id)))) x;


--
-- Name: sett_coordinate_source_name_review; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.sett_coordinate_source_name_review AS
 WITH matches AS (
         SELECT src_1.source_name,
            s_1.sett_id
           FROM (ingest.sett_coordinate_source_20261023 src_1
             JOIN research.setts s_1 ON ((regexp_replace(upper(src_1.source_name), '[^A-Z0-9]'::text, ''::text, 'g'::text) = regexp_replace(upper(s_1.sett_name), '[^A-Z0-9]'::text, ''::text, 'g'::text))))
        UNION ALL
         SELECT src_1.source_name,
            s_1.sett_id
           FROM (ingest.sett_coordinate_source_20261023 src_1
             JOIN research.setts s_1 ON ((((src_1.source_name = 'CLIFF.FACE'::text) AND (s_1.sett_name = 'CLIFF'::text)) OR ((src_1.source_name = 'GULLY'::text) AND (s_1.sett_name = 'GULLEY'::text)) OR ((src_1.source_name = 'STONEY.TRACK'::text) AND (s_1.sett_name = 'STONY TRACK'::text)) OR ((src_1.source_name = 'ELEVEN.ROW'::text) AND (s_1.sett_name = 'ELEVENTH ROW'::text)))))
        )
 SELECT src.source_name,
    src.source_display_name,
    src.easting,
    src.northing,
    s.sett_name AS matched_canonical_sett,
        CASE
            WHEN (s.sett_id IS NULL) THEN 'REVIEW_NAME'::text
            ELSE 'LINKED'::text
        END AS match_status
   FROM ((ingest.sett_coordinate_source_20261023 src
     LEFT JOIN matches m ON ((m.source_name = src.source_name)))
     LEFT JOIN research.setts s ON ((s.sett_id = m.sett_id)));


--
-- Name: VIEW sett_coordinate_source_name_review; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.sett_coordinate_source_name_review IS 'Definitive uploaded coordinate file compared against canonical sett names; unresolved source names remain visible with original easting/northing.';


--
-- Name: sett_coordinate_unmatched_v1; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.sett_coordinate_unmatched_v1 WITH (security_invoker='true') AS
 SELECT source_name,
    source_display_name,
    easting,
    northing,
    match_status
   FROM internal_v1.sett_coordinate_source_name_review
  WHERE (match_status = 'REVIEW_NAME'::text);


--
-- Name: VIEW sett_coordinate_unmatched_v1; Type: COMMENT; Schema: internal_v1; Owner: -
--

COMMENT ON VIEW internal_v1.sett_coordinate_unmatched_v1 IS 'Woodchester working V1 coordinate source names not yet matched to canonical sett identities.';


--
-- Name: sett_coordinates_approved; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.sett_coordinates_approved AS
 SELECT sett_name,
    easting,
    northing,
    coordinate_system,
    accuracy_m,
    coordinate_source AS source_reference,
    coordinate_observed_on AS observed_on
   FROM research.setts
  WHERE ((easting IS NOT NULL) AND (northing IS NOT NULL));


--
-- Name: sett_social_group_observed; Type: VIEW; Schema: internal_v1; Owner: -
--

CREATE VIEW internal_v1.sett_social_group_observed AS
 SELECT s.sett_id,
    s.sett_name,
    sg.social_group_id,
    sg.social_group_name,
    (EXTRACT(year FROM c.capture_date))::integer AS year,
    count(*) AS n_captures,
    min(c.capture_date) AS first_capture_date,
    max(c.capture_date) AS last_capture_date
   FROM ((research.captures c
     JOIN research.setts s ON ((c.sett_id = s.sett_id)))
     JOIN research.social_groups sg ON ((c.recorded_social_group_id = sg.social_group_id)))
  GROUP BY s.sett_id, s.sett_name, sg.social_group_id, sg.social_group_name, (EXTRACT(year FROM c.capture_date));


--
-- Name: brock_tests_brock_test_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.brock_tests ALTER COLUMN brock_test_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.brock_tests_brock_test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: captures_capture_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.captures ALTER COLUMN capture_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.captures_capture_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cultures_culture_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.cultures ALTER COLUMN culture_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.cultures_culture_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dpp_tests_dpp_test_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.dpp_tests ALTER COLUMN dpp_test_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.dpp_tests_dpp_test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: elisa_tests_elisa_test_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.elisa_tests ALTER COLUMN elisa_test_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.elisa_tests_elisa_test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ifn_gamma_elisa_ifn_test_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.ifn_gamma_elisa ALTER COLUMN ifn_test_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.ifn_gamma_elisa_ifn_test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: individuals_individual_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.individuals ALTER COLUMN individual_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.individuals_individual_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: infection_probabilities_infection_probability_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.infection_probabilities ALTER COLUMN infection_probability_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME research.infection_probabilities_infection_probability_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: infection_quarterly_probabilities_infection_quarterly_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.infection_quarterly_probabilities ALTER COLUMN infection_quarterly_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME research.infection_quarterly_probabilities_infection_quarterly_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sett_annual_territory_matches; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.sett_annual_territory_matches (
    year integer NOT NULL,
    sett_id bigint NOT NULL,
    polygon_id text,
    territory_name text,
    match_status text NOT NULL,
    polygon_source text NOT NULL,
    coordinate_source text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    match_id bigint NOT NULL,
    CONSTRAINT sett_annual_territory_matches_match_status_check CHECK ((match_status = ANY (ARRAY['ONE_POLYGON'::text, 'MULTIPLE_POLYGONS'::text, 'OUTSIDE_ALL'::text, 'NO_COORDINATE'::text, 'ON_BOUNDARY'::text]))),
    CONSTRAINT sett_annual_territory_matches_year_check CHECK (((year >= 1977) AND (year <= 2025))),
    CONSTRAINT status_polygon_consistency CHECK ((((polygon_id IS NULL) AND (match_status = ANY (ARRAY['OUTSIDE_ALL'::text, 'NO_COORDINATE'::text]))) OR ((polygon_id IS NOT NULL) AND (match_status = ANY (ARRAY['ONE_POLYGON'::text, 'MULTIPLE_POLYGONS'::text, 'ON_BOUNDARY'::text])))))
);


--
-- Name: TABLE sett_annual_territory_matches; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.sett_annual_territory_matches IS 'Annual polygon point-in-polygon crosswalk, not biologically verified social-group residency. Row per matching territory; NULL polygon where no coordinates or no containing polygon. Populated from audited 1977–2025 shapefiles using scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R.';


--
-- Name: sett_annual_territory_matches_match_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.sett_annual_territory_matches ALTER COLUMN match_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.sett_annual_territory_matches_match_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sett_social_group_links; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.sett_social_group_links (
    sett_social_group_id bigint NOT NULL,
    sett_id bigint NOT NULL,
    social_group_id bigint NOT NULL,
    valid_from date,
    valid_to date,
    notes text,
    CONSTRAINT sett_social_group_history_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: TABLE sett_social_group_links; Type: COMMENT; Schema: research; Owner: -
--

COMMENT ON TABLE research.sett_social_group_links IS 'Undated sett–social group associations imported from the original sett lookup, not annual membership or verified territory occupancy.';


--
-- Name: sett_social_group_history_sett_social_group_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.sett_social_group_links ALTER COLUMN sett_social_group_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.sett_social_group_history_sett_social_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: setts_sett_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.setts ALTER COLUMN sett_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.setts_sett_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: social_group_supergroup_history; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.social_group_supergroup_history (
    social_group_supergroup_id bigint NOT NULL,
    social_group_id bigint NOT NULL,
    supergroup_id bigint NOT NULL,
    valid_from date,
    valid_to date,
    notes text,
    CONSTRAINT social_group_supergroup_history_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: social_group_supergroup_history_social_group_supergroup_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.social_group_supergroup_history ALTER COLUMN social_group_supergroup_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.social_group_supergroup_history_social_group_supergroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: social_groups_social_group_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.social_groups ALTER COLUMN social_group_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.social_groups_social_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stat_pak_tests_stat_pak_test_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.stat_pak_tests ALTER COLUMN stat_pak_test_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.stat_pak_tests_stat_pak_test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: supergroups; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.supergroups (
    supergroup_id bigint NOT NULL,
    supergroup_name text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: supergroups_supergroup_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.supergroups ALTER COLUMN supergroup_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.supergroups_supergroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: wounds; Type: TABLE; Schema: research; Owner: -
--

CREATE TABLE research.wounds (
    wound_id bigint NOT NULL,
    capture_id bigint NOT NULL,
    wound_area text,
    wound_amount text,
    wound_age text,
    wound_size text,
    wound_type text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: wounds_wound_id_seq; Type: SEQUENCE; Schema: research; Owner: -
--

ALTER TABLE research.wounds ALTER COLUMN wound_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME research.wounds_wound_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: social_groups social_groups_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.social_groups
    ADD CONSTRAINT social_groups_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_badger tbl_badger_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_badger
    ADD CONSTRAINT tbl_badger_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_blood_sampler tbl_blood_sampler_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_blood_sampler
    ADD CONSTRAINT tbl_blood_sampler_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_brock_test tbl_brock_test_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_brock_test
    ADD CONSTRAINT tbl_brock_test_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_captures tbl_captures_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_captures
    ADD CONSTRAINT tbl_captures_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_culture tbl_culture_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_culture
    ADD CONSTRAINT tbl_culture_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_dpp_test tbl_dpp_test_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_dpp_test
    ADD CONSTRAINT tbl_dpp_test_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_elisa tbl_elisa_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_elisa
    ADD CONSTRAINT tbl_elisa_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_ifn_gamma_elisa tbl_ifn_gamma_elisa_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_ifn_gamma_elisa
    ADD CONSTRAINT tbl_ifn_gamma_elisa_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_sett tbl_sett_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_sett
    ADD CONSTRAINT tbl_sett_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_stat_pak tbl_stat_pak_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_stat_pak
    ADD CONSTRAINT tbl_stat_pak_pkey PRIMARY KEY (raw_row_id);


--
-- Name: tbl_wounds tbl_wounds_pkey; Type: CONSTRAINT; Schema: access_raw; Owner: -
--

ALTER TABLE ONLY access_raw.tbl_wounds
    ADD CONSTRAINT tbl_wounds_pkey PRIMARY KEY (raw_row_id);


--
-- Name: access_refresh_batches access_refresh_batches_pkey; Type: CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.access_refresh_batches
    ADD CONSTRAINT access_refresh_batches_pkey PRIMARY KEY (batch_id);


--
-- Name: access_refresh_batches access_refresh_batches_source_filename_source_sha256_key; Type: CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.access_refresh_batches
    ADD CONSTRAINT access_refresh_batches_source_filename_source_sha256_key UNIQUE (source_filename, source_sha256);


--
-- Name: access_refresh_table_audits access_refresh_table_audits_batch_id_source_table_key; Type: CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.access_refresh_table_audits
    ADD CONSTRAINT access_refresh_table_audits_batch_id_source_table_key UNIQUE (batch_id, source_table);


--
-- Name: access_refresh_table_audits access_refresh_table_audits_pkey; Type: CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.access_refresh_table_audits
    ADD CONSTRAINT access_refresh_table_audits_pkey PRIMARY KEY (audit_id);


--
-- Name: canonical_cleaning_decisions canonical_cleaning_decisions_pkey; Type: CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.canonical_cleaning_decisions
    ADD CONSTRAINT canonical_cleaning_decisions_pkey PRIMARY KEY (decision_id);


--
-- Name: sett_coordinate_source_20261023 sett_coordinate_source_20261023_pkey; Type: CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.sett_coordinate_source_20261023
    ADD CONSTRAINT sett_coordinate_source_20261023_pkey PRIMARY KEY (source_name);


--
-- Name: woodchester_data_baseline_versions woodchester_data_baseline_versions_pkey; Type: CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.woodchester_data_baseline_versions
    ADD CONSTRAINT woodchester_data_baseline_versions_pkey PRIMARY KEY (version_label);


--
-- Name: brock_tests brock_tests_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.brock_tests
    ADD CONSTRAINT brock_tests_pkey PRIMARY KEY (brock_test_id);


--
-- Name: capture_grid_coordinate_decisions capture_grid_coordinate_decisions_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.capture_grid_coordinate_decisions
    ADD CONSTRAINT capture_grid_coordinate_decisions_pkey PRIMARY KEY (capture_id);


--
-- Name: capture_sett_alias_decisions capture_sett_alias_decisions_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.capture_sett_alias_decisions
    ADD CONSTRAINT capture_sett_alias_decisions_pkey PRIMARY KEY (capture_id);


--
-- Name: captures captures_individual_id_capture_date_is_pm_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.captures
    ADD CONSTRAINT captures_individual_id_capture_date_is_pm_key UNIQUE (individual_id, capture_date, is_pm);


--
-- Name: captures captures_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.captures
    ADD CONSTRAINT captures_pkey PRIMARY KEY (capture_id);


--
-- Name: cultures cultures_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.cultures
    ADD CONSTRAINT cultures_pkey PRIMARY KEY (culture_id);


--
-- Name: disease_statuses disease_statuses_disease_status_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.disease_statuses
    ADD CONSTRAINT disease_statuses_disease_status_key UNIQUE (disease_status);


--
-- Name: disease_statuses disease_statuses_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.disease_statuses
    ADD CONSTRAINT disease_statuses_pkey PRIMARY KEY (disease_status_id);


--
-- Name: dpp_tests dpp_tests_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.dpp_tests
    ADD CONSTRAINT dpp_tests_pkey PRIMARY KEY (dpp_test_id);


--
-- Name: elisa_tests elisa_tests_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.elisa_tests
    ADD CONSTRAINT elisa_tests_pkey PRIMARY KEY (elisa_test_id);


--
-- Name: encounter_classification_decisions encounter_classification_decisions_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_classification_decisions
    ADD CONSTRAINT encounter_classification_decisions_pkey PRIMARY KEY (capture_id);


--
-- Name: encounter_episode_decisions encounter_episode_decisions_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_episode_decisions
    ADD CONSTRAINT encounter_episode_decisions_pkey PRIMARY KEY (live_capture_id);


--
-- Name: encounter_episode_decisions encounter_episode_decisions_pm_capture_id_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_episode_decisions
    ADD CONSTRAINT encounter_episode_decisions_pm_capture_id_key UNIQUE (pm_capture_id);


--
-- Name: encounter_pair_nonlinks encounter_pair_nonlinks_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_pair_nonlinks
    ADD CONSTRAINT encounter_pair_nonlinks_pkey PRIMARY KEY (first_capture_id, second_capture_id);


--
-- Name: ifn_gamma_elisa ifn_gamma_elisa_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.ifn_gamma_elisa
    ADD CONSTRAINT ifn_gamma_elisa_pkey PRIMARY KEY (ifn_test_id);


--
-- Name: individuals individuals_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.individuals
    ADD CONSTRAINT individuals_pkey PRIMARY KEY (individual_id);


--
-- Name: individuals individuals_tattoo_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.individuals
    ADD CONSTRAINT individuals_tattoo_key UNIQUE (tattoo);


--
-- Name: infection_probabilities infection_probabilities_individual_id_sample_date_model_var_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.infection_probabilities
    ADD CONSTRAINT infection_probabilities_individual_id_sample_date_model_var_key UNIQUE (individual_id, sample_date, model_variant, model_run);


--
-- Name: infection_probabilities infection_probabilities_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.infection_probabilities
    ADD CONSTRAINT infection_probabilities_pkey PRIMARY KEY (infection_probability_id);


--
-- Name: infection_quarterly_probabilities infection_quarterly_probabili_individual_id_year_quarter_mo_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.infection_quarterly_probabilities
    ADD CONSTRAINT infection_quarterly_probabili_individual_id_year_quarter_mo_key UNIQUE (individual_id, year, quarter, model_variant, model_run);


--
-- Name: infection_quarterly_probabilities infection_quarterly_probabilities_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.infection_quarterly_probabilities
    ADD CONSTRAINT infection_quarterly_probabilities_pkey PRIMARY KEY (infection_quarterly_id);


--
-- Name: sett_annual_territory_matches sett_annual_territory_matches_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.sett_annual_territory_matches
    ADD CONSTRAINT sett_annual_territory_matches_pkey PRIMARY KEY (match_id);


--
-- Name: sett_social_group_links sett_social_group_history_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.sett_social_group_links
    ADD CONSTRAINT sett_social_group_history_pkey PRIMARY KEY (sett_social_group_id);


--
-- Name: setts setts_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.setts
    ADD CONSTRAINT setts_pkey PRIMARY KEY (sett_id);


--
-- Name: setts setts_sett_name_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.setts
    ADD CONSTRAINT setts_sett_name_key UNIQUE (sett_name);


--
-- Name: social_group_supergroup_history social_group_supergroup_history_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.social_group_supergroup_history
    ADD CONSTRAINT social_group_supergroup_history_pkey PRIMARY KEY (social_group_supergroup_id);


--
-- Name: social_groups social_groups_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.social_groups
    ADD CONSTRAINT social_groups_pkey PRIMARY KEY (social_group_id);


--
-- Name: social_groups social_groups_social_group_name_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.social_groups
    ADD CONSTRAINT social_groups_social_group_name_key UNIQUE (social_group_name);


--
-- Name: stat_pak_tests stat_pak_tests_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.stat_pak_tests
    ADD CONSTRAINT stat_pak_tests_pkey PRIMARY KEY (stat_pak_test_id);


--
-- Name: supergroups supergroups_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.supergroups
    ADD CONSTRAINT supergroups_pkey PRIMARY KEY (supergroup_id);


--
-- Name: supergroups supergroups_supergroup_name_key; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.supergroups
    ADD CONSTRAINT supergroups_supergroup_name_key UNIQUE (supergroup_name);


--
-- Name: wecs_review_flags wecs_review_flags_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.wecs_review_flags
    ADD CONSTRAINT wecs_review_flags_pkey PRIMARY KEY (flag_id);


--
-- Name: wounds wounds_pkey; Type: CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.wounds
    ADD CONSTRAINT wounds_pkey PRIMARY KEY (wound_id);


--
-- Name: idx_raw_badger_tattoo; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_badger_tattoo ON access_raw.tbl_badger USING btree (tattoo);


--
-- Name: idx_raw_bloodsampler_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_bloodsampler_badger ON access_raw.tbl_blood_sampler USING btree (tattoo);


--
-- Name: idx_raw_brock_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_brock_badger ON access_raw.tbl_brock_test USING btree (badger_id);


--
-- Name: idx_raw_capture_date; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_capture_date ON access_raw.tbl_captures USING btree (capture_date);


--
-- Name: idx_raw_capture_tattoo; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_capture_tattoo ON access_raw.tbl_captures USING btree (tattoo);


--
-- Name: idx_raw_culture_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_culture_badger ON access_raw.tbl_culture USING btree (tattoo);


--
-- Name: idx_raw_dpp_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_dpp_badger ON access_raw.tbl_dpp_test USING btree (badger_id);


--
-- Name: idx_raw_elisa_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_elisa_badger ON access_raw.tbl_elisa USING btree (tattoo);


--
-- Name: idx_raw_ifn_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_ifn_badger ON access_raw.tbl_ifn_gamma_elisa USING btree (badger_id);


--
-- Name: idx_raw_statpak_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_statpak_badger ON access_raw.tbl_stat_pak USING btree (badger_id);


--
-- Name: idx_raw_wounds_badger; Type: INDEX; Schema: access_raw; Owner: -
--

CREATE INDEX idx_raw_wounds_badger ON access_raw.tbl_wounds USING btree (tattoo);


--
-- Name: idx_brock_result; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_brock_result ON research.brock_tests USING btree (test_result);


--
-- Name: idx_captures_date; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_captures_date ON research.captures USING btree (capture_date);


--
-- Name: idx_captures_individual; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_captures_individual ON research.captures USING btree (individual_id);


--
-- Name: idx_captures_sett; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_captures_sett ON research.captures USING btree (sett_id);


--
-- Name: idx_captures_social_group; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_captures_social_group ON research.captures USING btree (recorded_social_group_id);


--
-- Name: idx_cultures_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_cultures_capture ON research.cultures USING btree (capture_id);


--
-- Name: idx_cultures_sample_type; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_cultures_sample_type ON research.cultures USING btree (sample_type);


--
-- Name: idx_dpp_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_dpp_capture ON research.dpp_tests USING btree (capture_id);


--
-- Name: idx_dpp_result; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_dpp_result ON research.dpp_tests USING btree (test_result);


--
-- Name: idx_elisa_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_elisa_capture ON research.elisa_tests USING btree (capture_id);


--
-- Name: idx_elisa_result; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_elisa_result ON research.elisa_tests USING btree (test_result);


--
-- Name: idx_ifn_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_ifn_capture ON research.ifn_gamma_elisa USING btree (capture_id);


--
-- Name: idx_ifn_date; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_ifn_date ON research.ifn_gamma_elisa USING btree (experiment_date);


--
-- Name: idx_ifn_result; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_ifn_result ON research.ifn_gamma_elisa USING btree (test_result);


--
-- Name: idx_infection_prob_date; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_infection_prob_date ON research.infection_probabilities USING btree (sample_date);


--
-- Name: idx_infection_prob_individual; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_infection_prob_individual ON research.infection_probabilities USING btree (individual_id);


--
-- Name: idx_infection_prob_variant; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_infection_prob_variant ON research.infection_probabilities USING btree (model_variant);


--
-- Name: idx_infquarter_date; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_infquarter_date ON research.infection_quarterly_probabilities USING btree (quarter_date);


--
-- Name: idx_infquarter_individual; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_infquarter_individual ON research.infection_quarterly_probabilities USING btree (individual_id);


--
-- Name: idx_infquarter_variant; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_infquarter_variant ON research.infection_quarterly_probabilities USING btree (model_variant);


--
-- Name: idx_sett_sg_history_sett; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_sett_sg_history_sett ON research.sett_social_group_links USING btree (sett_id);


--
-- Name: idx_sett_sg_history_social_group; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_sett_sg_history_social_group ON research.sett_social_group_links USING btree (social_group_id);


--
-- Name: idx_sg_supergroup_history_sg; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_sg_supergroup_history_sg ON research.social_group_supergroup_history USING btree (social_group_id);


--
-- Name: idx_statpak_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_statpak_capture ON research.stat_pak_tests USING btree (capture_id);


--
-- Name: idx_statpak_result; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_statpak_result ON research.stat_pak_tests USING btree (test_result);


--
-- Name: idx_wounds_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE INDEX idx_wounds_capture ON research.wounds USING btree (capture_id);


--
-- Name: sett_annual_territory_matches_year_sett_polygon_uq; Type: INDEX; Schema: research; Owner: -
--

CREATE UNIQUE INDEX sett_annual_territory_matches_year_sett_polygon_uq ON research.sett_annual_territory_matches USING btree (year, sett_id, polygon_id) NULLS NOT DISTINCT;


--
-- Name: uq_brock_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE UNIQUE INDEX uq_brock_capture ON research.brock_tests USING btree (capture_id);


--
-- Name: uq_culture_capture_sample; Type: INDEX; Schema: research; Owner: -
--

CREATE UNIQUE INDEX uq_culture_capture_sample ON research.cultures USING btree (capture_id, sample_type);


--
-- Name: uq_dpp_source_raw_row; Type: INDEX; Schema: research; Owner: -
--

CREATE UNIQUE INDEX uq_dpp_source_raw_row ON research.dpp_tests USING btree (source_raw_row_id);


--
-- Name: uq_elisa_capture_type; Type: INDEX; Schema: research; Owner: -
--

CREATE UNIQUE INDEX uq_elisa_capture_type ON research.elisa_tests USING btree (capture_id, elisa_type);


--
-- Name: uq_statpak_capture; Type: INDEX; Schema: research; Owner: -
--

CREATE UNIQUE INDEX uq_statpak_capture ON research.stat_pak_tests USING btree (capture_id);


--
-- Name: captures trg_capture_clean_names_v1; Type: TRIGGER; Schema: research; Owner: -
--

CREATE TRIGGER trg_capture_clean_names_v1 BEFORE INSERT OR UPDATE OF sett_id, recorded_social_group_id, sett_name_clean, social_group_name_clean ON research.captures FOR EACH ROW EXECUTE FUNCTION research.sync_capture_clean_names_v1();


--
-- Name: access_refresh_table_audits access_refresh_table_audits_batch_id_fkey; Type: FK CONSTRAINT; Schema: ingest; Owner: -
--

ALTER TABLE ONLY ingest.access_refresh_table_audits
    ADD CONSTRAINT access_refresh_table_audits_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES ingest.access_refresh_batches(batch_id);


--
-- Name: brock_tests brock_tests_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.brock_tests
    ADD CONSTRAINT brock_tests_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id) ON DELETE CASCADE;


--
-- Name: capture_grid_coordinate_decisions capture_grid_coordinate_decisions_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.capture_grid_coordinate_decisions
    ADD CONSTRAINT capture_grid_coordinate_decisions_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id);


--
-- Name: capture_sett_alias_decisions capture_sett_alias_decisions_canonical_sett_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.capture_sett_alias_decisions
    ADD CONSTRAINT capture_sett_alias_decisions_canonical_sett_id_fkey FOREIGN KEY (canonical_sett_id) REFERENCES research.setts(sett_id);


--
-- Name: capture_sett_alias_decisions capture_sett_alias_decisions_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.capture_sett_alias_decisions
    ADD CONSTRAINT capture_sett_alias_decisions_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id);


--
-- Name: captures captures_individual_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.captures
    ADD CONSTRAINT captures_individual_id_fkey FOREIGN KEY (individual_id) REFERENCES research.individuals(individual_id);


--
-- Name: captures captures_recorded_social_group_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.captures
    ADD CONSTRAINT captures_recorded_social_group_id_fkey FOREIGN KEY (recorded_social_group_id) REFERENCES research.social_groups(social_group_id);


--
-- Name: captures captures_sett_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.captures
    ADD CONSTRAINT captures_sett_id_fkey FOREIGN KEY (sett_id) REFERENCES research.setts(sett_id);


--
-- Name: cultures cultures_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.cultures
    ADD CONSTRAINT cultures_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id) ON DELETE CASCADE;


--
-- Name: dpp_tests dpp_tests_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.dpp_tests
    ADD CONSTRAINT dpp_tests_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id) ON DELETE CASCADE;


--
-- Name: elisa_tests elisa_tests_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.elisa_tests
    ADD CONSTRAINT elisa_tests_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id) ON DELETE CASCADE;


--
-- Name: encounter_classification_decisions encounter_classification_decisions_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_classification_decisions
    ADD CONSTRAINT encounter_classification_decisions_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id);


--
-- Name: encounter_episode_decisions encounter_episode_decisions_live_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_episode_decisions
    ADD CONSTRAINT encounter_episode_decisions_live_capture_id_fkey FOREIGN KEY (live_capture_id) REFERENCES research.captures(capture_id);


--
-- Name: encounter_episode_decisions encounter_episode_decisions_pm_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_episode_decisions
    ADD CONSTRAINT encounter_episode_decisions_pm_capture_id_fkey FOREIGN KEY (pm_capture_id) REFERENCES research.captures(capture_id);


--
-- Name: encounter_pair_nonlinks encounter_pair_nonlinks_first_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_pair_nonlinks
    ADD CONSTRAINT encounter_pair_nonlinks_first_capture_id_fkey FOREIGN KEY (first_capture_id) REFERENCES research.captures(capture_id);


--
-- Name: encounter_pair_nonlinks encounter_pair_nonlinks_second_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.encounter_pair_nonlinks
    ADD CONSTRAINT encounter_pair_nonlinks_second_capture_id_fkey FOREIGN KEY (second_capture_id) REFERENCES research.captures(capture_id);


--
-- Name: captures fk_captures_disease_status; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.captures
    ADD CONSTRAINT fk_captures_disease_status FOREIGN KEY (disease_status_id) REFERENCES research.disease_statuses(disease_status_id);


--
-- Name: ifn_gamma_elisa ifn_gamma_elisa_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.ifn_gamma_elisa
    ADD CONSTRAINT ifn_gamma_elisa_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id) ON DELETE CASCADE;


--
-- Name: infection_probabilities infection_probabilities_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.infection_probabilities
    ADD CONSTRAINT infection_probabilities_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id);


--
-- Name: infection_probabilities infection_probabilities_individual_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.infection_probabilities
    ADD CONSTRAINT infection_probabilities_individual_id_fkey FOREIGN KEY (individual_id) REFERENCES research.individuals(individual_id);


--
-- Name: infection_quarterly_probabilities infection_quarterly_probabilities_individual_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.infection_quarterly_probabilities
    ADD CONSTRAINT infection_quarterly_probabilities_individual_id_fkey FOREIGN KEY (individual_id) REFERENCES research.individuals(individual_id);


--
-- Name: sett_annual_territory_matches sett_annual_territory_matches_sett_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.sett_annual_territory_matches
    ADD CONSTRAINT sett_annual_territory_matches_sett_id_fkey FOREIGN KEY (sett_id) REFERENCES research.setts(sett_id);


--
-- Name: sett_social_group_links sett_social_group_history_sett_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.sett_social_group_links
    ADD CONSTRAINT sett_social_group_history_sett_id_fkey FOREIGN KEY (sett_id) REFERENCES research.setts(sett_id);


--
-- Name: sett_social_group_links sett_social_group_history_social_group_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.sett_social_group_links
    ADD CONSTRAINT sett_social_group_history_social_group_id_fkey FOREIGN KEY (social_group_id) REFERENCES research.social_groups(social_group_id);


--
-- Name: social_group_supergroup_history social_group_supergroup_history_social_group_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.social_group_supergroup_history
    ADD CONSTRAINT social_group_supergroup_history_social_group_id_fkey FOREIGN KEY (social_group_id) REFERENCES research.social_groups(social_group_id);


--
-- Name: social_group_supergroup_history social_group_supergroup_history_supergroup_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.social_group_supergroup_history
    ADD CONSTRAINT social_group_supergroup_history_supergroup_id_fkey FOREIGN KEY (supergroup_id) REFERENCES research.supergroups(supergroup_id);


--
-- Name: stat_pak_tests stat_pak_tests_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.stat_pak_tests
    ADD CONSTRAINT stat_pak_tests_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id) ON DELETE CASCADE;


--
-- Name: wounds wounds_capture_id_fkey; Type: FK CONSTRAINT; Schema: research; Owner: -
--

ALTER TABLE ONLY research.wounds
    ADD CONSTRAINT wounds_capture_id_fkey FOREIGN KEY (capture_id) REFERENCES research.captures(capture_id) ON DELETE CASCADE;


--
-- Name: social_groups; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.social_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_badger; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_badger ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_blood_sampler; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_blood_sampler ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_brock_test; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_brock_test ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_captures; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_captures ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_culture; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_culture ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_dpp_test; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_dpp_test ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_elisa; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_elisa ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_ifn_gamma_elisa; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_ifn_gamma_elisa ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_sett; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_sett ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_stat_pak; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_stat_pak ENABLE ROW LEVEL SECURITY;

--
-- Name: tbl_wounds; Type: ROW SECURITY; Schema: access_raw; Owner: -
--

ALTER TABLE access_raw.tbl_wounds ENABLE ROW LEVEL SECURITY;

--
-- Name: infection_probabilities_import; Type: ROW SECURITY; Schema: ingest; Owner: -
--

ALTER TABLE ingest.infection_probabilities_import ENABLE ROW LEVEL SECURITY;

--
-- Name: infection_quarterly_import; Type: ROW SECURITY; Schema: ingest; Owner: -
--

ALTER TABLE ingest.infection_quarterly_import ENABLE ROW LEVEL SECURITY;

--
-- Name: brock_tests badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.brock_tests FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: capture_grid_coordinate_decisions badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.capture_grid_coordinate_decisions FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: capture_sett_alias_decisions badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.capture_sett_alias_decisions FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: captures badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.captures FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: cultures badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.cultures FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: disease_statuses badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.disease_statuses FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: dpp_tests badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.dpp_tests FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: elisa_tests badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.elisa_tests FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: encounter_classification_decisions badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.encounter_classification_decisions FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: encounter_episode_decisions badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.encounter_episode_decisions FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: encounter_pair_nonlinks badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.encounter_pair_nonlinks FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: ifn_gamma_elisa badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.ifn_gamma_elisa FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: individuals badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.individuals FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: infection_probabilities badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.infection_probabilities FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: infection_quarterly_probabilities badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.infection_quarterly_probabilities FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: sett_social_group_links badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.sett_social_group_links FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: setts badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.setts FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: social_group_supergroup_history badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.social_group_supergroup_history FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: social_groups badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.social_groups FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: stat_pak_tests badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.stat_pak_tests FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: supergroups badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.supergroups FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: wecs_review_flags badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.wecs_review_flags FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: wounds badger_research_readonly_select; Type: POLICY; Schema: research; Owner: -
--

CREATE POLICY badger_research_readonly_select ON research.wounds FOR SELECT TO badger_research_readonly USING (true);


--
-- Name: brock_tests; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.brock_tests ENABLE ROW LEVEL SECURITY;

--
-- Name: capture_grid_coordinate_decisions; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.capture_grid_coordinate_decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: capture_sett_alias_decisions; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.capture_sett_alias_decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: captures; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.captures ENABLE ROW LEVEL SECURITY;

--
-- Name: cultures; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.cultures ENABLE ROW LEVEL SECURITY;

--
-- Name: disease_statuses; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.disease_statuses ENABLE ROW LEVEL SECURITY;

--
-- Name: dpp_tests; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.dpp_tests ENABLE ROW LEVEL SECURITY;

--
-- Name: elisa_tests; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.elisa_tests ENABLE ROW LEVEL SECURITY;

--
-- Name: encounter_classification_decisions; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.encounter_classification_decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: encounter_episode_decisions; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.encounter_episode_decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: encounter_pair_nonlinks; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.encounter_pair_nonlinks ENABLE ROW LEVEL SECURITY;

--
-- Name: ifn_gamma_elisa; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.ifn_gamma_elisa ENABLE ROW LEVEL SECURITY;

--
-- Name: individuals; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.individuals ENABLE ROW LEVEL SECURITY;

--
-- Name: infection_probabilities; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.infection_probabilities ENABLE ROW LEVEL SECURITY;

--
-- Name: infection_quarterly_probabilities; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.infection_quarterly_probabilities ENABLE ROW LEVEL SECURITY;

--
-- Name: sett_social_group_links; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.sett_social_group_links ENABLE ROW LEVEL SECURITY;

--
-- Name: setts; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.setts ENABLE ROW LEVEL SECURITY;

--
-- Name: social_group_supergroup_history; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.social_group_supergroup_history ENABLE ROW LEVEL SECURITY;

--
-- Name: social_groups; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.social_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: stat_pak_tests; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.stat_pak_tests ENABLE ROW LEVEL SECURITY;

--
-- Name: supergroups; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.supergroups ENABLE ROW LEVEL SECURITY;

--
-- Name: wecs_review_flags; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.wecs_review_flags ENABLE ROW LEVEL SECURITY;

--
-- Name: wounds; Type: ROW SECURITY; Schema: research; Owner: -
--

ALTER TABLE research.wounds ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict PgZwMGaT8cV8faDSMnVhjoAqTHzK8A4ViMH8YYyCDGUW8BKTya44U7DXtFUkAn9


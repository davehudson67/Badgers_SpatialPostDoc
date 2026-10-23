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

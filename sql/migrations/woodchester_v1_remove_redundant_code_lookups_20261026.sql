-- V1 minimal research cleanup. Code lists are documented in V1 cleaning audit.
-- DPP samples: Serum Fresh; WB Field; Whole Blood; Serum Frozen.
-- DPP line: N=Negative; Nx=NegativeX; P=Positive; Px=PositiveX.
-- Stat-Pak: N=Negative (1); P=Positive (2); C=No Clotted Sample (3).
-- Verified: no foreign keys, dependent views or other PostgreSQL dependencies.
drop table research.dpp_sample_types;
drop table research.dpp_visual_line_results;
drop table research.stat_pak_results;

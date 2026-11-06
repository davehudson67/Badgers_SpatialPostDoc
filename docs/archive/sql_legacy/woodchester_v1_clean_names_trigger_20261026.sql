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

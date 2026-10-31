-- Love 21 starter schema (PostgreSQL / Supabase).
-- Initial Love 21 schema. Review security policies before production deployment.
create extension if not exists pgcrypto;

create table if not exists public.love21_config (
  singleton boolean primary key default true check (singleton),
  minimum_age smallint not null default 18 check (minimum_age >= 18),
  challenge_days smallint not null default 21 check (challenge_days = 21),
  reveal_days smallint not null default 14 check (reveal_days = 14),
  challenge_timezone text not null default 'Asia/Kolkata'
);
insert into public.love21_config(singleton) values (true) on conflict do nothing;
update public.love21_config set minimum_age = 18 where singleton;
alter table public.love21_config enable row level security;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  birth_date date not null,
  gender text not null check (gender in ('Man', 'Woman')),
  dating_preferences text[] not null default '{}',
  short_bio text not null default '',
  interests text[] not null default '{}',
  profile_photo_path text,
  age_eligible boolean not null default false,
  age_checked_at timestamptz,
  identity_status text not null default 'pending' check (identity_status in ('pending', 'verified', 'failed', 'review')),
  account_status text not null default 'active' check (account_status in ('active', 'suspended', 'deletion_requested')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.create_love21_profile()
returns trigger language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_min_age int; v_birth date; v_age int;
begin
  v_birth := (new.raw_user_meta_data->>'birth_date')::date;
  select minimum_age into v_min_age from public.love21_config where singleton;
  v_age := date_part('year', age(current_date, v_birth));
  insert into public.profiles(id, full_name, birth_date, gender)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    v_birth,
    coalesce(new.raw_user_meta_data->>'gender', 'Man')
  )
  on conflict (id) do nothing;
  update public.profiles set age_eligible = (v_age >= v_min_age), age_checked_at = now() where id = new.id;
  return new;
end;
$$;
drop trigger if exists love21_auth_user_created on auth.users;
create trigger love21_auth_user_created after insert on auth.users
for each row execute function public.create_love21_profile();

create or replace function public.protect_profile_gates()
returns trigger language plpgsql set search_path = public, auth, pg_temp as $$
begin
  if current_user in ('anon', 'authenticated') and (
    new.birth_date is distinct from old.birth_date or
    new.age_eligible is distinct from old.age_eligible or
    new.age_checked_at is distinct from old.age_checked_at or
    new.identity_status is distinct from old.identity_status or
    new.account_status is distinct from old.account_status
  ) then
    raise exception 'Eligibility and verification fields are server managed';
  end if;
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists love21_protect_profile_gates on public.profiles;
create trigger love21_protect_profile_gates before update on public.profiles
for each row execute function public.protect_profile_gates();

create table if not exists public.challenge_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  challenge_day smallint not null check (challenge_day between 1 and 21),
  attempt smallint not null check (attempt > 0),
  photo_path text not null,
  caption text not null default '',
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected')),
  reviewer_note text,
  submitted_at timestamptz not null default now(),
  submitted_on date not null,
  reviewed_at timestamptz,
  unique(user_id, challenge_day, attempt)
);
create index if not exists challenge_submissions_progress_idx
  on public.challenge_submissions(user_id, status, challenge_day);
create unique index if not exists one_counting_submission_per_local_day
  on public.challenge_submissions(user_id, submitted_on)
  where status in ('pending', 'verified');
create table if not exists public.submission_appeals (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null unique references public.challenge_submissions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 1000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved')),
  created_at timestamptz not null default now()
);

create table if not exists public.interest_actions (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  action text not null check (action in ('interested', 'not_for_me', 'view_later')),
  prompt_comment text,
  created_at timestamptz not null default now(),
  primary key(actor_id, target_id),
  check (actor_id <> target_id)
);

create table if not exists public.connections (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  matched_at timestamptz not null default now(),
  unmatched_at timestamptz,
  created_at timestamptz not null default now(),
  check (user_a < user_b),
  unique(user_a, user_b)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.connections(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists messages_connection_time_idx on public.messages(connection_id, created_at);

create table if not exists public.photo_reveal_consents (
  connection_id uuid not null references public.connections(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  consented boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key(connection_id, user_id)
);

create table if not exists public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create table if not exists public.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  details text not null default '',
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id)
);
create table if not exists public.account_deletion_requests (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  status text not null default 'requested' check (status in ('requested', 'processing', 'completed', 'cancelled'))
);
create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  notifications_enabled boolean not null default true,
  profile_visible boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.challenge_submissions enable row level security;
alter table public.submission_appeals enable row level security;
alter table public.interest_actions enable row level security;
alter table public.connections enable row level security;
alter table public.messages enable row level security;
alter table public.photo_reveal_consents enable row level security;
alter table public.blocked_users enable row level security;
alter table public.safety_reports enable row level security;
alter table public.account_deletion_requests enable row level security;
alter table public.user_settings enable row level security;

create policy profile_read_self on public.profiles for select to authenticated using (id = auth.uid());
create policy profile_update_self on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy submissions_read_self on public.challenge_submissions for select to authenticated using (user_id = auth.uid());
create policy appeals_read_self on public.submission_appeals for select to authenticated using (user_id = auth.uid());
create policy interest_read_self on public.interest_actions for select to authenticated using (actor_id = auth.uid());
create policy connections_read_member on public.connections for select to authenticated using (auth.uid() in (user_a, user_b));
create policy messages_read_member on public.messages for select to authenticated using (
  exists(select 1 from public.connections c where c.id = connection_id and auth.uid() in (c.user_a, c.user_b) and c.unmatched_at is null)
);
create policy reveal_read_self on public.photo_reveal_consents for select to authenticated using (user_id = auth.uid());
create policy block_read_self on public.blocked_users for select to authenticated using (blocker_id = auth.uid());
create policy report_read_own on public.safety_reports for select to authenticated using (reporter_id = auth.uid());
create policy deletion_read_self on public.account_deletion_requests for select to authenticated using (user_id = auth.uid());
create policy settings_read_self on public.user_settings for select to authenticated using (user_id = auth.uid());
create policy settings_insert_self on public.user_settings for insert to authenticated with check (user_id = auth.uid());
create policy settings_update_self on public.user_settings for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, update on public.profiles to authenticated;
grant select on public.challenge_submissions, public.submission_appeals, public.interest_actions, public.connections,
  public.messages, public.photo_reveal_consents, public.blocked_users,
  public.safety_reports, public.account_deletion_requests to authenticated;
grant select, insert, update on public.user_settings to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('private-challenge-photos', 'private-challenge-photos', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
create policy challenge_photo_owner_insert on storage.objects for insert to authenticated
with check (bucket_id = 'private-challenge-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy challenge_photo_owner_select on storage.objects for select to authenticated
using (bucket_id = 'private-challenge-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function public.check_my_age_eligibility()
returns boolean language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_birth date; v_min_age int; v_age int; v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select birth_date into v_birth from public.profiles where id = v_uid;
  select minimum_age into v_min_age from public.love21_config where singleton;
  if v_birth is null then return false; end if;
  v_age := date_part('year', age(current_date, v_birth));
  update public.profiles set age_eligible = (v_age >= v_min_age), age_checked_at = now() where id = v_uid;
  return v_age >= v_min_age;
end;
$$;

-- Called before sign-up so the user receives the age outcome immediately.
-- The birth date is evaluated in the database and is not stored by this function.
create or replace function public.check_age_for_registration(p_birth_date date)
returns boolean language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare v_min_age int;
begin
  if p_birth_date is null or p_birth_date > current_date then return false; end if;
  select minimum_age into v_min_age from public.love21_config where singleton;
  return date_part('year', age(current_date, p_birth_date)) >= v_min_age;
end;
$$;

create or replace function public.my_verified_day_count()
returns integer language sql stable security definer set search_path = public, auth, pg_temp as $$
  select count(distinct challenge_day)::integer
  from public.challenge_submissions
  where user_id = auth.uid() and status = 'verified'
$$;

create or replace function public.my_challenge_eligibility()
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select coalesce((
    select p.age_eligible and p.identity_status = 'verified' and p.account_status = 'active'
      and exists(select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
    from public.profiles p where p.id = auth.uid()
  ), false)
$$;

create or replace function public.my_discovery_eligibility()
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select coalesce((
    select p.age_eligible and p.identity_status = 'verified' and p.account_status = 'active'
      and exists(select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
      and (select count(distinct s.challenge_day) from public.challenge_submissions s where s.user_id = p.id and s.status = 'verified') >= cfg.challenge_days
    from public.profiles p cross join public.love21_config cfg
    where p.id = auth.uid() and cfg.singleton
  ), false)
$$;

create or replace function public.submit_challenge_day(p_challenge_day smallint, p_photo_path text, p_caption text)
returns uuid language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_uid uuid := auth.uid(); v_attempt smallint; v_id uuid; v_next_day smallint; v_local_day date; v_zone text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not public.my_challenge_eligibility() then
    raise exception 'Verified contact, age, identity, and active account required';
  end if;
  if p_challenge_day < 1 or p_challenge_day > 21 then raise exception 'Invalid challenge day'; end if;
  select (count(distinct challenge_day) + 1)::smallint into v_next_day
    from public.challenge_submissions where user_id = v_uid and status = 'verified';
  if p_challenge_day <> v_next_day then raise exception 'Submit the next unverified challenge day'; end if;
  select challenge_timezone into v_zone from public.love21_config where singleton;
  v_local_day := timezone(v_zone, now())::date;
  if exists(select 1 from public.challenge_submissions where user_id = v_uid and submitted_on = v_local_day and status in ('pending', 'verified')) then
    raise exception 'One challenge activity is allowed per local calendar day';
  end if;
  if p_photo_path is null or split_part(p_photo_path, '/', 1) <> v_uid::text then raise exception 'Invalid private photo path'; end if;
  if exists(select 1 from public.challenge_submissions where user_id = v_uid and challenge_day = p_challenge_day and status = 'verified') then
    raise exception 'This challenge day is already verified';
  end if;
  if exists(select 1 from public.challenge_submissions where user_id = v_uid and challenge_day = p_challenge_day and status = 'pending') then
    raise exception 'A submission for this day is already pending';
  end if;
  select coalesce(max(attempt), 0) + 1 into v_attempt from public.challenge_submissions where user_id = v_uid and challenge_day = p_challenge_day;
  insert into public.challenge_submissions(user_id, challenge_day, attempt, photo_path, caption, submitted_on)
  values(v_uid, p_challenge_day, v_attempt, p_photo_path, left(coalesce(p_caption, ''), 140), v_local_day)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.appeal_challenge_submission(p_submission_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.challenge_submissions where id = p_submission_id and user_id = auth.uid() and status = 'rejected') then
    raise exception 'Only your rejected submission can be appealed';
  end if;
  insert into public.submission_appeals(submission_id, user_id, reason)
  values(p_submission_id, auth.uid(), left(trim(coalesce(p_reason, '')), 1000))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.submit_interest(p_target_user_id uuid, p_prompt_comment text default null)
returns uuid language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_uid uuid := auth.uid(); v_me public.profiles%rowtype; v_target public.profiles%rowtype; v_connection uuid; v_a uuid; v_b uuid;
begin
  if v_uid is null or v_uid = p_target_user_id then raise exception 'Invalid target'; end if;
  if not public.my_discovery_eligibility() then raise exception 'Discovery eligibility required'; end if;
  select * into v_me from public.profiles where id = v_uid;
  select * into v_target from public.profiles where id = p_target_user_id and account_status = 'active';
  if v_target.id is null then raise exception 'Profile unavailable'; end if;
  if not v_target.age_eligible or v_target.identity_status <> 'verified' then raise exception 'Target is not eligible'; end if;
  if not exists(select 1 from auth.users u where u.id = p_target_user_id and u.email_confirmed_at is not null)
    or (select count(distinct s.challenge_day) from public.challenge_submissions s where s.user_id = p_target_user_id and s.status = 'verified')
      < (select challenge_days from public.love21_config where singleton) then
    raise exception 'Target is not discovery eligible';
  end if;
  if not (v_me.dating_preferences @> array[v_target.gender]) or not (v_target.dating_preferences @> array[v_me.gender]) then
    raise exception 'Dating preferences do not allow this connection';
  end if;
  if exists(select 1 from public.blocked_users b where (b.blocker_id = v_uid and b.blocked_id = p_target_user_id) or (b.blocker_id = p_target_user_id and b.blocked_id = v_uid)) then
    raise exception 'Connection unavailable';
  end if;
  insert into public.interest_actions(actor_id, target_id, action, prompt_comment)
  values(v_uid, p_target_user_id, 'interested', left(coalesce(p_prompt_comment, ''), 240))
  on conflict(actor_id, target_id) do update set action = excluded.action, prompt_comment = excluded.prompt_comment, created_at = now();
  if exists(select 1 from public.interest_actions where actor_id = p_target_user_id and target_id = v_uid and action = 'interested') then
    v_a := least(v_uid, p_target_user_id); v_b := greatest(v_uid, p_target_user_id);
    insert into public.connections(user_a, user_b) values(v_a, v_b)
    on conflict(user_a, user_b) do update set unmatched_at = null
    returning id into v_connection;
    return v_connection;
  end if;
  return null;
end;
$$;

create or replace function public.get_discovery_candidates()
returns table(candidate_id uuid, age integer, gender text, short_bio text, interests text[])
language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare v_me public.profiles%rowtype;
begin
  if not public.my_discovery_eligibility() then raise exception 'Discovery eligibility required'; end if;
  select * into v_me from public.profiles where id = auth.uid();
  return query
    select p.id,
      date_part('year', age(current_date, p.birth_date))::integer,
      p.gender,
      p.short_bio,
      p.interests
    from public.profiles p
    where p.id <> auth.uid()
      and p.age_eligible
      and p.identity_status = 'verified'
      and p.account_status = 'active'
      and p.dating_preferences @> array[v_me.gender]
      and v_me.dating_preferences @> array[p.gender]
      and (select count(distinct s.challenge_day) from public.challenge_submissions s where s.user_id = p.id and s.status = 'verified')
        >= (select challenge_days from public.love21_config where singleton)
      and exists(select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
      and coalesce((select us.profile_visible from public.user_settings us where us.user_id = p.id), true)
      and not exists(select 1 from public.interest_actions ia where ia.actor_id = auth.uid() and ia.target_id = p.id and ia.action in ('interested', 'not_for_me'))
      and not exists(select 1 from public.blocked_users b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    order by p.created_at
    limit 20;
end;
$$;

create or replace function public.record_discovery_action(p_target_user_id uuid, p_action text)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_me public.profiles%rowtype; v_target public.profiles%rowtype;
begin
  if auth.uid() is null or p_target_user_id = auth.uid() then raise exception 'Invalid target'; end if;
  if not public.my_discovery_eligibility() then raise exception 'Discovery eligibility required'; end if;
  if p_action not in ('not_for_me', 'view_later') then raise exception 'Unsupported action'; end if;
  select * into v_me from public.profiles where id = auth.uid();
  select * into v_target from public.profiles where id = p_target_user_id and account_status = 'active';
  if v_target.id is null or not v_target.age_eligible or v_target.identity_status <> 'verified'
    or not (v_me.dating_preferences @> array[v_target.gender])
    or not (v_target.dating_preferences @> array[v_me.gender]) then
    raise exception 'Target is not discovery eligible';
  end if;
  if (select count(distinct s.challenge_day) from public.challenge_submissions s where s.user_id = p_target_user_id and s.status = 'verified')
      < (select challenge_days from public.love21_config where singleton) then
    raise exception 'Target is not discovery eligible';
  end if;
  insert into public.interest_actions(actor_id, target_id, action)
  values(auth.uid(), p_target_user_id, p_action)
  on conflict(actor_id, target_id) do update set action = excluded.action, created_at = now();
end;
$$;

create or replace function public.send_connection_message(p_connection_id uuid, p_message text)
returns uuid language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(trim(coalesce(p_message, ''))) not between 1 and 2000 then raise exception 'Message must be 1 to 2000 characters'; end if;
  if not exists(select 1 from public.connections c where c.id = p_connection_id and auth.uid() in (c.user_a, c.user_b) and c.unmatched_at is null) then
    raise exception 'Connection unavailable';
  end if;
  insert into public.messages(connection_id, sender_id, body) values(p_connection_id, auth.uid(), trim(p_message)) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.set_photo_reveal_consent(p_connection_id uuid, p_consented boolean)
returns boolean language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_both boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.connections c where c.id = p_connection_id and auth.uid() in (c.user_a, c.user_b) and c.unmatched_at is null and now() >= c.matched_at + interval '14 days') then
    raise exception 'Photo reveal is not available';
  end if;
  insert into public.photo_reveal_consents(connection_id, user_id, consented)
  values(p_connection_id, auth.uid(), p_consented)
  on conflict(connection_id, user_id) do update set consented = excluded.consented, updated_at = now();
  select count(*) = 2 into v_both from public.photo_reveal_consents where connection_id = p_connection_id and consented;
  return coalesce(v_both, false);
end;
$$;

create or replace function public.request_account_deletion()
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.account_deletion_requests(user_id) values(auth.uid()) on conflict(user_id) do update set requested_at = now(), status = 'requested';
  update public.profiles set account_status = 'deletion_requested' where id = auth.uid();
end;
$$;

create or replace function public.block_user(p_blocked_user_id uuid)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if auth.uid() is null or p_blocked_user_id = auth.uid() then raise exception 'Invalid target'; end if;
  if not exists(select 1 from public.profiles where id = p_blocked_user_id) then raise exception 'Profile unavailable'; end if;
  insert into public.blocked_users(blocker_id, blocked_id) values(auth.uid(), p_blocked_user_id) on conflict do nothing;
  update public.connections set unmatched_at = coalesce(unmatched_at, now())
    where unmatched_at is null and ((user_a = auth.uid() and user_b = p_blocked_user_id) or (user_b = auth.uid() and user_a = p_blocked_user_id));
end;
$$;

create or replace function public.report_user(p_reported_user_id uuid, p_category text, p_details text default '')
returns uuid language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare v_id uuid;
begin
  if auth.uid() is null or p_reported_user_id = auth.uid() then raise exception 'Invalid target'; end if;
  if not exists(select 1 from public.profiles where id = p_reported_user_id) then raise exception 'Profile unavailable'; end if;
  if char_length(trim(coalesce(p_category, ''))) not between 1 and 80 then raise exception 'Choose a report category'; end if;
  insert into public.safety_reports(reporter_id, reported_id, category, details)
  values(auth.uid(), p_reported_user_id, left(trim(p_category), 80), left(coalesce(p_details, ''), 2000))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.unmatch_connection(p_connection_id uuid)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.connections set unmatched_at = coalesce(unmatched_at, now())
    where id = p_connection_id and auth.uid() in (user_a, user_b);
  if not found then raise exception 'Connection unavailable'; end if;
end;
$$;

create or replace function public.update_my_settings(p_notifications_enabled boolean, p_profile_visible boolean)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.user_settings(user_id, notifications_enabled, profile_visible)
  values(auth.uid(), p_notifications_enabled, p_profile_visible)
  on conflict(user_id) do update set notifications_enabled = excluded.notifications_enabled,
    profile_visible = excluded.profile_visible, updated_at = now();
end;
$$;

revoke all on function public.check_my_age_eligibility() from public, anon;
revoke all on function public.check_age_for_registration(date) from public;
revoke all on function public.my_verified_day_count() from public, anon;
revoke all on function public.my_challenge_eligibility() from public, anon;
revoke all on function public.my_discovery_eligibility() from public, anon;
revoke all on function public.submit_challenge_day(smallint, text, text) from public, anon;
revoke all on function public.appeal_challenge_submission(uuid, text) from public, anon;
revoke all on function public.submit_interest(uuid, text) from public, anon;
revoke all on function public.get_discovery_candidates() from public, anon;
revoke all on function public.record_discovery_action(uuid, text) from public, anon;
revoke all on function public.send_connection_message(uuid, text) from public, anon;
revoke all on function public.set_photo_reveal_consent(uuid, boolean) from public, anon;
revoke all on function public.request_account_deletion() from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.report_user(uuid, text, text) from public, anon;
revoke all on function public.unmatch_connection(uuid) from public, anon;
revoke all on function public.update_my_settings(boolean, boolean) from public, anon;
grant execute on function public.check_my_age_eligibility() to authenticated;
grant execute on function public.check_age_for_registration(date) to anon, authenticated;
grant execute on function public.my_verified_day_count() to authenticated;
grant execute on function public.my_challenge_eligibility() to authenticated;
grant execute on function public.my_discovery_eligibility() to authenticated;
grant execute on function public.submit_challenge_day(smallint, text, text) to authenticated;
grant execute on function public.appeal_challenge_submission(uuid, text) to authenticated;
grant execute on function public.submit_interest(uuid, text) to authenticated;
grant execute on function public.get_discovery_candidates() to authenticated;
grant execute on function public.record_discovery_action(uuid, text) to authenticated;
grant execute on function public.send_connection_message(uuid, text) to authenticated;
grant execute on function public.set_photo_reveal_consent(uuid, boolean) to authenticated;
grant execute on function public.request_account_deletion() to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.report_user(uuid, text, text) to authenticated;
grant execute on function public.unmatch_connection(uuid) to authenticated;
grant execute on function public.update_my_settings(boolean, boolean) to authenticated;

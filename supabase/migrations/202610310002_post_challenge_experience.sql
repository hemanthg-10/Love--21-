-- Secure profile image storage and backend-derived photo reveal state.
insert into storage.buckets(id, name, public)
values ('private-profile-photos', 'private-profile-photos', false)
on conflict (id) do update set public = false;

create or replace function public.photo_reveal_is_confirmed(p_connection_id uuid)
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select auth.uid() is not null
    and exists(select 1 from public.connections c where c.id = p_connection_id
      and auth.uid() in (c.user_a, c.user_b) and c.unmatched_at is null
      and now() >= c.matched_at + interval '14 days'
      and (select count(*) = 2 from public.photo_reveal_consents x where x.connection_id = c.id and x.consented))
$$;
revoke all on function public.photo_reveal_is_confirmed(uuid) from public, anon;
grant execute on function public.photo_reveal_is_confirmed(uuid) to authenticated;

drop policy if exists love21_profile_photo_read_owner on storage.objects;
create policy love21_profile_photo_read_owner on storage.objects
for select to authenticated using (
  bucket_id = 'private-profile-photos' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1 from public.connections c
      where c.unmatched_at is null and auth.uid() in (c.user_a, c.user_b)
        and (storage.foldername(name))[1] = case when c.user_a = auth.uid() then c.user_b::text else c.user_a::text end
        and public.photo_reveal_is_confirmed(c.id)
    )
  )
);
drop policy if exists love21_profile_photo_insert_owner on storage.objects;
create policy love21_profile_photo_insert_owner on storage.objects
for insert to authenticated with check (
  bucket_id = 'private-profile-photos' and (storage.foldername(name))[1] = auth.uid()::text
);
drop policy if exists love21_profile_photo_delete_owner on storage.objects;
create policy love21_profile_photo_delete_owner on storage.objects
for delete to authenticated using (
  bucket_id = 'private-profile-photos' and (storage.foldername(name))[1] = auth.uid()::text
);

create or replace function public.my_photo_reveal_status(p_connection_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare
  v_connection public.connections%rowtype;
  v_me boolean := false;
  v_other boolean := false;
  v_eligible_at timestamptz;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_connection from public.connections c
  where c.id = p_connection_id and auth.uid() in (c.user_a, c.user_b) and c.unmatched_at is null;
  if v_connection.id is null then raise exception 'Connection unavailable'; end if;
  v_eligible_at := v_connection.matched_at + interval '14 days';
  select coalesce(bool_or(consented) filter (where user_id = auth.uid()), false),
         coalesce(bool_or(consented) filter (where user_id <> auth.uid()), false)
    into v_me, v_other
    from public.photo_reveal_consents where connection_id = p_connection_id;
  return jsonb_build_object(
    'eligible_at', v_eligible_at,
    'eligible', now() >= v_eligible_at,
    'my_consented', v_me,
    'other_consented', v_other,
    'both_consented', v_me and v_other
  );
end;
$$;
revoke all on function public.my_photo_reveal_status(uuid) from public, anon;
grant execute on function public.my_photo_reveal_status(uuid) to authenticated;

create or replace function public.my_revealed_partner_photo_path(p_connection_id uuid)
returns text language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare v_path text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select p.profile_photo_path into v_path
  from public.connections c
  join public.profiles p on p.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  where c.id = p_connection_id and c.unmatched_at is null
    and auth.uid() in (c.user_a, c.user_b)
    and now() >= c.matched_at + interval '14 days'
    and (select count(*) = 2 from public.photo_reveal_consents x where x.connection_id = c.id and x.consented);
  return v_path;
end;
$$;
revoke all on function public.my_revealed_partner_photo_path(uuid) from public, anon;
grant execute on function public.my_revealed_partner_photo_path(uuid) to authenticated;

create or replace function public.get_discovery_candidates_page(p_offset integer default 0, p_limit integer default 20)
returns table(candidate_id uuid, age integer, gender text, short_bio text, interests text[])
language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare v_me public.profiles%rowtype;
begin
  if auth.uid() is null or not public.my_discovery_eligibility() then raise exception 'Discovery eligibility required'; end if;
  select * into v_me from public.profiles where id = auth.uid();
  return query
    select p.id, date_part('year', age(current_date, p.birth_date))::integer, p.gender, p.short_bio, p.interests
    from public.profiles p
    where p.id <> auth.uid() and p.age_eligible and p.identity_status = 'verified'
      and p.account_status = 'active' and p.dating_preferences @> array[v_me.gender]
      and v_me.dating_preferences @> array[p.gender]
      and (select count(distinct s.challenge_day) from public.challenge_submissions s where s.user_id = p.id and s.status = 'verified') >= (select challenge_days from public.love21_config where singleton)
      and exists(select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
      and coalesce((select us.profile_visible from public.user_settings us where us.user_id = p.id), true)
      and not exists(select 1 from public.interest_actions ia where ia.actor_id = auth.uid() and ia.target_id = p.id and ia.action in ('interested', 'not_for_me', 'view_later'))
      and not exists(select 1 from public.blocked_users b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    order by p.created_at
    offset greatest(p_offset, 0) limit least(greatest(p_limit, 1), 50);
end;
$$;

create or replace function public.my_saved_discovery_profiles()
returns table(candidate_id uuid, age integer, gender text, short_bio text, interests text[])
language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare v_me public.profiles%rowtype;
begin
  if auth.uid() is null or not public.my_discovery_eligibility() then raise exception 'Discovery eligibility required'; end if;
  select * into v_me from public.profiles where id = auth.uid();
  return query
    select p.id, date_part('year', age(current_date, p.birth_date))::integer, p.gender, p.short_bio, p.interests
    from public.interest_actions ia join public.profiles p on p.id = ia.target_id
    where ia.actor_id = auth.uid() and ia.action = 'view_later' and p.account_status = 'active'
      and p.age_eligible and p.identity_status = 'verified'
      and p.dating_preferences @> array[v_me.gender] and v_me.dating_preferences @> array[p.gender]
      and (select count(distinct s.challenge_day) from public.challenge_submissions s where s.user_id = p.id and s.status = 'verified') >= (select challenge_days from public.love21_config where singleton)
      and exists(select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
      and coalesce((select us.profile_visible from public.user_settings us where us.user_id = p.id), true)
      and not exists(select 1 from public.blocked_users b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    order by ia.created_at desc;
end;
$$;

create or replace function public.my_connection_previews()
returns table(id uuid, matched_at timestamptz, age integer, gender text, short_bio text, interests text[])
language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return query
    select c.id, c.matched_at,
      date_part('year', age(current_date, p.birth_date))::integer,
      p.gender, p.short_bio, p.interests
    from public.connections c
    join public.profiles p on p.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
    where auth.uid() in (c.user_a, c.user_b) and c.unmatched_at is null
    order by c.matched_at desc;
end;
$$;
revoke all on function public.get_discovery_candidates_page(integer, integer), public.my_saved_discovery_profiles(), public.my_connection_previews() from public, anon;
grant execute on function public.get_discovery_candidates_page(integer, integer), public.my_saved_discovery_profiles(), public.my_connection_previews() to authenticated;

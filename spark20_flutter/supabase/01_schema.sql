-- Spark20 schema. Run in Supabase SQL editor (whole file).
create extension if not exists pgcrypto;

create table spark20_admins(user_id uuid primary key references auth.users(id) on delete cascade);

create table spark20_business_settings(
  id int primary key default 1 check (id=1),
  brand text not null default 'Spark20',
  currency text not null default 'INR',
  payment_mode text not null default 'disabled' check (payment_mode = 'disabled'),
  intro_price_paise int not null default 2049,
  reply_reward_paise int not null default 500,
  reward_enabled boolean not null default true,
  min_qualifying_chars int not null default 20,
  reply_window_hours int not null default 72,
  reward_pending_days int not null default 7,
  minimum_withdrawal_paise int not null default 10000 check (minimum_withdrawal_paise >= 10000),
  cashouts_enabled boolean not null default false
);
insert into spark20_business_settings default values on conflict do nothing;

create table spark20_profiles(
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 40),
  age int not null check (age between 18 and 110),
  age_confirmed boolean not null check (age_confirmed),
  city text not null check (char_length(city) between 2 and 80),
  location_consent boolean not null check (location_consent),
  latitude double precision,
  longitude double precision,
  location_enabled boolean not null default false,
  height_cm int check (height_cm between 100 and 250),
  bio text not null default '' check (char_length(bio)<=500),
  gender_identity text not null,
  gender_identity_custom text check (char_length(gender_identity_custom)<=40),
  show_in_feed_genders text[] not null check (cardinality(show_in_feed_genders)>=1),
  interests text[] not null default '{}' check (cardinality(interests) between 3 and 12),
  relationship_goals text[] not null check (cardinality(relationship_goals)=1),
  min_age_preference int not null default 18,
  max_age_preference int not null default 80,
  min_height_preference_cm int not null default 100,
  max_height_preference_cm int not null default 250,
  photo_urls text[] not null default '{}' check (cardinality(photo_urls)<=6),
  visible boolean not null default true,
  suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (min_age_preference <= max_age_preference),
  check (min_height_preference_cm between 100 and 250 and min_height_preference_cm <= max_height_preference_cm),
  check ((latitude is null) = (longitude is null)),
  check (not location_enabled or latitude is not null),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);
create index on spark20_profiles(visible, city);

create table spark20_likes(
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null references spark20_profiles(id) on delete cascade,
  to_id uuid not null references spark20_profiles(id) on delete cascade,
  action text not null check (action in ('like','pass')),
  created_at timestamptz not null default now(),
  unique(from_id,to_id)
);
create table spark20_matches(
  id uuid primary key default gen_random_uuid(),
  profile_a uuid not null references spark20_profiles(id) on delete cascade,
  profile_b uuid not null references spark20_profiles(id) on delete cascade,
  active boolean not null default true,
  last_read_at_a timestamptz, last_read_at_b timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  unique(profile_a,profile_b), check (profile_a < profile_b)
);
create table spark20_chat_messages(
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references spark20_matches(id) on delete cascade,
  sender_id uuid not null references spark20_profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index on spark20_chat_messages(match_id, created_at);

create table spark20_introductions(
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references spark20_profiles(id) on delete cascade,
  recipient_id uuid not null references spark20_profiles(id) on delete cascade,
  content text not null,
  status text not null default 'pending_payment' check (status in
   ('pending_payment','payment_pending','payment_failed','cancelled','paid','accepted','declined','ignored','replied','blocked','reported')),
  price_paise int not null,
  idempotency_key text not null,
  payment_idempotency_key text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique(sender_id, idempotency_key)
);
create table spark20_introduction_replies(
  id uuid primary key default gen_random_uuid(),
  introduction_id uuid not null references spark20_introductions(id) on delete cascade,
  sender_id uuid not null references spark20_profiles(id) on delete cascade,
  content text not null,
  qualifies_for_reward boolean not null default false,
  created_at timestamptz not null default now()
);
create table spark20_ledger_entries(
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references spark20_profiles(id) on delete set null,
  introduction_id uuid references spark20_introductions(id) on delete set null,
  kind text not null check (kind in ('intro_charge','reward_pending','reward_pending_reversed','reward_available','reward_reversed','reward_disputed')),
  amount_paise int not null,
  status text not null,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);
create table spark20_blocks(
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references spark20_profiles(id) on delete cascade,
  blocked_id uuid not null references spark20_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(blocker_id,blocked_id)
);
create table spark20_reports(
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references spark20_profiles(id) on delete cascade,
  target_id uuid not null references spark20_profiles(id) on delete cascade,
  related_intro_id uuid references spark20_introductions(id) on delete set null,
  category text not null check (category in ('harassment','scam','threats','impersonation','explicit_content','underage_concern','other')),
  details text not null default '',
  status text not null default 'open' check (status in ('open','dismissed','actioned','needs_followup')),
  reviewed_by uuid, notes text, reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create table spark20_moderation_actions(
  id uuid primary key default gen_random_uuid(),
  report_id uuid references spark20_reports(id) on delete set null,
  target_id uuid references spark20_profiles(id) on delete set null,
  action text not null, actor uuid, created_at timestamptz not null default now()
);
create table spark20_payout_requests(
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references spark20_profiles(id) on delete set null,
  amount_paise int not null,
  status text not null default 'blocked_prelaunch',   -- payouts are permanently disabled
  created_at timestamptz not null default now()
);

create or replace function s20_touch() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
create trigger trg_touch before update on spark20_profiles for each row execute function s20_touch();

-- ============ RLS ============
alter table spark20_admins enable row level security;
alter table spark20_business_settings enable row level security;
alter table spark20_profiles enable row level security;
alter table spark20_likes enable row level security;
alter table spark20_matches enable row level security;
alter table spark20_chat_messages enable row level security;
alter table spark20_introductions enable row level security;
alter table spark20_introduction_replies enable row level security;
alter table spark20_ledger_entries enable row level security;
alter table spark20_blocks enable row level security;
alter table spark20_reports enable row level security;
alter table spark20_moderation_actions enable row level security;
alter table spark20_payout_requests enable row level security;

create policy cfg_read on spark20_business_settings for select using (true);
create policy own_profile_sel on spark20_profiles for select to authenticated using (user_id = auth.uid());
create policy own_profile_ins on spark20_profiles for insert to authenticated with check (user_id = auth.uid());
create policy own_profile_upd on spark20_profiles for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own_ledger on spark20_ledger_entries for select to authenticated
  using (profile_id in (select id from spark20_profiles where user_id = auth.uid()));
-- everything else is reachable only through the SECURITY DEFINER functions below.

revoke insert, update, delete on spark20_profiles from authenticated, anon;
grant insert (user_id,display_name,age,age_confirmed,city,location_consent,latitude,longitude,location_enabled,height_cm,bio,gender_identity,gender_identity_custom,
  show_in_feed_genders,interests,relationship_goals,min_age_preference,max_age_preference,min_height_preference_cm,max_height_preference_cm,photo_urls,visible)
  on spark20_profiles to authenticated;
grant update (display_name,age,age_confirmed,city,location_consent,latitude,longitude,location_enabled,height_cm,bio,gender_identity,gender_identity_custom,
  show_in_feed_genders,interests,relationship_goals,min_age_preference,max_age_preference,min_height_preference_cm,max_height_preference_cm,photo_urls,visible)
  on spark20_profiles to authenticated;

-- ============ Storage (photos) ============
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('photos','photos',true,8388608,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set file_size_limit=8388608, allowed_mime_types=array['image/jpeg','image/png','image/webp'];
create policy photos_ins on storage.objects for insert to authenticated
  with check (bucket_id='photos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy photos_del on storage.objects for delete to authenticated
  using (bucket_id='photos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy photos_sel on storage.objects for select using (bucket_id='photos');

-- ============ Helpers ============
create or replace function s20_me() returns uuid language sql stable security definer set search_path=public as
$$ select id from spark20_profiles where user_id=auth.uid() $$;
create or replace function s20_is_admin() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from spark20_admins where user_id=auth.uid()) $$;
create or replace function s20_bucket(g text) returns text language sql immutable as
$$ select case g when 'woman' then 'women' when 'trans_woman' then 'women'
  when 'man' then 'men' when 'trans_man' then 'men' else 'non_binary' end $$;
create or replace function s20_blocked(a uuid,b uuid) returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from spark20_blocks where (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a)) $$;

-- Reciprocal eligibility: feed gender + age range + visibility + blocks. Max age >= 80 means "80+" (no cap).
create or replace function s20_eligible(a uuid,b uuid) returns boolean language sql stable security definer set search_path=public as $$
 select a<>b and exists(
  select 1 from spark20_profiles v, spark20_profiles c where v.id=a and c.id=b
   and not v.suspended and c.visible and not c.suspended
   and ('everyone'=any(v.show_in_feed_genders) or s20_bucket(c.gender_identity)=any(v.show_in_feed_genders))
   and ('everyone'=any(c.show_in_feed_genders) or s20_bucket(v.gender_identity)=any(c.show_in_feed_genders))
   and c.age>=v.min_age_preference and (v.max_age_preference>=80 or c.age<=v.max_age_preference)
   and v.age>=c.min_age_preference and (c.max_age_preference>=80 or v.age<=c.max_age_preference)
   and (c.height_cm is null or c.height_cm between v.min_height_preference_cm and v.max_height_preference_cm)
   and (v.height_cm is null or v.height_cm between c.min_height_preference_cm and c.max_height_preference_cm)
 ) and not s20_blocked(a,b) $$;

create or replace function s20_distance_km(a_lat double precision,a_lon double precision,b_lat double precision,b_lon double precision)
returns double precision language sql immutable set search_path=pg_catalog as $$
  select 6371.0 * 2 * asin(sqrt(least(1::double precision, greatest(0::double precision,
    power(sin(radians(b_lat-a_lat)/2),2) +
    cos(radians(a_lat))*cos(radians(b_lat))*power(sin(radians(b_lon-a_lon)/2),2)))))
$$;

-- ============ Discovery / likes ============
create or replace function s20_discovery(p_city text default null, p_limit int default 12, p_radius_km int default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  if me is null then raise exception 'profile_required'; end if;
  if p_radius_km is not null and p_radius_km not between 1 and 500 then raise exception 'invalid_radius'; end if;
  if p_radius_km is not null and not exists(select 1 from spark20_profiles where id=me and location_enabled and latitude is not null) then
    raise exception 'location_required';
  end if;
  return (select coalesce(jsonb_agg(j),'[]'::jsonb) from (
    select jsonb_build_object('id',c.id,'displayName',c.display_name,'age',c.age,'heightCm',c.height_cm,'city',c.city,'bio',c.bio,
      'genderIdentity',c.gender_identity,'genderIdentityCustom',c.gender_identity_custom,
      'interests',c.interests,'relationshipGoals',c.relationship_goals,'photoUrls',c.photo_urls) j
    from spark20_profiles c
    where s20_eligible(me,c.id)
      and (p_city is null or p_city='' or c.city ilike p_city)
      and (p_radius_km is null or (c.location_enabled and c.latitude is not null and
        s20_distance_km((select latitude from spark20_profiles where id=me),(select longitude from spark20_profiles where id=me),c.latitude,c.longitude)<=p_radius_km))
      and not exists(select 1 from spark20_likes l where l.from_id=me and l.to_id=c.id)
    order by random() limit least(greatest(p_limit,1),30)) t);
end $$;
grant execute on function public.s20_discovery(text,integer,integer) to authenticated;

create or replace function s20_like(p_target uuid,p_action text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me(); mid uuid;
begin
  if me is null then raise exception 'profile_required'; end if;
  if p_action not in ('like','pass') then raise exception 'invalid_action'; end if;
  if not s20_eligible(me,p_target) then raise exception 'not_eligible'; end if;
  insert into spark20_likes(from_id,to_id,action) values(me,p_target,p_action) on conflict (from_id,to_id) do nothing;
  if p_action='like' then
    if exists(select 1 from spark20_likes where from_id=p_target and to_id=me and action='like') then
      insert into spark20_matches(profile_a,profile_b) values(least(me,p_target),greatest(me,p_target))
        on conflict (profile_a,profile_b) do update set profile_a=excluded.profile_a returning id into mid;
      return jsonb_build_object('matched',true,'matchId',mid);
    end if;
  end if;
  return jsonb_build_object('matched',false);
end $$;

-- ============ Matches / chat ============
create or replace function s20_matches() returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  if me is null then raise exception 'profile_required'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('matchId',m.id,'profileId',o.id,'displayName',o.display_name,
    'age',o.age,'city',o.city,'photoUrl',o.photo_urls[1],
    'lastMessage',(select content from spark20_chat_messages c where c.match_id=m.id order by c.created_at desc limit 1),
    'unread',(select count(*) from spark20_chat_messages c where c.match_id=m.id and c.sender_id<>me
       and c.created_at>coalesce(case when m.profile_a=me then m.last_read_at_a else m.last_read_at_b end,'epoch'::timestamptz))
  ) order by m.created_at desc),'[]'::jsonb)
  from spark20_matches m join spark20_profiles o on o.id=case when m.profile_a=me then m.profile_b else m.profile_a end
  where m.active and (m.profile_a=me or m.profile_b=me) and not s20_blocked(me,o.id));
end $$;

create or replace function s20_get_messages(p_match uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me(); m spark20_matches; o spark20_profiles;
begin
  select * into m from spark20_matches where id=p_match and (profile_a=me or profile_b=me);
  if not found then raise exception 'not_found'; end if;
  select * into o from spark20_profiles where id=case when m.profile_a=me then m.profile_b else m.profile_a end;
  if s20_blocked(me,o.id) then raise exception 'not_found'; end if;
  update spark20_matches set last_read_at_a=case when profile_a=me then now() else last_read_at_a end,
    last_read_at_b=case when profile_b=me then now() else last_read_at_b end where id=p_match;
  return jsonb_build_object('me',me,'active',m.active,
    'other',jsonb_build_object('id',o.id,'displayName',o.display_name,'photoUrl',o.photo_urls[1]),
    'messages',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'senderId',c.sender_id,'content',c.content,'createdAt',c.created_at) order by c.created_at),'[]'::jsonb)
                from spark20_chat_messages c where c.match_id=p_match));
end $$;

create or replace function s20_send_message(p_match uuid,p_content text) returns void
language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me(); m spark20_matches; oid uuid;
begin
  select * into m from spark20_matches where id=p_match and active and (profile_a=me or profile_b=me);
  if not found then raise exception 'not_found'; end if;
  oid:=case when m.profile_a=me then m.profile_b else m.profile_a end;
  if s20_blocked(me,oid) then raise exception 'not_found'; end if;
  if char_length(trim(p_content)) not between 1 and 2000 then raise exception 'invalid_content'; end if;
  if (select count(*) from spark20_chat_messages where sender_id=me and created_at>now()-interval '1 minute')>=20 then
    raise exception 'rate_limited'; end if;
  insert into spark20_chat_messages(match_id,sender_id,content) values(p_match,me,trim(p_content));
end $$;

create or replace function s20_unmatch(p_match uuid) returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  update spark20_matches set active=false, ended_at=now() where id=p_match and (profile_a=me or profile_b=me);
end $$;

-- ============ Safety ============
create or replace function s20_block(p_target uuid) returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  if me is null or me=p_target then raise exception 'invalid'; end if;
  insert into spark20_blocks(blocker_id,blocked_id) values(me,p_target) on conflict do nothing;
  update spark20_matches set active=false, ended_at=now()
   where profile_a=least(me,p_target) and profile_b=greatest(me,p_target);
end $$;

create or replace function s20_report(p_target uuid,p_category text,p_details text,p_intro uuid default null) returns void
language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  if me is null or me=p_target then raise exception 'invalid'; end if;
  insert into spark20_reports(reporter_id,target_id,related_intro_id,category,details)
  values(me,p_target,p_intro,p_category,coalesce(left(p_details,2000),''));
  if p_intro is not null then
    update spark20_introductions set status='reported' where id=p_intro and recipient_id=me and status in ('paid','accepted');
  end if;
end $$;

-- ============ Introductions ============
create or replace function s20_create_intro(p_recipient uuid,p_content text,p_idem text) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  raise exception 'payments_disabled';
end $$;

create or replace function s20_decision(p_intro uuid,p_decision text) returns void
language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me(); i spark20_introductions;
begin
  select * into i from spark20_introductions where id=p_intro and recipient_id=me;
  if not found then raise exception 'not_found'; end if;
  if i.status not in ('paid','accepted') then raise exception 'cannot_decide'; end if;
  if p_decision='accept' then update spark20_introductions set status='accepted' where id=i.id;
  elsif p_decision='decline' then update spark20_introductions set status='declined' where id=i.id;
  elsif p_decision='ignore' then update spark20_introductions set status='ignored' where id=i.id;
  elsif p_decision='block' then
    update spark20_introductions set status='blocked' where id=i.id;
    perform s20_block(i.sender_id);
  else raise exception 'invalid_decision'; end if;
end $$;

create or replace function s20_do_reply(p_me uuid,p_intro uuid,p_content text) returns void
language plpgsql security definer set search_path=public as $$
declare i spark20_introductions; bs spark20_business_settings; q boolean:=false;
begin
  select * into i from spark20_introductions where id=p_intro and (sender_id=p_me or recipient_id=p_me);
  if not found then raise exception 'not_found'; end if;
  if i.status not in ('accepted','replied') then raise exception 'cannot_reply'; end if;
  if char_length(trim(p_content)) not between 1 and 1000 then raise exception 'invalid_content'; end if;
  select * into bs from spark20_business_settings where id=1;
  if i.recipient_id=p_me
     and not exists(select 1 from spark20_introduction_replies where introduction_id=i.id and sender_id=i.recipient_id and qualifies_for_reward) then q:=true; end if;
  insert into spark20_introduction_replies(introduction_id,sender_id,content,qualifies_for_reward) values(i.id,p_me,trim(p_content),q);
  if q then
    insert into spark20_ledger_entries(profile_id,introduction_id,kind,amount_paise,status,idempotency_key)
    select beneficiary.profile_id,i.id,'reward_pending',bs.reply_reward_paise,'pending','reward:'||i.id||':'||beneficiary.profile_id
    from unnest(array[i.sender_id,i.recipient_id]) as beneficiary(profile_id)
    on conflict (idempotency_key) do nothing;
  end if;
  if i.recipient_id=p_me then update spark20_introductions set status='replied' where id=i.id; end if;
end $$;
create or replace function s20_reply(p_intro uuid,p_content text) returns void language plpgsql security definer set search_path=public as
$$ begin perform s20_do_reply(s20_me(),p_intro,p_content); end $$;

create or replace function s20_intros() returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  if me is null then raise exception 'profile_required'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'direction',case when i.sender_id=me then 'sent' else 'received' end,
    'status',i.status,'content',i.content,'pricePaise',i.price_paise,'paidAt',i.paid_at,'createdAt',i.created_at,
    'otherId',o.id,'otherName',o.display_name,'otherPhoto',o.photo_urls[1],
    'replies',(select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'mine',r.sender_id=me,'content',r.content,'createdAt',r.created_at) order by r.created_at),'[]'::jsonb)
               from spark20_introduction_replies r where r.introduction_id=i.id)
  ) order by i.created_at desc),'[]'::jsonb)
  from spark20_introductions i join spark20_profiles o on o.id=case when i.sender_id=me then i.recipient_id else i.sender_id end
  where (i.sender_id=me or i.recipient_id=me) and not s20_blocked(me,o.id)
    and (i.sender_id=me or i.status not in ('pending_payment','payment_pending','payment_failed','cancelled')));
end $$;

create or replace function s20_home_summary() returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  return jsonb_build_object(
   'matches',(select count(*) from spark20_matches m where m.active and (m.profile_a=me or m.profile_b=me)),
   'unread',(select count(*) from spark20_chat_messages c join spark20_matches m on m.id=c.match_id
      where m.active and (m.profile_a=me or m.profile_b=me) and c.sender_id<>me
      and c.created_at>coalesce(case when m.profile_a=me then m.last_read_at_a else m.last_read_at_b end,'epoch'::timestamptz)),
   'intros',(select count(*) from spark20_introductions where recipient_id=me and status='paid'));
end $$;

-- ============ Privacy ============
create or replace function s20_export() returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  return jsonb_build_object('profile',(select to_jsonb(p) from spark20_profiles p where id=me),
   'matches',(select coalesce(jsonb_agg(to_jsonb(m)),'[]'::jsonb) from spark20_matches m where profile_a=me or profile_b=me),
   'introductions',(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from spark20_introductions i where sender_id=me or recipient_id=me),
   'ledger',(select coalesce(jsonb_agg(to_jsonb(l)),'[]'::jsonb) from spark20_ledger_entries l where profile_id=me));
end $$;

-- Ledger rows are kept (profile_id -> null). Client removes storage objects first.
create or replace function s20_delete_account() returns void language plpgsql security definer set search_path=public,auth as $$
begin
  delete from spark20_profiles where user_id=auth.uid();
  delete from auth.users where id=auth.uid();
end $$;

-- ============ Admin ============
create or replace function s20_admin_guard() returns void language plpgsql security definer set search_path=public as
$$ begin if not s20_is_admin() then raise exception 'forbidden'; end if; end $$;

create or replace function s20_admin_reports() returns jsonb language plpgsql security definer set search_path=public as $$
begin perform s20_admin_guard();
  return (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'category',r.category,'details',r.details,'status',r.status,
    'reporter',a.display_name,'target',t.display_name,'targetId',t.id,'createdAt',r.created_at) order by r.created_at),'[]'::jsonb)
   from spark20_reports r join spark20_profiles a on a.id=r.reporter_id join spark20_profiles t on t.id=r.target_id
   where r.status in ('open','needs_followup'));
end $$;
create or replace function s20_admin_review_report(p_id uuid,p_status text,p_notes text default null) returns void
language plpgsql security definer set search_path=public as $$
declare r spark20_reports;
begin perform s20_admin_guard();
  if p_status not in ('dismissed','actioned','needs_followup') then raise exception 'invalid'; end if;
  select * into r from spark20_reports where id=p_id; if not found then raise exception 'not_found'; end if;
  update spark20_reports set status=p_status, notes=p_notes, reviewed_by=auth.uid(), reviewed_at=now() where id=p_id;
  if p_status='actioned' then
    update spark20_profiles set suspended=true where id=r.target_id;
    insert into spark20_moderation_actions(report_id,target_id,action,actor) values(p_id,r.target_id,'suspend',auth.uid());
  end if;
end $$;

create or replace function s20_admin_rewards() returns jsonb language plpgsql security definer set search_path=public as $$
begin perform s20_admin_guard();
  return (select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'amountPaise',l.amount_paise,'profile',p.display_name,'createdAt',l.created_at) order by l.created_at),'[]'::jsonb)
   from spark20_ledger_entries l left join spark20_profiles p on p.id=l.profile_id
   where l.kind='reward_pending' and l.status='pending'
     and l.created_at<=now()-make_interval(days=>(select reward_pending_days from spark20_business_settings where id=1)));
end $$;
create or replace function s20_admin_reward_decide(p_id uuid,p_decision text) returns void
language plpgsql security definer set search_path=public as $$
declare l spark20_ledger_entries;
begin perform s20_admin_guard();
  select * into l from spark20_ledger_entries where id=p_id and kind='reward_pending' and status='pending';
  if not found then raise exception 'not_found'; end if;
  if p_decision='approve' then
    update spark20_ledger_entries set status='approved' where id=p_id;
    insert into spark20_ledger_entries(profile_id,introduction_id,kind,amount_paise,status,idempotency_key)
    values(l.profile_id,l.introduction_id,'reward_available',l.amount_paise,'available','avail:'||p_id);
  elsif p_decision='reverse' then
    update spark20_ledger_entries set status='reversed' where id=p_id;
    insert into spark20_ledger_entries(profile_id,introduction_id,kind,amount_paise,status,idempotency_key)
    values(l.profile_id,l.introduction_id,'reward_pending_reversed',l.amount_paise,'reversed','rev:'||p_id);
  elsif p_decision='dispute' then
    update spark20_ledger_entries set status='disputed' where id=p_id;
    insert into spark20_ledger_entries(profile_id,introduction_id,kind,amount_paise,status,idempotency_key)
    values(l.profile_id,l.introduction_id,'reward_disputed',l.amount_paise,'disputed','disp:'||p_id);
  else raise exception 'invalid'; end if;
end $$;

create or replace function s20_admin_update_settings(p_price int,p_reward int,p_min int,p_days int,p_enabled boolean) returns void
language plpgsql security definer set search_path=public as $$
begin perform s20_admin_guard();
  update spark20_business_settings set intro_price_paise=2049, reply_reward_paise=500,
    min_qualifying_chars=1, reward_pending_days=greatest(p_days,0), reward_enabled=true where id=1;
end $$;

-- Disable all simulated money flows, remove demo records and set the withdrawal threshold.
-- Real payment processing remains off until verified Play Billing/Razorpay server functions exist.
begin;

alter table spark20_business_settings
  add column if not exists minimum_withdrawal_paise integer not null default 10000,
  add column if not exists cashouts_enabled boolean not null default false;

update spark20_business_settings
set payment_mode = 'disabled',
    intro_price_paise = 2049,
    reply_reward_paise = 500,
    reward_enabled = true,
    min_qualifying_chars = 1,
    minimum_withdrawal_paise = greatest(minimum_withdrawal_paise, 10000),
    cashouts_enabled = false
where id = 1;

alter table spark20_business_settings
  drop constraint if exists spark20_business_settings_payment_mode_check;
alter table spark20_business_settings
  add constraint spark20_business_settings_payment_mode_check check (payment_mode = 'disabled');
alter table spark20_business_settings
  drop constraint if exists spark20_business_settings_minimum_withdrawal_paise_check;
alter table spark20_business_settings
  add constraint spark20_business_settings_minimum_withdrawal_paise_check
  check (minimum_withdrawal_paise >= 10000);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'spark20_ledger_entries' and column_name = 'simulated'
  ) then
    execute 'delete from spark20_ledger_entries where simulated';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'spark20_introductions' and column_name = 'simulated'
  ) then
    execute 'delete from spark20_introductions where simulated';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'spark20_profiles' and column_name = 'is_fake'
  ) then
    execute 'delete from spark20_profiles where is_fake';
  end if;
end $$;

delete from spark20_ledger_entries
where kind in ('test_intro_charge', 'test_reward_pending', 'test_refund');

drop function if exists public.s20_test_payment(uuid, text, text);
drop function if exists public.s20_dev_fake_respond(uuid, text, text);
drop function if exists public.s20_dev_fake_respond(uuid, text);
drop function if exists public.s20_dev_seed_intros();
drop function if exists public.s20_dev_age_rewards();
drop function if exists public.s20_dev_guard();
drop function if exists public.s20_request_refund(uuid, text);
drop function if exists public.s20_admin_refunds();
drop function if exists public.s20_admin_refund_decide(uuid, text);

create or replace function public.s20_create_intro(p_recipient uuid, p_content text, p_idem text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  raise exception 'payments_disabled';
end $$;

create or replace function public.s20_like(p_target uuid, p_action text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := s20_me(); mid uuid;
begin
  if me is null then raise exception 'profile_required'; end if;
  if p_action not in ('like','pass') then raise exception 'invalid_action'; end if;
  if not s20_eligible(me,p_target) then raise exception 'not_eligible'; end if;
  insert into spark20_likes(from_id,to_id,action) values(me,p_target,p_action) on conflict (from_id,to_id) do nothing;
  if p_action = 'like' and exists(
    select 1 from spark20_likes where from_id=p_target and to_id=me and action='like'
  ) then
    insert into spark20_matches(profile_a,profile_b)
    values(least(me,p_target),greatest(me,p_target))
    on conflict (profile_a,profile_b) do update set profile_a=excluded.profile_a
    returning id into mid;
    return jsonb_build_object('matched',true,'matchId',mid);
  end if;
  return jsonb_build_object('matched',false);
end $$;

create or replace function public.s20_send_message(p_match uuid,p_content text) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := s20_me(); m spark20_matches; oid uuid;
begin
  select * into m from spark20_matches
  where id=p_match and active and (profile_a=me or profile_b=me);
  if not found then raise exception 'not_found'; end if;
  oid := case when m.profile_a=me then m.profile_b else m.profile_a end;
  if s20_blocked(me,oid) then raise exception 'not_found'; end if;
  if char_length(trim(p_content)) not between 1 and 2000 then raise exception 'invalid_content'; end if;
  if (select count(*) from spark20_chat_messages
      where sender_id=me and created_at>now()-interval '1 minute') >= 20 then
    raise exception 'rate_limited';
  end if;
  insert into spark20_chat_messages(match_id,sender_id,content)
  values(p_match,me,trim(p_content));
end $$;

create or replace function public.s20_do_reply(p_me uuid,p_intro uuid,p_content text) returns void
language plpgsql security definer set search_path = public as $$
declare i spark20_introductions; bs spark20_business_settings; q boolean := false;
begin
  select * into i from spark20_introductions
  where id=p_intro and (sender_id=p_me or recipient_id=p_me);
  if not found then raise exception 'not_found'; end if;
  if i.status not in ('accepted','replied') then raise exception 'cannot_reply'; end if;
  if char_length(trim(p_content)) not between 1 and 1000 then raise exception 'invalid_content'; end if;
  select * into bs from spark20_business_settings where id=1;
  if i.recipient_id=p_me and not exists(
    select 1 from spark20_introduction_replies
    where introduction_id=i.id and sender_id=i.recipient_id and qualifies_for_reward
  ) then
    q := true;
  end if;
  insert into spark20_introduction_replies(introduction_id,sender_id,content,qualifies_for_reward)
  values(i.id,p_me,trim(p_content),q);
  if q then
    insert into spark20_ledger_entries(profile_id,introduction_id,kind,amount_paise,status,idempotency_key)
    select beneficiary.profile_id,i.id,'reward_pending',bs.reply_reward_paise,'pending',
      'reward:'||i.id||':'||beneficiary.profile_id
    from unnest(array[i.sender_id,i.recipient_id]) as beneficiary(profile_id)
    on conflict (idempotency_key) do nothing;
  end if;
  if i.recipient_id=p_me then
    update spark20_introductions set status='replied' where id=i.id;
  end if;
end $$;

create or replace function public.s20_intros() returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := s20_me();
begin
  if me is null then raise exception 'profile_required'; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',i.id,
      'direction',case when i.sender_id=me then 'sent' else 'received' end,
      'status',i.status,
      'content',i.content,
      'pricePaise',i.price_paise,
      'paidAt',i.paid_at,
      'createdAt',i.created_at,
      'otherId',o.id,
      'otherName',o.display_name,
      'otherPhoto',o.photo_urls[1],
      'replies',(select coalesce(jsonb_agg(jsonb_build_object(
        'id',r.id,'mine',r.sender_id=me,'content',r.content,'createdAt',r.created_at
      ) order by r.created_at),'[]'::jsonb)
      from spark20_introduction_replies r where r.introduction_id=i.id)
    ) order by i.created_at desc),'[]'::jsonb)
    from spark20_introductions i
    join spark20_profiles o on o.id=case when i.sender_id=me then i.recipient_id else i.sender_id end
    where (i.sender_id=me or i.recipient_id=me)
      and not s20_blocked(me,o.id)
      and (i.sender_id=me or i.status not in ('pending_payment','payment_pending','payment_failed','cancelled'))
  );
end $$;

create or replace function public.s20_admin_rewards() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform s20_admin_guard();
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',l.id,'amountPaise',l.amount_paise,'profile',p.display_name,'createdAt',l.created_at
    ) order by l.created_at),'[]'::jsonb)
    from spark20_ledger_entries l
    left join spark20_profiles p on p.id=l.profile_id
    where l.kind='reward_pending' and l.status='pending'
      and l.created_at<=now()-make_interval(days=>(
        select reward_pending_days from spark20_business_settings where id=1
      ))
  );
end $$;

create or replace function public.s20_admin_reward_decide(p_id uuid,p_decision text) returns void
language plpgsql security definer set search_path = public as $$
declare l spark20_ledger_entries;
begin
  perform s20_admin_guard();
  select * into l from spark20_ledger_entries
  where id=p_id and kind='reward_pending' and status='pending';
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
  else
    raise exception 'invalid';
  end if;
end $$;

create or replace function public.s20_admin_update_settings(p_price int,p_reward int,p_min int,p_days int,p_enabled boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform s20_admin_guard();
  update spark20_business_settings
  set intro_price_paise=2049,
      reply_reward_paise=500,
      min_qualifying_chars=1,
      reward_pending_days=greatest(p_days,0),
      reward_enabled=true,
      minimum_withdrawal_paise=greatest(minimum_withdrawal_paise,10000),
      cashouts_enabled=false,
      payment_mode='disabled'
  where id=1;
end $$;

alter table spark20_ledger_entries
  drop constraint if exists spark20_ledger_entries_kind_check;
alter table spark20_ledger_entries
  add constraint spark20_ledger_entries_kind_check check (kind in (
    'intro_charge','reward_pending','reward_pending_reversed',
    'reward_available','reward_reversed','reward_disputed'
  ));

alter table spark20_profiles drop column if exists is_fake;
alter table spark20_profiles drop column if exists fake_mode;
alter table spark20_introductions drop column if exists simulated;
alter table spark20_ledger_entries drop column if exists simulated;

notify pgrst, 'reload schema';
commit;

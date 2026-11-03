-- Apply to an existing database after 01_schema.sql has been installed.
begin;

update spark20_business_settings
set intro_price_paise=2049, reply_reward_paise=500, min_qualifying_chars=1, reward_enabled=true
where id=1;

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
  insert into spark20_introduction_replies(introduction_id,sender_id,content,qualifies_for_reward)
  values(i.id,p_me,trim(p_content),q);
  if q then
    insert into spark20_ledger_entries(profile_id,introduction_id,kind,amount_paise,status,idempotency_key)
    select beneficiary.profile_id,i.id,'reward_pending',bs.reply_reward_paise,'pending',
      'reward:'||i.id||':'||beneficiary.profile_id
    from unnest(array[i.sender_id,i.recipient_id]) as beneficiary(profile_id)
    on conflict (idempotency_key) do nothing;
  end if;
  if i.recipient_id=p_me then update spark20_introductions set status='replied' where id=i.id; end if;
end $$;

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

create or replace function s20_admin_update_settings(p_price int,p_reward int,p_min int,p_days int,p_enabled boolean) returns void
language plpgsql security definer set search_path=public as $$
begin perform s20_admin_guard();
  update spark20_business_settings set intro_price_paise=2049, reply_reward_paise=500,
    min_qualifying_chars=1, reward_pending_days=greatest(p_days,0), reward_enabled=true where id=1;
end $$;

drop function if exists s20_request_refund(uuid,text);
drop function if exists s20_admin_refunds();
drop function if exists s20_admin_refund_decide(uuid,text);

commit;

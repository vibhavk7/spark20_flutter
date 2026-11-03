-- Apply to an existing database after 01_schema.sql and earlier migrations. Safe to rerun.
begin;

alter table spark20_profiles
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_enabled boolean not null default false,
  add column if not exists height_cm int,
  add column if not exists min_height_preference_cm int not null default 100,
  add column if not exists max_height_preference_cm int not null default 250;

alter table spark20_profiles drop constraint if exists spark20_profiles_height_cm_check;
alter table spark20_profiles add constraint spark20_profiles_height_cm_check
  check (height_cm is null or height_cm between 100 and 250);
alter table spark20_profiles drop constraint if exists spark20_profiles_min_height_preference_cm_check;
alter table spark20_profiles add constraint spark20_profiles_min_height_preference_cm_check
  check (min_height_preference_cm between 100 and 250 and min_height_preference_cm <= max_height_preference_cm);
alter table spark20_profiles drop constraint if exists spark20_profiles_latitude_check;
alter table spark20_profiles add constraint spark20_profiles_latitude_check
  check (latitude is null or latitude between -90 and 90);
alter table spark20_profiles drop constraint if exists spark20_profiles_longitude_check;
alter table spark20_profiles add constraint spark20_profiles_longitude_check
  check (longitude is null or longitude between -180 and 180);
alter table spark20_profiles drop constraint if exists spark20_profiles_location_coordinates_check;
alter table spark20_profiles add constraint spark20_profiles_location_coordinates_check
  check ((latitude is null) = (longitude is null) and (not location_enabled or latitude is not null));

grant insert (latitude,longitude,location_enabled,height_cm,min_height_preference_cm,max_height_preference_cm)
  on spark20_profiles to authenticated;
grant update (latitude,longitude,location_enabled,height_cm,min_height_preference_cm,max_height_preference_cm)
  on spark20_profiles to authenticated;

create or replace function s20_eligible(a uuid,b uuid) returns boolean
language sql stable security definer set search_path=public as $$
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

drop function if exists public.s20_discovery(text,integer);
create or replace function public.s20_discovery(p_city text default null,p_limit integer default 12,p_radius_km integer default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid:=s20_me();
begin
  if me is null then raise exception 'profile_required'; end if;
  if p_radius_km is not null and p_radius_km not between 1 and 500 then raise exception 'invalid_radius'; end if;
  if p_radius_km is not null and not exists(
    select 1 from spark20_profiles where id=me and location_enabled and latitude is not null
  ) then raise exception 'location_required'; end if;
  return (select coalesce(jsonb_agg(j),'[]'::jsonb) from (
    select jsonb_build_object('id',c.id,'displayName',c.display_name,'age',c.age,'heightCm',c.height_cm,'city',c.city,'bio',c.bio,
      'genderIdentity',c.gender_identity,'genderIdentityCustom',c.gender_identity_custom,
      'interests',c.interests,'relationshipGoals',c.relationship_goals,'photoUrls',c.photo_urls) j
    from spark20_profiles c
    where s20_eligible(me,c.id)
      and (p_city is null or p_city='' or c.city ilike p_city)
      and (p_radius_km is null or (c.location_enabled and c.latitude is not null and
        s20_distance_km((select latitude from spark20_profiles where id=me),
          (select longitude from spark20_profiles where id=me),c.latitude,c.longitude)<=p_radius_km))
      and not exists(select 1 from spark20_likes l where l.from_id=me and l.to_id=c.id)
    order by random() limit least(greatest(p_limit,1),30)
  ) t);
end $$;

grant execute on function public.s20_discovery(text,integer,integer) to authenticated;

notify pgrst, 'reload schema';
commit;

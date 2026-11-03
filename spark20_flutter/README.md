# Spark20

Flutter + Supabase dating app. Profile, discovery, private radius/height filters, mutual matches,
chat, introductions, safety tools, and a wallet ledger are implemented.

## Current payment status

Real payments and payouts are **not live**. Direct introductions are disabled in the app and rejected
by the database until server-side payment creation, signature/webhook verification, and idempotent
ledger posting are deployed. No test payment controls or fake financial activity are included.

The web Razorpay estimate is ₹20.49 gross to approximately cover the current 2% + GST gateway fee
and preserve ₹10 for Spark20 after two ₹5 rewards. The wallet shows an estimated ₹0.48 fee on that
amount; the actual settled fee must come from the verified gateway transaction. Android pricing must
be set from the configured Play product and current Play Console terms. The single ₹20.49 value is
not authorization to charge; payment mode is pinned to `disabled`.

The withdrawal minimum is ₹100 of available balance. Withdrawals remain unavailable until payout,
identity/compliance, and reconciliation flows are implemented and enabled. Do not promise users a
cash payout before those steps are complete.

Do not put Razorpay secrets, Google service-account credentials, Supabase service-role keys, or a
database password in Flutter, source control, or chat. Configure server-only secrets in Supabase
Edge Function secrets after the payment functions are implemented.

## Supabase

For a new project, run these scripts in the Supabase SQL Editor in order:

1. `supabase/01_schema.sql`
2. `supabase/02_seed.sql` (intentional no-op; no synthetic profiles)
3. `supabase/03_intro_reward_and_refund_migration.sql`
4. `supabase/04_location_height_migration.sql`
5. `supabase/05_production_cutover.sql`

For an existing project where the previous schema/reward/location migrations have already run,
run `supabase/05_production_cutover.sql`. It disables payments and payouts, removes simulated rows
and fake profiles, removes demo-only fields/RPCs, and reloads the PostgREST schema cache. If the
location/height migration has not run yet, run `04_location_height_migration.sql` before `05`.

These scripts have not been applied to the live Supabase project from this workspace. Run them in
the project SQL Editor and verify that `s20_discovery(text, integer, integer)` exists afterward.

Enable Supabase Auth email confirmation and configure the production redirect URLs before launch.
Add the first moderator using:

```sql
insert into spark20_admins(user_id)
select id from auth.users where email = 'you@example.com';
```

## Run and build

```bash
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=<project-url> --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

The current workspace contains the Flutter web manifest/icons, so a deployed HTTPS web build can be
installed as a PWA. Native Android/iOS platform folders are not present yet. Before creating the
Android project, choose the permanent Play package ID in Play Console; `flutter create` with a
placeholder package ID could create a different Play app later.

For Android, add `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` to
`android/app/src/main/AndroidManifest.xml`; for iOS, add
`NSLocationWhenInUseUsageDescription` to `ios/Runner/Info.plist`. Location is requested only when a
user explicitly enables it on their profile. Exact coordinates are private and used only for radius
filtering. Height and height preferences are stored in centimeters.

## Payment launch checklist

- Choose the permanent Android package ID and create the Play Billing one-time product.
- Implement Android Play Billing and server-side purchase verification.
- Approve/configure the Razorpay live account for web and implement order creation plus verified,
  idempotent webhooks. Never trust a client-reported success.
- Record actual processor fees and reconcile them against payment settlements.
- Implement a compliant payout provider and withdrawal workflow before enabling cash-outs.
- Obtain legal, tax, consumer-disclosure, privacy, and Play policy review for the actual product.

The ₹5 + ₹5 rewards are created only after the recipient accepts and sends a reply on a paid
introduction. Both ledger rewards remain pending for moderator review. The two-party reward logic
and payment collection are separate: the app currently has no live collection provider.

## Privacy and safety

- Discovery returns public profile fields only; exact location and preferences remain private.
- Radius results require both profiles to enable location-based filtering.
- Height filters are mutual; profiles without a listed height remain eligible.
- Block/report tools are available from profiles and introductions.
- Photos are stored in the `photos` bucket; configure production storage limits and policies before launch.

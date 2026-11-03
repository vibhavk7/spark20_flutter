import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

String storagePath(String url) => Uri.decodeComponent(url.split('/photos/').last);

class ProfileScreen extends StatefulWidget { const ProfileScreen({super.key}); @override State<ProfileScreen> createState() => _S(); }
class _S extends State<ProfileScreen> {
  final name = TextEditingController(), ageC = TextEditingController(), heightC = TextEditingController(), city = TextEditingController(), bio = TextEditingController(), custom = TextEditingController();
  String? gender, goal; Set<String> feed = {}, interests = {}; RangeValues ages = const RangeValues(18, 45), heights = const RangeValues(100, 250);
  double? latitude, longitude;
  List<String> photos = []; final removed = <String>[]; bool confirm = false, consent = false, saving = false, uploading = false; String q = '';
  bool useLocation = false;

  @override void initState() {
    super.initState();
    final p = app.profile; if (p == null) return;
    name.text = p['display_name']; ageC.text = '${p['age']}'; city.text = p['city']; bio.text = p['bio'] ?? '';
    gender = p['gender_identity']; custom.text = p['gender_identity_custom'] ?? '';
    feed = Set<String>.from(p['show_in_feed_genders']); interests = Set<String>.from(p['interests']);
    goal = (p['relationship_goals'] as List).first; photos = List<String>.from(p['photo_urls']);
    ages = RangeValues((p['min_age_preference'] as int).toDouble(), (p['max_age_preference'] as int).toDouble());
    heightC.text = p['height_cm'] == null ? '' : '${p['height_cm']}';
    heights = RangeValues(((p['min_height_preference_cm'] ?? 100) as int).toDouble(), ((p['max_height_preference_cm'] ?? 250) as int).toDouble());
    latitude = (p['latitude'] as num?)?.toDouble(); longitude = (p['longitude'] as num?)?.toDouble();
    useLocation = p['location_enabled'] == true;
    confirm = p['age_confirmed'] == true; consent = p['location_consent'] == true;
  }

  void toggleFeed(String k) => setState(() {
    if (k == 'everyone') { feed = feed.contains('everyone') ? {} : {'everyone'}; }
    else { feed.remove('everyone'); feed.contains(k) ? feed.remove(k) : feed.add(k); }
  });
  void toggleInterest(String k) => setState(() {
    if (interests.contains(k)) { interests.remove(k); }
    else if (interests.length >= 12) { toast(context, 'Up to 12 interests.'); }
    else { interests.add(k); }
  });

  Future<void> addPhoto() async {
    if (photos.length >= 6) return;
    setState(() => uploading = true);
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) { if (mounted) toast(context, 'Photos can be up to 8MB.'); return; }
      final ext = x.name.split('.').last.toLowerCase();
      const types = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
      if (!types.containsKey(ext)) { if (mounted) toast(context, 'Use a JPEG, PNG or WebP photo.'); return; }
      final path = '${sb.auth.currentUser!.id}/${uid()}.$ext';
      await sb.storage.from('photos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: types[ext]));
      setState(() => photos.add(sb.storage.from('photos').getPublicUrl(path)));
    } catch (e) { if (mounted) toast(context, errText(e)); }
    finally { if (mounted) setState(() => uploading = false); }
  }
  Future<void> setDeviceLocation() async {
    if (!useLocation) { toast(context, 'Enable private location use first.'); return; }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        toast(context, 'Turn on location services, then try again.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        toast(context, permission == LocationPermission.deniedForever
            ? 'Location permission is blocked. Enable it in your browser or device settings.'
            : 'Allow location permission to set your private search location.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
      toast(context, 'Private location captured. Save your profile to apply it.');
    } catch (e) {
      if (mounted) toast(context, 'Could not get your location: ${errText(e)}');
    }
  }
  void move(int i, int d) { final j = i + d; if (j < 0 || j >= photos.length) return; setState(() { final t = photos[i]; photos[i] = photos[j]; photos[j] = t; }); }

  Future<void> save() async {
    String? err;
    final age = int.tryParse(ageC.text.trim());
    final height = heightC.text.trim().isEmpty ? null : int.tryParse(heightC.text.trim());
    if (name.text.trim().length < 2 || name.text.trim().length > 40) err = 'Display name: 2–40 characters.';
    else if (age == null || age < 18 || age > 110) err = 'Age must be between 18 and 110.';
    else if (heightC.text.trim().isNotEmpty && (height == null || height < 100 || height > 250)) err = 'Height must be between 100 and 250 cm.';
    else if (city.text.trim().length < 2) err = 'Please add your city.';
    else if (gender == null) err = 'Choose how you identify.';
    else if (feed.isEmpty) err = 'Choose who should appear in your feed.';
    else if (interests.length < 3) err = 'Pick at least 3 interests.';
    else if (goal == null) err = 'Choose a relationship goal.';
    else if (!confirm) err = 'Please confirm you are 18 or older.';
    else if (!consent) err = 'City consent is needed for discovery.';
    else if (useLocation && (latitude == null || longitude == null)) err = 'Set your private location or turn off location filtering.';
    if (err != null) { toast(context, err); return; }
    setState(() => saving = true);
    final data = {
      'display_name': name.text.trim(), 'age': age, 'age_confirmed': confirm, 'city': city.text.trim(), 'location_consent': consent,
      'bio': bio.text.trim(), 'gender_identity': gender, 'gender_identity_custom': gender == 'self_describe' ? custom.text.trim() : null,
      'show_in_feed_genders': feed.toList(), 'interests': interests.toList(), 'relationship_goals': [goal],
      'min_age_preference': ages.start.round(), 'max_age_preference': ages.end.round(), 'photo_urls': photos,
      'height_cm': height, 'min_height_preference_cm': heights.start.round(), 'max_height_preference_cm': heights.end.round(),
      'location_enabled': useLocation && latitude != null && longitude != null,
      'latitude': useLocation ? latitude : null, 'longitude': useLocation ? longitude : null,
    };
    final uidv = sb.auth.currentUser!.id;
    final ok = await guard(context, () async {
      if (app.profile == null) { await sb.from('spark20_profiles').insert({...data, 'user_id': uidv}); }
      else { await sb.from('spark20_profiles').update(data).eq('user_id', uidv); }
      return true;
    });
    if (ok == true) {
      if (removed.isNotEmpty) { try { await sb.storage.from('photos').remove(removed.map(storagePath).toList()); } catch (_) {} removed.clear(); }
      await app.load();
      if (mounted) { toast(context, 'Profile saved.'); context.go('/discover'); }
    }
    if (mounted) setState(() => saving = false);
  }

  Widget sec(String eyebrow, String? hint, Widget child) => Padding(padding: const EdgeInsets.only(top: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Eyebrow(eyebrow), if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: const TextStyle(color: C.muted, fontSize: 12))), const SizedBox(height: 10), child]));

  Widget photoTile(int i) {
    if (i >= photos.length) {
      return InkWell(borderRadius: BorderRadius.circular(16), onTap: (uploading || i != photos.length) ? null : addPhoto,
        child: Container(decoration: BoxDecoration(color: C.sage, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
          child: Center(child: uploading && i == photos.length ? const CircularProgressIndicator() : const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_a_photo_outlined, color: C.green), Text('Add photo', style: TextStyle(fontSize: 12))]))));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [
      Image.network(photos[i], fit: BoxFit.cover),
      if (i == 0) Positioned(top: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(99)), child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 11)))),
      Positioned(bottom: 0, left: 0, right: 0, child: Container(color: const Color(0x99000000), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ib(Icons.chevron_left, () => move(i, -1)), _ib(Icons.chevron_right, () => move(i, 1)),
        if (i != 0) _ib(Icons.star_border, () => move(i, -i)) ,
        _ib(Icons.delete_outline, () => setState(() { removed.add(photos[i]); photos.removeAt(i); }))]))),
    ]));
  }
  Widget _ib(IconData i, VoidCallback f) => InkWell(onTap: f, child: Padding(padding: const EdgeInsets.all(4), child: Icon(i, color: Colors.white, size: 18)));

  @override Widget build(BuildContext c) {
    final shown = kInterests.where((e) => e.toLowerCase().contains(q.toLowerCase()));
    return Pad([
      const Eyebrow('Profile'), Text(app.profile == null ? 'Tell us a little about you.' : 'Your profile.', style: serif(34)),
      const SizedBox(height: 6), const Text('A profile is never a promise to respond.', style: TextStyle(color: C.muted)),
      sec('Photos', 'Up to 6. The first is your main photo. JPEG, PNG or WebP, max 8MB.', GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, children: [for (var i = 0; i < 6; i++) photoTile(i)])),
      sec('Basics', null, Column(children: [
        TextField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: 'Display name')), const SizedBox(height: 8),
        TextField(controller: ageC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age')), const SizedBox(height: 14),
        TextField(controller: heightC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm, optional)')), const SizedBox(height: 14),
        TextField(controller: city, maxLength: 80, decoration: const InputDecoration(labelText: 'City', helperText: 'Your city is shown on your profile. Precise location is optional and private.')), const SizedBox(height: 8),
        TextField(controller: bio, maxLength: 500, maxLines: 4, decoration: const InputDecoration(labelText: 'Bio')),
      ])),
      sec('Private distance location', 'Only used to filter discovery by radius. Exact coordinates are never shown to other users.', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CheckboxListTile(value: useLocation, onChanged: (v) => setState(() {
          useLocation = v ?? false;
          if (!useLocation) { latitude = null; longitude = null; }
        }), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Use my device location privately for distance filtering.', style: TextStyle(fontSize: 13))),
        if (useLocation) Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton(onPressed: setDeviceLocation, child: Text(latitude == null ? 'Set my location' : 'Update my location')),
          if (latitude != null) const Text('Location set (private)', style: TextStyle(color: C.green, fontSize: 12)),
        ]),
      ])),
      sec('Gender identity', 'Who I am', Wrap(spacing: 8, runSpacing: 8, children: [for (final g in kGenders) SparkChip(g.$2, selected: gender == g.$1, onTap: () => setState(() => gender = g.$1))])),
      if (gender == 'self_describe') Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: custom, maxLength: 40, decoration: const InputDecoration(labelText: 'In your words'))),
      sec('Who should appear in my feed', 'Private. Never shown on your card.', Wrap(spacing: 8, runSpacing: 8, children: [for (final f in kFeed) SparkChip(f.$2, selected: feed.contains(f.$1), onTap: () => toggleFeed(f.$1))])),
      sec('Interests', 'Pick 3 to 12 (${interests.length} chosen)', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search activities')), const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final k in shown) SparkChip(k, selected: interests.contains(k), onTap: () => toggleInterest(k))])])),
      sec('Relationship goals', null, Wrap(spacing: 8, runSpacing: 8, children: [for (final g in kGoals) SparkChip(g.$2, selected: goal == g.$1, onTap: () => setState(() => goal = g.$1))])),
      sec('Age preference', null, AgeRangeField(ages, (v) => setState(() => ages = v))),
      sec('Height preference', 'Only profiles that list a height are filtered by this range.', HeightRangeField(heights, (v) => setState(() => heights = v))),
      const SizedBox(height: 16),
      CheckboxListTile(value: confirm, onChanged: (v) => setState(() => confirm = v!), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('I confirm that I am 18 or older. (Self-confirmed, not independently verified.)', style: TextStyle(fontSize: 13))),
      CheckboxListTile(value: consent, onChanged: (v) => setState(() => consent = v!), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('My city may be used for discovery. Precise location is optional and only used privately for distance filtering.', style: TextStyle(fontSize: 13))),
      const SizedBox(height: 12),
      FilledButton(key: const Key('save-profile'), onPressed: saving ? null : save, child: Text(saving ? 'Saving…' : 'Save profile')),
    ]);
  }
}

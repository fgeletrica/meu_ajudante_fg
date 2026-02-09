import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final _sb = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getMyProfile() async {
    final u = _sb.auth.currentUser;
    if (u == null) return null;
    return await _sb.from('profiles').select().eq('id', u.id).maybeSingle();
  }

  static Future<void> upsertMyProfile(Map<String, dynamic> data) async {
    final u = _sb.auth.currentUser;
    if (u == null) return;

    final payload = Map<String, dynamic>.from(data);
    payload['id'] = u.id;

    await _sb.from('profiles').upsert(payload);
  }
}

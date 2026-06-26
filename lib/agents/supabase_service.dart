import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const _url = 'https://qbacvlncbywggswegrgk.supabase.co';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFiYWN2bG5jYnl3Z2dzd2VncmdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0OTMyNTksImV4cCI6MjA5ODA2OTI1OX0.rCKMVATAXynvgd-IYz7JRuegZaWzIlV4N4AYO62GR_g';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(url: _url, anonKey: _anonKey);
    _initialized = true;
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> fetchUser(String userId) async {
    final response =
        await _client.from('users').select().eq('id', userId).single();
    return response;
  }

  Future<List<Map<String, dynamic>>> fetchOrderHistory(String userId) async {
    final response = await _client
        .from('order_history')
        .select()
        .eq('user_id', userId)
        .order('ordered_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchBonusPaths(String userId) async {
    final response = await _client
        .from('bonus_paths')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('urgency_days', ascending: true, nullsFirst: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchBehaviorPatterns(
    String tier,
  ) async {
    final response = await _client
        .from('behavior_patterns')
        .select()
        .contains('applicable_tiers', [tier]);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchPlayEarnHistory(
    String userId,
  ) async {
    final response = await _client
        .from('play_earn_events')
        .select()
        .eq('user_id', userId)
        .order('played_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }
}

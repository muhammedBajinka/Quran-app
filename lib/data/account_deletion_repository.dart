import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AccountDeletionStore {
  Future<bool> hasPendingRequest();
  Future<void> requestDeletion();
  Future<void> cancelRequest();
}

/// Records a request for review; it does not claim the account was removed.
class AccountDeletionRepository implements AccountDeletionStore {
  final SupabaseClient _client;

  AccountDeletionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in to manage account deletion.');
    }
    return user.id;
  }

  @override
  Future<bool> hasPendingRequest() async {
    final row = await _client.from('account_deletion_requests')
        .select('id').eq('user_id', _userId).eq('status', 'pending')
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> requestDeletion() async {
    final userId = _userId;
    try {
      await _client.from('account_deletion_requests').insert({'user_id': userId});
    } on PostgrestException catch (error) {
      // A second tap/session can race with the first insert.
      if (error.code != '23505' || !await hasPendingRequest()) rethrow;
    }
  }

  @override
  Future<void> cancelRequest() async {
    final rows = await _client.from('account_deletion_requests')
        .update({'status': 'cancelled'}).eq('user_id', _userId)
        .eq('status', 'pending').select('id');
    if (rows.isEmpty && await hasPendingRequest()) {
      throw StateError('The request could not be cancelled.');
    }
  }
}

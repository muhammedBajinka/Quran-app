import 'package:flutter/material.dart';
import '../../data/account_deletion_repository.dart';

class AccountDeletionScreen extends StatefulWidget {
  final AccountDeletionStore? repository;
  const AccountDeletionScreen({super.key, this.repository});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  late final AccountDeletionStore _repository =
      widget.repository ?? AccountDeletionRepository();
  bool _loading = true;
  bool _busy = false;
  bool _pending = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadFailed = false; });
    try {
      final pending = await _repository.hasPendingRequest();
      if (!mounted) return;
      setState(() { _pending = pending; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _loadFailed = true; });
    }
  }

  Future<void> _changeRequest() async {
    if (_busy || _loading || _loadFailed) return;
    final cancelling = _pending;
    if (!cancelling) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Request account deletion?'),
          content: const Text('This submits a request for review. Your account '
              'and posts remain available until removal is completed. '
              'You can cancel a pending request here.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep account')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Submit request')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (cancelling) {
        await _repository.cancelRequest();
      } else {
        await _repository.requestDeletion();
      }
      final pending = await _repository.hasPendingRequest();
      if (!mounted) return;
      setState(() => _pending = pending);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          cancelling ? 'Deletion request cancelled.' : 'Deletion request submitted. Your account has not been deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update the deletion request. Refresh its status before retrying.')));
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account deletion')),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Your account and content', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text('Request permanent removal of your account and associated content. '
                  'Requests require review; removal is not automatic and no completion time is promised. '
                  'Submitting a request does not sign you out or delete your posts immediately.'),
              const SizedBox(height: 12),
              const Text('You can delete individual posts from your creator profile now. '
                  'Quran progress and memorization recordings stored on this device are separate from your online account.'),
              const SizedBox(height: 24),
              if (_loadFailed) ...[
                const Text('Could not load your request status.'),
                TextButton(onPressed: _busy ? null : _load, child: const Text('Retry')),
              ] else ...[
                Text(_pending ? 'Deletion request pending' : 'No pending deletion request', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _changeRequest,
                    child: Text(_busy ? 'Updating…' : (_pending ? 'Cancel deletion request' : 'Request account deletion'))),
                TextButton(onPressed: _busy ? null : _load, child: const Text('Refresh status')),
              ],
            ]),
    );
  }
}

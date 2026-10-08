import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/services/media_worker_service.dart';

void main() {
  test('expired session prompts sign-in rather than an uncertain deletion', () {
    expect(
      MediaDeletionException.fromResponse(
        401,
        '{"error":"Invalid session"}',
      ).message,
      contains('Sign in again'),
    );
  });
  test(
    'legacy migration failure is distinguished from transient server errors',
    () {
      expect(
        MediaDeletionException.fromResponse(
          409,
          '{"error":"Media needs storage migration before deletion"}',
        ).message,
        contains('older upload'),
      );
      expect(
        MediaDeletionException.fromResponse(
          502,
          '{"error":"Could not hide post"}',
        ).message,
        contains('server 502'),
      );
    },
  );
  test('ownership failure does not suggest that the post was removed', () {
    expect(
      MediaDeletionException.fromResponse(
        409,
        '{"error":"Storage ownership mismatch"}',
      ).message,
      contains('could not be verified'),
    );
  });
  test(
    'HTML gateway error still produces a useful failed-deletion message',
    () {
      expect(
        MediaDeletionException.fromResponse(
          503,
          '<html>Unavailable</html>',
        ).message,
        'Delete failed (server 503). Please try again.',
      );
    },
  );
}

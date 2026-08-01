import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitpay/core/services/offline_sync_queue_service.dart';
import 'package:splitpay/core/storage/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSyncQueueService Tests', () {
    late OfflineSyncQueueService queueService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();
      queueService = OfflineSyncQueueService();
    });

    test('getQueue returns empty list initially', () {
      expect(queueService.getQueue(), isEmpty);
    });

    test('enqueue adds pending sync action to queue', () async {
      final action = PendingSyncAction(
        id: 'action_1',
        endpoint: '/settlements',
        method: SyncHttpMethod.post,
        body: {'groupId': 'group_123', 'amount': 250.0},
      );

      await queueService.enqueue(action);

      final queue = queueService.getQueue();
      expect(queue.length, equals(1));
      expect(queue.first.id, equals('action_1'));
      expect(queue.first.endpoint, equals('/settlements'));
      expect(queue.first.body['amount'], equals(250.0));
    });

    test('remove deletes action from queue by id', () async {
      final action1 = PendingSyncAction(
        id: 'action_1',
        endpoint: '/settlements',
        method: SyncHttpMethod.post,
        body: {'amount': 100.0},
      );
      final action2 = PendingSyncAction(
        id: 'action_2',
        endpoint: '/expenses',
        method: SyncHttpMethod.post,
        body: {'amount': 500.0},
      );

      await queueService.enqueue(action1);
      await queueService.enqueue(action2);
      expect(queueService.getQueue().length, equals(2));

      await queueService.remove('action_1');

      final queue = queueService.getQueue();
      expect(queue.length, equals(1));
      expect(queue.first.id, equals('action_2'));
    });

    test('clear removes all queued actions', () async {
      final action = PendingSyncAction(
        id: 'action_1',
        endpoint: '/settlements',
        method: SyncHttpMethod.post,
        body: {},
      );

      await queueService.enqueue(action);
      expect(queueService.getQueue().length, equals(1));

      await queueService.clear();

      expect(queueService.getQueue(), isEmpty);
    });
  });
}

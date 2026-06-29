import 'package:integration_test/integration_test.dart';

import 'auth_test.dart' as auth;
import 'transaction_test.dart' as tx;
import 'budget_test.dart' as budget;
import 'navigation_test.dart' as nav;
import 'analytics_test.dart' as analytics;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  auth.main();
  tx.main();
  budget.main();
  nav.main();
  analytics.main();
}

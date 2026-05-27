class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.60:3000/api/v1',
  );

  // Auth
  static const String authGoogle = '/auth/google';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';

  // Users
  static const String usersMe = '/users/me';
  static const String usersSearch = '/users/search';

  // Groups
  static const String groups = '/groups';
  static String groupById(String id) => '/groups/$id';
  static String groupMembers(String id) => '/groups/$id/members';
  static String groupMember(String gId, String mId) => '/groups/$gId/members/$mId';
  static String groupExpenses(String id) => '/groups/$id/expenses';
  static String groupBalances(String id) => '/groups/$id/balances';
  static String groupSettlements(String id) => '/groups/$id/settlements';
  static String groupActivity(String id) => '/groups/$id/activity';

  // Expenses + Settlements
  static const String expenses = '/expenses';
  static String expenseById(String id) => '/expenses/$id';
  static const String settlements = '/settlements';

  // Invites
  static String groupInvites(String id) => '/groups/$id/invites';
  static String inviteByCode(String code) => '/invites/$code';
  static String inviteJoin(String code) => '/invites/$code/join';

  // Notifications
  static const String notifications = '/notifications';
  static String notificationById(String id) => '/notifications/$id';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
  static const String notificationsRegisterToken = '/notifications/register-token';

  // Personal Transactions
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';

  // Custom Categories
  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';

  // Sync
  static const String syncPush = '/sync/transactions';
  static const String syncPull = '/sync/changes';
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_constants.dart';
import '../models/auth_user_model.dart';
import '../models/balance_model.dart';
import '../models/expense_participant_model.dart';
import '../models/group_expense_model.dart';
import '../models/group_model.dart';
import '../models/activity_model.dart';
import '../models/member_model.dart';
import '../models/settlement_model.dart';

const _useMock = false;

class GroupApiService {
  final Dio _dio;

  GroupApiService(this._dio);

  // ──────────────────────────────────────────────
  // Groups
  // ──────────────────────────────────────────────

  Future<List<GroupModel>> getGroups() async {
    if (_useMock) return _mockGroups();
    final res = await _dio.get(ApiConstants.groups);
    final list = res.data['data'] as List<dynamic>;
    return list.map((g) => GroupModel.fromJson(g as Map<String, dynamic>)).toList();
  }

  Future<GroupModel> createGroup({
    required String name,
    String? description,
  }) async {
    if (_useMock) {
      final now = DateTime.now();
      return GroupModel(
        id: 'grp_${now.millisecondsSinceEpoch}',
        name: name,
        description: description,
        createdById: 'user_1',
        members: [_mockMember('user_1', 'You', 'you@email.com', role: 'ADMIN')],
        createdAt: now,
        updatedAt: now,
      );
    }
    final res = await _dio.post(
      ApiConstants.groups,
      data: {'name': name, if (description != null) 'description': description},
    );
    return GroupModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<GroupModel> getGroup(String groupId) async {
    if (_useMock) {
      return _mockGroups().firstWhere(
        (g) => g.id == groupId,
        orElse: () => _mockGroups().first,
      );
    }
    final res = await _dio.get(ApiConstants.groupById(groupId));
    return GroupModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> addMember(String groupId, String userId) async {
    if (_useMock) return;
    await _dio.post(
      ApiConstants.groupMembers(groupId),
      data: {'userId': userId},
    );
  }

  Future<void> removeMember(String groupId, String memberId) async {
    if (_useMock) return;
    await _dio.delete(ApiConstants.groupMember(groupId, memberId));
  }

  Future<GroupModel> updateGroup(
    String groupId, {
    String? name,
    String? description,
  }) async {
    final res = await _dio.patch(
      ApiConstants.groupById(groupId),
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
    );
    return GroupModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteGroup(String groupId) async {
    await _dio.delete(ApiConstants.groupById(groupId));
  }

  Future<void> updateMemberRole(String groupId, String memberId, String role) async {
    await _dio.patch(
      ApiConstants.groupMember(groupId, memberId),
      data: {'role': role},
    );
  }

  Future<Map<String, dynamic>> generateInvite(String groupId) async {
    final res = await _dio.post(ApiConstants.groupInvites(groupId));
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInviteInfo(String code) async {
    final res = await _dio.get(ApiConstants.inviteByCode(code));
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<GroupModel> joinViaInvite(String code) async {
    final res = await _dio.post(ApiConstants.inviteJoin(code));
    return GroupModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // Expenses
  // ──────────────────────────────────────────────

  Future<List<GroupExpenseModel>> getGroupExpenses(String groupId) async {
    if (_useMock) return _mockExpenses(groupId);
    final res = await _dio.get(ApiConstants.groupExpenses(groupId));
    final list = res.data['data'] as List<dynamic>;
    return list
        .map((e) => GroupExpenseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupExpenseModel> updateExpense(
    String expenseId, {
    String? title,
    double? amount,
    String? paidById,
    String? splitType,
    List<Map<String, dynamic>>? participants,
    String? notes,
  }) async {
    final res = await _dio.patch(
      ApiConstants.expenseById(expenseId),
      data: {
        if (title != null) 'title': title,
        if (amount != null) 'amount': amount,
        if (paidById != null) 'paidById': paidById,
        if (splitType != null) 'splitType': splitType,
        if (participants != null) 'participants': participants,
        if (notes != null) 'notes': notes,
      },
    );
    return GroupExpenseModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _dio.delete(ApiConstants.expenseById(expenseId));
  }

  Future<GroupExpenseModel> createExpense({
    required String groupId,
    required String title,
    required double amount,
    required String paidById,
    required String splitType,
    required List<Map<String, dynamic>> participants,
    String? notes,
  }) async {
    if (_useMock) {
      final now = DateTime.now();
      return GroupExpenseModel(
        id: 'exp_${now.millisecondsSinceEpoch}',
        groupId: groupId,
        title: title,
        amount: amount,
        paidById: paidById,
        paidByName: 'You',
        splitType: splitType,
        participants: participants
            .map((p) => ExpenseParticipantModel.fromJson(p))
            .toList(),
        notes: notes,
        date: now,
        createdAt: now,
      );
    }
    // BE route is POST /expenses (groupId goes in the body)
    final res = await _dio.post(
      ApiConstants.expenses,
      data: {
        'groupId': groupId,
        'title': title,
        'amount': amount,
        'paidById': paidById,
        'splitType': splitType,
        'participants': participants,
        if (notes != null) 'notes': notes,
      },
    );
    return GroupExpenseModel.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // Balances
  // ──────────────────────────────────────────────

  Future<GroupBalanceSummary> getGroupBalances(
    String groupId,
    String currentUserId,
  ) async {
    if (_useMock) return _mockBalances(groupId, currentUserId);
    final res = await _dio.get(ApiConstants.groupBalances(groupId));
    return GroupBalanceSummary.fromJson(
      res.data['data'] as Map<String, dynamic>,
      currentUserId,
    );
  }

  // ──────────────────────────────────────────────
  // Settlements
  // ──────────────────────────────────────────────

  Future<List<SettlementModel>> getGroupSettlements(String groupId) async {
    if (_useMock) return _mockSettlements(groupId);
    final res = await _dio.get(ApiConstants.groupSettlements(groupId));
    final list = res.data['data'] as List<dynamic>;
    return list
        .map((s) => SettlementModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<SettlementModel> createSettlement({
    required String groupId,
    required String payeeId,
    required double amount,
    String? notes,
  }) async {
    if (_useMock) {
      final now = DateTime.now();
      return SettlementModel(
        id: 'set_${now.millisecondsSinceEpoch}',
        groupId: groupId,
        payerId: 'user_1',
        payerName: 'You',
        payeeId: payeeId,
        payeeName: 'Rahul Sharma',
        amount: amount,
        notes: notes,
        settledAt: now,
      );
    }
    // BE route is POST /settlements (groupId goes in the body)
    final res = await _dio.post(
      ApiConstants.settlements,
      data: {
        'groupId': groupId,
        'payeeId': payeeId,
        'amount': amount,
        if (notes != null) 'notes': notes,
      },
    );
    return SettlementModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // Activity
  // ──────────────────────────────────────────────

  Future<List<ActivityModel>> getGroupActivity(String groupId) async {
    if (_useMock) return _mockActivity(groupId);
    final res = await _dio.get(ApiConstants.groupActivity(groupId));
    final list = res.data['data'] as List<dynamic>;
    return list
        .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────────
  // Users
  // ──────────────────────────────────────────────

  Future<List<AuthUserModel>> searchUsers(String query) async {
    if (_useMock) return _mockUserSearch(query);
    final res = await _dio.get(
      ApiConstants.usersSearch,
      queryParameters: {'q': query},
    );
    final list = res.data['data'] as List<dynamic>;
    return list
        .map((u) => AuthUserModel.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────────
  // Mock data helpers
  // ──────────────────────────────────────────────

  MemberModel _mockMember(
    String userId,
    String name,
    String email, {
    String role = 'MEMBER',
    String? avatar,
  }) {
    return MemberModel(
      id: 'mem_$userId',
      userId: userId,
      name: name,
      email: email,
      avatar: avatar,
      role: role,
      joinedAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  List<GroupModel> _mockGroups() {
    final now = DateTime.now();
    return [
      GroupModel(
        id: 'grp_1',
        name: 'Goa Trip 2024',
        description: 'Beach trip with the squad',
        createdById: 'user_1',
        members: [
          _mockMember('user_1', 'You', 'you@email.com', role: 'ADMIN'),
          _mockMember('user_2', 'Rahul Sharma', 'rahul@email.com'),
          _mockMember('user_3', 'Priya Patel', 'priya@email.com'),
          _mockMember('user_4', 'Amit Kumar', 'amit@email.com'),
        ],
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      GroupModel(
        id: 'grp_2',
        name: 'Flat Expenses',
        description: 'Monthly rent, groceries, utilities',
        createdById: 'user_2',
        members: [
          _mockMember('user_1', 'You', 'you@email.com'),
          _mockMember('user_2', 'Rahul Sharma', 'rahul@email.com', role: 'ADMIN'),
          _mockMember('user_5', 'Sneha Gupta', 'sneha@email.com'),
        ],
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      GroupModel(
        id: 'grp_3',
        name: 'Office Lunch Gang',
        description: 'Daily lunch and coffee runs',
        createdById: 'user_1',
        members: [
          _mockMember('user_1', 'You', 'you@email.com', role: 'ADMIN'),
          _mockMember('user_3', 'Priya Patel', 'priya@email.com'),
          _mockMember('user_6', 'Karan Mehta', 'karan@email.com'),
          _mockMember('user_7', 'Divya Nair', 'divya@email.com'),
          _mockMember('user_8', 'Vijay Reddy', 'vijay@email.com'),
        ],
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }

  List<GroupExpenseModel> _mockExpenses(String groupId) {
    final now = DateTime.now();

    final Map<String, List<GroupExpenseModel>> mockData = {
      'grp_1': [
        GroupExpenseModel(
          id: 'exp_1',
          groupId: groupId,
          title: 'Hotel booking',
          amount: 12000,
          paidById: 'user_1',
          paidByName: 'You',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 3000),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 3000),
            ExpenseParticipantModel(userId: 'user_3', userName: 'Priya Patel', share: 3000),
            ExpenseParticipantModel(userId: 'user_4', userName: 'Amit Kumar', share: 3000),
          ],
          date: now.subtract(const Duration(days: 10)),
          createdAt: now.subtract(const Duration(days: 10)),
        ),
        GroupExpenseModel(
          id: 'exp_2',
          groupId: groupId,
          title: 'Beach shack dinner',
          amount: 3200,
          paidById: 'user_2',
          paidByName: 'Rahul Sharma',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 800),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 800),
            ExpenseParticipantModel(userId: 'user_3', userName: 'Priya Patel', share: 800),
            ExpenseParticipantModel(userId: 'user_4', userName: 'Amit Kumar', share: 800),
          ],
          date: now.subtract(const Duration(days: 9)),
          createdAt: now.subtract(const Duration(days: 9)),
        ),
        GroupExpenseModel(
          id: 'exp_3',
          groupId: groupId,
          title: 'Scuba diving',
          amount: 5600,
          paidById: 'user_3',
          paidByName: 'Priya Patel',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 1400),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 1400),
            ExpenseParticipantModel(userId: 'user_3', userName: 'Priya Patel', share: 1400),
            ExpenseParticipantModel(userId: 'user_4', userName: 'Amit Kumar', share: 1400),
          ],
          date: now.subtract(const Duration(days: 8)),
          createdAt: now.subtract(const Duration(days: 8)),
        ),
        GroupExpenseModel(
          id: 'exp_4',
          groupId: groupId,
          title: 'Taxi & fuel',
          amount: 2400,
          paidById: 'user_1',
          paidByName: 'You',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 600),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 600),
            ExpenseParticipantModel(userId: 'user_3', userName: 'Priya Patel', share: 600),
            ExpenseParticipantModel(userId: 'user_4', userName: 'Amit Kumar', share: 600),
          ],
          date: now.subtract(const Duration(days: 7)),
          createdAt: now.subtract(const Duration(days: 7)),
        ),
        GroupExpenseModel(
          id: 'exp_5',
          groupId: groupId,
          title: 'Drinks & snacks',
          amount: 1800,
          paidById: 'user_4',
          paidByName: 'Amit Kumar',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 450),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 450),
            ExpenseParticipantModel(userId: 'user_3', userName: 'Priya Patel', share: 450),
            ExpenseParticipantModel(userId: 'user_4', userName: 'Amit Kumar', share: 450),
          ],
          date: now.subtract(const Duration(days: 6)),
          createdAt: now.subtract(const Duration(days: 6)),
        ),
      ],
      'grp_2': [
        GroupExpenseModel(
          id: 'exp_6',
          groupId: groupId,
          title: 'Monthly rent',
          amount: 45000,
          paidById: 'user_2',
          paidByName: 'Rahul Sharma',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 15000),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 15000),
            ExpenseParticipantModel(userId: 'user_5', userName: 'Sneha Gupta', share: 15000),
          ],
          date: now.subtract(const Duration(days: 2)),
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        GroupExpenseModel(
          id: 'exp_7',
          groupId: groupId,
          title: 'Electricity bill',
          amount: 3600,
          paidById: 'user_1',
          paidByName: 'You',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 1200),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 1200),
            ExpenseParticipantModel(userId: 'user_5', userName: 'Sneha Gupta', share: 1200),
          ],
          date: now.subtract(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 5)),
        ),
        GroupExpenseModel(
          id: 'exp_8',
          groupId: groupId,
          title: 'Groceries',
          amount: 2800,
          paidById: 'user_5',
          paidByName: 'Sneha Gupta',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 933.33),
            ExpenseParticipantModel(userId: 'user_2', userName: 'Rahul Sharma', share: 933.33),
            ExpenseParticipantModel(userId: 'user_5', userName: 'Sneha Gupta', share: 933.34),
          ],
          date: now.subtract(const Duration(days: 3)),
          createdAt: now.subtract(const Duration(days: 3)),
        ),
      ],
      'grp_3': [
        GroupExpenseModel(
          id: 'exp_9',
          groupId: groupId,
          title: 'Lunch at Barbeque Nation',
          amount: 4500,
          paidById: 'user_1',
          paidByName: 'You',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 900),
            ExpenseParticipantModel(userId: 'user_3', userName: 'Priya Patel', share: 900),
            ExpenseParticipantModel(userId: 'user_6', userName: 'Karan Mehta', share: 900),
            ExpenseParticipantModel(userId: 'user_7', userName: 'Divya Nair', share: 900),
            ExpenseParticipantModel(userId: 'user_8', userName: 'Vijay Reddy', share: 900),
          ],
          date: now.subtract(const Duration(days: 1)),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        GroupExpenseModel(
          id: 'exp_10',
          groupId: groupId,
          title: 'Coffee & desserts',
          amount: 750,
          paidById: 'user_6',
          paidByName: 'Karan Mehta',
          splitType: 'EQUAL',
          participants: [
            ExpenseParticipantModel(userId: 'user_1', userName: 'You', share: 150),
            ExpenseParticipantModel(userId: 'user_3', userName: 'Priya Patel', share: 150),
            ExpenseParticipantModel(userId: 'user_6', userName: 'Karan Mehta', share: 150),
            ExpenseParticipantModel(userId: 'user_7', userName: 'Divya Nair', share: 150),
            ExpenseParticipantModel(userId: 'user_8', userName: 'Vijay Reddy', share: 150),
          ],
          date: now.subtract(const Duration(hours: 5)),
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
      ],
    };

    return mockData[groupId] ?? mockData['grp_1']!;
  }

  GroupBalanceSummary _mockBalances(String groupId, String currentUserId) {
    final Map<String, List<BalanceModel>> mockBalances = {
      'grp_1': [
        BalanceModel(
          fromUserId: 'user_2',
          fromUserName: 'Rahul Sharma',
          toUserId: 'user_1',
          toUserName: 'You',
          amount: 2200,
        ),
        BalanceModel(
          fromUserId: 'user_1',
          fromUserName: 'You',
          toUserId: 'user_3',
          toUserName: 'Priya Patel',
          amount: 800,
        ),
        BalanceModel(
          fromUserId: 'user_4',
          fromUserName: 'Amit Kumar',
          toUserId: 'user_2',
          toUserName: 'Rahul Sharma',
          amount: 1400,
        ),
      ],
      'grp_2': [
        BalanceModel(
          fromUserId: 'user_1',
          fromUserName: 'You',
          toUserId: 'user_2',
          toUserName: 'Rahul Sharma',
          amount: 13800,
        ),
        BalanceModel(
          fromUserId: 'user_5',
          fromUserName: 'Sneha Gupta',
          toUserId: 'user_2',
          toUserName: 'Rahul Sharma',
          amount: 13800,
        ),
      ],
      'grp_3': [
        BalanceModel(
          fromUserId: 'user_3',
          fromUserName: 'Priya Patel',
          toUserId: 'user_1',
          toUserName: 'You',
          amount: 750,
        ),
        BalanceModel(
          fromUserId: 'user_7',
          fromUserName: 'Divya Nair',
          toUserId: 'user_1',
          toUserName: 'You',
          amount: 750,
        ),
        BalanceModel(
          fromUserId: 'user_8',
          fromUserName: 'Vijay Reddy',
          toUserId: 'user_1',
          toUserName: 'You',
          amount: 750,
        ),
      ],
    };

    final balances = mockBalances[groupId] ?? [];

    double owed = 0;
    double lent = 0;
    for (final b in balances) {
      if (b.fromUserId == currentUserId) owed += b.amount;
      if (b.toUserId == currentUserId) lent += b.amount;
    }

    return GroupBalanceSummary(
      balances: balances,
      totalOwed: owed,
      totalLent: lent,
    );
  }

  List<SettlementModel> _mockSettlements(String groupId) {
    final now = DateTime.now();
    return [
      SettlementModel(
        id: 'set_1',
        groupId: groupId,
        payerId: 'user_2',
        payerName: 'Rahul Sharma',
        payeeId: 'user_1',
        payeeName: 'You',
        amount: 1000,
        settledAt: now.subtract(const Duration(days: 3)),
      ),
      SettlementModel(
        id: 'set_2',
        groupId: groupId,
        payerId: 'user_4',
        payerName: 'Amit Kumar',
        payeeId: 'user_3',
        payeeName: 'Priya Patel',
        amount: 500,
        notes: 'GPay transfer',
        settledAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<ActivityModel> _mockActivity(String groupId) {
    final now = DateTime.now();
    return [
      ActivityModel(
        id: 'act_1',
        groupId: groupId,
        userId: 'user_1',
        userName: 'You',
        type: ActivityType.expenseAdded,
        metadata: {'title': 'Hotel booking', 'amount': 12000},
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      ActivityModel(
        id: 'act_2',
        groupId: groupId,
        userId: 'user_2',
        userName: 'Rahul Sharma',
        type: ActivityType.expenseAdded,
        metadata: {'title': 'Beach shack dinner', 'amount': 3200},
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      ActivityModel(
        id: 'act_3',
        groupId: groupId,
        userId: 'user_2',
        userName: 'Rahul Sharma',
        type: ActivityType.settlementCompleted,
        metadata: {'amount': 1000, 'payeeName': 'You'},
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      ActivityModel(
        id: 'act_4',
        groupId: groupId,
        userId: 'user_3',
        userName: 'Priya Patel',
        type: ActivityType.memberJoined,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      ActivityModel(
        id: 'act_5',
        groupId: groupId,
        userId: 'user_1',
        userName: 'You',
        type: ActivityType.groupCreated,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
    ];
  }

  List<AuthUserModel> _mockUserSearch(String query) {
    final allUsers = [
      AuthUserModel(
        id: 'user_9',
        email: 'arjun@email.com',
        name: 'Arjun Singh',
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
      ),
      AuthUserModel(
        id: 'user_10',
        email: 'neha@email.com',
        name: 'Neha Verma',
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
      ),
      AuthUserModel(
        id: 'user_11',
        email: 'saurabh@email.com',
        name: 'Saurabh Joshi',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      AuthUserModel(
        id: 'user_12',
        email: 'meera@email.com',
        name: 'Meera Krishnan',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    ];

    if (query.isEmpty) return allUsers;
    final q = query.toLowerCase();
    return allUsers
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }
}

final groupApiServiceProvider = Provider<GroupApiService>((ref) {
  return GroupApiService(ref.watch(dioProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/activity_model.dart';
import '../data/models/balance_model.dart';
import '../data/models/group_expense_model.dart';
import '../data/models/group_model.dart';
import '../data/models/settlement_model.dart';
import '../data/services/group_api_service.dart';
import 'auth_provider.dart';

// ──────────────────────────────────────────────
// Groups list
// ──────────────────────────────────────────────

class GroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  @override
  Future<List<GroupModel>> build() async {
    return ref.read(groupApiServiceProvider).getGroups();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(groupApiServiceProvider).getGroups(),
    );
  }

  Future<GroupModel> createGroup(
    String name, {
    String? description,
    String? avatar,
    List<String> memberIds = const [],
  }) async {
    final service = ref.read(groupApiServiceProvider);
    final group = await service.createGroup(
      name: name,
      description: description,
      avatar: avatar,
      memberIds: memberIds,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([group, ...current]);
    return group;
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    await ref.read(groupApiServiceProvider).addMember(groupId, userId);
    await refresh();
  }

  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    await ref.read(groupApiServiceProvider).removeMember(groupId, memberId);
    await refresh();
  }
}

final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<GroupModel>>(GroupsNotifier.new);

// ──────────────────────────────────────────────
// Single group detail
// ──────────────────────────────────────────────

class GroupDetailNotifier
    extends FamilyAsyncNotifier<GroupModel, String> {
  @override
  Future<GroupModel> build(String arg) async {
    return ref.read(groupApiServiceProvider).getGroup(arg);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(groupApiServiceProvider).getGroup(arg),
    );
  }
}

final groupDetailProvider =
    AsyncNotifierProviderFamily<GroupDetailNotifier, GroupModel,
        String>(GroupDetailNotifier.new);

// ──────────────────────────────────────────────
// Group expenses
// ──────────────────────────────────────────────

final groupExpensesProvider =
    FutureProvider.family<List<GroupExpenseModel>, String>(
  (ref, groupId) async {
    return ref.read(groupApiServiceProvider).getGroupExpenses(groupId);
  },
);

// ──────────────────────────────────────────────
// Group balances
// ──────────────────────────────────────────────

final groupBalancesProvider =
    FutureProvider.family<GroupBalanceSummary, String>(
  (ref, groupId) async {
    final userId = ref.watch(currentUserProvider)?.id ?? 'user_1';
    return ref
        .read(groupApiServiceProvider)
        .getGroupBalances(groupId, userId);
  },
);

// ──────────────────────────────────────────────
// Group activity
// ──────────────────────────────────────────────

final groupActivityProvider =
    FutureProvider.family<List<ActivityModel>, String>(
  (ref, groupId) async {
    return ref.read(groupApiServiceProvider).getGroupActivity(groupId);
  },
);

// ──────────────────────────────────────────────
// Group settlements
// ──────────────────────────────────────────────

final groupSettlementsProvider =
    FutureProvider.family<List<SettlementModel>, String>(
  (ref, groupId) async {
    return ref.read(groupApiServiceProvider).getGroupSettlements(groupId);
  },
);

// ──────────────────────────────────────────────
// Group search
// ──────────────────────────────────────────────

final groupSearchQueryProvider = StateProvider<String>((_) => '');

final searchedGroupsProvider = Provider<List<GroupModel>>((ref) {
  final groups = ref.watch(groupsProvider).valueOrNull ?? [];
  final query = ref.watch(groupSearchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) return groups;
  return groups.where((g) {
    return g.name.toLowerCase().contains(query) ||
        (g.description?.toLowerCase().contains(query) ?? false);
  }).toList();
});

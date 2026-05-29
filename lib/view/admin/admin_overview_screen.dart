import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/api_service.dart';

/// Full admin operations console — gated by the `is_admin()` SQL helper.
///
/// Three connected views over the same ground truth:
///
///   1. **Providers** — every provider business with owner contact, joined
///      date, place count, effective plan, moderation status, and an action
///      menu (approve / suspend / reject / pending).
///   2. **Users** — every signed-up account with their role (admin / provider
///      / user), email, phone, joined date. Lets the admin tell a regular
///      visitor apart from a provider apart from a fellow admin at a glance.
///   3. **Subscriptions** — every currently-active paid subscription with
///      tier, billing cycle (monthly/yearly), gateway/source (demo, manual,
///      Paymob, …), amount paid, period_start → period_end, and the
///      business it belongs to. This is where revenue lives.
///
/// A KPI strip across the top stays visible regardless of the active tab so
/// the admin always sees the headline numbers: total users, providers, paid
/// subs, pending approvals, projected MRR.
///
/// Everything reads directly from the schema (`profiles`, `user_roles`,
/// `providers`, `provider_current_plan`, `provider_subscriptions`) — no
/// intermediate caching — so the admin always sees live truth, never a
/// stale snapshot. RLS guarantees non-admin sessions get empty rows.
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<_AdminData> _future;
  String _search = '';
  PlanTier? _filterTier;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<_AdminData> _load() async {
    await ApiService.ensureSupabaseInitialized();
    final client = Supabase.instance.client;

    // 1. Every profile (every signed-up human).
    final profileRows = await client
        .from('profiles')
        .select('id,full_name,email,phone,created_at')
        .order('created_at', ascending: false)
        .limit(500);

    // 2. Roles — used to bucket profiles into admin / provider / user.
    final roleRows = await client
        .from('user_roles')
        .select('user_id,role,revoked_at');

    final rolesByUser = <String, Set<String>>{};
    for (final r in (roleRows as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      if (m['revoked_at'] != null) continue;
      final uid = m['user_id'] as String;
      final role = m['role'] as String;
      rolesByUser.putIfAbsent(uid, () => <String>{}).add(role);
    }

    // 3. Providers + their owner ids so we can join back to profiles.
    final providerRows = await client
        .from('providers')
        .select('id,owner_id,business_name,contact_email,contact_phone,'
            'status,created_at')
        .order('created_at', ascending: false)
        .limit(500);

    final providerIds = (providerRows as List)
        .map((r) => (r as Map)['id'] as String)
        .toList();

    // 4. Effective plan per provider (view collapses inactive rows to Free).
    Map<String, _PlanSnap> planByProvider = {};
    if (providerIds.isNotEmpty) {
      final planRows = await client
          .from('provider_current_plan')
          .select('provider_id,tier,period_end,cancel_at_period_end,status')
          .inFilter('provider_id', providerIds);
      for (final r in (planRows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        planByProvider[m['provider_id'] as String] = _PlanSnap(
          tier: PlanTierX.fromWire(m['tier'] as String? ?? 'free'),
          periodEnd: _parseDate(m['period_end']),
          cancelAtPeriodEnd: m['cancel_at_period_end'] == true,
          status: m['status'] as String? ?? 'active',
        );
      }
    }

    // 5. Active raw subscriptions for the Subscriptions tab — the view above
    //    flattens to "current plan" but for the revenue/audit view we want
    //    the underlying row (billing cycle, gateway, amount, metadata).
    final subRows = await client
        .from('provider_subscriptions')
        .select('id,provider_id,tier,status,gateway,period_start,period_end,'
            'cancel_at_period_end,amount_paid_egp,currency,metadata,created_at')
        .inFilter('status', ['active', 'trialing', 'past_due'])
        .order('created_at', ascending: false)
        .limit(500);

    // 6. Place count per provider — useful to spot active vs ghost accounts.
    Map<String, int> placeCountByProvider = {};
    if (providerIds.isNotEmpty) {
      try {
        final placeRows = await client
            .from('places')
            .select('provider_id')
            .inFilter('provider_id', providerIds);
        for (final r in (placeRows as List)) {
          final pid = (r as Map)['provider_id'] as String?;
          if (pid == null) continue;
          placeCountByProvider[pid] = (placeCountByProvider[pid] ?? 0) + 1;
        }
      } catch (_) {
        // places table may RLS-block — admins should be able to read it, but
        // if not, just leave counts at 0 rather than failing the whole load.
      }
    }

    // 7. Subscription catalog so we can resolve the yearly-vs-monthly amount
    //    for any sub whose row has amount=0 (legacy demo entries).
    Map<PlanTier, _CatalogPrice> catalog = {};
    try {
      final catRows = await client
          .from('subscription_plans')
          .select('tier,price_monthly_egp,price_yearly_egp');
      for (final r in (catRows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        catalog[PlanTierX.fromWire(m['tier'] as String)] = _CatalogPrice(
          monthly: (m['price_monthly_egp'] as int?) ?? 0,
          yearly: (m['price_yearly_egp'] as int?) ?? 0,
        );
      }
    } catch (_) {/* swallow — public catalog rarely fails */}

    // ----- Assemble view models ------------------------------------------------

    final profilesById = <String, _UserRow>{};
    for (final r in (profileRows as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      final uid = m['id'] as String;
      final roles = rolesByUser[uid] ?? const <String>{};
      profilesById[uid] = _UserRow(
        id: uid,
        name: (m['full_name'] as String?) ?? '—',
        email: (m['email'] as String?) ?? '—',
        phone: m['phone'] as String?,
        joinedAt: _parseDate(m['created_at']),
        isAdmin: roles.contains('admin'),
        isProvider: roles.contains('provider'),
      );
    }

    final providers = (providerRows).map<_ProviderRow>((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['id'] as String;
      final ownerId = m['owner_id'] as String?;
      final ownerProfile = ownerId == null ? null : profilesById[ownerId];
      final snap = planByProvider[id];
      return _ProviderRow(
        id: id,
        ownerId: ownerId,
        businessName: (m['business_name'] as String?) ?? '—',
        contactEmail: (m['contact_email'] as String?) ?? ownerProfile?.email ?? '—',
        contactPhone: (m['contact_phone'] as String?) ?? ownerProfile?.phone,
        status: (m['status'] as String?) ?? 'pending',
        createdAt: _parseDate(m['created_at']),
        tier: snap?.tier ?? PlanTier.free,
        periodEnd: snap?.periodEnd,
        cancelAtPeriodEnd: snap?.cancelAtPeriodEnd ?? false,
        placeCount: placeCountByProvider[id] ?? 0,
      );
    }).toList();

    final providerNameById = {for (final p in providers) p.id: p.businessName};

    final subs = (subRows as List).map<_SubRow>((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final tier = PlanTierX.fromWire(m['tier'] as String? ?? 'free');
      final start = _parseDate(m['period_start']);
      final end = _parseDate(m['period_end']);
      final meta = (m['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
      final yearlyFlag = meta['yearly'] == true ||
          (start != null && end != null && end.difference(start).inDays > 90);
      var amount = (m['amount_paid_egp'] as int?) ?? 0;
      if (amount == 0 && catalog[tier] != null) {
        amount = yearlyFlag ? catalog[tier]!.yearly : catalog[tier]!.monthly;
      }
      return _SubRow(
        id: m['id'] as String,
        providerId: m['provider_id'] as String,
        providerName: providerNameById[m['provider_id']] ?? '—',
        tier: tier,
        status: m['status'] as String? ?? 'active',
        gateway: m['gateway'] as String? ?? 'manual',
        yearly: yearlyFlag,
        periodStart: start,
        periodEnd: end,
        cancelAtPeriodEnd: m['cancel_at_period_end'] == true,
        amountEgp: amount,
        source: (meta['source'] as String?) ?? '',
      );
    }).toList();

    // Project MRR: yearly subs → /12, monthly subs counted as-is.
    var mrr = 0;
    for (final s in subs) {
      mrr += s.yearly ? (s.amountEgp ~/ 12) : s.amountEgp;
    }

    return _AdminData(
      users: profilesById.values.toList()
        ..sort((a, b) => (b.joinedAt ?? DateTime(0))
            .compareTo(a.joinedAt ?? DateTime(0))),
      providers: providers,
      subscriptions: subs,
      paidSubsCount: subs.where((s) => s.tier != PlanTier.free).length,
      pendingProvidersCount:
          providers.where((p) => p.status == 'pending').length,
      projectedMrrEgp: mrr,
    );
  }

  Future<void> _setStatus(_ProviderRow row, String next) async {
    try {
      await Supabase.instance.client
          .from('providers')
          .update({'status': next}).eq('id', row.id);
      AppFeedback.success(AppCopy.successGeneric);
      if (!mounted) return;
      setState(() => _future = _load());
    } catch (_) {
      AppFeedback.error(AppCopy.errorGeneric);
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return AppPageScaffold(
        unpadded: true,
        header: const AppPageHeader(title: AppCopy.adminTitle),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: AppStateView.search(
            title: 'لوحة الإدارة للويب فقط',
            message:
                'الإدارة والمراقبة موجودة في الويب فقط، وليست جزءًا من الموبايل.',
          ),
        ),
      );
    }

    return AppPageScaffold(
      unpadded: true,
      header: const AppPageHeader(title: AppCopy.adminTitle),
      body: FutureBuilder<_AdminData>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColor.primary),
            );
          }
          final data = snap.data ?? _AdminData.empty();
          return RefreshIndicator(
            color: AppColor.primary,
            onRefresh: _refresh,
            child: Column(
              children: [
                _KpiStrip(data: data),
                _TabsBar(controller: _tabs),
                _SearchBar(
                  onChanged: (v) => setState(() => _search = v.trim()),
                  onTierChanged: (t) => setState(() => _filterTier = t),
                  filterTier: _filterTier,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ProvidersTab(
                        rows: _applyProviderFilters(data.providers),
                        onAction: _setStatus,
                      ),
                      _UsersTab(rows: _applyUserFilter(data.users)),
                      _SubscriptionsTab(
                        rows: _applySubFilters(data.subscriptions),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  List<_ProviderRow> _applyProviderFilters(List<_ProviderRow> rows) {
    final q = _search.toLowerCase();
    return rows.where((r) {
      if (_filterTier != null && r.tier != _filterTier) return false;
      if (q.isEmpty) return true;
      return r.businessName.toLowerCase().contains(q) ||
          r.contactEmail.toLowerCase().contains(q);
    }).toList();
  }

  List<_UserRow> _applyUserFilter(List<_UserRow> rows) {
    final q = _search.toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            r.email.toLowerCase().contains(q))
        .toList();
  }

  List<_SubRow> _applySubFilters(List<_SubRow> rows) {
    final q = _search.toLowerCase();
    return rows.where((r) {
      if (_filterTier != null && r.tier != _filterTier) return false;
      if (q.isEmpty) return true;
      return r.providerName.toLowerCase().contains(q);
    }).toList();
  }
}

// =============================================================================
// View models
// =============================================================================

class _AdminData {
  _AdminData({
    required this.users,
    required this.providers,
    required this.subscriptions,
    required this.paidSubsCount,
    required this.pendingProvidersCount,
    required this.projectedMrrEgp,
  });

  factory _AdminData.empty() => _AdminData(
        users: const [],
        providers: const [],
        subscriptions: const [],
        paidSubsCount: 0,
        pendingProvidersCount: 0,
        projectedMrrEgp: 0,
      );

  final List<_UserRow> users;
  final List<_ProviderRow> providers;
  final List<_SubRow> subscriptions;
  final int paidSubsCount;
  final int pendingProvidersCount;
  final int projectedMrrEgp;
}

class _UserRow {
  _UserRow({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.joinedAt,
    required this.isAdmin,
    required this.isProvider,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final DateTime? joinedAt;
  final bool isAdmin;
  final bool isProvider;
}

class _ProviderRow {
  _ProviderRow({
    required this.id,
    required this.ownerId,
    required this.businessName,
    required this.contactEmail,
    required this.contactPhone,
    required this.status,
    required this.createdAt,
    required this.tier,
    required this.periodEnd,
    required this.cancelAtPeriodEnd,
    required this.placeCount,
  });

  final String id;
  final String? ownerId;
  final String businessName;
  final String contactEmail;
  final String? contactPhone;
  final String status;
  final DateTime? createdAt;
  final PlanTier tier;
  final DateTime? periodEnd;
  final bool cancelAtPeriodEnd;
  final int placeCount;
}

class _SubRow {
  _SubRow({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.tier,
    required this.status,
    required this.gateway,
    required this.yearly,
    required this.periodStart,
    required this.periodEnd,
    required this.cancelAtPeriodEnd,
    required this.amountEgp,
    required this.source,
  });

  final String id;
  final String providerId;
  final String providerName;
  final PlanTier tier;
  final String status;
  final String gateway;
  final bool yearly;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool cancelAtPeriodEnd;
  final int amountEgp;
  final String source;
}

class _PlanSnap {
  _PlanSnap({
    required this.tier,
    required this.periodEnd,
    required this.cancelAtPeriodEnd,
    required this.status,
  });

  final PlanTier tier;
  final DateTime? periodEnd;
  final bool cancelAtPeriodEnd;
  final String status;
}

class _CatalogPrice {
  _CatalogPrice({required this.monthly, required this.yearly});
  final int monthly;
  final int yearly;
}

// =============================================================================
// KPI strip
// =============================================================================

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.data});
  final _AdminData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.lg.h,
        AppSpacing.lg.w,
        AppSpacing.md.h,
      ),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(bottom: BorderSide(color: AppColor.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _KpiCard(
              label: AppCopy.adminKpiTotalUsers,
              value: data.users.length.toString(),
              icon: Icons.people_alt_rounded,
              tone: AppColor.primary,
            ),
            gapH(AppSpacing.md),
            _KpiCard(
              label: AppCopy.adminKpiProviders,
              value: data.providers.length.toString(),
              icon: Icons.storefront_rounded,
              tone: AppColor.info,
            ),
            gapH(AppSpacing.md),
            _KpiCard(
              label: AppCopy.adminKpiPaidSubs,
              value: data.paidSubsCount.toString(),
              icon: Icons.workspace_premium_rounded,
              tone: AppColor.success,
            ),
            gapH(AppSpacing.md),
            _KpiCard(
              label: AppCopy.adminKpiPending,
              value: data.pendingProvidersCount.toString(),
              icon: Icons.hourglass_top_rounded,
              tone: AppColor.warning,
            ),
            gapH(AppSpacing.md),
            _KpiCard(
              label: AppCopy.adminKpiMrr,
              value: '${data.projectedMrrEgp} ج.م',
              icon: Icons.payments_rounded,
              tone: AppColor.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200.w,
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColor.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tone, size: 22.sp),
          ),
          gapH(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.caption.copyWith(
                    color: AppColor.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                gapV(AppSpacing.xs),
                Text(
                  value,
                  style: AppText.headingSm.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tabs + Search
// =============================================================================

class _TabsBar extends StatelessWidget {
  const _TabsBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(bottom: BorderSide(color: AppColor.border)),
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: AppColor.primary,
        indicatorWeight: 3,
        labelColor: AppColor.primary,
        unselectedLabelColor: AppColor.textSecondary,
        labelStyle: AppText.labelMd.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            AppText.labelMd.copyWith(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: AppCopy.adminProviders),
          Tab(text: AppCopy.adminUsers),
          Tab(text: AppCopy.adminSubscriptions),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.onChanged,
    required this.onTierChanged,
    required this.filterTier,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<PlanTier?> onTierChanged;
  final PlanTier? filterTier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.md.h,
      ),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(bottom: BorderSide(color: AppColor.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42.h,
              child: TextField(
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: AppCopy.adminSearchHint,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColor.textSecondary,
                    size: 20.sp,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w,
                  ),
                  filled: true,
                  fillColor: AppColor.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.rMd,
                    borderSide: const BorderSide(color: AppColor.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadii.rMd,
                    borderSide: const BorderSide(color: AppColor.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.rMd,
                    borderSide:
                        const BorderSide(color: AppColor.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          gapH(AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TierChip(
                    label: AppCopy.adminAllPlans,
                    selected: filterTier == null,
                    onTap: () => onTierChanged(null),
                  ),
                  for (final t in PlanTier.values) ...[
                    gapH(AppSpacing.sm),
                    _TierChip(
                      label: t.name.toUpperCase(),
                      selected: filterTier == t,
                      onTap: () => onTierChanged(t),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColor.primary : AppColor.surfaceCard,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Text(
            label,
            style: AppText.labelMd.copyWith(
              color: selected ? AppColor.white : AppColor.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Providers tab
// =============================================================================

class _ProvidersTab extends StatelessWidget {
  const _ProvidersTab({required this.rows, required this.onAction});

  final List<_ProviderRow> rows;
  final Future<void> Function(_ProviderRow, String) onAction;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        child: AppStateView.search(message: AppCopy.adminEmptyProviders),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      itemCount: rows.length,
      separatorBuilder: (_, __) => gapV(AppSpacing.sm),
      itemBuilder: (_, i) => _ProviderTile(
        row: rows[i],
        onAction: (next) => onAction(rows[i], next),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.row, required this.onAction});

  final _ProviderRow row;
  final ValueChanged<String> onAction;

  Color _statusColor() {
    switch (row.status) {
      case 'approved':
        return AppColor.success;
      case 'rejected':
      case 'suspended':
        return AppColor.error;
      default:
        return AppColor.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.businessName,
                  style:
                      AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PlanBadge(tier: row.tier),
            ],
          ),
          gapV(AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.mail_outline_rounded,
                  size: 14.sp, color: AppColor.textSecondary),
              gapH(AppSpacing.xs),
              Expanded(
                child: Text(
                  row.contactEmail,
                  style: AppText.bodySm
                      .copyWith(color: AppColor.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (row.contactPhone != null) ...[
                gapH(AppSpacing.md),
                Icon(Icons.phone_outlined,
                    size: 14.sp, color: AppColor.textSecondary),
                gapH(AppSpacing.xs),
                Text(
                  row.contactPhone!,
                  style:
                      AppText.bodySm.copyWith(color: AppColor.textSecondary),
                ),
              ],
            ],
          ),
          gapV(AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusColor(),
                  shape: BoxShape.circle,
                ),
              ),
              gapH(AppSpacing.xs),
              Text(row.status, style: AppText.bodySm),
              gapH(AppSpacing.lg),
              Icon(Icons.place_outlined,
                  size: 14.sp, color: AppColor.textSecondary),
              gapH(AppSpacing.xs),
              Text(
                '${AppCopy.adminPlacesCount}: ${row.placeCount}',
                style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
              ),
              gapH(AppSpacing.lg),
              Icon(Icons.calendar_today_outlined,
                  size: 13.sp, color: AppColor.textSecondary),
              gapH(AppSpacing.xs),
              Text(
                '${AppCopy.adminJoinedAt} ${_fmtDate(row.createdAt)}',
                style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded,
                    color: AppColor.textSecondary, size: 22.sp),
                onSelected: onAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'approved', child: Text('اعتماد')),
                  PopupMenuItem(value: 'suspended', child: Text('تعليق')),
                  PopupMenuItem(value: 'rejected', child: Text('رفض')),
                  PopupMenuItem(value: 'pending', child: Text('انتظار')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Users tab
// =============================================================================

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.rows});

  final List<_UserRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        child: AppStateView.search(message: AppCopy.adminEmptyUsers),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      itemCount: rows.length,
      separatorBuilder: (_, __) => gapV(AppSpacing.sm),
      itemBuilder: (_, i) => _UserTile(row: rows[i]),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.row});
  final _UserRow row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: AppColor.primary.withValues(alpha: 0.12),
            child: Text(
              _initial(row.name),
              style: AppText.titleMd.copyWith(
                color: AppColor.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          gapH(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.name,
                        style: AppText.titleMd
                            .copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    gapH(AppSpacing.sm),
                    _RoleBadge(
                      isAdmin: row.isAdmin,
                      isProvider: row.isProvider,
                    ),
                  ],
                ),
                gapV(2),
                Text(
                  row.email,
                  style:
                      AppText.bodySm.copyWith(color: AppColor.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                gapV(2),
                Row(
                  children: [
                    if (row.phone != null) ...[
                      Icon(Icons.phone_outlined,
                          size: 12.sp, color: AppColor.textMuted),
                      gapH(AppSpacing.xs),
                      Text(
                        row.phone!,
                        style:
                            AppText.caption.copyWith(color: AppColor.textMuted),
                      ),
                      gapH(AppSpacing.md),
                    ],
                    Icon(Icons.calendar_today_outlined,
                        size: 12.sp, color: AppColor.textMuted),
                    gapH(AppSpacing.xs),
                    Text(
                      _fmtDate(row.joinedAt),
                      style:
                          AppText.caption.copyWith(color: AppColor.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin, required this.isProvider});
  final bool isAdmin;
  final bool isProvider;

  @override
  Widget build(BuildContext context) {
    final (label, color) = isAdmin
        ? (AppCopy.adminRoleAdmin, AppColor.error)
        : isProvider
            ? (AppCopy.adminRoleProvider, AppColor.info)
            : (AppCopy.adminRoleUser, AppColor.textSecondary);
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rSm,
      ),
      child: Text(
        label,
        style: AppText.labelSm
            .copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// =============================================================================
// Subscriptions tab
// =============================================================================

class _SubscriptionsTab extends StatelessWidget {
  const _SubscriptionsTab({required this.rows});
  final List<_SubRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        child: AppStateView.search(message: AppCopy.adminEmptySubs),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      itemCount: rows.length,
      separatorBuilder: (_, __) => gapV(AppSpacing.sm),
      itemBuilder: (_, i) => _SubTile(row: rows[i]),
    );
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({required this.row});
  final _SubRow row;

  String _gatewayLabel() {
    switch (row.gateway) {
      case 'manual':
        return row.source == 'demo'
            ? AppCopy.adminSubSourceDemo
            : AppCopy.adminSubSourceManual;
      case 'paymob':
        return AppCopy.adminSubSourcePaymob;
      case 'stripe':
        return AppCopy.adminSubSourceStripe;
      default:
        return row.gateway;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cycle =
        row.yearly ? AppCopy.adminBillingYearly : AppCopy.adminBillingMonthly;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.providerName,
                  style:
                      AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PlanBadge(tier: row.tier),
            ],
          ),
          gapV(AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md.w,
            runSpacing: AppSpacing.xs.h,
            children: [
              _Meta(icon: Icons.event_repeat_rounded, text: cycle),
              _Meta(
                icon: Icons.payments_outlined,
                text: '${row.amountEgp} ج.م',
              ),
              _Meta(
                icon: Icons.account_balance_wallet_outlined,
                text: _gatewayLabel(),
              ),
              _Meta(
                icon: Icons.event_available_rounded,
                text:
                    '${AppCopy.adminPeriodEnd} ${_fmtDate(row.periodEnd)}',
              ),
              if (row.cancelAtPeriodEnd)
                const _Meta(
                  icon: Icons.cancel_schedule_send_rounded,
                  text: 'سيُلغى في نهاية الفترة',
                  tone: AppColor.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.tone});

  final IconData icon;
  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = tone ?? AppColor.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: c),
        gapH(AppSpacing.xs),
        Text(text, style: AppText.bodySm.copyWith(color: c)),
      ],
    );
  }
}

// =============================================================================
// Utils
// =============================================================================

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

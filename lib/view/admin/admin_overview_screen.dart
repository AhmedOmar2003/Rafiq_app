import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/api_service.dart';

/// Lightweight admin overview, gated by the `is_admin()` SQL helper.
///
/// Shows every provider with their effective plan tier, business name,
/// status, and a moderation menu (approve / suspend). The page reads
/// directly from views (`providers` + `provider_current_plan`) so the
/// admin sees ground truth — no separate caching.
///
/// Production note: this screen will not return rows for non-admin users
/// because of RLS. Either hide the entry behind a role check or accept the
/// graceful empty state shown here.
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  late Future<List<_ProviderRow>> _future;
  PlanTier? _filterTier;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ProviderRow>> _load() async {
    await ApiService.ensureSupabaseInitialized();
    final client = Supabase.instance.client;

    final providers = await client
        .from('providers')
        .select('id,business_name,status,created_at')
        .order('created_at', ascending: false)
        .limit(100);

    final ids =
        (providers as List).map((r) => (r as Map)['id'] as String).toList();

    Map<String, Map<String, dynamic>> plans = {};
    if (ids.isNotEmpty) {
      final planRows = await client
          .from('provider_current_plan')
          .select('provider_id,tier,period_end')
          .inFilter('provider_id', ids);
      for (final row in (planRows as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        plans[m['provider_id'] as String] = m;
      }
    }

    return providers.map<_ProviderRow>((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final plan = plans[m['id'] as String];
      return _ProviderRow(
        id: m['id'] as String,
        name: (m['business_name'] as String?) ?? '—',
        status: (m['status'] as String?) ?? 'pending',
        tier: plan == null
            ? PlanTier.free
            : PlanTierX.fromWire(plan['tier'] as String? ?? 'free'),
      );
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return AppPageScaffold(
        header: const AppPageHeader(title: AppCopy.adminTitle),
        body: AppStateView.search(
          title: 'لوحة الإدارة للويب فقط',
          message:
              'الإدارة والمراقبة موجودة في الويب فقط، وليست جزءًا من الموبايل.',
        ),
      );
    }

    return AppPageScaffold(
      header: const AppPageHeader(title: AppCopy.adminTitle),
      body: FutureBuilder<List<_ProviderRow>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColor.primary),
            );
          }
          final rows = (snap.data ?? const <_ProviderRow>[])
              .where((r) => _filterTier == null || r.tier == _filterTier)
              .toList();

          return Column(
            children: [
              _FilterBar(
                current: _filterTier,
                onChanged: (t) => setState(() => _filterTier = t),
              ),
              Expanded(
                child: rows.isEmpty
                    ? AppStateView.search()
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.xxl.w,
                          AppSpacing.lg.h,
                          AppSpacing.xxl.w,
                          AppSpacing.xxl.h,
                        ),
                        itemBuilder: (_, i) => _ProviderTile(
                          row: rows[i],
                          onAction: (next) => _setStatus(rows[i], next),
                        ),
                        separatorBuilder: (_, __) => gapV(AppSpacing.sm),
                        itemCount: rows.length,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderRow {
  _ProviderRow({
    required this.id,
    required this.name,
    required this.status,
    required this.tier,
  });

  final String id;
  final String name;
  final String status;
  final PlanTier tier;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChanged});

  final PlanTier? current;
  final ValueChanged<PlanTier?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl.w,
        vertical: AppSpacing.md.h,
      ),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(bottom: BorderSide(color: AppColor.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: AppCopy.adminAllPlans,
              selected: current == null,
              onTap: () => onChanged(null),
            ),
            for (final t in PlanTier.values) ...[
              gapH(AppSpacing.sm),
              _Chip(
                label: t.name.toUpperCase(),
                selected: current == t,
                onTap: () => onChanged(t),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
                  row.name,
                  style: AppText.titleMd.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PlanBadge(tier: row.tier),
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

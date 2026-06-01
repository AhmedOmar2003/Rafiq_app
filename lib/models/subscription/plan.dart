import 'package:flutter/material.dart';

/// Plan tier identifier — mirrors `public.plan_tier` in Postgres.
enum PlanTier { free, pro, max }

extension PlanTierX on PlanTier {
  String get wire => name;

  static PlanTier fromWire(String s) {
    return PlanTier.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PlanTier.free,
    );
  }
}

/// One row from `subscription_plans`.
@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.displayName,
    required this.tagline,
    required this.priceMonthlyEgp,
    required this.priceYearlyEgp,
    required this.maxPlaces,
    required this.maxGalleryImages,
    required this.maxVideos,
    required this.maxCoverImages,
    required this.maxCampaigns,
    required this.rankingBoost,
    required this.isVerified,
    required this.hasAnalyticsBasic,
    required this.hasAnalyticsPro,
    required this.hasPromotions,
    required this.hasFeaturedSlot,
    required this.hasPushCampaigns,
    required this.hasHomepageSpotlight,
    required this.hasPrioritySupport,
    required this.hasPriorityModeration,
    required this.badgeLabel,
    required this.accentColor,
    required this.ctaLabel,
    required this.sortOrder,
  });

  final PlanTier tier;
  final String displayName;
  final String tagline;
  final int priceMonthlyEgp;
  final int priceYearlyEgp;
  final int maxPlaces;
  final int maxGalleryImages;
  final int maxVideos;
  final int maxCoverImages;
  final int maxCampaigns;
  final double rankingBoost;
  final bool isVerified;
  final bool hasAnalyticsBasic;
  final bool hasAnalyticsPro;
  final bool hasPromotions;
  final bool hasFeaturedSlot;
  final bool hasPushCampaigns;
  final bool hasHomepageSpotlight;
  final bool hasPrioritySupport;
  final bool hasPriorityModeration;
  final String? badgeLabel;
  final Color accentColor;
  final String ctaLabel;
  final int sortOrder;

  bool get isFree => tier == PlanTier.free;

  /// Yearly savings vs. paying 12× the monthly. Returns a percent (0–100).
  int get yearlySavingsPct {
    final monthlyTotal = priceMonthlyEgp * 12;
    if (monthlyTotal == 0) return 0;
    final saved = monthlyTotal - priceYearlyEgp;
    return ((saved / monthlyTotal) * 100).round();
  }

  factory SubscriptionPlan.fromRow(Map<String, dynamic> row) {
    Color parseHex(String? hex) {
      if (hex == null || hex.isEmpty) return const Color(0xff681F00);
      final h = hex.replaceFirst('#', '');
      final value = int.tryParse(h, radix: 16);
      if (value == null) return const Color(0xff681F00);
      return Color(value | 0xFF000000);
    }

    return SubscriptionPlan(
      tier: PlanTierX.fromWire(row['tier'] as String),
      displayName: row['display_name'] as String,
      tagline: row['tagline'] as String,
      priceMonthlyEgp: (row['price_monthly_egp'] as num).toInt(),
      priceYearlyEgp: (row['price_yearly_egp'] as num).toInt(),
      maxPlaces: (row['max_places'] as num).toInt(),
      maxGalleryImages: (row['max_gallery_images'] as num).toInt(),
      maxVideos: (row['max_videos'] as num).toInt(),
      maxCoverImages: (row['max_cover_images'] as num).toInt(),
      maxCampaigns: (row['max_campaigns'] as num?)?.toInt() ?? 0,
      rankingBoost: (row['ranking_boost'] as num).toDouble(),
      isVerified: row['is_verified'] as bool? ?? false,
      hasAnalyticsBasic: row['has_analytics_basic'] as bool? ?? false,
      hasAnalyticsPro: row['has_analytics_pro'] as bool? ?? false,
      hasPromotions: row['has_promotions'] as bool? ?? false,
      hasFeaturedSlot: row['has_featured_slot'] as bool? ?? false,
      hasPushCampaigns: row['has_push_campaigns'] as bool? ?? false,
      hasHomepageSpotlight: row['has_homepage_spotlight'] as bool? ?? false,
      hasPrioritySupport: row['has_priority_support'] as bool? ?? false,
      hasPriorityModeration: row['has_priority_moderation'] as bool? ?? false,
      badgeLabel: row['badge_label'] as String?,
      accentColor: parseHex(row['accent_color_hex'] as String?),
      ctaLabel: row['cta_label'] as String? ?? 'اشترك',
      sortOrder: (row['sort_order'] as num).toInt(),
    );
  }
}

/// Resolved entitlement for the current provider (read from
/// `provider_current_plan` view). All feature checks should ask this
/// object, not the raw subscription row.
@immutable
class ProviderEntitlement {
  const ProviderEntitlement({
    required this.tier,
    required this.maxGalleryImages,
    required this.maxVideos,
    required this.maxPlaces,
    required this.maxCoverImages,
    required this.maxCampaigns,
    required this.isVerified,
    required this.hasAnalyticsBasic,
    required this.hasAnalyticsPro,
    required this.hasPromotions,
    required this.hasFeaturedSlot,
    required this.hasPushCampaigns,
    required this.hasHomepageSpotlight,
    required this.hasPrioritySupport,
    required this.badgeLabel,
    required this.periodEnd,
    required this.cancelAtPeriodEnd,
  });

  final PlanTier tier;
  final int maxGalleryImages;
  final int maxVideos;
  final int maxPlaces;
  final int maxCoverImages;
  final int maxCampaigns;
  final bool isVerified;
  final bool hasAnalyticsBasic;
  final bool hasAnalyticsPro;
  final bool hasPromotions;
  final bool hasFeaturedSlot;
  final bool hasPushCampaigns;
  final bool hasHomepageSpotlight;
  final bool hasPrioritySupport;
  final String? badgeLabel;
  final DateTime? periodEnd;
  final bool cancelAtPeriodEnd;

  /// Default for users with no row — silently treated as Free.
  static const ProviderEntitlement freeFallback = ProviderEntitlement(
    tier: PlanTier.free,
    maxGalleryImages: 3,
    maxVideos: 0,
    maxPlaces: 1,
    maxCoverImages: 1,
    maxCampaigns: 0,
    isVerified: false,
    hasAnalyticsBasic: false,
    hasAnalyticsPro: false,
    hasPromotions: false,
    hasFeaturedSlot: false,
    hasPushCampaigns: false,
    hasHomepageSpotlight: false,
    hasPrioritySupport: false,
    badgeLabel: null,
    periodEnd: null,
    cancelAtPeriodEnd: false,
  );

  factory ProviderEntitlement.fromRow(Map<String, dynamic> row) {
    return ProviderEntitlement(
      tier: PlanTierX.fromWire(row['tier'] as String? ?? 'free'),
      maxGalleryImages: (row['max_gallery_images'] as num?)?.toInt() ?? 3,
      maxVideos: (row['max_videos'] as num?)?.toInt() ?? 0,
      maxPlaces: (row['max_places'] as num?)?.toInt() ?? 1,
      maxCoverImages: (row['max_cover_images'] as num?)?.toInt() ?? 1,
      maxCampaigns: (row['max_campaigns'] as num?)?.toInt() ?? 0,
      isVerified: row['is_verified'] as bool? ?? false,
      hasAnalyticsBasic: row['has_analytics_basic'] as bool? ?? false,
      hasAnalyticsPro: row['has_analytics_pro'] as bool? ?? false,
      hasPromotions: row['has_promotions'] as bool? ?? false,
      hasFeaturedSlot: row['has_featured_slot'] as bool? ?? false,
      hasPushCampaigns: row['has_push_campaigns'] as bool? ?? false,
      hasHomepageSpotlight: row['has_homepage_spotlight'] as bool? ?? false,
      hasPrioritySupport: row['has_priority_support'] as bool? ?? false,
      badgeLabel: row['badge_label'] as String?,
      periodEnd: row['period_end'] == null
          ? null
          : DateTime.parse(row['period_end'] as String),
      cancelAtPeriodEnd: row['cancel_at_period_end'] as bool? ?? false,
    );
  }
}

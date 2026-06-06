import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'package:rafiq_app/view/pages/legal/help_screen.dart';
import 'package:rafiq_app/view/pages/legal/privacy_policy_screen.dart';
import 'package:rafiq_app/view/pages/legal/terms_screen.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rafiq_app/core/design/tokens/tokens.dart';

import '../../auth/login/login_screen.dart';
import '../../core/design/components/components.dart';
import '../../core/utils/app_microcopy.dart';
import '../../core/utils/app_error_formatter.dart';
import '../../model/place.dart';
import '../../models/subscription/plan.dart';
import '../../models/suggestion_item_model/suggestion_item.dart';
import '../../service/api_service.dart';
import '../../service/accessibility_preferences.dart';
import '../../service/auth_service.dart';
import '../../service/profile_image_store.dart';
import '../../service/subscription_service.dart';
import '../../auth/post_auth_router.dart';
import '../../service/user_role_store.dart';
import '../details/details_page.dart';
import '../provider/hub/provider_hub_screen.dart';
import '../provider/subscription/subscription_screen.dart';
import 'delete_account_sheet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.enableRemoteBootstrap = true,
  });

  final bool enableRemoteBootstrap;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? userEmail;
  bool _isLoading = false;

  /// Number of places this provider owns. Decides the singular vs plural
  /// copy on the "return" banner.
  int _myPlacesCount = 0;
  late Future<List<Place>> _favoritePlacesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.enableRemoteBootstrap) {
      _loadUserData();
    } else {
      _loadCachedUserData();
    }
    // ProfileImageStore is the single source of truth — just make sure it's
    // loaded. The hero image listens to its ValueNotifier so we never need
    // local setState plumbing for the picture.
    unawaited(ProfileImageStore.instance.ensureLoaded());
    // Make sure the role flag + subscription catalog are warm before the
    // user expects to see plan-specific copy in the row.
    if (widget.enableRemoteBootstrap) {
      unawaited(UserRoleStore.instance.ensureLoaded());
      unawaited(() async {
        try {
          await SubscriptionService.instance.loadCatalog();
        } catch (_) {
          // Keep the profile page resilient when catalog/network bootstrap fails.
        }
      }());
      _resolveProviderContext();
      _favoritePlacesFuture =
          ApiService().fetchFavoritePlaces().catchError((_) => <Place>[]);
    } else {
      _favoritePlacesFuture = Future<List<Place>>.value(const <Place>[]);
    }
  }

  /// Resolve provider id + place count in the background so the banner
  /// renders the right copy when the page is open. Both reads are wrapped
  /// in try-catch — the profile page should never fail because we couldn't
  /// look these up.
  Future<void> _resolveProviderContext() async {
    try {
      final id = await ApiService().lookupCurrentProviderId();
      if (!mounted || id == null || id.isEmpty) return;
      final places = await ApiService().fetchProviderPlaces(providerId: id);
      if (!mounted) return;
      setState(() {
        _myPlacesCount = places.length;
      });
    } catch (_) {
      // Silent — banner just falls back to its safe state.
    }
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await AuthService().fetchCurrentUserProfile();
      if (!mounted) return;
      if (profile != null) {
        setState(() {
          userName = profile.name.isNotEmpty
              ? profile.name
              : AppCopy.profileNameFallback;
          userEmail = profile.email.isNotEmpty
              ? profile.email
              : AppCopy.profileEmailFallback;
        });
        return;
      }
    } catch (_) {
      // Fall back to the cached identity below.
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('userName') ?? AppCopy.profileNameFallback;
      userEmail = prefs.getString('userEmail') ?? AppCopy.profileEmailFallback;
    });
  }

  Future<void> _loadCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('userName') ?? AppCopy.profileNameFallback;
      userEmail = prefs.getString('userEmail') ?? AppCopy.profileEmailFallback;
    });
  }

  Future<void> _refreshFavoritePlaces() async {
    final next = ApiService()
        .fetchFavoritePlaces(forceRefresh: true)
        .catchError((_) => <Place>[]);
    if (!mounted) return;
    setState(() => _favoritePlacesFuture = next);
    await next;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (pickedFile == null) return;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) return;
      await ProfileImageStore.instance.setWebBytes(bytes);
      return;
    }

    final persistedPath = await _persistProfileImage(File(pickedFile.path));
    if (persistedPath == null) return;
    await ProfileImageStore.instance.setMobileImage(File(persistedPath));
  }

  Future<String?> _persistProfileImage(File sourceImage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authUserId =
          prefs.getString('authUserId') ?? (userEmail ?? 'default_user');
      final safeId = authUserId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/profile_images');
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final extension =
          sourceImage.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final targetPath = '${profileDir.path}/profile_$safeId.$extension';
      final persistedFile = await sourceImage.copy(targetPath);
      return persistedFile.path;
    } catch (e) {
      if (!mounted) return null;
      AppFeedback.error(AppCopy.profileImageSaveError);
      return null;
    }
  }

  /// Context-aware **Delete account** flow.
  ///
  /// Reads the current role + entitlement so the confirmation copy tells
  /// the user exactly what they're about to lose (no surprises later).
  /// On confirm, calls the DB RPC, then resets every client-side store and
  /// navigates to login.
  Future<void> _handleDeleteAccount() async {
    if (_isLoading) return;
    final isProvider = UserRoleStore.instance.isProvider.value;
    final ent = SubscriptionService.instance.entitlement.value;
    final planName = _planDisplayName(ent.tier);

    final ({bool confirmed, String? reason}) result =
        await DeleteAccountSheet.show(
      context,
      isProvider: isProvider,
      tier: ent.tier,
      planDisplayName: planName,
    );
    if (!result.confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().deleteMyAccount(reason: result.reason);
      // After the RPC the auth row is gone — drop every client-side
      // singleton so a fresh signup starts from zero.
      await UserRoleStore.instance.clear();
      await SubscriptionService.instance.applyDemoFree();
      if (!mounted) return;
      AppFeedback.success(AppCopy.deleteAccountSuccess);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(AppCopy.deleteAccountError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogoutConfirmedDirect() async {
    if (_isLoading) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Log out locally + Supabase first for immediate UX.
      //
      // We intentionally do NOT touch [UserRoleStore] or
      // [SubscriptionService] here. Logout is a session boundary, not a
      // data wipe — the same user logging back in expects to find the
      // same role and the same active plan. Clearing those belongs to the
      // delete-account flow, not to sign-out.
      await AuthService().signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(AppCopy.logoutError);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void showChangePasswordDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final ValueNotifier<bool> isLoading = ValueNotifier(false);
    final ValueNotifier<String?> errorMessage = ValueNotifier(null);

    // PERFORMANCE / CORRECTNESS: dialog-scoped controllers must be disposed
    // when the dialog closes, otherwise they leak ChangeNotifier subscribers
    // for the lifetime of the app.
    void disposeResources() {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
      isLoading.dispose();
      errorMessage.dispose();
    }

    Future<void> changePassword() async {
      if (!formKey.currentState!.validate()) return;
      isLoading.value = true;
      errorMessage.value = null;
      try {
        await AuthService().changeCurrentPassword(
          currentPassword: currentPasswordController.text,
          newPassword: newPasswordController.text,
        );
        if (!context.mounted) return;
        Navigator.of(context).pop();
        AppFeedback.success(AppCopy.changePwSuccess);
      } catch (e) {
        errorMessage.value = AppErrorFormatter.userMessage(e);
      } finally {
        isLoading.value = false;
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
          elevation: 8,
          backgroundColor: AppColor.surface,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xl.w, vertical: AppSpacing.lg.h),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                AppCopy.changePwTitle,
                                style: AppText.titleLg.copyWith(
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close,
                                color: AppColor.primary, size: 24),
                            tooltip: AppCopy.cancel,
                          ),
                        ],
                      ),
                      gapV(AppSpacing.lg),
                      AppInput(
                        label: AppCopy.changePwCurrent,
                        hintText: AppCopy.authPasswordHint,
                        controller: currentPasswordController,
                        isPassword: true,
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppColor.primary),
                        validator: (v) => (v == null || v.isEmpty)
                            ? AppCopy.passwordRequired
                            : null,
                      ),
                      AppInput(
                        label: AppCopy.changePwNew,
                        hintText: AppCopy.authPasswordHint,
                        controller: newPasswordController,
                        isPassword: true,
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppColor.primary),
                        validator: (v) => (v == null || v.isEmpty)
                            ? AppCopy.passwordRequired
                            : null,
                      ),
                      AppInput(
                        label: AppCopy.changePwConfirm,
                        hintText: AppCopy.resetConfirmHint,
                        controller: confirmPasswordController,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => changePassword(),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppColor.primary),
                        paddingBottom: 8,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return AppCopy.passwordRequired;
                          }
                          if (v != newPasswordController.text) {
                            return AppCopy.passwordsMismatch;
                          }
                          return null;
                        },
                      ),
                      gapV(AppSpacing.md),
                      ValueListenableBuilder<bool>(
                        valueListenable: isLoading,
                        builder: (_, loading, __) => AppButton(
                          text: AppCopy.changePwCta,
                          onPress: () {
                            if (!loading) changePassword();
                          },
                          isLoading: loading,
                        ),
                      ),
                      gapV(AppSpacing.sm),
                      ValueListenableBuilder<String?>(
                        valueListenable: errorMessage,
                        builder: (_, error, __) {
                          return AnimatedOpacity(
                            opacity: error == null ? 0.0 : 1.0,
                            duration: AppMotion.base,
                            child: error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding:
                                        EdgeInsets.only(top: AppSpacing.xs.h),
                                    child: Text(
                                      error,
                                      style: AppText.bodyMd
                                          .copyWith(color: AppColor.error),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                          );
                        },
                      ),
                      gapV(AppSpacing.xs),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          AppCopy.cancel,
                          style: AppText.bodyLg.copyWith(
                            color: AppColor.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(disposeResources);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: const AppPageHeader(
        title: AppCopy.profileTitle,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _ProfileHero(
                name: userName,
                email: userEmail,
                child: _buildProfileImage(),
              ),
              gapV(AppSpacing.lg),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                child: Column(
                  children: [
                    _buildRoleBanner(),
                    _buildInfoSection(),
                    gapV(AppSpacing.lg),
                    _buildFavoritesSection(),
                    gapV(AppSpacing.lg),
                    _buildAppearanceSection(),
                    gapV(AppSpacing.lg),
                    const _SupportSection(),
                    gapV(AppSpacing.lg),
                    _buildLogoutButton(),
                    gapV(AppSpacing.md),
                    _buildDeleteAccountButton(),
                    gapV(AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Semantics(
        button: true,
        label: AppCopy.profileChangeAvatarHint,
        child: GestureDetector(
          onTap: _pickImage,
          child: ValueListenableBuilder<ProfileImageState>(
            valueListenable: ProfileImageStore.instance,
            builder: (_, snap, __) {
              final ImageProvider provider = snap.bytes != null
                  ? MemoryImage(snap.bytes!)
                  : snap.file != null
                      ? FileImage(snap.file!)
                      : const AssetImage('assets/images/default_profile.webp')
                          as ImageProvider;
              return CircleAvatar(
                radius: 54.w,
                backgroundColor: AppColor.surfaceCard,
                child: CircleAvatar(
                  radius: 51.w,
                  backgroundImage: provider,
                  child: snap.hasImage
                      ? null
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColor.black.withValues(alpha: 0.4),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: AppColor.white,
                            size: 28.w,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Two-state banner that anchors the Profile page above everything else:
  ///
  ///   1. Regular user who has *never* confirmed a provider plan
  ///      → "كن مقدّم خدمة" invite card with the brand gradient.
  ///   2. Confirmed provider who switched into user mode
  ///      → "ارجع لخدمتك / خدماتك" warm card with their place count.
  ///
  /// Hidden entirely when the user is already in provider mode — they
  /// don't need a CTA pointing to where they already are.
  Widget _buildRoleBanner() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        UserRoleStore.instance.isProvider,
        UserRoleStore.instance.hasProviderHistory,
      ]),
      builder: (_, __) {
        final isProvider = UserRoleStore.instance.isProvider.value;
        final hasProviderHistory =
            UserRoleStore.instance.hasProviderHistory.value;
        if (isProvider) return const SizedBox.shrink();

        // Personalize the title with the user's first name when we have one.
        // "أحمد، تحب نشاطك..." reads as a friend talking, not a sales banner.
        // Falls back to a clean prompt with no comma when the name is missing.
        String personalize(String base) {
          final name = (userName ?? '').trim();
          if (name.isEmpty || name == AppCopy.profileNameFallback) return base;
          final firstName = name.split(' ').first;
          return '$firstName، $base';
        }

        if (hasProviderHistory) {
          // Returning provider — bring them home.
          final isMulti = _myPlacesCount > 1;
          return Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xl.h),
            child: _RoleBanner(
              tone: _RoleBannerTone.warm,
              icon: Icons.storefront_rounded,
              title: isMulti
                  ? AppCopy.profileBannerReturnTitleMulti
                  : AppCopy.profileBannerReturnTitleSingle,
              body: AppCopy.profileBannerReturnBody,
              cta: isMulti
                  ? AppCopy.profileBannerReturnCtaMulti
                  : AppCopy.profileBannerReturnCtaSingle,
              onTap: _enterProviderFlow,
            ),
          );
        }

        // First-time invite — make it look like a brand ad.
        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.xl.h),
          child: _RoleBanner(
            tone: _RoleBannerTone.brand,
            icon: Icons.rocket_launch_rounded,
            title: personalize(AppCopy.profileBannerInviteTitle),
            body: AppCopy.profileBannerInviteBody,
            cta: AppCopy.profileBannerInviteCta,
            onTap: _enterProviderFlow,
          ),
        );
      },
    );
  }

  Widget _buildInfoSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: UserRoleStore.instance.isProvider,
      builder: (_, isProvider, __) {
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileInfoRow(
                icon: Icons.person_2_outlined,
                label: AppCopy.profileNameLabel,
                value: userName ?? AppCopy.profileNameFallback,
              ),
              const Divider(height: 1, color: AppColor.border),
              _ProfileInfoRow(
                icon: Icons.email_outlined,
                label: AppCopy.profileEmailLabel,
                value: userEmail ?? AppCopy.profileEmailFallback,
              ),
              const Divider(height: 1, color: AppColor.border),
              _ProfileInfoRow(
                icon: Icons.lock_outline,
                label: AppCopy.profilePasswordLabel,
                value: '••••••••',
                trailing: IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: AppColor.primary,
                    size: 22.sp,
                  ),
                  onPressed: () => showChangePasswordDialog(context),
                  tooltip: AppCopy.changePwTitle,
                ),
              ),
              // Switch-role row only when the user is currently in provider
              // mode — gives them a quick way to flip back to "browse mode"
              // without losing their plan or places. The opposite direction
              // (regular → provider) lives in the banner above so it gets
              // the visual weight it deserves.
              if (isProvider) ...[
                const Divider(height: 1, color: AppColor.border),
                _ProfileInfoRow(
                  icon: Icons.travel_explore_rounded,
                  label: AppCopy.profileSwitchToUser,
                  value: AppCopy.profileSwitchToUserValue,
                  onTap: () => _handleRoleSwitch(toProvider: false),
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    color: AppColor.textTertiary,
                    size: 24.sp,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesSection() {
    return FutureBuilder<List<Place>>(
      future: _favoritePlacesFuture,
      builder: (context, snapshot) {
        final places = snapshot.data ?? const <Place>[];
        final isLoading = snapshot.connectionState != ConnectionState.done;
        return _FavoritePlacesSection(
          isLoading: isLoading,
          places: places,
          onRefresh: _refreshFavoritePlaces,
          onOpenPlace: (place) async {
            final items = places.map(SuggestionItemModel.fromPlace).toList();
            final current = SuggestionItemModel.fromPlace(place);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsPage(
                  model: current,
                  suggestionItemList: items,
                ),
              ),
            );
            await _refreshFavoritePlaces();
          },
        );
      },
    );
  }

  Widget _buildAppearanceSection() {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppCopy.profileAppearanceSection,
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
          ),
          gapV(AppSpacing.md),
          ValueListenableBuilder<double>(
            valueListenable: AccessibilityPreferences.instance.textScale,
            builder: (_, scale, __) {
              final options = <(double, String)>[
                (0.95, AppCopy.profileTextSizeSmall),
                (1.10, AppCopy.profileTextSizeMedium),
                (1.25, AppCopy.profileTextSizeLarge),
              ];
              return Wrap(
                spacing: AppSpacing.sm.w,
                runSpacing: AppSpacing.sm.h,
                children: options.map((option) {
                  final isSelected = (scale - option.$1).abs() < 0.01;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${AppCopy.profileTextSizeLabel} ${option.$2}',
                    child: InkWell(
                      onTap: () => AccessibilityPreferences.instance
                          .setTextScale(option.$1),
                      borderRadius: AppRadii.rPill,
                      child: Ink(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md.w,
                          vertical: AppSpacing.sm.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppColor.primary : AppColor.surface,
                          borderRadius: AppRadii.rPill,
                          border: Border.all(
                            color:
                                isSelected ? AppColor.primary : AppColor.border,
                          ),
                        ),
                        child: Text(
                          option.$2,
                          style: AppText.labelMd.copyWith(
                            color: isSelected
                                ? AppColor.white
                                : AppColor.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Flip the user-role flag and route to the right home for the new role.
  ///
  /// Session and subscription state are preserved; the user can switch back
  /// at any time without re-onboarding or re-subscribing.
  Future<void> _enterProviderFlow() async {
    final hadProviderHistory = UserRoleStore.instance.hasProviderHistory.value;

    if (hadProviderHistory) {
      await UserRoleStore.instance.chooseProvider();
      if (!mounted) return;
      final providerId = await ApiService().ensureCurrentProviderId();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ProviderHubScreen(providerId: providerId),
        ),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubscriptionScreen(
          onboarding: true,
          onPlanChosen: (providerId) async {
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => ProviderHubScreen(providerId: providerId),
              ),
              (_) => false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleRoleSwitch({required bool toProvider}) async {
    if (toProvider) {
      await _enterProviderFlow();
      return;
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppCopy.profileSwitchConfirmTitle,
      message: AppCopy.profileSwitchConfirmUser,
      confirmLabel: AppCopy.confirm,
      cancelLabel: AppCopy.cancel,
      icon: Icons.travel_explore_rounded,
    );
    if (!confirmed || !mounted) return;

    await UserRoleStore.instance.chooseRegularUser();
    if (!mounted) return;
    await PostAuthRouter.replaceWithHome(context);
  }

  String _planDisplayName(PlanTier tier) {
    final cat = SubscriptionService.instance.catalog.value;
    for (final p in cat) {
      if (p.tier == tier) return p.displayName;
    }
    // Fallbacks if catalog isn't loaded yet.
    switch (tier) {
      case PlanTier.free:
        return 'مجاني';
      case PlanTier.pro:
        return 'برو';
      case PlanTier.max:
        return 'ماكس';
    }
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          if (_isLoading) return;
          final confirmed = await AppConfirmDialog.show(
            context,
            title: AppCopy.logoutTitle,
            message: AppCopy.logoutMessage,
            confirmLabel: AppCopy.logoutConfirm,
            cancelLabel: AppCopy.cancel,
            tone: AppConfirmTone.danger,
            icon: Icons.logout_rounded,
          );
          if (!mounted) return;
          if (confirmed) await _handleLogoutConfirmedDirect();
        },
        icon: Icon(Icons.logout_rounded, color: AppColor.error, size: 22.sp),
        label: Text(
          AppCopy.logoutCta,
          style: AppText.titleMd.copyWith(
            color: AppColor.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(52.h),
          backgroundColor: AppColor.surfaceCard,
          side: const BorderSide(color: AppColor.error, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        ),
      ),
    );
  }

  /// Subtle "danger zone" link styled as a text button rather than another
  /// big outlined action — sign-out is the primary exit, account deletion
  /// is intentional and rare.
  Widget _buildDeleteAccountButton() {
    return TextButton.icon(
      onPressed: _isLoading ? null : _handleDeleteAccount,
      icon: Icon(
        Icons.delete_forever_outlined,
        color: AppColor.error,
        size: 18.sp,
      ),
      label: Text(
        AppCopy.deleteAccountRow,
        style: AppText.labelMd.copyWith(
          color: AppColor.error,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: AppColor.error.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ===========================================================================
// Support section — calm, two-group layout
// ===========================================================================
//
// Visual rules (per the user's "اشيك واهدى" request):
//   * Section labels are small uppercase-ish chips in textTertiary, not bold
//     headlines.
//   * Rows use a muted icon background (8% primary) instead of saturated
//     orange so the eye glides instead of jumping.
//   * Dividers are 1px hairlines (no thick separators).
//   * Two groups: "معلومات" (read-only legal pages) and "تواصل معانا"
//     (action: call / whatsapp / email).

class _SupportSection extends StatelessWidget {
  const _SupportSection();

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _call(String phone) => _launch('tel:$phone');

  void _whatsapp(String phone, String message) => _launch(
        'https://wa.me/2$phone?text=${Uri.encodeComponent(message)}',
      );

  void _email() => _launch(
        'mailto:${AppCopy.supportEmail}'
        '?subject=${Uri.encodeComponent(AppCopy.supportEmailSubject)}'
        '&body=${Uri.encodeComponent(AppCopy.supportEmailBody)}',
      );

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.sm.h,
          ),
          childrenPadding: EdgeInsets.only(bottom: AppSpacing.md.h),
          leading: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.08),
              borderRadius: AppRadii.rMd,
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: AppColor.primary,
              size: 20.sp,
            ),
          ),
          title: Text(
            AppCopy.profileSupportSection,
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            AppCopy.profileSupportSubtitle,
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          ),
          children: [
            const _GroupLabel(text: AppCopy.supportInfoGroup),
            _SupportRow(
              icon: Icons.privacy_tip_outlined,
              label: AppCopy.profilePrivacyPolicy,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            const _Hairline(),
            _SupportRow(
              icon: Icons.gavel_outlined,
              label: AppCopy.profileTerms,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
            ),
            const _Hairline(),
            _SupportRow(
              icon: Icons.help_outline_rounded,
              label: AppCopy.profileHelp,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
            gapV(AppSpacing.lg),
            const _GroupLabel(text: AppCopy.profileContactUs),
            _SupportRow(
              icon: Icons.phone_outlined,
              label: AppCopy.supportCallLabel,
              trailing: AppCopy.supportPhone1,
              onTap: () => _call(AppCopy.supportPhone1),
            ),
            const _Hairline(),
            _SupportRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: AppCopy.supportWhatsappLabel,
              trailing: AppCopy.supportPhone2,
              onTap: () => _whatsapp(
                AppCopy.supportPhone2,
                AppCopy.supportWhatsappMessage,
              ),
            ),
            const _Hairline(),
            _SupportRow(
              icon: Icons.email_outlined,
              label: AppCopy.supportEmailLabel,
              trailing: AppCopy.supportEmail,
              onTap: _email,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritePlacesSection extends StatelessWidget {
  const _FavoritePlacesSection({
    required this.isLoading,
    required this.places,
    required this.onRefresh,
    required this.onOpenPlace,
  });

  final bool isLoading;
  final List<Place> places;
  final Future<void> Function() onRefresh;
  final ValueChanged<Place> onOpenPlace;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: AppColor.error.withValues(alpha: 0.10),
                  borderRadius: AppRadii.rMd,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: AppColor.error,
                  size: 22.sp,
                ),
              ),
              gapH(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCopy.profileFavoritesTitle,
                      style: AppText.titleMd.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    gapV(AppSpacing.xs / 2),
                    Text(
                      AppCopy.profileFavoritesBody,
                      style: AppText.bodySm.copyWith(
                        color: AppColor.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppColor.primary,
                  size: 22.sp,
                ),
                tooltip: AppCopy.profileFavoritesRefresh,
              ),
            ],
          ),
          gapV(AppSpacing.lg),
          if (isLoading)
            SizedBox(
              height: 96.h,
              child: const Center(
                child: CircularProgressIndicator(color: AppColor.primary),
              ),
            )
          else if (places.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.lg.w),
              decoration: BoxDecoration(
                color: AppColor.surfaceVariant,
                borderRadius: AppRadii.rLg,
                border: Border.all(color: AppColor.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    color: AppColor.textTertiary,
                    size: 28.sp,
                  ),
                  gapV(AppSpacing.sm),
                  Text(
                    AppCopy.emptyFavoritesTitle,
                    style: AppText.labelLg.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  gapV(AppSpacing.xs),
                  Text(
                    AppCopy.emptyFavoritesBody,
                    style: AppText.bodySm.copyWith(
                      color: AppColor.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var index = 0;
                    index < places.length && index < 4;
                    index++) ...[
                  _FavoritePlaceRow(
                    place: places[index],
                    onTap: () => onOpenPlace(places[index]),
                  ),
                  if (index < places.length - 1 && index < 3)
                    const Divider(height: 1, color: AppColor.border),
                ],
                if (places.length > 4) ...[
                  gapV(AppSpacing.md),
                  Text(
                    AppCopy.profileFavoritesMore
                        .replaceFirst('%n', '${places.length - 4}'),
                    style: AppText.bodySm.copyWith(
                      color: AppColor.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _FavoritePlaceRow extends StatelessWidget {
  const _FavoritePlaceRow({
    required this.place,
    required this.onTap,
  });

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rLg,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.rMd,
              child: SizedBox(
                width: 68.w,
                height: 68.w,
                child:
                    place.imageUrl != null && place.imageUrl!.trim().isNotEmpty
                        ? Image.network(
                            place.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _favoriteFallback(),
                          )
                        : _favoriteFallback(),
              ),
            ),
            gapH(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: AppText.labelLg.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  gapV(AppSpacing.xs / 2),
                  Text(
                    place.activityName,
                    style: AppText.bodySm.copyWith(
                      color: AppColor.primary,
                    ),
                  ),
                  gapV(AppSpacing.xs / 2),
                  Text(
                    place.placeAddress,
                    style: AppText.bodySm.copyWith(
                      color: AppColor.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(AppSpacing.sm.w),
              decoration: const BoxDecoration(
                color: AppColor.primary50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14.sp,
                color: AppColor.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriteFallback() {
    return Container(
      color: AppColor.surfaceVariant,
      child: Icon(
        Icons.place_outlined,
        color: AppColor.textTertiary,
        size: 24.sp,
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        right: AppSpacing.md.w,
        bottom: AppSpacing.sm.h,
      ),
      child: Text(
        text,
        style: AppText.labelSm.copyWith(
          color: AppColor.textTertiary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Divider(height: 1, color: AppColor.border.withValues(alpha: 0.5)),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg.w,
          vertical: AppSpacing.md.h,
        ),
        child: Row(
          children: [
            // Muted icon chip — 8% primary, never solid orange.
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColor.primary.withValues(alpha: 0.08),
                borderRadius: AppRadii.rSm,
              ),
              child: Icon(icon, size: 18.sp, color: AppColor.primary),
            ),
            gapH(AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (trailing != null) ...[
              gapH(AppSpacing.sm),
              Flexible(
                child: Text(
                  trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: AppColor.textTertiary,
                  ),
                ),
              ),
              gapH(AppSpacing.xs),
            ],
            Icon(
              Icons.chevron_left_rounded,
              size: 18.sp,
              color: AppColor.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Profile internals
// ===========================================================================

/// Brand hero block at the top of the profile screen.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.child,
  });

  final String? name;
  final String? email;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.xl.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          child,
          gapV(AppSpacing.md),
          Text(
            name ?? AppCopy.profileNameFallback,
            textAlign: TextAlign.center,
            style: AppText.headingSm.copyWith(
              color: AppColor.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          gapV(AppSpacing.xs / 2),
          Text(
            email ?? AppCopy.profileEmailFallback,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyLg.copyWith(
              color: AppColor.white.withValues(alpha: 0.85),
            ),
          ),
          // Plan badge is part of the provider identity, so it only renders
          // for the provider track. Regular users see a clean cream hero.
          ValueListenableBuilder<bool>(
            valueListenable: UserRoleStore.instance.isProvider,
            builder: (_, isProvider, __) {
              if (!isProvider) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(top: AppSpacing.md.h),
                child: ValueListenableBuilder<ProviderEntitlement>(
                  valueListenable: SubscriptionService.instance.entitlement,
                  builder: (_, ent, __) =>
                      PlanBadge(tier: ent.tier, size: PlanBadgeSize.header),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Single row inside the profile info card.
class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg.w,
          vertical: AppSpacing.md.h,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm.w),
              decoration: const BoxDecoration(
                color: AppColor.primary50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColor.primary, size: 20.sp),
            ),
            gapH(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.caption),
                  gapV(AppSpacing.xs / 2),
                  Text(
                    value,
                    style: AppText.bodyLg.copyWith(color: AppColor.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Role banner — context-aware CTA at the top of Profile
// ===========================================================================
//
// Two tones express two different relationships:
//
//   • brand  → "you don't have a hub yet — start one". Bold gradient,
//              white text, primary glow. Reads as a marketing ad on
//              first open.
//   • warm   → "your hub is waiting for you". Soft surface card with the
//              primary accent. Reads like a friendly nudge, not a sales
//              pitch — because the user already crossed the threshold.

enum _RoleBannerTone { brand, warm }

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  final _RoleBannerTone tone;
  final IconData icon;
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBrand = tone == _RoleBannerTone.brand;
    return Semantics(
      button: true,
      label: '$title. $body. $cta',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.rXl,
          child: Ink(
            decoration: BoxDecoration(
              gradient: isBrand
                  ? LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        AppColor.primary,
                        AppColor.primary.withValues(alpha: 0.78),
                      ],
                    )
                  : null,
              color: isBrand ? null : AppColor.primary.withValues(alpha: 0.06),
              borderRadius: AppRadii.rXl,
              border: isBrand
                  ? null
                  : Border.all(
                      color: AppColor.primary.withValues(alpha: 0.22),
                    ),
              boxShadow: isBrand ? AppShadows.primaryGlow : null,
            ),
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 330.w;
                final iconBox = Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: isBrand
                        ? AppColor.white.withValues(alpha: 0.20)
                        : AppColor.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadii.rLg,
                  ),
                  child: Icon(
                    icon,
                    size: 24.sp,
                    color: isBrand ? AppColor.white : AppColor.primary,
                  ),
                );
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.titleMd.copyWith(
                        color: isBrand ? AppColor.white : AppColor.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    gapV(AppSpacing.xs / 2),
                    Text(
                      body,
                      style: AppText.bodySm.copyWith(
                        color: isBrand
                            ? AppColor.white.withValues(alpha: 0.92)
                            : AppColor.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    gapV(AppSpacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.sm.h,
                      ),
                      decoration: BoxDecoration(
                        color: isBrand ? AppColor.white : AppColor.primary,
                        borderRadius: AppRadii.rPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cta,
                            style: AppText.labelMd.copyWith(
                              color:
                                  isBrand ? AppColor.primary : AppColor.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          gapH(AppSpacing.xs),
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 12.sp,
                            color: isBrand ? AppColor.primary : AppColor.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      iconBox,
                      gapV(AppSpacing.md),
                      content,
                    ],
                  );
                }

                return Row(
                  children: [
                    iconBox,
                    gapH(AppSpacing.md),
                    Expanded(child: content),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

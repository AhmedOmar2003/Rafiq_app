import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
import 'package:rafiq_app/view/details/details_page.dart';
import 'package:rafiq_app/view/pages/cubit.dart';
import 'package:rafiq_app/view/pages/profile_page.dart';
import 'package:rafiq_app/view/pages/suggestions/widgets/suggestion_container.dart';
import 'package:rafiq_app/view/pages/suggestions/widgets/suggestion_item.dart';

/// The main screen that displays suggestions and filters
class SuggestionsScreen extends StatefulWidget {
  final List<SuggestionItemModel> suggestionItemList;

  const SuggestionsScreen({
    super.key,
    required this.suggestionItemList,
  });

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  List<SuggestionItemModel> filteredSuggestions = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Profile image is owned by ProfileImageStore (singleton). Just nudge it
    // to load if it hasn't yet — re-mounts are free.
    ProfileImageStore.instance.ensureLoaded();
    filteredSuggestions = widget.suggestionItemList;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FilterCubit, FilterState>(
      listener: (context, state) {
        if (state.places != null) {
          setState(() {
            filteredSuggestions = state.places!
                .map((place) => SuggestionItemModel.fromPlace(place))
                .toList();
          });
        }
      },
      child: AppPageScaffold(
        unpadded: true,
        header: AppPageHeader(
          title: AppCopy.suggestionsTitle,
          subtitle: filteredSuggestions.length == 1
              ? AppCopy.suggestionsCountOne
              : AppCopy.suggestionsCountMany
                  .replaceFirst('%n', '${filteredSuggestions.length}'),
          actions: [_buildProfileAvatar()],
        ),
        body: CustomScrollView(
          controller: _scrollController,
          // PERFORMANCE: pre-cache ~one viewport off-screen so scroll feels
          // instant without holding too many widgets alive at once.
          cacheExtent: 600,
          // Physics tuned for a long product feed: snappy on touch, momentum
          // on iOS, no over-eager bouncing on the filter bar.
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildFilterBar()),
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              sliver: _buildSuggestionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Padding(
      padding: EdgeInsets.only(right: AppSpacing.sm.w),
      child: Semantics(
        button: true,
        label: AppCopy.openProfileLabel,
        child: InkResponse(
          radius: 24.w,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          ).then((_) => ProfileImageStore.instance.refresh()),
          // Only the avatar rebuilds when the picture changes, not the whole
          // suggestions screen.
          child: ValueListenableBuilder<ProfileImageState>(
            valueListenable: ProfileImageStore.instance,
            builder: (_, snap, __) {
              ImageProvider provider;
              if (snap.bytes != null) {
                provider = MemoryImage(snap.bytes!);
              } else if (snap.remoteUrl?.isNotEmpty ?? false) {
                provider = NetworkImage(snap.remoteUrl!);
              } else if (snap.file != null) {
                provider = FileImage(snap.file!);
              } else {
                provider =
                    const AssetImage('assets/images/default_profile.webp');
              }
              return CircleAvatar(
                radius: 18.w,
                backgroundColor: AppColor.surfaceMuted,
                backgroundImage: provider,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: AppSpacing.lg.h, horizontal: AppSpacing.sm.w),
      margin: EdgeInsets.only(bottom: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: const Border(
          bottom: BorderSide(color: AppColor.border, width: 1),
        ),
        boxShadow: AppShadows.level1,
      ),
      // Height must exceed chip minHeight (48.h) so chips aren't clipped.
      child: SizedBox(
        height: 52.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: suggestionList.length,
          itemBuilder: (context, index) => SuggestionItem(
            model: suggestionList[index],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (filteredSuggestions.isEmpty) {
      return SliverFillRemaining(child: AppStateView.search());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final model = filteredSuggestions[index];
          // RepaintBoundary isolates each card on its own layer so scrolling
          // doesn't repaint the whole list every frame.
          return RepaintBoundary(
            child: CustomSuggestionContainer(
              key: ValueKey(model.placeId),
              model: model,
              onTap: () => _navigateToDetails(model),
            ),
          );
        },
        childCount: filteredSuggestions.length,
        // PERFORMANCE: long product feeds shouldn't hang on to off-screen
        // children — let them GC and rebuild from the model when scrolled
        // back into view.
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false, // we wrap manually above
      ),
    );
  }

  void _navigateToDetails(SuggestionItemModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPage(
          model: model,
          suggestionItemList: filteredSuggestions,
        ),
      ),
    );
  }
}

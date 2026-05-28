import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/view/details/details_page.dart';
import 'package:rafiq_app/view/pages/cubit.dart';
import 'package:rafiq_app/view/pages/profile_page.dart';
import 'package:rafiq_app/view/pages/suggestions/widgets/suggestion_container.dart';
import 'package:rafiq_app/view/pages/suggestions/widgets/suggestion_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The main screen that displays suggestions and filters
class SuggestionsScreen extends StatefulWidget {
  final List<SuggestionItemModel> suggestionItemList;

  const SuggestionsScreen({
    Key? key,
    required this.suggestionItemList,
  }) : super(key: key);

  @override
  _SuggestionsScreenState createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  static const String _profileImageKey = 'profile_image';
  static const String _profileImageWebKey = 'profile_image_base64';
  List<SuggestionItemModel> filteredSuggestions = [];
  File? _profileImage;
  Uint8List? _profileImageBytes;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    filteredSuggestions = widget.suggestionItemList;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      final base64Value = prefs.getString(_profileImageWebKey);
      if (base64Value == null || base64Value.isEmpty) {
        if (!mounted) return;
        setState(() {
          _profileImageBytes = null;
          _profileImage = null;
        });
        return;
      }
      try {
        final bytes = base64Decode(base64Value);
        if (!mounted) return;
        setState(() {
          _profileImageBytes = bytes;
          _profileImage = null;
        });
      } catch (_) {
        await prefs.remove(_profileImageWebKey);
      }
      return;
    }

    final savedPath = prefs.getString(_profileImageKey);
    if (savedPath == null || savedPath.isEmpty) return;

    final file = File(savedPath);
    if (await file.exists()) {
      if (!mounted) return;
      setState(() {
        _profileImage = file;
      });
    } else {
      await prefs.remove(_profileImageKey);
    }
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
      child: InkResponse(
        radius: 24.w,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        ).then((_) => _loadProfileImage()),
        child: CircleAvatar(
          radius: 18.w,
          backgroundColor: AppColor.surfaceMuted,
          backgroundImage: _profileImageBytes != null
              ? MemoryImage(_profileImageBytes!) as ImageProvider
              : _profileImage != null
                  ? FileImage(_profileImage!)
                  : const AssetImage('assets/images/default_profile.png'),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h, horizontal: AppSpacing.sm.w),
      margin: EdgeInsets.only(bottom: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border(
          bottom: BorderSide(color: AppColor.border, width: 1),
        ),
        boxShadow: AppShadows.level1,
      ),
      child: SizedBox(
        height: 44.h,
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
    return filteredSuggestions.isNotEmpty
        ? SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final model = filteredSuggestions[index];
                return CustomSuggestionContainer(
                  model: model,
                  onTap: () => _navigateToDetails(model),
                );
              },
              childCount: filteredSuggestions.length,
            ),
          )
        : SliverFillRemaining(
            child: AppStateView.search(),
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

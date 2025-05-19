import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
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
  List<SuggestionItemModel> filteredSuggestions = [];
  File? _profileImage;
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
    final savedPath = prefs.getString('profile_image');
    if (savedPath != null) {
      setState(() {
        _profileImage = File(savedPath);
      });
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
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: _buildFilterBar(),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              sliver: _buildSuggestionsList(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(90.h),
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.ofWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColor.black,
                size: 24.sp,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: Padding(
            padding: EdgeInsets.only(top: 20.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomTextWidget(
                  label: "الاقتراحات",
                  style: TextStyleTheme.textStyle24Medium.copyWith(
                    color: AppColor.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildProfileAvatar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        ).then((_) => _loadProfileImage()),
        child: CircleAvatar(
          radius: 22.w,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 20.w,
            backgroundImage: _profileImage != null
                ? FileImage(_profileImage!)
                : const AssetImage('assets/images/default_profile.png') as ImageProvider,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColor.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 40.h,
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
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48.sp,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16.h),
                    CustomTextWidget(
                      label: "لا توجد اقتراحات متاحة حالياً.",
                      style: TextStyleTheme.textStyle20Bold.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
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

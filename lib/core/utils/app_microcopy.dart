/// Centralized Egyptian-Arabic microcopy.
///
/// Tone: warm, light, human, respectful — never robotic or technical. The user
/// should feel the app *understands* them. Keep messages short. No raw error
/// codes or stack traces in front of users.
///
/// Grouped by intent so screens reuse the same voice instead of inventing
/// one-off strings. Add new copy here, not inline.
class AppCopy {
  AppCopy._();

  // --- Offline / connectivity --------------------------------------------------
  static const offlineTitle = 'النت فاصل شوية';
  static const offlineBody = 'أول ما يرجع هنكمّل. جرّب تاني بعد شوية.';
  static const offlineBanner = 'مفيش نت دلوقتي. بنحاول نوصل تاني.';
  static const backOnline = 'النت رجع';

  // --- Generic errors (friendly, no jargon) ------------------------------------
  static const errorTitle = 'حصلت مشكلة بسيطة';
  static const errorBody = 'مقدرناش نكمّل دلوقتي. جرّب تاني بعد شوية.';
  static const errorRetry = 'حاول تاني';
  static const errorGeneric = 'في حاجة مش ظابطة. جرّب تاني بعد شوية.';

  // --- Empty states ------------------------------------------------------------
  static const emptyResultsTitle = 'مفيش حاجة هنا لسه';
  static const emptyResultsBody = 'جرّب تغيّر اختياراتك وهنلاقيلك حاجة تعجبك.';
  static const emptySearchTitle = 'ملقيناش اللي بتدوّر عليه';
  static const emptySearchBody = 'جرّب كلمة تانية أو قلّل الفلاتر.';
  static const emptyFavoritesTitle = 'لسه مفيش مفضّلة';
  static const emptyFavoritesBody =
      'أول ما يعجبك مكان، دوس على القلب وهيتحفظ هنا.';

  // --- Loading -----------------------------------------------------------------
  static const loading = 'ثانية بس...';
  static const loadingSuggestions = 'بندوّرلك على أحلى أماكن...';
  static const loadingSaving = 'بنحفظ بياناتك...';

  // --- Success -----------------------------------------------------------------
  static const successGeneric = 'تمام! اتعمل بنجاح ✅';
  static const successSaved = 'اتحفظ بنجاح';
  static const welcomeBack = 'نورت تاني';

  // --- Form validation (soft, guiding) -----------------------------------------
  static const fieldRequired = 'اكتب البيانات دي عشان نكمّل';
  static const emailInvalid = 'راجع الإيميل كده';
  static const emailGmailOnly = 'لازم يكون بريد @gmail.com';
  static const passwordRequired = 'اكتب كلمة السر';
  static const passwordShort =
      'استخدم 8 حروف على الأقل: حرف كبير، حرف صغير، رقم ورمز';
  static const passwordsMismatch = 'الكلمتين مش زي بعض، راجعهم';

  // --- Actions / buttons -------------------------------------------------------
  static const retry = 'جرّب تاني';
  static const ok = 'تمام';
  static const cancel = 'إلغاء';
  static const confirm = 'أكيد';
  static const next = 'اللي بعده';
  static const done = 'خلصنا';
  static const refresh = 'تحديث';

  // --- Suggestion / place cards ------------------------------------------------
  static const priceStartsFrom = 'تبدأ من';
  static const priceUnspecified = 'السعر مش متحدد';
  static const currencyEgp = 'جنيه مصري';
  static const ratingFallback = '(جديد)';

  // --- Home / step flow --------------------------------------------------------
  static const homeTitle = 'ابدأ مشوارك';
  static const stepCity = 'المدينة';
  static const stepBudget = 'الميزانية';
  static const stepActivity = 'النشاط';
  static const homeIncomplete =
      'كمّل الاختيارات الأول، عشان نلاقيلك أحلى أماكن.';
  static const homeCtaFinal = 'شوف اقتراحاتي';
  static const homeStepCounter = 'خطوة %d من %t'; // %d=current, %t=total
  static const back = 'رجوع';
  static const stepCityRequired = 'اختار المدينة الأول.';
  static const stepBudgetRequired = 'اختار ميزانيتك الأول.';
  static const stepActivityRequired = 'اختار النشاط اللي يناسبك.';

  // Step screen headings & bodies
  static const stepCityTitle = 'عايز تخرج فين؟';
  static const stepCityBody = 'اختار مدينة واحدة.';
  static const stepBudgetTitle = 'ميزانيتك كام؟';
  static const stepBudgetBody = 'اختار أقرب ميزانية ليك.';
  static const stepActivityTitle = 'عايز تعمل إيه؟';
  static const stepActivityBody = 'اختار نشاط واحد.';

  // --- Chatbot -----------------------------------------------------------------
  static const chatTitle = 'رفيق الذكي 🤖';
  static const chatOpenLabel = 'افتح رفيق الذكي';

  // --- Choice / role picker ----------------------------------------------------
  static const choiceQuestion = 'إنت مين معانا اليوم؟';
  static const choiceRoleUser = 'مستخدم عادي';
  static const choiceRoleProvider = 'مقدم خدمة';
  static const choiceUserSubtitle = 'استكشف الأماكن وشارك تجاربك';
  static const choiceProviderSubtitle = 'ضيف مكانك واستقبل زوارك';
  static const choicePickFirst = 'اختار الأول: مستخدم ولا مقدم خدمة؟';
  // After a provider has chosen a plan, the second card transitions from
  // "مقدم خدمة" (sign-up posture) to "تابع خدمتك" (active customer).
  static const choiceRoleProviderActive = 'تابع خدمتك';
  static const choiceProviderActiveSubtitle =
      'افتح لوحتك وشوف أماكنك وإحصائياتك';

  // --- Provider / add-place flow ----------------------------------------------
  static const providerFormTitle = 'بيانات مكانك';
  static const providerSessionExpired =
      'انتهت جلسة الدخول، سجّل تاني عشان نكمّل.';
  static const providerAddedSuccess =
      'استلمنا المكان. هو دلوقتي قيد المراجعة وعادة بيرد خلال 24 ساعة.';
  static const providerResubmittedSuccess =
      'اتحفظت التعديلات ورجع للمراجعة تاني.';
  static const providerImagePickError =
      'حصلت مشكلة وانت بتختار الصورة، جرّب تاني.';
  static const providerSavedTitle = 'مبروك! بيانات مكانك اتسجلت';
  static const providerGalleryTitle = 'صور المكان';
  static const providerCoverHint = 'الصورة الأولى هتبقى الكوفر';
  static const providerAddImage = 'ضيف صورة';
  static const providerImagesUsed = '%u من %m صورة';
  static const providerImagesUnlimited = '%u صورة';
  static const providerRemoveImage = 'احذف الصورة';
  static const addPlaceNameLabel = 'اسم المكان';
  static const addPlaceNameRequired = 'الرجاء إدخال اسم المكان';
  static const addPlaceCityLabel = 'المدينة';
  static const addPlaceCityRequired = 'الرجاء اختيار المدينة';
  static const addPlaceTypeLabel = 'نوع النشاط';
  static const addPlaceTypeRequired = 'الرجاء اختيار نوع النشاط';
  static const addPlaceBudgetLabel = 'الميزانية';
  static const addPlaceBudgetRequired = 'الرجاء اختيار الميزانية';
  static const addPlaceAddressLabel = 'العنوان التفصيلي';
  static const addPlaceAddressRequired = 'الرجاء إدخال العنوان';
  static const addPlaceDescLabel = 'وصف عن المكان ومميزاته';
  static const addPlaceDescRequired = 'الرجاء إدخال وصف عن المكان';
  static const addPlaceSaveEdit = 'حفظ التعديلات';
  static const addPlaceSaveNew = 'حفظ البيانات';
  static const providerEditedSuccess = 'تم حفظ تعديل المكان';
  static const providerApprovedEditSubmitted =
      'تم إرسال التعديل للمراجعة. هنرد عليك خلال 6 ساعات.';
  static const addPlaceNameHint = 'اكتب اسم المكان';
  static const addPlaceAddressHint = 'اكتب العنوان بالتفصيل';
  static const addPlaceDescHint = 'وصف مختصر عن المكان وأهم مميزاته';
  static const promoFieldTitleHint = 'مثلاً: خصم 20% على كل التورتات';
  static const promoFieldBodyHint = 'تفاصيل العرض أو المناسبة...';
  static const promoFieldCtaHint = 'مثلاً: اعرف التفاصيل';

  // --- Suggestions list --------------------------------------------------------
  static const suggestionsTitle = 'اقتراحاتنا ليك';
  static const suggestionsCountOne = 'نتيجة واحدة';
  static const suggestionsCountMany = '%n نتيجة'; // %n = number

  // --- Filters -----------------------------------------------------------------
  static const filterActivity = 'النشاط';
  static const filterPlace = 'المكان';
  static const filterBudget = 'الميزانية';
  static const filterClear = 'شيل الفلتر';
  static const filterApply = 'طبّق الفلتر';
  static const filterApplied = 'تم التحديث';

  // --- Reviews / evaluations ---------------------------------------------------
  static const reviewsTitle = 'التقييمات';
  static const reviewDateUnknown = 'بدون تاريخ';
  static const reviewAuthorAnonymous = 'مستخدم مجهول';
  static const reviewInputHint = 'قول لنا رأيك في المكان...';
  static const reviewEmptyText = 'اكتب تعليق قصير وبعدين ابعته.';
  static const reviewPickStars = 'اختر تقييمك بالنجوم';
  static const reviewSendCta = 'أرسل التقييم';
  static const reviewStarsHelper = 'اختار النجوم، ولو حابب اكتب تعليق.';
  static const reviewWriteOptional = 'اكتب تعليقك هنا';
  static const reviewNoCommentFallback = 'أضاف تقييمًا بدون تعليق نصي.';
  static const reviewThanksTitle = 'وصل تقييمك';
  static const reviewThanksBody = 'رأيك هيساعد ناس تختار أسهل';
  static const reviewsEmptyHeadline = 'لسه مفيش تقييمات';
  static const reviewsEmptyShare = 'ابدأ أول تقييم';
  static const reviewsEmptyHelp = 'رأيك هيفرق مع غيرك';
  static const reviewsEmptyDiscover = 'قول رأيك ببساطة';

  // --- Details page ------------------------------------------------------------
  static const detailsTitle = 'التفاصيل';
  static const detailsBeFirstReview = 'لسه مفيش تقييمات';
  static const detailsAddYourComment = 'اكتب أول تقييم';
  static const detailsDescriptionTitle = 'عن المكان';
  static const detailsOffersTitle = 'العروض الحالية';
  static const detailsOfferActiveNow = 'نشط الآن';
  static const detailsOfferEndsSoon = 'متاح حتى %date';
  static const detailsOfferNoEndDate = 'العرض شغال حاليًا';
  static const detailsSimilarHeading = 'أماكن شبهه';
  static const detailsNoSimilar = 'مفيش أماكن مشابهة دلوقتي';
  static const detailsLocationLabel = 'الموقع';
  static const detailsPriceLabel = 'السعر';
  static const detailsOpenMap = 'عرض على الخريطة';
  static const detailsFavoriteAdd = 'إضافة إلى المفضلة';
  static const detailsFavoriteRemove = 'إزالة من المفضلة';
  static const detailsFavoriteSaved = 'اتحفظ في المفضلة ❤️';
  static const detailsFavoriteRemoved = 'اتشال من المفضلة';
  static const detailsReport = 'بلّغ عن هذا المكان';
  static const detailsOffersSemanticPrefix = 'العروض الحالية';
  static const detailsDescriptionSemanticLabel = 'وصف المكان';
  static const detailsSimilarSemanticPrefix = 'أماكن مشابهة';
  static const detailsFirstReviewSemantic = 'اكتب أول تقييم لهذا المكان';
  static const reportPickReason = 'اختر سبب البلاغ';
  static const reportDetailsHint = 'تفاصيل إضافية (اختياري)';
  static const reportSendCta = 'إرسال البلاغ';
  static const reportMissingReason = 'من فضلك اختر سبب البلاغ أولاً';
  static const reportCannotSubmit =
      'مش قادرين نرفع البلاغ على المكان ده دلوقتي';
  static const reportSentSuccess = 'وصلنا بلاغك، هنراجعه قريباً ✅';
  static const reportSentFail = 'معرفناش نبعت البلاغ، جرّب تاني';
  static const placeCardOpen = 'افتح '; // append place name
  static const placePlanPro = 'برو';
  static const placePlanMax = 'ماكس';
  static const placePlanProSemantic = 'مكان بخطة برو';
  static const placePlanMaxSemantic = 'مكان بخطة ماكس';
  static const profileOpenLabel = 'افتح البروفايل';

  // --- Profile page ------------------------------------------------------------
  static const profileTitle = 'الملف الشخصي';
  static const profileNameFallback = 'مستخدم رفيق';
  static const profileEmailFallback = 'لسه مفيش بريد ظاهر';
  static const profileNameLabel = 'الاسم';
  static const profileEmailLabel = 'البريد الإلكتروني';
  static const profilePasswordLabel = 'كلمة السر';
  static const profileAccountSection = 'حسابك';
  static const profileAppearanceSection = 'الوضوح والشكل';
  static const profileTextSizeLabel = 'حجم الخط';
  static const profileTextSizeHint = 'اختار الحجم اللي يريح عينك.';
  static const profileTextSizeSmall = 'عادي';
  static const profileTextSizeMedium = 'أوضح';
  static const profileTextSizeLarge = 'كبير';
  static const profileChangeAvatarHint = 'دوس عشان تغيّر الصورة';
  static const profileImageSaveError = 'معرفناش نحفظ الصورة، جرّب تاني.';
  static const profileSwitchToProvider = 'حوّل لمقدم خدمة';
  static const profileSwitchToProviderValue = 'افتح خطط الاشتراك وأضف مكانك';
  static const profileSwitchToUser = 'تصفح كمستخدم عادي';
  static const profileSwitchToUserValue = 'خطتك وأماكنك محفوظة';
  static const profileSwitchConfirmTitle = 'تأكيد تغيير الدور';
  static const profileSwitchConfirmProvider =
      'هتروح للخطط وتختار اللي يناسبك. تقدر ترجع مستخدم عادي في أي وقت.';
  static const profileSwitchConfirmUser =
      'هترجع تتصفح كمستخدم عادي. اشتراكك وأماكنك هيفضلوا محفوظين.';
  static const profileFavoritesTitle = 'أماكنك المفضلة';
  static const profileFavoritesBody = 'الأماكن اللي حفظتها.';
  static const profileFavoritesRefresh = 'تحديث المفضلة';
  static const profileFavoritesMore = 'فيه %n أماكن مفضلة كمان محفوظين عندك.';

  // --- Profile banners (context-aware CTA, personalized by name) ----------
  /// Regular user who never confirmed a provider plan — friendly invite.
  /// Title is composed at render time as "{name}، ..." so each user feels
  /// the prompt is for them, not a generic ad. The body explains the value
  /// in human terms; the CTA is short and warm ("يلا أبدأ").
  static const profileBannerInviteTitle = 'عندك مكان أو خدمة؟';
  static const profileBannerInviteBody = 'ضيفها وخلي الناس تقدر توصلك بسهولة.';
  static const profileBannerInviteCta = 'ابدأ كمقدم خدمة';

  /// Provider who switched to user mode — invite them back to their hub.
  /// Singular/plural copy auto-picked from the place count.
  static const profileBannerReturnTitleSingle = 'خدمتك جاهزة';
  static const profileBannerReturnTitleMulti = 'خدماتك جاهزة';
  static const profileBannerReturnBody = 'كل بياناتك محفوظة.';
  static const profileBannerReturnCtaSingle = 'تابع خدمتك';
  static const profileBannerReturnCtaMulti = 'تابع خدماتك';
  static const logoutTitle = 'هتسجل خروج؟';
  static const logoutMessage = 'متأكد إنك عايز تخرج من التطبيق؟';
  static const logoutConfirm = 'أكيد، خروج';
  static const logoutCta = 'تسجيل الخروج';
  static const logoutError = 'معرفناش نسجّل خروجك دلوقتي، جرّب تاني.';

  // --- Auth (shared) -----------------------------------------------------------
  static const authSeparatorOr = 'أو';
  static const authOrDividerLabel = 'أو يمكنك';
  static const authEmailLabel = 'البريد الإلكتروني';
  static const authEmailHint = 'example@gmail.com';
  static const authPasswordLabel = 'كلمة السر';
  static const authPasswordHint = 'مثال: Ahmed11#';
  static const authPasswordHelper = 'اكتب كلمة السر اللي سجلت بيها.';
  static const authForgotPasswordLink = 'نسيت كلمة السر؟';

  // --- Login -------------------------------------------------------------------
  static const loginTitle = 'تسجيل الدخول';
  static const loginCta = 'دخول';
  static const loginGoogle = 'كمّل بـ Google';
  static const loginSuccess = 'تمام، دخلت بنجاح ✅';
  static const loginNoAccountPrefix = 'لسه ما عملتش حساب؟ ';
  static const loginGoToRegister = 'سجّل دلوقتي';
  static const loginSubtitle = 'ادخل وكمل مكان ما وقفت.';

  // --- Register ----------------------------------------------------------------
  static const registerTitle = 'إنشاء حساب';
  static const registerCta = 'سجّل';
  static const registerGoogle = 'سجّل بـ Google';
  static const registerSuccess = 'حسابك جاهز ✅';
  static const registerNameLabel = 'اسمك';
  static const registerNameHint = 'مثلاً: أحمد عصام';
  static const registerHasAccountPrefix = 'عندك حساب بالفعل؟ ';
  static const registerGoToLogin = 'سجّل دخول';
  static const registerSubtitle = 'خطوة صغيرة ونبدأ.';
  static const registerPasswordHelper = 'مثال قوي: Ahmed11#';
  static const registerPasswordTip = 'اختار كلمة مختلفة عن أي حساب تاني.';

  // --- Forgot password ---------------------------------------------------------
  static const forgotTitle = 'نسيت كلمة السر؟';
  static const forgotBody = 'اكتب بريدك وهنبعتلك كود ترجع تدخل بيه.';
  static const forgotSendCode = 'ابعت الكود';
  static const forgotCodeSent = 'بعتنالك كود التأكيد على بريدك ✉️';
  static const forgotHint = 'لما الكود يوصلك اكتبه وكمل.';

  // --- Verify code -------------------------------------------------------------
  static const verifyTitle = 'تأكيد الكود';
  static const verifyBodyPrefix = 'بعتنالك كود على ';
  static const verifyBodySuffix = ' — اكتبه عشان نكمّل.';
  static const verifyCta = 'أكّد الكود';
  static const verifyResend = 'ابعت الكود تاني';
  static const verifyResendIn = 'تقدر تطلبه تاني بعد';
  static const verifyCodeWrongLength = 'الكود لازم يكون 6 أرقام';

  // --- Signup verification (new flow after register) --------------------------
  static const signupVerifyTitle = 'أكّد إيميلك';
  static const signupVerifyBody = 'بعتنالك كود على بريدك.';
  static const signupVerifyTail = 'اكتبه تحت ونكمّل.';
  static const signupVerifySuccessTitle = 'حسابك اتفعّل ✅';
  static const signupVerifySuccessBody = 'يلا نبدأ';

  // --- Password reset verification --------------------------------------------
  static const resetVerifyTitle = 'تأكيد الهوية';
  static const resetVerifyBody = 'بعتنالك كود على بريدك.';
  static const resetVerifyTail = 'اكتبه عشان نكمّل بأمان.';

  // --- Reset password ----------------------------------------------------------
  static const resetTitle = 'كلمة سر جديدة';
  static const resetBody = 'اختار كلمة سر جديدة وسهلة.';
  static const resetCta = 'حفظ كلمة السر';
  static const resetSuccess = 'تمام! كلمة السر اتغيّرت ✅';
  static const resetSuccessBody = 'تقدر دلوقتي تسجّل دخولك بكلمة السر الجديدة.';
  static const resetConfirmHint = 'اكتبها تاني للتأكيد';
  static const resetOtpHint = '6 أرقام';

  // --- Subscription page -------------------------------------------------------
  static const subTitle = 'خطط الاشتراك';
  static const subSubtitle = 'اختار اللي يناسبك.';
  static const subBillingMonthly = 'شهري';
  static const subBillingYearly = 'سنوي';
  static const subYearlyDiscount = 'وفّر %p%'; // %p replaced with discount pct
  static const subCurrent = 'خطتك الحالية';
  static const subRecommended = 'الأكثر اختياراً';
  static const subCancelRenewal = 'الرجوع للخطة المجانية';
  static const subDowngradeTitle = 'ترجع للخطة المجانية؟';
  static const subDowngradeMessage =
      'مميزات خطتك الحالية هتتوقف، وتقدر تختار خطة تانية بعدين.';
  static const subDowngradeConfirm = 'أيوه، ارجع للمجانية';
  static const subDowngradeSuccess = 'رجعت للخطة المجانية.';
  static const subUpgrade = 'رقّي خطتك';
  static const subManage = 'إدارة الاشتراك';
  static const subFreeForever = 'مجاني للأبد';
  static const subPerMonth = '/شهر';
  static const subPerYear = '/سنة';
  static const subRenewsOn = 'يتجدد في';
  static const subCancelsOn = 'ينتهي في';
  static const subFeatureUnlimited = 'بلا حدود';
  static const subCompareTitle = 'أهم الفروق';
  static const subLimitReached = 'وصلت الحد الأقصى للخطة الحالية';
  static const subUpgradeCta = 'رقّي الخطة عشان تكمّل';
  static const subUpgradeSheetHint =
      'شوف الخطط المتاحة واختار اللي يناسب شغلك.';
  static const subFeatPlaces = 'عدد الأماكن';
  static const subFeatGallery = 'صور المعرض';
  static const subFeatVideos = 'الفيديوهات';
  static const subFeatRanking = 'تحسين الظهور';
  static const subFeatVerified = 'شارة موثَّق';
  static const subFeatAnalytics = 'تحليلات';
  static const subFeatPromotions = 'إعلانات وعروض';
  static const subFeatPromoSlots = 'عدد الإعلانات والعروض';
  static const subFeatFeatured = 'ظهور مميّز';
  static const subFeatPush = 'إشعارات ترويجية';
  static const subFeatSpotlight = 'بريميوم في الصفحة الرئيسية';
  static const subFeatSupport = 'دعم أولوية';
  static const subFeatPlaceReview = 'مراجعة المكان خلال 24 ساعة';
  static const subFeatCampaignReview = 'مراجعة الإعلان خلال 6 ساعات';
  static const subStatusActive = 'نشط';
  static const subStatusTrialing = 'تجربة';
  static const subStatusPastDue = 'متأخّر';
  static const subStatusCanceled = 'سيتم الإنهاء';
  static const subStatusExpired = 'منتهي';
  static const subUpgradeInProgress =
      'تم استلام طلبك، هنبعتلك تأكيد على بريدك.';

  // --- Onboarding (provider plan picker) --------------------------------------
  static const subOnboardingTitle = 'اختار خطتك';
  static const subOnboardingSubtitle = 'اختار بنفسك. مفيش اختيار تلقائي.';
  static const subReviewWindowNotice = 'مراجعة المكان خلال 24 ساعة.';
  static const subOnboardingFreeCta = 'كمّل بالخطة المجانية';
  static const subOnboardingContinueCta = 'يلا نضيف مكانك';
  static const subSaveFailed =
      'تعذر تأكيد الخطة الآن. جرّب مرة أخرى عشان نحفظ اختيارك بشكل صحيح.';

  // --- Demo upgrade flow -------------------------------------------------------
  static const subConfirmTitle = 'أكّد اشتراكك';
  static const subConfirmSubtitlePrefix = 'هتنضم لخطة';
  static const subConfirmBenefitsHeading = 'هتحصل على:';
  static const subConfirmPriceLabel = 'المبلغ';
  static const subConfirmCta = 'أكّد الاشتراك';
  static const subSuccessTitlePrefix = 'مبروك! خطة';
  static const subSuccessTitleSuffix = 'اتفعّلت ✨';
  static const subSuccessBody =
      'دلوقتي تقدر تستمتع بكل المميزات، وفترة اشتراكك سارية لمدة شهر.';
  static const subSuccessCta = 'يلا نبدأ';
  static const subDemoBadge = 'تجربة عرض';
  static const subDemoExplainer = 'الدفع الحقيقي لسه ما اتفعلش.';

  // --- Provider hub ------------------------------------------------------------
  static const hubTitle = 'تابع خدمتك';
  static const hubProfileRowLabel = 'تابع خدمتك';
  static const hubProfileRowValue = 'إدارة مكانك وإحصائياتك';
  static const hubGreetingPrefix = 'أهلاً بيك';
  static const hubCurrentPlan = 'خطتك الحالية';
  static const hubManagePlan = 'إدارة الخطة';
  static const hubKpiPlaces = 'أماكن';
  static const hubKpiImages = 'صور لكل مكان';
  static const hubKpiAnalytics = 'تحليلات';
  static const hubFeatTitleAnalytics = 'تحليلات الأداء';
  static const hubFeatBodyAnalytics = 'شوف الحركة الحقيقية على مكانك.';
  static const hubFeatTitlePromotions = 'إعلانات وعروض';
  static const hubFeatBodyPromotions =
      'اعمل عرض بسيط وخلّيه يوصل للناس بعد المراجعة.';
  static const hubFeatTitlePlaces = 'أماكنك';
  static const hubFeatBodyPlaces = 'إدارة الأماكن، التعديل، وإضافة جديد.';
  static const hubFeatTitleSubscription = 'الاشتراك';
  static const hubFeatBodySubscription = 'بدّل أو رقّي خطتك في أي وقت.';
  static const hubLockedTag = 'يفتح مع برو';
  static const hubLockedMax = 'يفتح مع ماكس';
  static const hubPlacesMultiTitle = 'تابع خدماتك';
  static const hubPlacesSingleTitle = 'شوف مكانك';
  static const hubPlacesEmptyBody = 'أضف مكانك الأول وابدأ شغلك.';
  static const hubStepPlan = 'الخطة';
  static const hubStepPreview = 'المعاينة';
  static const hubPlaceApproved = 'تم اعتماد "%s" — ظاهر للجمهور دلوقتي';
  static const hubPlaceRejected = 'تم رفض "%s" — راجع السبب وعدّل';
  static const hubPlaceSuspended = 'تم تعليق "%s" مؤقتاً';
  static const hubPlacePending = '"%s" رجع للمراجعة';
  static const hubMyPlacesTitle = 'أماكني';
  static const hubPlacesEmptyFirstBody = 'أضف مكانك الأول، وهتلاقيه هنا فورًا.';
  static const hubPlacesManageBody = 'اختار الحالة وتابع كل مكان بسهولة.';
  static const hubPlacesFilterSemantics = 'تصفية الأماكن حسب حالة المراجعة';
  static const hubFilterAll = 'الكل';
  static const hubFilterPending = 'قيد المراجعة';
  static const hubFilterApproved = 'معتمد';
  static const hubFilterRejected = 'مرفوض';
  static const hubFilterSuspended = 'موقوف';
  static const hubFilterEmpty = 'مفيش أماكن بحالة "%s" دلوقتي';
  static const hubPlacePreview = 'المعاينة';
  static const hubPlaceEdit = 'تعديل';
  static const hubPlaceDelete = 'حذف';
  static const hubPlaceMore = 'خيارات المكان';
  static const hubPendingEditHint =
      'تقدر تعدّل بيانات المكان طول ما هو تحت المراجعة.';
  static const hubApprovedEditTitle = 'اطلب تعديل المكان';
  static const hubApprovedEditBody =
      'المكان هيفضل ظاهر ببياناته الحالية. بعد موافقة الإدارة تقدر تعدّله، والتغيير الجديد يتراجع خلال 6 ساعات قبل نشره.';
  static const hubApprovedEditConfirm = 'ابعت طلب التعديل';
  static const hubEditRequestSent =
      'طلب التعديل وصل للإدارة. هنبلغك أول ما يتفتح التعديل.';
  static const hubEditRequestPending = 'طلب التعديل قيد المراجعة';
  static const hubEditRequestApproved = 'تم فتح التعديل — عدّل الآن';
  static const hubEditRequestSubmitted =
      'تعديلك تحت المراجعة، وهنرد عليك خلال 6 ساعات.';
  static const hubEditRequestRejected = 'طلب التعديل اترفض';
  static const hubEditRequestUnavailable =
      'التعديل مش متاح للمكان بالحالة دي دلوقتي.';
  static const hubBootstrapTitle = 'جارٍ تجهيز حسابك';
  static const hubBootstrapError = 'تعذر تجهيز بيانات الحساب الآن';
  static const hubBootstrapRetryHint =
      'اضغط إعادة المحاولة أو اسحب لأسفل لتحديث البيانات';
  static const hubRetryLabel = 'إعادة المحاولة';
  static const hubTabPlatformTitle = 'تابع خدماتك';
  static const hubPlacesBodyCount =
      'عندك %p من %m أماكن. ولكل مكان حتى %i صورة.';
  static const hubAddPlace = 'أضف مكان جديد';
  static const hubAddPlaceLimitReached = 'وصلت الحد';
  static const hubRejectedTitle = 'تم رفض الإضافة';
  static const hubRejectedBody = 'راجع السبب وعدّل أو قدّم طعناً';
  static const hubRejectedReasonPrefix = 'السبب:';
  static const hubRejectedEditAllowed = 'سمحنالك تعدّل وترجّعه للمراجعة';
  static const hubEditAndResubmit = 'عدّل وارجّعه';
  static const hubEmptyPlacesTitle = 'لسه ما أضفتش أي مكان';
  static const hubEmptyPlacesMsgBody =
      'أضف مكانك الأول عشان تبدأ اللوحة وتظهر كل الإحصائيات';
  static const hubAddPlaceNow = 'أضف مكانك الآن';
  static const hubStatusApproved = 'تم الاعتماد';
  static const hubStatusRejected = 'تم الرفض';
  static const hubStatusSuspended = 'موقوف مؤقتًا';
  static const hubStatusUnderReview = 'جاري مراجعته الآن';
  static const hubStatusAwaitingReview = 'في انتظار المراجعة';
  static const hubReviewQueueTitle = 'قيد المراجعة';
  static const hubReviewQueueBody = 'المراجعة عادة خلال 24 ساعة من وقت الإضافة';
  static const openProfileLabel = 'افتح ملفك الشخصي';
  static const placeOpenPrefix = 'افتح';
  static const anaFilterByLabel = 'تصفية حسب';

  // --- Analytics screen --------------------------------------------------------
  static const anaTitle = 'تحليلاتك';
  static const anaLast30Days = 'آخر 30 يوم';
  static const anaRealDataHint = 'الأرقام دي من فتح المكان، المفضلة، والخريطة.';
  static const anaViewsReal = 'فتح صفحة المكان';
  static const anaTotalActions = 'إجمالي التفاعلات';
  static const anaFavoriteAdds = 'إضافات للمفضلة';
  static const anaFavoriteRemovals = 'إزالة من المفضلة';
  static const anaOtherActions = 'تفاعلات أخرى';
  static const anaPlaceViews = 'مشاهدات المكان';
  static const anaInteractions = 'إجمالي التفاعلات';
  static const anaFavorites = 'إضافة للمفضلة';
  static const anaMapClicks = 'فتح الخريطة';
  static const anaCampaignClicks = 'ضغطات الإعلانات';
  static const anaLockedTitle = 'فعّل تحليلات الأداء';
  static const anaLockedBody =
      'متاحة في برو أو ماكس عشان تتابع تفاعل الناس مع مكانك.';
  static const anaUpgradeCta = 'رقّي لـ برو';
  static const anaAllPlaces = 'كل الأماكن';
  static const anaLastDays = 'آخر %d يوم'; // %d = number of days
  static const anaTrendTitle = 'اتجاه فتح المكان';
  static const anaTrendHint =
      'كل نقطة بتوضح الحركة اليومية في الفترة اللي اخترتها.';
  static const anaNoApprovedTitle = 'التحليلات هتظهر أول ما مكانك يتعتمد';
  static const anaNoApprovedBody =
      'لو مكانك لسه تحت المراجعة، هتلاقي الأرقام هنا بعد الاعتماد.';

  // --- Promotions screen -------------------------------------------------------
  static const promoTitle = 'إعلاناتك';
  static const promoEmptyTitle = 'لسه ما عملتش حملة';
  static const promoEmptyBody =
      'اعمل عرض أو إعلان لمكانك وهيوصل لناس أكتر بعد المراجعة.';
  static const promoCreateCta = 'اعمل حملة جديدة';
  static const promoCreatePendingBody =
      'أي حملة جديدة بتدخل مراجعة، وغالبًا بنرد خلال 6 ساعات.';
  static const promoRejectedReason = 'سبب الرفض';
  static const promoPendingReview = 'بانتظار مراجعة الأدمن';
  static const promoLockedTitle = 'الإعلانات تبدأ من خطة برو';
  static const promoLockedBody = 'فعّل الإعلانات عشان توصّل عرضك لناس أكتر.';
  static const promoSectionTitle = 'إعلاناتك وعروضك';
  static const promoAllPlaces = 'كل الأماكن';
  static const promoNoApprovedPlaces = 'لا توجد أماكن معتمدة بعد';
  static const promoSelectedPlaceFallback = 'مكان محدد';
  static const promoQuotaAvailable = 'المتاح الآن: %n حملة';
  static const promoQuotaUsed = 'المستخدم الآن: %n';
  static const promoPlanNote =
      'الحملات النشطة أو تحت المراجعة فقط هي اللي بتتحسب على الخطة.';
  static const promoLimitReached = 'وصلت لحد الخطة الحالي';
  static const promoRequestEditSuccess =
      'تم إرسال طلب التعديل للإدارة. هنراجع الطلب ونبلغك أول ما يتفتح التعديل.';
  static const promoEditRequestPendingNotice =
      'طلب التعديل اتبعت للإدارة. بمجرد الموافقة هيتحول الزر إلى "عدّل الآن".';
  static const promoEditRequestApprovedNotice =
      'تمت الاستجابة للطلب. عدّل الإعلان وابعته من جديد، وهيعود للمراجعة خلال 6 ساعات أو أقل.';
  static const promoAllCampaigns = 'كل الحملات';
  static const promoCampaignsActive = 'نشطة';
  static const promoCampaignsPending = 'قيد المراجعة';
  static const promoActionEditNow = 'تمت الاستجابة للطلب — عدّل الآن';
  static const promoActionEditPending = 'تم إرسال طلب التعديل';
  static const promoActionRequestEdit = 'طلب تعديل الإعلان';
  static const promoCreateTitle = 'حملة جديدة';
  static const promoEditTitle = 'تعديل الإعلان';
  static const promoEditReviewBody =
      'التعديل بعد الموافقة يرجع الإعلان للمراجعة من جديد، وهدفنا نرد خلال 6 ساعات.';
  static const promoValidationError =
      'اختَر المكان واكتب عنوانًا واضحًا للحملة.';
  static const promoSentSuccess = 'تم إرسال الحملة للمراجعة بنجاح ✅';
  static const promoEditSentSuccess =
      'تم حفظ التعديلات وإرجاع الإعلان للمراجعة. هنراجع خلال 6 ساعات أو أقل ✅';
  static const promoFieldPlace = 'المكان';
  static const promoFieldKind = 'نوع الحملة';
  static const promoFieldTitle = 'عنوان الإعلان أو العرض';
  static const promoFieldBody = 'تفاصيل العرض';
  static const promoFieldCta = 'نص الزر (اختياري)';
  static const promoFieldDuration = 'مدة العرض';
  static const promoCtaDefault = 'اعرف العرض';
  static const promoSendCta = 'إرسال للمراجعة';
  static const promoEditSendCta = 'حفظ التعديل وإعادة الإرسال';
  static const promoEditDialogTitle = 'طلب تعديل الإعلان';
  static const promoEditDialogBody =
      'هيوصل طلبك للإدارة أولًا. بعد الموافقة هتلاقي الزر اتحول إلى "عدّل الآن"، وبعد الحفظ الإعلان هيرجع للمراجعة لمدة 6 ساعات أو أقل.';
  static const promoEditDialogConfirm = 'أكيد، ابعت الطلب';
  static const promoNoApprovedPlacesTitle = 'العروض هتظهر بعد اعتماد أول مكان';
  static const promoNoApprovedPlacesBody =
      'أول ما مكانك يتعتمد هتقدر تعمل له حملة خاصة.';
  static const promoEmptyPlaceBody =
      '%n لسه ما عليهش حملات. أول حملة هتدخل مراجعة قبل ما تظهر للناس.';
  static const promoDateNow = 'الآن';
  static const promoDateOpen = 'غير محدد';
  static const promoImageNone = 'صورة الإعلان اختيارية';
  static const promoImageExisting =
      'الصورة الحالية مرفوعة. تقدر تغيّرها لو حبيت.';
  static const promoImageSelected = 'تم اختيار صورة للإعلان';
  static const promoImagePick = 'اختَر صورة';
  static const promoImageChange = 'غيّر الصورة';

  // --- Admin overview ----------------------------------------------------------
  static const adminTitle = 'لوحة الإدارة';
  static const adminProviders = 'المزودون';
  static const adminUsers = 'المستخدمين';
  static const adminSubscriptions = 'الاشتراكات';
  static const adminAllPlans = 'كل الخطط';
  static const adminKpiTotalUsers = 'إجمالي المستخدمين';
  static const adminKpiProviders = 'مقدّمي الخدمة';
  static const adminKpiPaidSubs = 'مشتركين مدفوع';
  static const adminKpiPending = 'في انتظار اعتماد';
  static const adminKpiMrr = 'إيراد شهري متوقّع';
  static const adminSearchHint = 'ابحث بالاسم أو الإيميل…';
  static const adminRoleAdmin = 'أدمن';
  static const adminRoleProvider = 'مقدّم خدمة';
  static const adminRoleUser = 'مستخدم';
  static const adminEmptyUsers = 'مفيش مستخدمين مطابقين للبحث.';
  static const adminEmptyProviders = 'مفيش مقدّمي خدمة لسه.';
  static const adminEmptySubs = 'مفيش اشتراكات نشطة لسه.';
  static const adminBillingMonthly = 'شهري';
  static const adminBillingYearly = 'سنوي';
  static const adminSubSourceDemo = 'تجريبي';
  static const adminSubSourceManual = 'يدوي';
  static const adminSubSourcePaymob = 'Paymob';
  static const adminSubSourceStripe = 'Stripe';
  static const adminPlacesCount = 'الأماكن';
  static const adminJoinedAt = 'انضم في';
  static const adminPeriodEnd = 'ينتهي في';
  static const adminAmount = 'المبلغ';

  // --- Delete account ----------------------------------------------------------
  static const deleteAccountRow = 'حذف الحساب';
  static const deleteAccountRowValue = 'حذف نهائي للحساب وبياناتك';
  static const deleteAccountTitle = 'تأكيد حذف الحساب';
  static const deleteAccountConfirm = 'احذف حسابي';
  // Context-aware confirmation bodies (chosen at runtime by ProfilePage)
  static const deleteAccountBodyRegular =
      'هتمسح حسابك للأبد. كل تقييماتك ومفضلاتك هتروح. الإجراء ده مفيش رجوع منه.';
  static const deleteAccountBodyProviderFree =
      'حسابك ومكانك ومراجعاتك هيتمسحوا للأبد. الإجراء ده مفيش رجوع منه.';
  static const deleteAccountBodyProviderPaidPrefix = 'انت مشترك حالياً في خطة ';
  static const deleteAccountBodyProviderPaidSuffix =
      '. الاشتراك ده هيتلغى تلقائياً. حسابك ومكانك وكل بياناتك هيتمسحوا للأبد. الإجراء ده مفيش رجوع منه.';
  static const deleteAccountSuccess = 'اتمسح حسابك بنجاح.';
  static const deleteAccountError =
      'معرفناش نمسح حسابك دلوقتي، جرّب تاني بعد شوية.';
  static const deleteAccountReasonHint = 'لو حابب تقولنا السبب (اختياري)';

  // --- Change password dialog --------------------------------------------------
  static const changePwTitle = 'تغيير كلمة السر';
  static const changePwCurrent = 'كلمة السر الحالية';
  static const changePwNew = 'كلمة السر الجديدة';
  static const changePwConfirm = 'تأكيد كلمة السر الجديدة';
  static const changePwCta = 'تحديث كلمة المرور';
  static const changePwSuccess = 'اتغيّرت كلمة السر بنجاح ✅';
  static const changePwGenericFail = 'معرفناش نغيّر كلمة السر، راجع بياناتك.';
  static const changePwMissingEmail =
      'لقيناش البريد الإلكتروني، سجل دخول تاني.';

  // --- Profile support section -------------------------------------------------
  static const profileSupportSection = 'الدعم والمساعدة';
  static const profileSupportSubtitle = 'المساعدة والقوانين وطرق التواصل';
  static const profilePrivacyPolicy = 'سياسة الخصوصية';
  static const profileTerms = 'الشروط والأحكام';
  static const profileHelp = 'مركز المساعدة';
  static const profileContactUs = 'تواصل معنا';
  static const supportInfoGroup = 'معلومات';
  static const supportCallLabel = 'اتصال مباشر';
  static const supportWhatsappLabel = 'واتساب';
  static const supportEmailLabel = 'البريد الإلكتروني';
  static const supportWhatsappMessage = 'مرحباً، أحتاج مساعدة في تطبيق رفيق.';
  static const supportEmailSubject = 'طلب مساعدة — رفيق';
  static const supportEmailBody = 'مرحباً،\n\nأحتاج مساعدة في...';
  static const supportOpenError = 'معرفناش نفتح وسيلة التواصل. جرّب تاني.';
  static const supportPhone1 = '01036925982';
  static const supportPhone2 = '01050242285';
  static const supportEmail = 'ahmedessam.uiux@gmail.com';
  static const supportWhatsappHint = 'واتساب: ';

  // --- Onboarding --------------------------------------------------------------
  static const onboardingTitle1 = 'محتار؟\nهنساعدك في الاختيار';
  static const onboardingTitle2 = 'هتلاقي مجموعة\nمتنوعة من الاختيارات';
  static const onboardingBody2 =
      'أي مكان بتدوّر عليه هتلاقي اللي يناسبك\nسواء جوّة أو بره المدينة';
  static const onboardingTitle3 = 'اكتشف الأماكن اللي\nتناسب مزاجك وميزانيتك';
  static const onboardingCta = 'يلا نبدأ';
  static const onboardingNext = 'التالي';
  static const onboardingSkip = 'تخطّي';

  // --- Place appeal flow -------------------------------------------------------
  static const appealTitle = 'طعن في قرار الرفض';
  static const appealSubtitle =
      'أخبرنا بسبب اعتراضك وهنراجع الطلب في أقرب وقت.';
  static const appealNameHint = 'اسمك الكامل';
  static const appealPhoneHint = 'رقم الموبايل';
  static const appealMessageHint = 'اشرح اعتراضك هنا...';
  static const appealSend = 'إرسال الطعن';
  static const appealSentSuccess = 'وصلنا طعنك، هنتواصل معاك قريباً ✅';
  static const appealSentFail = 'معرفناش نبعت الطعن، جرّب تاني.';
  static const appealPlaceholder = 'اكتب سبب الاعتراض...';

  // --- Add Place form ----------------------------------------------------------
  static const addPlaceCoverLabel = 'الغلاف';
  static const addPlaceReviewNotice =
      'بعد ما تضيف مكانك، هيعدي على مراجعتنا خلال 24 ساعة قبل ما يظهر للناس. هنبلّغك بنتيجة المراجعة فور ما تتاح.';
  static const editPlaceReviewNotice =
      'تعديلك هيروح للإدارة ويتراجع خلال 6 ساعات أو أقل. مكانك هيفضل ظاهر ببياناته الحالية لحد ما التعديل يتقبل.';

  // --- Provider hub — delete dialog + appeal validation -----------------------
  static const hubDeletePlaceTitle = 'حذف المكان';
  static const hubDeletePlaceMessage =
      'هل تريد حذف "%s"؟ الحذف نهائي ومفيش رجوع.';
  static const hubDeletePlaceConfirm = 'حذف';
  static const hubAppealFillAllFields =
      'من فضلك اكمل جميع الحقول عشان نقدر نساعدك';
  static const hubAppealInvalidPhone = 'رقم الموبايل غير صحيح، تأكد منه';

  // --- Promotions — campaign status labels ------------------------------------
  static const promoCampaignStatusActive = 'نشطة';
  static const promoCampaignStatusPending = 'قيد المراجعة';
  static const promoCampaignStatusPaused = 'موقوفة';
  static const promoCampaignStatusRejected = 'مرفوضة';
  static const promoCampaignStatusEnded = 'انتهت';
  static const promoCampaignStatusDraft = 'مسودة';

  // --- Promotions — campaign kind labels --------------------------------------
  static const promoKindDiscount = 'خصم / عرض خاص';
  static const promoKindFeatured = 'ظهور مميز';
  static const promoKindSpotlight = 'سبوت لايت';
  static const promoKindPush = 'إشعار ترويجي';
  static const promoKindDefault = 'حملة';

  // --- Promotions — duration options ------------------------------------------
  static const promoDuration3Days = '3 أيام';
  static const promoDuration7Days = '7 أيام';
  static const promoDuration14Days = '14 يوم';
  static const promoDuration30Days = '30 يوم';

  // --- Promotions — metrics labels -------------------------------------------
  static const promoMetricImpressions = 'مشاهدات';
  static const promoMetricClicks = 'نقرات';
  static const promoReviewNotice6h =
      'الحملة هتعدي على مراجعة خلال 6 ساعات من الإرسال. هنبلّغك بالنتيجة.';
}

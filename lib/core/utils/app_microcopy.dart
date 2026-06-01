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
  static const offlineTitle = 'النت واخد بريك صغير 😅';
  static const offlineBody = 'أول ما يرجع هنكمّل علطول. جرّب تاني كمان شوية.';
  static const offlineBanner = 'مفيش نت دلوقتي — بنحاول نوصل تاني...';
  static const backOnline = 'رجع النت! 🎉';

  // --- Generic errors (friendly, no jargon) ------------------------------------
  static const errorTitle = 'حصل لخبطة بسيطة';
  static const errorBody =
      'مقدرناش نكمّل دلوقتي. جرّب تاني، ولو فضلت، استنّى شوية.';
  static const errorRetry = 'حاول تاني';
  static const errorGeneric = 'في حاجة مش ظابطة، جرّب تاني بعد شوية.';

  // --- Empty states ------------------------------------------------------------
  static const emptyResultsTitle = 'مفيش حاجة هنا لسه';
  static const emptyResultsBody = 'جرّب تغيّر اختياراتك وهنلاقيلك حاجة تعجبك.';
  static const emptySearchTitle = 'ملقيناش اللي بتدوّر عليه';
  static const emptySearchBody = 'جرّب كلمة تانية أو قلّل الفلاتر.';
  static const emptyFavoritesTitle = 'لسه مفيش مفضّلة';
  static const emptyFavoritesBody =
      'أول ما يعجبك مكان، دوس على القلب وهيتحفظ هنا.';

  // --- Loading -----------------------------------------------------------------
  static const loading = 'ثانية واحدة...';
  static const loadingSuggestions = 'بندوّرلك على أحلى أماكن...';
  static const loadingSaving = 'بنحفظ بياناتك...';

  // --- Success -----------------------------------------------------------------
  static const successGeneric = 'تمام! اتعمل بنجاح ✅';
  static const successSaved = 'اتحفظ بنجاح';
  static const welcomeBack = 'نوّرت تاني! 👋';

  // --- Form validation (soft, guiding) -----------------------------------------
  static const fieldRequired = 'الحقل ده مهم، اكتبه عشان نكمّل';
  static const emailInvalid = 'البريد شكله مش مظبوط، راجعه بسرعة';
  static const emailGmailOnly = 'لازم يكون بريد @gmail.com';
  static const passwordRequired = 'اكتب كلمة السر';
  static const passwordShort = 'كلمة السر قصيّرة شوية، خليها 6 حروف على الأقل';
  static const passwordsMismatch = 'الكلمتين مش زي بعض، راجعهم';

  // --- Actions / buttons -------------------------------------------------------
  static const retry = 'جرّب تاني';
  static const ok = 'تمام';
  static const cancel = 'إلغاء';
  static const confirm = 'أكيد';
  static const next = 'اللي بعده';
  static const done = 'خلصنا';

  // --- Suggestion / place cards ------------------------------------------------
  static const priceStartsFrom = 'تبدأ من';
  static const priceUnspecified = 'السعر مش متحدد';
  static const currencyEgp = 'جنيه مصري';
  static const ratingFallback = '(جديد)';

  // --- Home / step flow --------------------------------------------------------
  static const stepCity = 'المدينة';
  static const stepBudget = 'الميزانية';
  static const stepActivity = 'النشاط';
  static const homeIncomplete =
      'كمّل الاختيارات الأول، عشان نلاقيلك أحلى أماكن.';
  static const homeCtaFinal = 'يلا نفسح!';
  static const homeStepCounter = 'خطوة %d من %t'; // %d=current, %t=total
  static const back = 'رجوع';

  // --- Chatbot -----------------------------------------------------------------
  static const chatTitle = 'رفيق الذكي 🤖';

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
      'تم استلام المكان وهو الآن قيد المراجعة. الاعتماد عادة يتم خلال 24 ساعة.';
  static const providerResubmittedSuccess =
      'تم حفظ التعديلات وإرجاع المكان للمراجعة من جديد.';
  static const providerImagePickError =
      'حصلت مشكلة وانت بتختار الصورة، جرّب تاني.';
  static const providerSavedTitle = 'مبروك! بيانات مكانك اتسجلت';
  static const providerGalleryTitle = 'صور المكان';
  static const providerCoverHint = 'الصورة الأولى هتبقى الكوفر';
  static const providerAddImage = 'ضيف صورة';
  static const providerImagesUsed = '%u من %m صورة';
  static const providerImagesUnlimited = '%u صورة';
  static const providerRemoveImage = 'احذف الصورة';

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

  // --- Reviews / evaluations ---------------------------------------------------
  static const reviewsTitle = 'التقييمات';
  static const reviewDateUnknown = 'بدون تاريخ';
  static const reviewAuthorAnonymous = 'مستخدم مجهول';
  static const reviewInputHint = 'قول لنا رأيك في المكان...';
  static const reviewEmptyText = 'اكتب تقييمك الأول، وبعدها ابعته.';
  static const reviewThanksTitle = 'وصل رأيك! شكراً ليك';
  static const reviewThanksBody = 'تقييمك هيساعد ناس تختار صح';
  static const reviewsEmptyHeadline = 'كن أول واحد يشارك تجربته!';
  static const reviewsEmptyShare = 'شارك تجربتك مع غيرك';
  static const reviewsEmptyHelp = 'ساعد الناس تختار صح';
  static const reviewsEmptyDiscover = 'اكتشف أماكن جديدة مع الجميع';

  // --- Details page ------------------------------------------------------------
  static const detailsTitle = 'التفاصيل';
  static const detailsBeFirstReview = 'كن أول واحد يعلّق';
  static const detailsAddYourComment = 'ضيف تعليقك';
  static const detailsSimilarHeading = 'فعاليات مشابهة';
  static const detailsNoSimilar = 'مفيش أماكن مشابهة دلوقتي';

  // --- Profile page ------------------------------------------------------------
  static const profileTitle = 'الملف الشخصي';
  static const profileNameFallback = 'مستخدم رفيق';
  static const profileEmailFallback = 'لسه ما اضفتش بريد';
  static const profileNameLabel = 'الاسم';
  static const profileEmailLabel = 'البريد الإلكتروني';
  static const profilePasswordLabel = 'كلمة السر';
  static const profileChangeAvatarHint = 'دوس عشان تغيّر الصورة';
  static const profileImageSaveError = 'معرفناش نحفظ الصورة، جرّب تاني.';
  static const profileSwitchToProvider = 'حوّل لمقدم خدمة';
  static const profileSwitchToProviderValue = 'افتح خطط الاشتراك وأضف مكانك';
  static const profileSwitchToUser = 'تصفح كمستخدم عادي';
  static const profileSwitchToUserValue =
      'استكشف الأماكن كزائر (خطتك وأماكنك محفوظة بأمان)';
  static const profileSwitchConfirmTitle = 'تأكيد تغيير الدور';
  static const profileSwitchConfirmProvider =
      'هتدخل صفحة الخطط تختار اللي يناسبك (مجاني، Pro، أو Max). تقدر ترجع مستخدم عادي في أي وقت وكل حاجة هتفضل محفوظة.';
  static const profileSwitchConfirmUser =
      'هتنتقل لمسار المستخدم العادي عشان تشوف الأماكن زي أي زائر. متقلقش، اشتراكك وأماكنك محفوظة بالكامل لما تحب ترجع.';

  // --- Profile banners (context-aware CTA, personalized by name) ----------
  /// Regular user who never confirmed a provider plan — friendly invite.
  /// Title is composed at render time as "{name}، ..." so each user feels
  /// the prompt is for them, not a generic ad. The body explains the value
  /// in human terms; the CTA is short and warm ("يلا أبدأ").
  static const profileBannerInviteTitle = 'ابدأ رحلتك كمقدم خدمة';
  static const profileBannerInviteBody =
      'وسّع فرصك داخل التطبيق، واختار الخطة المناسبة لك بحرية كاملة من غير أي فرض أو استعجال.';
  static const profileBannerInviteCta = 'يلا نبدأ';

  /// Provider who switched to user mode — invite them back to their hub.
  /// Singular/plural copy auto-picked from the place count.
  static const profileBannerReturnTitleSingle = 'خدمتك مستنياك';
  static const profileBannerReturnTitleMulti = 'خدماتك مستنياك';
  static const profileBannerReturnBody =
      'ارجع لإدارة نشاطك. خطتك ومكانك واشتراكك كله محفوظ زي ما سيبته.';
  static const profileBannerReturnCtaSingle = 'ارجع تابع خدمتك';
  static const profileBannerReturnCtaMulti = 'ارجع تابع خدماتك';
  static const logoutTitle = 'هتسجل خروج؟';
  static const logoutMessage = 'متأكد إنك عايز تخرج من التطبيق؟';
  static const logoutConfirm = 'أكيد، خروج';
  static const logoutCta = 'تسجيل الخروج';
  static const logoutError = 'معرفناش نسجّل خروجك دلوقتي، جرّب تاني.';

  // --- Auth (shared) -----------------------------------------------------------
  static const authSeparatorOr = 'أو';
  static const authEmailLabel = 'البريد الإلكتروني';
  static const authEmailHint = 'example@gmail.com';
  static const authPasswordLabel = 'كلمة السر';
  static const authPasswordHint = '6 حروف على الأقل';
  static const authForgotPasswordLink = 'نسيت كلمة السر؟';

  // --- Login -------------------------------------------------------------------
  static const loginTitle = 'تسجيل الدخول';
  static const loginCta = 'دخول';
  static const loginGoogle = 'كمّل بـ Google';
  static const loginSuccess = 'دخلت بنجاح ✅';
  static const loginNoAccountPrefix = 'لسه ما عملتش حساب؟ ';
  static const loginGoToRegister = 'سجّل دلوقتي';

  // --- Register ----------------------------------------------------------------
  static const registerTitle = 'إنشاء حساب';
  static const registerCta = 'سجّل';
  static const registerGoogle = 'سجّل بـ Google';
  static const registerSuccess = 'حسابك اتعمل بنجاح ✅';
  static const registerNameLabel = 'اسمك';
  static const registerNameHint = 'مثلاً: أحمد عصام';
  static const registerHasAccountPrefix = 'عندك حساب بالفعل؟ ';
  static const registerGoToLogin = 'سجّل دخول';

  // --- Forgot password ---------------------------------------------------------
  static const forgotTitle = 'نسيت كلمة السر؟';
  static const forgotBody =
      'اكتب بريد Gmail بتاعك وهنبعتلك كود تأكيد عشان تختار كلمة سر جديدة.';
  static const forgotSendCode = 'ابعت الكود';
  static const forgotCodeSent = 'بعتنالك كود التأكيد على بريدك ✉️';
  static const forgotHint =
      'أول ما يوصلك الكود، اكتبه في الشاشة اللي بعدها واختار كلمة سر جديدة.';

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
  static const signupVerifyBody = 'بعتنالك كود على بريد جيميل بتاعك،';
  static const signupVerifyTail = 'اكتبه تحت عشان نفعّل حسابك.';
  static const signupVerifySuccessTitle = 'حسابك اتفعّل ✅';
  static const signupVerifySuccessBody = 'يلا نبدأ نلاقيلك أحلى الأماكن!';

  // --- Password reset verification --------------------------------------------
  static const resetVerifyTitle = 'تأكيد الهوية';
  static const resetVerifyBody = 'بعتنالك كود على بريدك،';
  static const resetVerifyTail = 'اكتبه عشان نأكّد إنك إنت.';

  // --- Reset password ----------------------------------------------------------
  static const resetTitle = 'كلمة سر جديدة';
  static const resetBody = 'اختار كلمة سر قوية وسهل تفتكرها.';
  static const resetCta = 'حفظ كلمة السر';
  static const resetSuccess = 'تمام! كلمة السر اتغيّرت ✅';
  static const resetSuccessBody = 'تقدر دلوقتي تسجّل دخولك بكلمة السر الجديدة.';
  static const resetConfirmHint = 'اكتبها تاني للتأكيد';
  static const resetOtpHint = '6 أرقام';

  // --- Subscription page -------------------------------------------------------
  static const subTitle = 'خطط الاشتراك';
  static const subSubtitle = 'اختار الخطة اللي تناسب نشاطك';
  static const subBillingMonthly = 'شهري';
  static const subBillingYearly = 'سنوي';
  static const subYearlyDiscount = 'وفّر %p%'; // %p replaced with discount pct
  static const subCurrent = 'خطتك الحالية';
  static const subUpgrade = 'رقّي خطتك';
  static const subManage = 'إدارة الاشتراك';
  static const subFreeForever = 'مجاني للأبد';
  static const subPerMonth = '/شهر';
  static const subPerYear = '/سنة';
  static const subRenewsOn = 'يتجدد في';
  static const subCancelsOn = 'ينتهي في';
  static const subFeatureUnlimited = 'بلا حدود';
  static const subCompareTitle = 'مقارنة الخطط';
  static const subLimitReached = 'وصلت الحد الأقصى للخطة الحالية';
  static const subUpgradeCta = 'رقّي الخطة عشان تكمّل';
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
  static const subOnboardingSubtitle =
      'كل خطة بتفتحلك مميزات أكتر لمكانك. ولا خطة هتتحدد إلا باختيارك أنت.';
  static const subReviewWindowNotice =
      'بعد اختيار الخطة وإضافة خدمتك أو مكانك، بيظهر في لوحتك بحالة مراجعة ومعاه عدّاد واضح. الاعتماد يتم عادة خلال 24 ساعة.';
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
  static const subDemoExplainer =
      'ده وضع تجريبي — مفيش دفع حقيقي حتى الربط ببوابة الدفع.';

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
  static const hubFeatBodyAnalytics =
      'شوف ناس بتزور صفحتك إزاي والوقت المفضّل ليهم.';
  static const hubFeatTitlePromotions = 'إعلانات وعروض';
  static const hubFeatBodyPromotions =
      'اعمل عروض ترويجية تظهر في الواجهة الرئيسية للزوار.';
  static const hubFeatTitlePlaces = 'أماكنك';
  static const hubFeatBodyPlaces = 'إدارة الأماكن، التعديل، وإضافة جديد.';
  static const hubFeatTitleSubscription = 'الاشتراك';
  static const hubFeatBodySubscription =
      'رقّي خطتك في أي وقت أو إلغي الاشتراك بسهولة.';
  static const hubLockedTag = 'يفتح مع برو';
  static const hubLockedMax = 'يفتح مع ماكس';

  // --- Analytics screen --------------------------------------------------------
  static const anaTitle = 'تحليلاتك';
  static const anaLast30Days = 'آخر 30 يوم';
  static const anaPlaceViews = 'مشاهدات المكان';
  static const anaInteractions = 'إجمالي التفاعلات';
  static const anaFavorites = 'إضافة للمفضلة';
  static const anaMapClicks = 'فتح الخريطة';
  static const anaLockedTitle = 'فعّل تحليلات الأداء';
  static const anaLockedBody =
      'متاحة لخطة برو أو ماكس — شوف ناس بتزور صفحتك من فين، وكام مرة بيفتحوا أماكنك.';
  static const anaUpgradeCta = 'رقّي لـ برو';

  // --- Promotions screen -------------------------------------------------------
  static const promoTitle = 'إعلاناتك';
  static const promoEmptyTitle = 'لسه ما عملتش حملة';
  static const promoEmptyBody =
      'اعمل حملة "Featured" أو عرض خصم — هتظهر في الواجهة الرئيسية وتجيب زوار جداد.';
  static const promoCreateCta = 'اعمل حملة جديدة';
  static const promoCreatePendingBody =
      'أي إعلان جديد يروح للأدمن أولًا بحالة قيد المراجعة، وهدفنا نرد خلال 6 ساعات.';
  static const promoRejectedReason = 'سبب الرفض';
  static const promoPendingReview = 'بانتظار مراجعة الأدمن';
  static const promoLockedTitle = 'الإعلانات تبدأ من خطة برو';
  static const promoLockedBody =
      'الإعلانات والعروض الترويجية ميزة بتساعدك تجيب زوار أكتر بسرعة.';

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
  static const changePwConfirm = 'تأكيد كلمة السر';
  static const changePwSuccess = 'اتغيّرت كلمة السر بنجاح ✅';
  static const changePwGenericFail = 'معرفناش نغيّر كلمة السر، راجع بياناتك.';
  static const changePwMissingEmail =
      'لقيناش البريد الإلكتروني، سجل دخول تاني.';

  // --- Profile support section -------------------------------------------------
  static const profileSupportSection = 'الدعم والمساعدة';
  static const profilePrivacyPolicy = 'سياسة الخصوصية';
  static const profileTerms = 'الشروط والأحكام';
  static const profileHelp = 'مركز المساعدة';
  static const profileContactUs = 'تواصل معنا';
  static const supportPhone1 = '01036925982';
  static const supportPhone2 = '01050242285';
  static const supportEmail = 'ahmedessam.uiux@gmail.com';
  static const supportWhatsappHint = 'واتساب: ';

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
}

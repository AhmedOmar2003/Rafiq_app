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
  static const errorBody = 'مقدرناش نكمّل دلوقتي. جرّب تاني، ولو فضلت، استنّى شوية.';
  static const errorRetry = 'حاول تاني';
  static const errorGeneric = 'في حاجة مش ظابطة، جرّب تاني بعد شوية.';

  // --- Empty states ------------------------------------------------------------
  static const emptyResultsTitle = 'مفيش حاجة هنا لسه';
  static const emptyResultsBody = 'جرّب تغيّر اختياراتك وهنلاقيلك حاجة تعجبك.';
  static const emptySearchTitle = 'ملقيناش اللي بتدوّر عليه';
  static const emptySearchBody = 'جرّب كلمة تانية أو قلّل الفلاتر.';
  static const emptyFavoritesTitle = 'لسه مفيش مفضّلة';
  static const emptyFavoritesBody = 'أول ما يعجبك مكان، دوس على القلب وهيتحفظ هنا.';

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
  static const homeIncomplete = 'كمّل الاختيارات الأول، عشان نلاقيلك أحلى أماكن.';
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

  // --- Provider / add-place flow ----------------------------------------------
  static const providerFormTitle = 'بيانات مكانك';
  static const providerSessionExpired =
      'انتهت جلسة الدخول، سجّل تاني عشان نكمّل.';
  static const providerAddedSuccess = 'اتضاف بنجاح ✅';
  static const providerImagePickError = 'حصلت مشكلة وانت بتختار الصورة، جرّب تاني.';
  static const providerSavedTitle = 'مبروك! بيانات مكانك اتسجلت';

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

  // --- Payment -----------------------------------------------------------------
  static const paymentTitle = 'الدفع';
  static const findMyPlace = 'دور على مكانك';
  static const bookNow = 'احجز دلوقتي';
  static const paymentFailed = 'الدفع ما عدّاش، جرّب تاني.';
  static const paymentError = 'في حاجة لخبطت في الدفع، جرّب تاني.';
  static const paymentSuccessTitle = 'الحجز اتأكد! 🎉';
  static const paymentSuccessBody = 'ميّرتنا الاختيار، يلا قضّي وقت لذيذ.';

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

  // --- Reset password ----------------------------------------------------------
  static const resetTitle = 'كلمة سر جديدة';
  static const resetBody = 'اختار كلمة سر قوية وسهل تفتكرها.';
  static const resetCta = 'حفظ كلمة السر';
  static const resetSuccess = 'تمام! كلمة السر اتغيّرت ✅';
  static const resetSuccessBody =
      'تقدر دلوقتي تسجّل دخولك بكلمة السر الجديدة.';
  static const resetConfirmHint = 'اكتبها تاني للتأكيد';
  static const resetOtpHint = '6 أرقام';
  static const verifyCodeWrongLength = 'الكود لازم يكون 6 أرقام';

  // --- Change password dialog --------------------------------------------------
  static const changePwTitle = 'تغيير كلمة السر';
  static const changePwCurrent = 'كلمة السر الحالية';
  static const changePwNew = 'كلمة السر الجديدة';
  static const changePwConfirm = 'تأكيد كلمة السر';
  static const changePwSuccess = 'اتغيّرت كلمة السر بنجاح ✅';
  static const changePwGenericFail = 'معرفناش نغيّر كلمة السر، راجع بياناتك.';
  static const changePwMissingEmail = 'لقيناش البريد الإلكتروني، سجل دخول تاني.';
}

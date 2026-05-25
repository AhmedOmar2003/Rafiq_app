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
}

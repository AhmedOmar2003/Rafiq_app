/// Asset path constants.
///
/// All raster images ship as **WebP** (quality 80, max 1200px on the long
/// side). The conversion saved ~4.4 MB from the bundle. WebP is supported
/// natively by Flutter via the standard `Image.asset` / `Image.network`
/// constructors — no extra package needed.
class AppImages {
  AppImages._();

  // ---- Images ----
  static const basePathImages = 'assets/images/';
  static const warning = '${basePathImages}warning.webp';
  static const logo = '${basePathImages}rafiq_logo.webp';
  static const angham = '${basePathImages}angham.webp';
  static const padel = '${basePathImages}padel.webp';
  static const bird = '${basePathImages}bird.webp';
  static const visa = '${basePathImages}visa.webp';
  static const miza = '${basePathImages}miza.webp';
  static const vodafone = '${basePathImages}vodafone.webp';
  static const orange = '${basePathImages}orange.webp';
  static const masterCard = '${basePathImages}master_card.webp';
  static const instaPay = '${basePathImages}insta_pay.webp';
  static const etisalat = '${basePathImages}etisalat.webp';
  static const onboarding1 = '${basePathImages}onboarding1.webp';
  static const onboarding2 = '${basePathImages}onboarding2.webp';
  static const onboarding3 = '${basePathImages}onboarding3.webp';
  static const success = 'assets/animations/success.json';
  static const loginSuccess = '${basePathImages}Group 34246.webp';
  static const choice = '${basePathImages}Choice.webp';

  // ---- SVG icons (vector, no conversion needed) ----
  static const basePathIcons = 'assets/icons/';
  static const format = '.svg';
  static const user = '${basePathIcons}user$format';
  static const eye = '${basePathIcons}eye-open$format';
  static const ball = '${basePathIcons}ball$format';
  static const email = '${basePathIcons}email$format';
  static const search = '${basePathIcons}search$format';
  static const money = '${basePathIcons}money$format';
  static const activitie = '${basePathIcons}activitie$format';
  static const location = '${basePathIcons}location$format';
  static const mapPin = '${basePathIcons}mapPin$format';
  static const friends = '${basePathIcons}friends$format';
  static const dollar = '${basePathIcons}dollar$format';
  static const eating = '${basePathIcons}eating$format';
  static const sports = '${basePathIcons}sports$format';
  static const surprise = '${basePathIcons}surprise$format';
  static const activities = '${basePathIcons}activities$format';
  static const entertainment = '${basePathIcons}entertainment$format';
  static const entertaiment = '${basePathIcons}entertaiment$format';
}

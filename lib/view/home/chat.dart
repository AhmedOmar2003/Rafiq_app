import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:rafiq_app/core/design/custom_app_bar.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/config/api_config.dart';

class BotScreen extends StatefulWidget {
  const BotScreen({super.key});

  @override
  State<BotScreen> createState() => _BotScreenState();
}

class _BotScreenState extends State<BotScreen> {
  final TextEditingController _userMessage = TextEditingController();
  final FlutterTts flutterTts = FlutterTts(); // ✅ إنشاء كائن TTS
  late final GenerativeModel model;
  bool _isLoading = false;

  final List<Message> _messages = [
    Message(
      isUser: false,
      message:
          "أهلاً بك في تطبيق 'رفيق'! نحن هنا لنساعدك في العثور على أفضل الأماكن السياحية، الثقافية، والتعليمية في مصر، مع التركيز على الأماكن التي تحافظ على الهوية المصرية وتشجع السياحة الداخلية. كيف يمكنني مساعدتك اليوم؟",
      date: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: ApiConfig.geminiApiKey,
    );
    _speakWelcomeMessage(); // ✅ تشغيل الصوت الترحيبي عند فتح الصفحة
  }

  @override
  void dispose() {
    _userMessage.dispose();
    flutterTts.stop();
    super.dispose();
  }

  // ✅ دالة تشغيل الصوت الترحيبي
  Future<void> _speakWelcomeMessage() async {
    try {
      await flutterTts.setLanguage("ar"); // ✅ ضبط اللغة إلى العربية
      await flutterTts.setPitch(1.0); // ✅ ضبط حدة الصوت
      await flutterTts.setSpeechRate(0.5); // ✅ ضبط سرعة القراءة
      await flutterTts.speak(
          "أهلاً بك في مساعدك الافتراضي لتطبيق رفيق! لإرشادك وتوجيهك إلى المكان المناسب لك."); // ✅ تشغيل الصوت
    } catch (e) {
      debugPrint('Error in text-to-speech: $e');
    }
  }

  Future<void> sendMessage() async {
    final message = _userMessage.text.trim();
    if (message.isEmpty) return;

    _userMessage.clear();
    setState(() {
      _isLoading = true;
      _messages.add(
        Message(
          isUser: true,
          message: message,
          date: DateTime.now(),
        ),
      );
    });

    try {
      // **تحسين المدخلات ليكون Gemini أكثر دقة في التوصيات**
      final prompt = """
        أنت مساعد افتراضي تابع لتطبيق "رفيق"، وهو تطبيق متخصص في ترشيح الأماكن السياحية، الثقافية، التعليمية، والمطاعم في مصر، مع التركيز على الأماكن الشعبية والمحلية التي تحافظ على الهوية المصرية وتشجع السياحة الداخلية. 
        مهمتك هي اقتراح أماكن تناسب تفضيلات المستخدم بأسعار معقولة، وتقديم معلومات دقيقة عنها.
        الآن، استجب للسؤال التالي:
        
        "$message"
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (!mounted) return;

      setState(() {
        _messages.add(
          Message(
            isUser: false,
            message:
                response.text ?? 'عذرًا، لم أتمكن من العثور على إجابة مناسبة.',
            date: DateTime.now(),
          ),
        );
      });

      // ✅ تشغيل الصوت لقراءة الرد الصوتي للمساعد الافتراضي
      await flutterTts.speak(response.text ?? '');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          Message(
            isUser: false,
            message: 'عذرًا، حدث خطأ في معالجة طلبك. يرجى المحاولة مرة أخرى.',
            date: DateTime.now(),
          ),
        );
      });
      debugPrint('Error in sendMessage: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        backgroundColor: AppColor.primary,
        backIconColor: AppColor.white,
        title: Align(
          alignment: AlignmentDirectional.center,
          child: Padding(
            padding: const EdgeInsets.only(left: 40.0),
            child: Text(
              "رفيق الذكي 🤖",
              style: AppText.headingSm.copyWith(color: AppColor.white),
            ),
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Messages(
                  isUser: message.isUser,
                  message: message.message,
                  date: DateFormat('HH:mm').format(message.date),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
                      strokeWidth: 2,
                    ),
                  ),
                  gapH(AppSpacing.sm),
                  Text("رفيق بيفكر...", style: AppText.bodySm),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w,
              vertical: AppSpacing.sm.h,
            ),
            decoration: BoxDecoration(
              color: AppColor.surface,
              boxShadow: AppShadows.level2,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userMessage,
                      style: AppText.bodyLg,
                      decoration: InputDecoration(
                        hintText: "اسأل رفيق عن أي مكان...",
                        hintStyle: AppText.bodyLg.copyWith(color: AppColor.textTertiary),
                        filled: true,
                        fillColor: AppColor.surfaceCard,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg.w,
                          vertical: AppSpacing.md.h,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColor.border),
                          borderRadius: AppRadii.rPill,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColor.primary, width: 1.5),
                          borderRadius: AppRadii.rPill,
                        ),
                        border: OutlineInputBorder(borderRadius: AppRadii.rPill),
                      ),
                      onSubmitted: _isLoading ? null : (_) => sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  gapH(AppSpacing.sm),
                  Material(
                    color: _isLoading
                        ? AppColor.primary.withOpacity(0.4)
                        : AppColor.primary,
                    borderRadius: AppRadii.rPill,
                    child: InkWell(
                      borderRadius: AppRadii.rPill,
                      onTap: _isLoading ? null : sendMessage,
                      child: SizedBox(
                        width: 46.w,
                        height: 46.w,
                        child: Icon(Icons.send_rounded, color: AppColor.white, size: 20.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Messages extends StatelessWidget {
  final bool isUser;
  final String message;
  final String date;

  const Messages(
      {super.key,
      required this.isUser,
      required this.message,
      required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15.h),
      margin: EdgeInsets.symmetric(vertical: 10.h).copyWith(
        left: isUser ? 80.w : 10.w,
        right: isUser ? 10.w : 80.w,
      ),
      decoration: BoxDecoration(
        color: isUser ? AppColor.primary : AppColor.neutral100,
        boxShadow: AppShadows.level1,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadii.xl.r),
          bottomLeft: isUser ? Radius.circular(AppRadii.xl.r) : Radius.zero,
          topRight: Radius.circular(AppRadii.xl.r),
          bottomRight: isUser ? Radius.zero : Radius.circular(AppRadii.xl.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppText.bodyLg.copyWith(
              color: isUser ? AppColor.white : AppColor.textPrimary,
            ),
          ),
          gapV(AppSpacing.xs),
          Text(
            date,
            style: AppText.caption.copyWith(
              color: isUser
                  ? AppColor.white.withOpacity(0.7)
                  : AppColor.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final bool isUser;
  final String message;
  final DateTime date;

  Message({
    required this.isUser,
    required this.message,
    required this.date,
  });
}

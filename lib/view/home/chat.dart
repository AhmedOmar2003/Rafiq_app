import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart'; // ✅ استيراد مكتبة تحويل النص إلى صوت
import 'package:rafiq_app/core/design/custom_app_bar.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/core/config/api_config.dart'; // Add this import

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
        backIconColor: Colors.white,
        title: Align(
          alignment: AlignmentDirectional.center,
          child: Padding(
            padding: const EdgeInsets.only(left: 40.0),
            child: CustomTextWidget(
              label: "Rafiq Chat",
              style: TextStyleTheme.textStyle20Medium.copyWith(
                color: AppColor.white,
              ),
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
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0.w, vertical: 15.h),
            child: Row(
              children: [
                Expanded(
                  flex: 15,
                  child: TextFormField(
                    controller: _userMessage,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColor.primary),
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColor.primary),
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                      label: const Text("...Ask Now"),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.all(15.h),
                  iconSize: 30,
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColor.primary),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                    shape: MaterialStateProperty.all(
                      const CircleBorder(),
                    ),
                  ),
                  onPressed: _isLoading ? null : sendMessage,
                  icon: const Icon(Icons.send, color: AppColor.ofWhite),
                ),
              ],
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
      margin: EdgeInsets.symmetric(vertical: 15.h).copyWith(
        left: isUser ? 100 : 10,
        right: isUser ? 10 : 100,
      ),
      decoration: BoxDecoration(
        color: isUser ? AppColor.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          bottomLeft: isUser ? Radius.circular(30.r) : Radius.zero,
          topRight: Radius.circular(30.r),
          bottomRight: isUser ? Radius.zero : Radius.circular(30.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: isUser ? Colors.white : Colors.black),
          ),
          Text(
            date,
            style: TextStyle(color: isUser ? Colors.white : Colors.black),
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

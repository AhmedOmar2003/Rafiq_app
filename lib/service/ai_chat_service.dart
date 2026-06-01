import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/service/api_service.dart';

class AiChatService {
  AiChatService._();

  static final AiChatService instance = AiChatService._();

  Future<String> sendMessage(String message) async {
    await ApiService.ensureSupabaseInitialized();

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('اكتب سؤالك الأول.');
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-chat',
        body: {'message': trimmed},
      );
      final data = response.data;
      if (data is Map && data['reply'] is String) {
        final reply = (data['reply'] as String).trim();
        if (reply.isNotEmpty) {
          return reply;
        }
      }
      throw Exception('الرد رجع ناقص من الخدمة.');
    } on FunctionException catch (e) {
      throw Exception(
        e.details is Map && e.details['error'] is String
            ? e.details['error'] as String
            : 'المساعد الذكي غير متاح حاليًا. جرّب مرة أخرى بعد قليل.',
      );
    } catch (_) {
      throw Exception('المساعد الذكي غير متاح حاليًا. جرّب مرة أخرى بعد قليل.');
    }
  }
}

import 'package:openai_dart/openai_dart.dart';

/// Lightweight LLM caller for agent classes.
/// Each agent gets its own system prompt and sends one request.
class AgentLlm {
  AgentLlm._();

  static const _baseUrl = 'https://api.featherless.ai/v1';
  static const _model = 'Qwen/Qwen2.5-72B-Instruct';
  static const _apiKey = String.fromEnvironment('FEATHERLESS_API_KEY');

  static final _client = OpenAIClient.withApiKey(
    _apiKey,
    baseUrl: _baseUrl,
  );

  /// Send a single prompt to the LLM with a system prompt and return
  /// the complete response as a string.
  static Future<String> call({
    required String systemPrompt,
    required String userMessage,
  }) async {
    final response = await _client.chat.completions.create(
      ChatCompletionCreateRequest(
        model: _model,
        messages: [
          ChatMessage.system(systemPrompt),
          ChatMessage.user(userMessage),
        ],
      ),
    );
    return response.choices.firstOrNull?.message.content ?? '';
  }
}

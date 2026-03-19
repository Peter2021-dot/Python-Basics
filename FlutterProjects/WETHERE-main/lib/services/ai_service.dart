import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // Replace with your API Key or load from environment/config
  static const String _apiKey = 'AIzaSyBFrdqUy90DhV9NAwS9UTfjw_oJX9kSYPU';
  
  late final GenerativeModel _model;
  ChatSession? _chat;

  AIService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.system('''
You are the WeThere Support Assistant. 
WeThere is a platform where people find companions for activities (shopping, gym, events) to combat loneliness.

Your goals:
1. Help users understand how the app works.
2. Assist with journey creation or application questions.
3. Provide safety tips (meet in public, check ratings).
4. Be friendly, empathetic, and professional.

If you don't know the answer, suggest they contact support@wethere.app or use the "Emergency" option in the help menu if it's urgent.
'''),
    );
    _chat = _model.startChat();
  }

  Future<String> sendMessage(String message) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return 'Please set up your Gemini API Key in lib/services/ai_service.dart to start chatting!';
    }

    try {
      final response = await _chat!.sendMessage(Content.text(message));
      return response.text ?? 'I am sorry, I could not generate a response.';
    } catch (e) {
      return 'Error: Could not connect to Gemini. Please check your API key and connection.';
    }
  }

  void resetChat() {
    _chat = _model.startChat();
  }
}

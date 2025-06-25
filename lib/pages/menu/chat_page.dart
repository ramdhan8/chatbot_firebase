import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/chat_bubble.dart';

class AIModel {
  final String name;
  final String apiKey;
  final String modelName;

  AIModel({required this.name, required this.apiKey, required this.modelName});
}

class Chat {
  final String id;
  final String otherUser;
  final DateTime createdAt;

  Chat({
    required this.id,
    required this.otherUser,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'otherUser': otherUser,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
        id: json['id'],
        otherUser: json['otherUser'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class ChatPage extends StatefulWidget {
  final String? chatId;
  const ChatPage({super.key, this.chatId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<AIModel> aiModels = [
  AIModel(
    name: 'Gemini',
    apiKey: dotenv.env['GOOGLE_API_KEY']!,
    modelName: 'gemini-1.5-flash-latest',
  ),
  AIModel(
    name: 'Grok',
    apiKey: dotenv.env['GROQ_API_KEY']!,
    modelName: 'llama3-70b-8192',
  ),
  AIModel(
    name: 'DeepSeek',
    apiKey: dotenv.env['OPENROUTER_API_KEY']!,
    modelName: 'deepseek/deepseek-r1-0528:free',
  ),
  AIModel(
    name: 'MistralAI',
    apiKey: dotenv.env['OPENROUTER_API_KEY']!,
    modelName: 'mistralai/mistral-small-3.2-24b-instruct:free',
  ),
  AIModel(
    name: 'MoonshotAI',
    apiKey: dotenv.env['OPENROUTER_API_KEY']!,
    modelName: 'moonshotai/kimi-dev-72b:free',
  ),
  AIModel(
    name: 'OpenvLab',
    apiKey: dotenv.env['OPENROUTER_API_KEY']!,
    modelName: 'opengvlab/internvl3-14b:free',
  ),
  AIModel(
    name: 'Llama-3.1',
    apiKey: dotenv.env['OPENROUTER_API_KEY']!,
    modelName: 'nvidia/llama-3.1-nemotron-ultra-253b-v1:free',
  ),
  AIModel(
    name: 'Gemma-3',
    apiKey: dotenv.env['OPENROUTER_API_KEY']!,
    modelName: 'google/gemma-3-27b-it:free',
  ),
];

  AIModel? selectedModel;
  TextEditingController messageController = TextEditingController();
  List<Map<String, dynamic>> chatHistory = [];
  List<ChatBubble> chatBubbles = [];
  bool isLoading = false;
  late String currentChatId;
  DateTime? chatStartTime;

  @override
  void initState() {
    super.initState();
    currentChatId = widget.chatId ?? DateTime.now().millisecondsSinceEpoch.toString();
    chatStartTime = widget.chatId != null ? null : DateTime.now();
    selectedModel = aiModels.first;
    _loadChatHistory();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatData = prefs.getString('chat_history_$currentChatId');
    if (chatData != null) {
      final List<dynamic> decoded = jsonDecode(chatData);
      setState(() {
        chatBubbles = decoded.map((item) {
          return ChatBubble(
            direction: item['direction'] == 'left' ? Direction.left : Direction.right,
            message: item['message'],
            photoUrl: item['photoUrl'] ?? 'images/bot.png',
            type: BubbleType.alone,
          );
        }).toList();
        chatHistory = decoded
            .where((item) => item['message'] != 'Typing...' && item['message'] != 'Listening...')
            .map((item) => ({
                  'role': item['direction'] == 'right' ? 'user' : 'assistant',
                  'content': item['message'],
                }))
            .toList();
      });
    } else {
      setState(() {
        chatBubbles = selectedModel!.name == 'DeepSeek'
            ? []
            : [
                const ChatBubble(
                  direction: Direction.left,
                  message: 'Halo, Ada yang bisa saya bantu?',
                  photoUrl: 'images/bot.png',
                  type: BubbleType.alone,
                ),
              ];
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> chatData = chatBubbles.map((bubble) {
      return {
        'direction': bubble.direction == Direction.left ? 'left' : 'right',
        'message': bubble.message,
        'photoUrl': bubble.photoUrl,
      };
    }).toList();
    await prefs.setString('chat_history_$currentChatId', jsonEncode(chatData));
    await _ensureChatInHistory();
  }

  Future<void> _clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history_$currentChatId');
    await _removeChatFromHistory();
  }

  Future<void> _ensureChatInHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatsString = prefs.getString('chats');
    List<Chat> chats = [];

    if (chatsString != null) {
      final List<dynamic> chatJson = jsonDecode(chatsString);
      chats = chatJson.map((json) => Chat.fromJson(json)).toList();
    }

    final existingChat = Chat(
      id: currentChatId,
      otherUser: 'AI',
      createdAt: chatStartTime ?? DateTime.now(),
    );

    if (!chats.any((chat) => chat.id == currentChatId)) {
      chats.add(existingChat);
      await prefs.setString('chats', jsonEncode(chats.map((c) => c.toJson()).toList()));
    }
  }

  Future<void> _removeChatFromHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatsString = prefs.getString('chats');
    if (chatsString == null) return;

    final List<dynamic> chatJson = jsonDecode(chatsString);
    List<Chat> chats = chatJson.map((json) => Chat.fromJson(json)).toList();

    chats.removeWhere((chat) => chat.id == currentChatId);
    await prefs.setString('chats', jsonEncode(chats.map((c) => c.toJson()).toList()));
  }

  Future<void> _createNewChat() async {
    if (chatBubbles.length > 1) {
      await _saveChatHistory();
    }

    final newChatId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      currentChatId = newChatId;
      chatStartTime = DateTime.now();
      chatBubbles = selectedModel!.name == 'DeepSeek'
          ? []
          : [
              const ChatBubble(
                direction: Direction.left,
                message: 'Halo, Ada yang bisa saya bantu?',
                photoUrl: 'images/bot.png',
                type: BubbleType.alone,
              ),
            ];
      chatHistory = [];
      messageController.clear();
    });
  }

  void changeModel(AIModel newModel) {
    setState(() {
      selectedModel = newModel;
      chatHistory.clear();
      chatBubbles = selectedModel!.name == 'DeepSeek'
          ? []
          : [
              ChatBubble(
                direction: Direction.left,
                message: 'Model diubah ke ${newModel.name}. Ada yang bisa saya bantu?',
                photoUrl: 'images/bot.png',
                type: BubbleType.alone,
              ),
            ];
    });
  }

  Future<String?> _generateResponse(String message) async {
    if (selectedModel!.name == 'Gemini') {
      try {
        final model = GenerativeModel(
          model: selectedModel!.modelName,
          apiKey: selectedModel!.apiKey,
        );
        final content = chatHistory.map((msg) => Content.text(msg['content'])).toList();
        content.add(Content.text(message));
        final response = await model.generateContent(content);
        return response.text;
      } catch (e) {
        return 'Error: Failed to communicate with Gemini API. $e';
      }
    } else if (selectedModel!.name == 'Grok') {
      try {
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${selectedModel!.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': selectedModel!.modelName,
            'messages': [
              ...chatHistory,
              {'role': 'user', 'content': message},
            ],
            'temperature': 0.7,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'];
        } else {
          return 'Error: Failed to communicate with Groq API. Status: ${response.statusCode}, Body: ${response.body}';
        }
      } catch (e) {
        return 'Error: $e';
      }
    } else {
      // Handle all OpenRouter models (DeepSeek, MistralAI, MoonshotAI, OpenvLab, Llama-3.1, Gemma-3)
      try {
        // Filter out initial assistant messages for OpenRouter models
        final filteredHistory = chatHistory
            .asMap()
            .entries
            .where((entry) => entry.key > 0 || entry.value['role'] == 'user')
            .map((entry) => entry.value)
            .toList();
        final requestBody = {
          'model': selectedModel!.modelName,
          'messages': [
            ...filteredHistory,
            {'role': 'user', 'content': message},
          ],
        };
        print('OpenRouter Request Headers: Authorization: Bearer ${selectedModel!.apiKey}');
        print('OpenRouter Request Body: ${jsonEncode(requestBody)}');
        for (int attempt = 0; attempt < 3; attempt++) {
          final response = await http.post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${selectedModel!.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          );
          print('OpenRouter Response [${selectedModel!.name}]: Status ${response.statusCode}, Body: ${response.body}');
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return data['choices'][0]['message']['content'];
          } else if (response.statusCode == 429 || response.statusCode == 503) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
          return 'Error: Failed to communicate with ${selectedModel!.name} API. Status: ${response.statusCode}, Body: ${response.body}';
        }
        return 'Error: Max retries exceeded for ${selectedModel!.name}';
      } catch (e) {
        return 'Error: $e';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (chatBubbles.length > 1) {
          await _saveChatHistory();
        }
        return true;
      },
      child: Scaffold(
        appBar: null,
        body: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                reverse: true,
                padding: const EdgeInsets.all(10),
                children: chatBubbles.reversed.toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(color: Colors.black),
                      cursorColor: Colors.blue,
                      decoration: const InputDecoration(
                        hintText: 'Tanya apa saja',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      onChanged: (text) {
                        setState(() {});
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Row(
                        children: [
                          Container(
                            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0.2,
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.attach_file, color: Colors.black),
                              iconSize: 15,
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0.2,
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.format_shapes, color: Colors.black),
                              iconSize: 15,
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0.2,
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.lightbulb_outline, color: Colors.black),
                              iconSize: 15,
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0.2,
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.black),
                              iconSize: 15,
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0.2,
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            child: PopupMenuButton<AIModel>(
                              icon: const Icon(Icons.smart_toy, color: Colors.black, size: 15),
                              offset: const Offset(0, 40),
                              onSelected: (AIModel newModel) {
                                changeModel(newModel);
                              },
                              itemBuilder: (BuildContext context) => aiModels.map((AIModel model) {
                                return PopupMenuItem<AIModel>(
                                  value: model,
                                  child: Text(
                                    model.name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              tooltip: 'Pilih Model AI',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0.2,
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.black),
                              iconSize: 20,
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await _createNewChat();
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0.2,
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: messageController.text.isNotEmpty
                                  ? const Icon(Icons.arrow_upward, color: Colors.black)
                                  : const Icon(Icons.mic, color: Colors.black),
                              iconSize: 20,
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                if (messageController.text.isNotEmpty) {
                                  String messageText = messageController.text;

                                  setState(() {
                                    messageController.clear();
                                    isLoading = true;
                                    chatBubbles = [
                                      ...chatBubbles,
                                      ChatBubble(
                                        direction: Direction.right,
                                        message: messageText,
                                        photoUrl: null,
                                        type: BubbleType.alone,
                                      ),
                                      const ChatBubble(
                                        direction: Direction.left,
                                        message: 'Typing...',
                                        photoUrl: 'images/bot.png',
                                        type: BubbleType.alone,
                                      ),
                                    ];
                                  });

                                  chatHistory.add({'role': 'user', 'content': messageText});

                                  final responseText = await _generateResponse(messageText);

                                  setState(() {
                                    chatBubbles.removeLast();
                                    chatBubbles = [
                                      ...chatBubbles,
                                      ChatBubble(
                                        direction: Direction.left,
                                        message: responseText ?? 'Maaf, saya tidak mengerti',
                                        photoUrl: 'images/bot.png',
                                        type: BubbleType.alone,
                                      ),
                                    ];
                                    if (responseText != null) {
                                      chatHistory.add({'role': 'assistant', 'content': responseText});
                                    }
                                    isLoading = false;
                                  });
                                } else {
                                  setState(() {
                                    isLoading = true;
                                    chatBubbles = [
                                      ...chatBubbles,
                                      const ChatBubble(
                                        direction: Direction.left,
                                        message: 'Listening...',
                                        photoUrl: 'images/bot.png',
                                        type: BubbleType.alone,
                                      ),
                                    ];
                                  });
                                  await Future.delayed(const Duration(seconds: 2));
                                  setState(() {
                                    chatBubbles.removeLast();
                                    isLoading = false;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
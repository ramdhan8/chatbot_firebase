import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'chat_page.dart';

// Simple Chat model class
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

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Chat> chats = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchChats();
  }

  Future<void> fetchChats() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? chatsString = prefs.getString('chats');
      
      if (chatsString != null) {
        final List<dynamic> chatJson = jsonDecode(chatsString);
        chats = chatJson.map((json) => Chat.fromJson(json)).toList();
      } else {
        chats = [];
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load chats: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> addChat(Chat chat) async {
    chats.add(chat);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chats', jsonEncode(chats.map((c) => c.toJson()).toList()));
    setState(() {});
  }

  Future<void> deleteChat(String chatId) async {
    setState(() {
      chats.removeWhere((chat) => chat.id == chatId);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chats', jsonEncode(chats.map((c) => c.toJson()).toList()));
    await prefs.remove('chat_history_$chatId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchChats,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : chats.isEmpty
                  ? const Center(child: Text('No chats yet'))
                  : ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return ListTile(
                          title: Text(chat.otherUser == 'AI' ? 'Chat with AI' : chat.otherUser),
                          subtitle: Text(chat.createdAt.toString()),
                          onTap: () {
                            try {
                              print('Navigating to ChatPage with chatId: ${chat.id}');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(chatId: chat.id),
                                ),
                              );
                            } catch (e) {
                              print('Navigation error: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to open chat: $e')),
                              );
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await deleteChat(chat.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Chat deleted')),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
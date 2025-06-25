import 'package:chatbot_firebase/pages/menu/chat_page.dart';
import 'package:chatbot_firebase/pages/menu/chatpdf_page.dart';
import 'package:chatbot_firebase/pages/menu/history_page.dart';
import 'package:chatbot_firebase/pages/drawer/my_drawer_header.dart';
import 'package:flutter/material.dart';
import 'package:chatbot_firebase/pages/auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var currentPage = DrawerSections.chatPage;
  Widget? container;

  Future<void> _logout() async {
    try {
      // Clear all chat histories from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('chat_history_'));
      for (var key in keys) {
        await prefs.remove(key);
      }

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Navigate to LoginPage and clear navigation stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal logout: $e')),
      );
      // Still navigate to LoginPage even if there's an error
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Assign container based on currentPage
    switch (currentPage) {
      case DrawerSections.chatPage:
        container = const ChatPage();
        break;
      case DrawerSections.historyPage:
        container = const HistoryPage();
        break;
      case DrawerSections.chatpdfPage:
        container =  ChatpdfPage();
        break;
      default:
        container = const ChatPage(); // Default to ChatPage for other cases
    }

    return WillPopScope(
      onWillPop: () async {
        // Handle back button press
        if (currentPage != DrawerSections.chatPage) {
          setState(() {
            currentPage = DrawerSections.chatPage;
            container = const ChatPage();
          });
          return false; // Prevent back button from exiting
        }
        return false; // Prevent exiting the app
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                backgroundImage: const AssetImage('images/bot.png'),
                radius: 20,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Text(
                        'ChatBot',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        '👋',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  Text(
                    'Know Everything',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: container,
        drawer: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Drawer(
            child: SingleChildScrollView(
              child: Column(
                children: [
                   MyHeaderDrawer(),
                  MyDrawerList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget MyDrawerList() {
    return Container(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        children: [
          menuItem(1, "ChatPage", Icons.chat_outlined, currentPage == DrawerSections.chatPage),
          menuItem(2, "History", Icons.history_outlined, currentPage == DrawerSections.historyPage),
          menuItem(3, "ChatPdf", Icons.picture_as_pdf_outlined, currentPage == DrawerSections.chatpdfPage),
          menuItem(4, "Logout", Icons.logout, currentPage == DrawerSections.logout),
        ],
      ),
    );
  }

  Widget menuItem(int id, String title, IconData icon, bool selected) {
    return Material(
      color: selected ? Colors.grey[300] : Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          setState(() {
            if (id == 1) {
              currentPage = DrawerSections.chatPage;
              container = const ChatPage();
            } else if (id == 2) {
              currentPage = DrawerSections.historyPage;
              container = const HistoryPage();
            } else if (id == 3) {
              currentPage = DrawerSections.chatpdfPage;
              container =  ChatpdfPage();
            } else if (id == 4) {
              _logout(); // Only call logout, don't set container
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            children: [
              Expanded(
                child: Icon(
                  icon,
                  size: 20,
                  color: Colors.black,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum DrawerSections {
  chatPage,
  historyPage,
  menulisPage,
  menerjemahPage,
  ocrPage,
  tataPage,
  bertanyaPage,
  cariPage,
  lukisPage,
  chatpdfPage,
  wisebasePage,
  opsiPage,
  alatPage,
  logout,
}
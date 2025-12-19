import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edge_panel.dart';
import 'proj_chat.dart';
import 'test_screen.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController controller;
  String currentUrl = "https://www.google.com";

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => currentUrl = url),
        ),
      )
      ..loadRequest(Uri.parse(currentUrl));
  }

  Future<String> getPageText() async {
    final js = "window.document.body.innerText";
    final text = await controller.runJavaScriptReturningResult(js);
    return text.toString();
  }

  String truncateText(String text, {int maxBytes = 30000}) {
    final bytes = utf8.encode(text);
    if (bytes.length <= maxBytes) return text;
    return utf8.decode(bytes.sublist(0, maxBytes), allowMalformed: true);
  }

  Future<List<double>> getEmbedding(String text) async {
    final apiKey = dotenv.env['geminiapikey'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Missing GEMINI API Key in .env file");
    }

    final safeText = truncateText(text);
    final url =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: jsonEncode({
        "model": "models/gemini-embedding-001",
        "content": {"parts": [{"text": safeText}]},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to generate embedding: ${response.body}");
    }

    final data = jsonDecode(response.body);
    final embeddingList = data['embedding']?['values'] ?? data['embedding'];
    if (embeddingList == null || embeddingList.isEmpty) {
      throw Exception("No embedding returned from Gemini API");
    }

    return List<double>.from(embeddingList);
  }

  Future<void> sendPage() async {
    final text = await getPageText();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "No text found on page");
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final List<dynamic> projects = await supabase.from('projects').select();
      if (projects.isEmpty) {
        Fluttertoast.showToast(msg: "No projects found. Create one first.");
        return;
      }

      final selectedProjectId = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Select Project"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ListTile(
                    title: Text(project['title'] ?? 'Untitled Project'),
                    onTap: () => Navigator.pop(context, project['id'].toString()),
                  );
                },
              ),
            ),
          );
        },
      );

      if (selectedProjectId == null) return;

      final embedding = await getEmbedding(text);
      if (embedding.isEmpty) {
        Fluttertoast.showToast(msg: "Embedding is empty, cannot save page");
        return;
      }

      await supabase.from('project_pages').insert([
        {
          'project_id': selectedProjectId,
          'user_id': FirebaseAuth.instance.currentUser!.uid,
          'url': currentUrl,
          'text': text,
          'embedding': embedding,
          'created_at': DateTime.now().toIso8601String(),
        }
      ]);

      Fluttertoast.showToast(msg: "Page saved successfully!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error saving page: $e");
      print(e);
    }
  }

  Future<void> handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Logout failed: $e");
    }
  }

  void openBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: EdgePanelPage(currentUrl: currentUrl),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchProjects() async {
    final supabase = Supabase.instance.client;
    final data =
        await supabase.from('projects').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await controller.canGoBack()) {
          controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.deepPurpleAccent,
          titleSpacing: 0,
          leading: null,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  if (await controller.canGoBack()) controller.goBack();
                  else Fluttertoast.showToast(msg: "No previous page");
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                onPressed: () async {
                  if (await controller.canGoForward()) controller.goForward();
                  else Fluttertoast.showToast(msg: "No next page");
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Kioku Browser",
                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'save':
                    sendPage();
                    break;
                  case 'reload':
                    controller.reload();
                    break;
                  case 'logout':
                    handleLogout();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.send, color: Colors.deepPurple),
                      SizedBox(width: 10),
                      Text("Save Page"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reload',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.blue),
                      SizedBox(width: 10),
                      Text("Reload Page"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text("Logout"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: WebViewWidget(controller: controller),

        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: "panelBtn",
                tooltip: "Open AI Panel",
                onPressed: openBottomSheet,
                backgroundColor: Colors.deepPurpleAccent,
                child: const Icon(Icons.menu_open),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

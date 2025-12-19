import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // <-- new

class ProjectChatScreen extends StatefulWidget {
  final String projectId;
  const ProjectChatScreen({super.key, required this.projectId});

  @override
  State<ProjectChatScreen> createState() => _ProjectChatScreenState();
}

class _ProjectChatScreenState extends State<ProjectChatScreen> {
  final Color accent = const Color(0xFF7C4DFF);
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool isLoading = false;
  String projectTitle = "Project"; // default title until fetched

  @override
  void initState() {
    super.initState();
    fetchProjectTitle();
  }

  Future<void> fetchProjectTitle() async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('projects')
          .select('title')
          .eq('id', widget.projectId)
          .single();

      if (res != null && res['title'] != null) {
        setState(() {
          projectTitle = res['title'];
        });
      }
    } catch (e) {
      print("❌ Error fetching project title: $e");
    }
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  void sendMessage() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': query});
      isLoading = true;
    });
    _controller.clear();

    final response = await fetchProjectLLM(query);

    setState(() {
      messages.add({'role': 'ai', 'content': response});
      isLoading = false;
    });
  }

  Future<String> fetchProjectLLM(String userInput) async {
    final supabase = Supabase.instance.client;

    try {
      final allPages = await supabase
          .from('project_pages')
          .select('text, embedding_vector')
          .eq('project_id', widget.projectId);

      if (allPages == null || allPages.isEmpty) {
        return "No pages found for this project.";
      }

      final pages = (allPages as List).map((page) {
        List<double> emb;
        try {
          emb = List<double>.from(jsonDecode(page['embedding_vector']));
        } catch (_) {
          emb = [];
        }
        return {...page, 'embedding': emb};
      }).toList();

      final topPages = pages
          .where((p) => (p['embedding'] as List<double>).isNotEmpty)
          .take(5)
          .toList();

      final context = topPages.map((p) => p['text']).join("\n---\n");

      final prompt = """
You are an AI assistant. Answer the user's question using the following project content context:

$context

User question:
$userInput
""";

      final apiKey = dotenv.env['geminiapikey']!;
      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: jsonEncode({
          "contents": [
            {"parts": [{"text": prompt}]}
          ]
        }),
      );

      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          "No response";
    } catch (e) {
      print("❌ Error in fetchProjectLLM: $e");
      return "Error: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            title: Text(projectTitle,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  final msg = messages[index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUser ? accent.withOpacity(0.7) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isUser
                          ? Text(msg['content'] ?? '',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white))
                          : MarkdownBody(
                              data: msg['content'] ?? '',
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    fontSize: 16, color: Colors.black87),
                                code: const TextStyle(
                                    backgroundColor: Color(0xFFF0F0F0),
                                    fontFamily: 'monospace'),
                                strong: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 50,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Ask something about project",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: sendMessage,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

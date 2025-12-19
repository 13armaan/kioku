import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'proj_chat.dart';
import 'test_screen.dart';

class EdgePanelPage extends StatefulWidget {
  final String currentUrl;
  const EdgePanelPage({super.key, required this.currentUrl});

  @override
  State<EdgePanelPage> createState() => _EdgePanelPageState();
}

class _EdgePanelPageState extends State<EdgePanelPage> {
  String aiResponse = "Loading insights...";
  bool isLoading = false;
  List<Map<String, dynamic>> projects = [];

  final Color accent = const Color(0xFF7C4DFF);

  double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => fetchPageLLM());
    fetchProjects();
  }

  Future<void> fetchPageLLM() async {
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final currentPage = await supabase
          .from('project_pages')
          .select()
          .eq('url', widget.currentUrl)
          .maybeSingle();

      if (currentPage == null) {
        setState(() {
          aiResponse = "No data found for this page!";
          isLoading = false;
        });
        return;
      }

      final currentEmbedding = List<double>.from(currentPage['embedding']);
      final currentText = currentPage['text'];

      final allPages = await supabase.from('project_pages').select();
      final scored = (allPages as List).map((page) {
        final emb = List<double>.from(page['embedding']);
        final score = cosineSimilarity(currentEmbedding, emb);
        return {...page, 'score': score};
      }).toList();

      scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      final topPages = scored.take(5).toList();

      String context = "";
      for (int i = 0; i < topPages.length; i++) {
        final page = topPages[i];
        context += "### Page ${i + 1}\n[Link](${page['url']})\n${page['text']}\n---\n";
      }

      final prompt = """
You are an AI assistant. Summarize the content of this page briefly, highlighting key points and insights. Also, describe how the topics or concepts on this page relate to content on other pages, focusing on connections and relevance, without mentioning any page numbers or names explicitly.
$context

User is viewing page: $currentText
""";

      final apiKey = dotenv.env['geminiapikey']!;
      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

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
      String llmText = data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ??
          "No response from LLM.";

      setState(() {
        aiResponse = llmText;
      });
    } catch (e) {
      setState(() => aiResponse = "Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void fetchProjects() async {
    final supabase = Supabase.instance.client;
    final data =
        await supabase.from('projects').select().order('created_at', ascending: false);
    projects = List<Map<String, dynamic>>.from(data);
    setState(() {});
  }

  Future<void> onTapLink(String text, String? href, String title) async {
    if (href != null && await canLaunchUrl(Uri.parse(href))) {
      await launchUrl(Uri.parse(href));
    }
  }

  Future<void> createProjectDialog() async {
    String? projectName = await showDialog(
      context: context,
      builder: (context) {
        String input = "";
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("New Project"),
          content: TextField(
            onChanged: (val) => input = val,
            decoration: const InputDecoration(
              hintText: "Enter project name",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, input),
              child: const Text("Create"),
            ),
          ],
        );
      },
    );

    if (projectName == null || projectName.trim().isEmpty) return;

    try {
      final supabase = Supabase.instance.client;

      final projectResponse = await supabase
          .from('projects')
          .insert([
            {
              'title': projectName.trim(),
              'created_at': DateTime.now().toIso8601String(),
            }
          ])
          .select()
          .maybeSingle();

      final projectId = projectResponse?['id'];
      if (projectId == null) throw "Failed to create project";

      await supabase.from('project_pages').insert([
        {
          'project_id': projectId,
          'url': widget.currentUrl,
          'created_at': DateTime.now().toIso8601String(),
        }
      ]);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Project created successfully!")),
      );
      fetchProjects();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating project: $e")),
      );
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
            title: const Text("Kioku Edge",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                tooltip: "Create Project",
                onPressed: createProjectDialog,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.chat, color: Colors.white),
                tooltip: "Select Project (Chat)",
                itemBuilder: (context) => projects.map((project) {
                  return PopupMenuItem<String>(
                    value: project['id'].toString(),
                    child: Text(project['title'] ?? 'Untitled Project'),
                  );
                }).toList(),
                onSelected: (projectId) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectChatScreen(projectId: projectId),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.school, color: Colors.white),
                tooltip: "Make Test",
                itemBuilder: (context) => projects.map((project) {
                  return PopupMenuItem<String>(
                    value: project['id'].toString(),
                    child: Text(project['title'] ?? 'Untitled Project'),
                  );
                }).toList(),
                onSelected: (projectId) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MCQTestScreen(projectId: projectId),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
            : SingleChildScrollView( // ✅ fixes bottom overflow
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: aiResponse,
                    onTapLink: onTapLink,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 16, height: 1.5),
                      h3: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

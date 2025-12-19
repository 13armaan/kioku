import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MCQTestScreen extends StatefulWidget {
  final String projectId;
  const MCQTestScreen({super.key, required this.projectId});

  @override
  State<MCQTestScreen> createState() => _MCQTestScreenState();
}

class _MCQTestScreenState extends State<MCQTestScreen> {
  final Color accent = const Color(0xFF7C4DFF);
  bool isLoading = true;
  List<Map<String, dynamic>> questions = [];
  Map<int, int> selectedAnswers = {}; // questionIndex -> chosenOptionIndex
  bool showResults = false;

  @override
  void initState() {
    super.initState();
    fetchQuestionsFromLLM();
  }

  String cleanJsonString(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith("```json")) cleaned = cleaned.replaceFirst("```json", "");
    if (cleaned.startsWith("```")) cleaned = cleaned.replaceFirst("```", "");
    if (cleaned.endsWith("```")) cleaned = cleaned.substring(0, cleaned.length - 3);
    return cleaned.trim();
  }

  double cosineSimilarity(List<dynamic> a, List<dynamic> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  Future<void> fetchQuestionsFromLLM() async {
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Fetch all pages for this project
      final pagesData = await supabase
          .from('project_pages')
          .select()
          .eq('project_id', widget.projectId);

      if (pagesData.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      // Optional: Pick top pages by cosine similarity (here we just pick first 5 for simplicity)
      final topPages = (pagesData as List).take(5).toList();
      final context = topPages.map((p) => p['text']).join("\n---\n");

      // Call LLM (Gemini)
      final apiKey = dotenv.env['geminiapikey'];
      if (apiKey == null || apiKey.isEmpty) throw Exception("Missing GEMINI API Key");

      final prompt = """
Generate 3-5 multiple choice questions with 4 options each based on the following text. Include the correct answer for each question:
$context
Return as JSON array like:
[{"question":"...","options":["..","..","..",".."],"correctOption":0}, ...]
""";

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
      final text = data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];
      if (text == null) throw "No response from AI";

      final cleaned = cleanJsonString(text);
      final decoded = jsonDecode(cleaned);
      questions = List<Map<String, dynamic>>.from(decoded);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error fetching questions: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void onSelectOption(int questionIndex, int optionIndex) {
    setState(() {
      selectedAnswers[questionIndex] = optionIndex;
    });
  }

  void checkAnswers() {
    setState(() {
      showResults = true;
    });
  }

  Color getOptionColor(int questionIndex, int optionIndex, int correctIndex) {
    // Highlight the selected option immediately
    if (selectedAnswers[questionIndex] == optionIndex) {
      if (showResults) {
        // show correct/incorrect colors after submission
        if (optionIndex == correctIndex) return Colors.green[300]!;
        return Colors.red[300]!;
      } else {
        // highlight edge for selected option before submission
        return accent.withOpacity(0.2);
      }
    }

    // neutral for unselected options
    if (showResults && optionIndex == correctIndex) return Colors.green[300]!;

    return Colors.grey[200]!;
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
            title: const Text("MCQ Test",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ...List.generate(questions.length, (qIndex) {
                      final q = questions[qIndex];
                      final options = List<String>.from(q['options']);
                      final correctIndex = q['correctOption'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${qIndex + 1}. ${q['question']}",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(options.length, (oIndex) {
                              return GestureDetector(
                                onTap: () => onSelectOption(qIndex, oIndex),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: getOptionColor(qIndex, oIndex, correctIndex),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    options[oIndex],
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: checkAnswers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "Submit",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

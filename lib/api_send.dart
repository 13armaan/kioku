import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiSend extends StatefulWidget {
  final String projectId;
  const ApiSend({super.key,required this.projectId});

  @override
  State<ApiSend> createState() => _ApiSendState();
}

class _ApiSendState extends State<ApiSend> {
  bool isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final url = args['url'] as String?;
    final text = args['text'] as String?;

    if (url != null && text != null) {
      savePage(text, url);
    } else {
      Fluttertoast.showToast(msg: "No page data received");
      Navigator.pop(context);
    }
  }

  Future<List<double>> getEmbedding(String text) async {
    
    final apiKey = dotenv.env['geminiapikey'];
     

      if (apiKey == null || apiKey.isEmpty) {
    throw Exception("Missing OPENAI_API_KEY in .env file");
  }
    final url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent";
    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key":apiKey,
      },
      body: jsonEncode({
        "model": "models/gemini-embedding-001",
     "content": {
     "parts":[{
     "text": text
     }]}
    }),
    );
    if (response.statusCode != 200) {
      print(response.body);
    throw Exception("Failed to generate embedding: ${response.body}");
  }
    else{
      print("embeddings formed");
    }
    final data = jsonDecode(response.body);
     if (data['embedding'] == null) {
    throw Exception("No embedding returned from Gemini API");
  }
  print(data);
  
    return List<double>.from(data["embedding"]['values']);
  }

  Future<void> savePage(String text, String url) async {
    try {
      final embedding = await getEmbedding(text);
      print(embedding);

      final supabase = Supabase.instance.client;

      await supabase.from('pages').insert({
        'user_id': FirebaseAuth.instance.currentUser!.uid,
        'url': url,
        'text': text,
        'embedding': embedding,
        'created_at': DateTime.now().toIso8601String(),
        // 'project_id':projectId,
      });

      Fluttertoast.showToast(msg: "Page saved!");
      Navigator.pop(context);
    } catch (e) {
      print(e);
      Fluttertoast.showToast(msg: "Error saving page: $e");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

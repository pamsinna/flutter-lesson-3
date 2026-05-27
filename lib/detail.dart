import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:celebrities/tts.dart';

class DetailPage extends StatefulWidget {
  final Map celebrity;

  const DetailPage({super.key, required this.celebrity});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final player = AudioPlayer();

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _playSpeech() async {
    try {
      final name = widget.celebrity["name"] as String;
      // 名字含任何中文字就用國語、純英文就用英文
      // (TTS server 一次只吃一種語言，混語會 Exception)
      final lang = RegExp(r'[一-鿿]').hasMatch(name) ? "zh" : "en";

      String? path = await processAudio(name, language: lang);
      if (path != null && path.isNotEmpty) {
        await player.setFilePath(path);
        await player.play();
      }
    } catch (e) {
      print("播放失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.celebrity['name']),
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15.0),
                  child: Image.asset(
                    widget.celebrity['image'],
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.celebrity['name'],
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () async {
                      await _playSpeech();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.celebrity['occupation'],
                style: const TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  widget.celebrity['description'] ?? '',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

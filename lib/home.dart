import 'dart:math';
import 'package:flutter/material.dart';
import 'package:celebrities/detail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:celebrities/stt.dart';
import 'package:celebrities/tts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List _celebrities = [
    {
      "name": "Michael Jordan",
      "occupation": "得分後衛",
      "image": "assets/images/jordan.jpg",
      "description": "黑人耶穌"
    },
    {
      "name": "Kobe Bryant",
      "occupation": "得分後衛",
      "image": "assets/images/kobe.jpg",
      "description": "黑曼巴"
    },
    {
      "name": "LeBron James",
      "occupation": "小前鋒",
      "image": "assets/images/lebron.jpg",
      "description": "小皇帝"
    },
    {
      "name": "Stephen Curry",
      "occupation": "控球後衛",
      "image": "assets/images/curry.jpg",
      "description": "萌神"
    },
    {
      "name": "林書豪",
      "occupation": "控球後衛",
      "image": "assets/images/lin.jpg",
      "description": "Linsanity"
    },
  ];

  List showCelebrities = [];
  final TextEditingController _searchController = TextEditingController();
  final record = AudioRecorder();
  final player = AudioPlayer();

  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    showCelebrities = List.from(_celebrities);

    // 原本自動測試合成的這段先拿掉
    // Future.microtask(() async {
    //   String? path = await processAudioFile("測試測試1111111111111111111111111");
    //   print("TTS path: $path");
    // });
  }

  @override
  void dispose() {
    _searchController.dispose();
    player.dispose();
    record.dispose();
    super.dispose();
  }

  void _searchCelebrities(String keyword) {
    setState(() {
      showCelebrities = _celebrities
          .where((celebrity) =>
      celebrity["name"].contains(keyword) ||
          celebrity["occupation"].contains(keyword))
          .toList();
    });
  }

  // ============================
  // 新增：測試 TTS 播放
  // 按下按鈕後，先做語音合成
  // 再把回傳的音檔路徑交給 just_audio 播放
  // ============================
  Future<void> _playTestTts() async {
    try {
      String? path = await processAudio("測試");

      if (path != null && path.isNotEmpty) {
        await player.setFilePath(path);
        await player.play();
      } else {
        print("TTS 失敗，沒有拿到音檔路徑");
      }
    } catch (e) {
      print("播放測試音失敗: $e");
    }
  }
  
  void _navigateToRandom() {
    if (_celebrities.isEmpty) return;
    
    final random = Random();
    final index = random.nextInt(_celebrities.length);
    final selected = _celebrities[index];
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) {
        return DetailPage(
          celebrity: selected,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Celebrities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino),
            tooltip: 'Random Celebrity',
            onPressed: _navigateToRandom,
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(10),
                  height: 50,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                ),
              ),

              // ============================
              // 錄音按鈕
              // ============================
              SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    // 先抓 Messenger，避免 await 之後再用 context 觸發 lint
                    final messenger = ScaffoldMessenger.of(context);
                    final tempPath = await getTemporaryDirectory();
                    String path = "${tempPath.path}/audio.wav";

                    if (isRecording) {
                      // debug 用：追蹤錄音停止、API 呼叫流程；不需要可以刪
                      print("[REC] 停止錄音");
                      await record.stop();
                      print("[REC] 呼叫 STT request($path)");
                      String? result = await request(path);
                      print("[REC] STT result = $result");

                      if (result != null) {
                        _searchController.text = result;
                      } else {
                        _searchController.text = "";
                      }

                      isRecording = false;
                    } else {
                      // debug 用：權限被拒時印出來最容易發現問題
                      final hasPerm = await record.hasPermission();
                      print("[REC] hasPermission = $hasPerm");
                      if (hasPerm) {
                        print("[REC] 開始錄音 path=$path");
                        await record.start(
                          const RecordConfig(
                            sampleRate: 16000,
                            numChannels: 1,
                            encoder: AudioEncoder.wav,
                          ),
                          path: path,
                        );
                        isRecording = true;
                      } else {
                        print("[REC] ❌ 沒有麥克風權限");
                        messenger.showSnackBar(
                          const SnackBar(content: Text('請開啟麥克風權限')),
                        );
                      }
                    }

                    setState(() {});
                  },
                  backgroundColor: isRecording ? Colors.red : Colors.blue,
                  label: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              // ============================
              // 新增：播放測試按鈕
              // 按下後會合成「測試測試」並播放
              // ============================
              IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () async {
                  await _playTestTts();
                },
              ),

              // ============================
              // 原本的搜尋按鈕
              // ============================
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _searchCelebrities(_searchController.text),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: showCelebrities.length,
              itemBuilder: (context, index) {
                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Image.asset(
                      showCelebrities[index]["image"],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(showCelebrities[index]["name"]),
                    subtitle: Text(showCelebrities[index]["occupation"]),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) {
                            return DetailPage(
                              celebrity: showCelebrities[index],
                            );
                          }),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
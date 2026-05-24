import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TtsClient {
  final String server = '140.116.245.146';
  final int port = 9998;
  final String endOfTransmission = 'EOT';
  final String token = "mi2stts";
  final String apiId = "10012";

  // 9998 (VITS-TCP_server) 接受的命名語者
  
  static const Set<String> namedSpeakers = {'P_M_005', 'M04', 'M90'};

  late Future<Socket> _socketFuture;

  TtsClient() {
    _socketFuture = Socket.connect(server, port, timeout: Duration(seconds: 5));
  }

  Future<void> send(String language, String speaker, String data) async {
    // Port 9998 語者：整數 0~4815，或下列命名語者 P_M_005 / M04 / M90 / M95
    if (!namedSpeakers.contains(speaker)) {
      final spkInt = int.tryParse(speaker);
      if (spkInt == null || spkInt < 0 || spkInt > 4815) {
        throw ArgumentError(
            "Speaker for Port 9998 must be 0~4815 or one of $namedSpeakers.");
      }
    }

    // 文字本身不能含分隔符 '@@@'，否則伺服器會無法正確解析欄位
    if (data.isEmpty) {
      throw ArgumentError("TTS 文字不能為空");
    }
    if (data.contains('@@@')) {
      throw ArgumentError("TTS 文字不能含分隔符 '@@@'");
    }

    String message = "$apiId@@@$token@@@$language@@@$speaker@@@$data$endOfTransmission";
    final socket = await _socketFuture;
    socket.add(utf8.encode(message));
    await socket.flush();
  }

  // 9998 (VITS) 在多人同時打時會排隊，實測 15 人同時打最久要 ~21 秒，
  // 拉到 60 秒給 3x 緩衝；若教室人數較多可再拉長
  Future<String> receive({Duration timeout = const Duration(seconds: 60)}) async {
    final socket = await _socketFuture;
    final bytes = <int>[];
    final completer = Completer<String>();

    socket.listen(
          (chunk) => bytes.addAll(chunk),
      onDone: () => completer.complete(utf8.decode(bytes)),
      onError: (e) => completer.completeError(e),
      cancelOnError: true,
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException('TTS receive timeout'),
    );
  }

  Future<void> close() async {
    try {
      final socket = await _socketFuture;
      await socket.close();
      socket.destroy();
    } catch (_) {
      // 連線建立階段就失敗時，這裡會再丟一次例外，吞掉即可
    }
  }
}

/// 語音合成 (Port 9998 / VITS-TCP_server)
/// [text]     要合成的文字（中文輸入即可，依 language 切換輸出語言）
/// [speaker]  語者 id：整數 0~4815 或 P_M_005 / M04 / M90
///            推薦語者：
///              - "2775"  女生
///              - "4793"  男生（預設）
/// [language] 支援：
///   - 'zh'        中文（國語）
///   - 'tw'        台語（輸入中文字）
///   - 'hakka'     客語（輸入中文字）
///   - 'en'        英文
Future<String?> processAudio(
  String text, {
  String speaker = "4793", // 男生；想換女聲改成 "2775"
  String language = "tw",
}) async {
  final client = TtsClient();
  try {
    await client.send(language, speaker, text);
    final result = await client.receive();
    if (result.isEmpty) return null;

    final response = jsonDecode(result);
    if (response["status"] == true) {
      final wavBytes = base64Decode(response["bytes"] ?? "");
      final outputPath = "${Directory.systemTemp.path}/tts_out.wav";
      File(outputPath).writeAsBytesSync(wavBytes);

      print("✅ Synthesis Success: $outputPath");
      if (response.containsKey("ctl_tone_sandhi")) {
        print("Tone Sandhi: ${response["ctl_tone_sandhi"]}");
      }
      return outputPath;
    } else {
      // 兼容伺服器端大小寫不一的 "message" 或 "Message"
      final error = response["message"] ?? response["Message"] ?? "Unknown Error";
      print("❌ Server Error: $error");
      return null;
    }
  } catch (e) {
    print("❌ Fatal Error: $e");
    return null;
  } finally {
    await client.close();
  }
}

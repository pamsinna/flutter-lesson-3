import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TtsClient {
  final String server = '140.116.245.146';
  final int port = 9993;
  final String endOfTransmission = 'EOT';
  final String token = "mi2stts";
  final String apiId = "10012";

  late Future<Socket> _socketFuture;

  TtsClient() {
    _socketFuture = Socket.connect(server, port, timeout: Duration(seconds: 5));
  }

  Future<void> send(String language, String speaker, String data) async {
    // Port 9993 語者範圍為 0 到 58
    int? spkInt = int.tryParse(speaker);
    if (spkInt == null || spkInt < 0 || spkInt > 58) {
      throw ArgumentError("Speaker ID must be 0 ~ 58 for Port 9993.");
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

  Future<String> receive({Duration timeout = const Duration(seconds: 30)}) async {
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

Future<String?> processAudio(String text, {String speaker = "10"}) async {
  final client = TtsClient();
  try {
    await client.send('tw', speaker, text);
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
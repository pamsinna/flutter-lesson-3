import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String?> request(String path) async {
  try {
    // debug: 看是不是真的有讀到檔案；不需要可以刪
    print("[STT] 讀取音檔: $path");
    File file = File(path);
    if (!await file.exists()) {
      print("[STT] ❌ 音檔不存在");
      return null;
    }
    List<int> fileBytes = await file.readAsBytes();
    // debug: 音檔太小通常代表麥克風沒收到聲音
    print("[STT] 音檔大小: ${fileBytes.length} bytes");

    String base64Audio = base64Encode(fileBytes);

    Map<String, dynamic> data = {
      "audio": base64Audio,
      "lang": "TA and ZH Medical V1",
      "source": "人本and多語",
      "timestamp": false
    };

    Uri url = Uri.parse("http://140.116.245.154:9001/api/base64_recognition");
    // debug: 確認真的有送出 request
    print("[STT] POST → $url");
    http.Response response = await http.post(
      url,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
    // debug: 看 server 回什麼最直接；不需要可以刪這兩行
    print("[STT] 回應 status=${response.statusCode}");
    print("[STT] 回應 body (前 200 字): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");

    if (response.statusCode == 200) {
      if (response.body == "<{silent}>") {
        print("[STT] 偵測為靜音");
        return null;
      } else {
        return response.body;
      }
    } else {
      print("[STT] ❌ Request failed: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    // debug: 網路問題、檔案問題、JSON 壞掉都會跑到這裡
    print("[STT] ❌ Exception: $e");
    return null;
  }
}
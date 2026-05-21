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

    // 新 API 使用 form-encoded (application/x-www-form-urlencoded)
    // 直接把 Map 傳給 http.post 的 body，套件會自動編碼
    Map<String, String> data = {
      "lang": "TA and ZH Medical V1", // 中文輸出；台羅拼音請改成 "TA_toned"
      "token": "2025@mi2s_asr@tai",
      "audio": base64Audio,
    };

    Uri url = Uri.parse("http://140.116.245.149:5002/proxy");
    // debug: 確認真的有送出 request
    print("[STT] POST → $url");
    // 最多等 60 秒；超過就放棄，避免 server 掛掉時 UI 永遠卡住
    http.Response response = await http
        .post(url, body: data)
        .timeout(const Duration(seconds: 60));
    // debug: 看 server 回什麼最直接；不需要可以刪這兩行
    print("[STT] 回應 status=${response.statusCode}");
    print("[STT] 回應 body (前 200 字): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");

    if (response.statusCode == 200) {
      // 新 API 永遠回 JSON，要從 "sentence" 欄位取結果
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sentence = body["sentence"] as String?;
      if (sentence == null || sentence == "<{silent}>") {
        print("[STT] 偵測為靜音");
        return null;
      }
      return sentence.trim(); // server 回的字串前後常有空白
    } else {
      print("[STT] ❌ Request failed: ${response.statusCode} body=${response.body}");
      return null;
    }
  } catch (e) {
    // debug: 網路問題、檔案問題、JSON 壞掉都會跑到這裡
    print("[STT] ❌ Exception: $e");
    return null;
  }
}
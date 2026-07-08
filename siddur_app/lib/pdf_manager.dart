import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfManager {
  // כתובת בסיס ברירת מחדל להורדת הקבצים. 
  static String baseUrl = 'https://raw.githubusercontent.com/bnq9705-creator/siddur/shortcuts-test/pdfs/';

  static const List<String> pdfFiles = [
    "02_shacharit_chol.pdf",
    "03_mincha_chol.pdf",
    "04_arvit_chol.pdf",
    "05_kriat_shema_mita.pdf",
    "birkat_amazon.pdf",
    "rosh_chodesh.pdf",
    "special_readings.pdf",
    "tehillim.pdf",
    "torah_readings.pdf"
  ];

  static Map<String, dynamic>? _remoteManifest;

  /// מוריד את קובץ המניפסט לצורך מעקב גרסאות ועדכונים
  static Future<Map<String, dynamic>?> fetchManifest() async {
    if (_remoteManifest != null) return _remoteManifest;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final url = baseUrl.endsWith('pdfs/')
          ? baseUrl.replaceAll('pdfs/', 'manifest.json')
          : '${baseUrl}manifest.json';
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final contents = await response.transform(utf8.decoder).join();
        _remoteManifest = json.decode(contents) as Map<String, dynamic>;
        return _remoteManifest;
      }
    } catch (e) {
      debugPrint("Failed to fetch manifest: $e");
    } finally {
      client.close();
    }
    return null;
  }

  static const int currentAppVersion = 1;

  static int getMinVersion() {
    if (_remoteManifest == null) return 1;
    return _remoteManifest!['min_version'] as int? ?? 1;
  }

  static bool isAppDisabled() {
    if (_remoteManifest == null) return false;
    return _remoteManifest!['is_app_disabled'] as bool? ?? false;
  }

  static String getDisableMessage() {
    if (_remoteManifest == null) return "הגישה לאפליקציה חסומה זמנית.";
    return _remoteManifest!['disable_message'] as String? ?? "הגישה לאפליקציה חסומה זמנית.";
  }

  static String getStoreUrl() {
    if (_remoteManifest == null) return "";
    return _remoteManifest!['store_url'] as String? ?? "";
  }


  /// בודק אם יש עדכונים לקבצים ברשת, ומוחק קבצים ישנים מקומית כדי שיורדו מחדש
  static Future<void> checkForUpdates() async {
    final manifest = await fetchManifest();
    if (manifest == null || manifest['files'] == null) return;

    final prefs = await SharedPreferences.getInstance();
    final filesInfo = manifest['files'] as Map<String, dynamic>;
    final dir = await getApplicationDocumentsDirectory();

    for (String fileName in pdfFiles) {
      if (filesInfo.containsKey(fileName)) {
        final fileInfo = filesInfo[fileName] as Map<String, dynamic>;
        final onlineVersion = fileInfo['version'] as int;
        final localVersionKey = 'pdf_version_$fileName';
        final localVersion = prefs.getInt(localVersionKey) ?? 0;

        final file = File("${dir.path}/$fileName");
        if (await file.exists() && localVersion < onlineVersion) {
          debugPrint("PDF $fileName is outdated (local: $localVersion, online: $onlineVersion). Deleting to trigger update.");
          try {
            await file.delete();
            await prefs.setInt(localVersionKey, 0);
          } catch (e) {
            debugPrint("Error deleting outdated file $fileName: $e");
          }
        }
      }
    }
  }

  /// בודק אם קובץ מסוים כבר קיים במלואו מקומית במכשיר
  static Future<bool> isFileDownloaded(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$fileName");
    return await file.exists() && await file.length() > 1000;
  }

  static final Map<String, Future<String>> _activeDownloads = {};

  /// מחזיר את הנתיב המקומי של הקובץ. אם הוא לא קיים - מוריד אותו מיידית עם תמיכה באחוזים.
  static Future<String> getPdfPath(String fileName, {void Function(double progress)? onProgress}) {
    if (_activeDownloads.containsKey(fileName)) {
      return _activeDownloads[fileName]!;
    }

    final future = _getPdfPathImpl(fileName, onProgress: onProgress);
    _activeDownloads[fileName] = future;

    future.then((_) {
      _activeDownloads.remove(fileName);
    }).catchError((_) {
      _activeDownloads.remove(fileName);
    });

    return future;
  }

  static Future<String> _getPdfPathImpl(String fileName, {void Function(double progress)? onProgress}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$fileName");

    if (await file.exists() && await file.length() > 1000) {
      return file.path;
    }

    final tempFile = File("${dir.path}/$fileName.temp");
    try {
      await downloadFile(fileName, tempFile, onProgress: onProgress);
      
      // Rename temp file to final destination on successful download completion
      if (await tempFile.exists()) {
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
      }
      return file.path;
    } catch (e) {
      // Clean up temp file if download fails
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// מוריד קובץ בודד מהשרת ושומר אותו מקומית עם מעקב אחוזים
  static Future<void> downloadFile(String fileName, File destination, {void Function(double progress)? onProgress}) async {
    final url = '$baseUrl$fileName';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        if (await destination.exists()) {
          await destination.delete();
        }

        final contentLength = response.contentLength;
        int downloadedBytes = 0;
        final fileSink = destination.openWrite();

        try {
          await for (var chunk in response) {
            fileSink.add(chunk);
            downloadedBytes += chunk.length;
            if (contentLength > 0 && onProgress != null) {
              onProgress(downloadedBytes / contentLength);
            }
          }
        } finally {
          await fileSink.flush();
          await fileSink.close();
        }

        // שמירת הגרסה המקומית ב-SharedPreferences לאחר הורדה מוצלחת
        final manifest = await fetchManifest();
        int version = 1;
        if (manifest != null && manifest['files'] != null) {
          final filesInfo = manifest['files'] as Map<String, dynamic>;
          if (filesInfo.containsKey(fileName)) {
            version = filesInfo[fileName]['version'] ?? 1;
          }
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('pdf_version_$fileName', version);

      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      if (await destination.exists()) {
        try {
          await destination.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// בודק אם כל קבצי ה-PDF כבר ירדו למכשיר
  static Future<bool> areAllFilesDownloaded() async {
    for (String fileName in pdfFiles) {
      if (!await isFileDownloaded(fileName)) {
        return false;
      }
    }
    return true;
  }

  /// מוחק את כל הקבצים המקומיים ואת הגדרות הגרסאות שלהם
  static Future<void> clearCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final prefs = await SharedPreferences.getInstance();
    for (String fileName in pdfFiles) {
      final file = File("${dir.path}/$fileName");
      if (await file.exists()) {
        await file.delete();
      }
      await prefs.remove('pdf_version_$fileName');
    }
  }
}

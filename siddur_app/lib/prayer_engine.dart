import 'package:flutter/foundation.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'parashot_data.dart';
import 'tehillim_data.dart'; // הוספת מפת התהילים

class PrayerPage {
  final String pdfAssetPath; // מאיזה קובץ PDF לקחת את העמוד
  final int pageNumber; // איזה עמוד בקובץ

  PrayerPage({required this.pdfAssetPath, required this.pageNumber});
}

class PrayerEngine {
  static const String baseShacharitPdf = 'assets/pdfs/02_shacharit_chol.pdf';
  static const String torahReadingsPdf = 'assets/pdfs/torah_readings.pdf';
  static const String tehillimPdf = 'assets/pdfs/tehillim.pdf'; // הקובץ החדש שחתכנו

  static List<PrayerPage> generateShacharitPlaylist({bool isInIsrael = true}) {
    List<PrayerPage> playlist = [];

    // --- בלוק 1: תחילת שחרית עד סוף תחנון (עמודים 6 עד 65) ---
    for (int i = 6; i <= 65; i++) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
    }

    // --- בלוק 2: בדיקת יום (שני/חמישי) והשתלת קריאת התורה ---
    DateTime now = DateTime.now();

    if (now.weekday == DateTime.monday || now.weekday == DateTime.thursday) {
      String? parashaKey;
      try {
        JewishCalendar jewishCalendar = JewishCalendar.fromDateTime(now);
        jewishCalendar.inIsrael = isInIsrael;
        int safetyNet = 0;
        while (jewishCalendar.getParshah() == Parsha.NONE && safetyNet < 7) {
          jewishCalendar.forward();
          safetyNet++;
        }
        Parsha upcomingParsha = jewishCalendar.getParshah();
        parashaKey = 'Parsha.${upcomingParsha.name}'; 
        debugPrint('PrayerEngine: זוהתה פרשה (${isInIsrael ? "ישראל" : "חו\"ל"}): $parashaKey');
      } catch (e) {
        debugPrint('PrayerEngine: שגיאה בחישוב פרשה: $e');
      }

      if (parashaKey != null) {
        ParashaData? parashaData = parashotMap[parashaKey];
        if (parashaData != null) {
          for (int page in parashaData.pages) {
            playlist.add(PrayerPage(pdfAssetPath: torahReadingsPdf, pageNumber: page));
          }
        }
      }
    }

    // --- בלוק 3: המשך שחרית (אשרי יושבי ביתך עד לפני שיר של יום - עמודים 66 עד 70) ---
    for (int i = 66; i <= 70; i++) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
    }

    // --- בלוק 3.5: לוגיקה דינמית לשיר של יום (לפי מספרי עמודים מקוריים) ---
    int weekday = now.weekday; 
    
    if (weekday == DateTime.sunday) {
      // יום ראשון: 71 (שיר של יום + הושיענו)
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 71));
    } else if (weekday == DateTime.monday || weekday == DateTime.tuesday) {
      // יום שני/שלישי: 72 -> 71 (הושיענו)
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 72));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 71));
    } else if (weekday == DateTime.wednesday) {
      // יום רביעי: 73 -> 71 (הושיענו)
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 73));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 71));
    } else if (weekday == DateTime.thursday) {
      // יום חמישי: 73 -> 74 -> 71 (הושיענו)
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 73));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 74));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 71));
    } else if (weekday == DateTime.friday) {
      // יום שישי: 74 -> 71 (הושיענו)
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 74));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 71));
    }

    // המשך התפילה אחרי שיר של יום (עמוד 76 ואילך עד 81)
    for (int i = 76; i <= 81; i++) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
    }

    // --- בלוק 4: תהילים יומי ---
    try {
      JewishCalendar jCal = JewishCalendar.fromDateTime(now);
      int dayOfMonth = jCal.getJewishDayOfMonth();
      int totalDaysInMonth = jCal.getDaysInJewishMonth();

      debugPrint('PrayerEngine: תהילים ליום $dayOfMonth (חודש של $totalDaysInMonth ימים)');

      // הוספת היום הנוכחי
      List<int>? pagesToday = tehillimMap[dayOfMonth];
      if (pagesToday != null) {
        for (int p in pagesToday) {
          playlist.add(PrayerPage(pdfAssetPath: tehillimPdf, pageNumber: p));
        }
      }

      // אם החודש הוא בן 29 ימים והיום הוא כ"ט - מוסיפים גם את היום ה-30
      if (totalDaysInMonth == 29 && dayOfMonth == 29) {
        debugPrint('PrayerEngine: חודש חסר - מוסיף גם תהילים של יום ל');
        List<int>? pagesDay30 = tehillimMap[30];
        if (pagesDay30 != null) {
          for (int p in pagesDay30) {
            playlist.add(PrayerPage(pdfAssetPath: tehillimPdf, pageNumber: p));
          }
        }
      }
    } catch (e) {
      debugPrint('PrayerEngine: שגיאה בחישוב תהילים: $e');
    }

    return playlist;
  }
}

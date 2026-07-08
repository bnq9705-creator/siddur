import 'package:flutter/foundation.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'parashot_data.dart';
import 'tehillim_data.dart';
import 'chabad_dates.dart';

class PrayerPage {
  final String pdfAssetPath; 
  final int pageNumber; 

  PrayerPage({required this.pdfAssetPath, required this.pageNumber});
}

class PrayerEngine {
  static const String baseShacharitPdf = 'assets/pdfs/02_shacharit_chol.pdf';
  static const String torahReadingsPdf = 'assets/pdfs/torah_readings.pdf';
  static const String tehillimPdf = 'assets/pdfs/tehillim.pdf';
  static const String specialReadingsPdf = 'assets/pdfs/special_readings.pdf';
  static const String roshChodeshPdf = 'assets/pdfs/rosh_chodesh.pdf';

  /// פונקציה לייצור פלייליסט של ברכות השחר בלבד (עמודים 1-5 מהקובץ הראשי)
  static List<PrayerPage> generateBirchotHashacharPlaylist() {
    List<PrayerPage> playlist = [];
    for (int i = 1; i <= 5; i++) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
    }
    return playlist;
  }

  static List<PrayerPage> generateShacharitPlaylist({bool isInIsrael = true, DateTime? simulatedDate}) {
    debugPrint('🚀 PrayerEngine: GENERATING PLAYLIST v2.2 (Shir Shel Yom Refined)');
    List<PrayerPage> playlist = [];
    DateTime now = simulatedDate ?? DateTime.now();
    JewishCalendar jCal = JewishCalendar.fromDateTime(now);
    jCal.inIsrael = isInIsrael;

    int m = jCal.getJewishMonth();
    int d = jCal.getJewishDayOfMonth();
    
    // בדיקת חגים ומועדים
    bool isRoshChodesh = jCal.isRoshChodesh() || jCal.isCholHamoed();
    bool isPurim = (m == JewishDate.ADAR && (d == 14 || d == 15)) || 
                   (m == JewishDate.ADAR_II && (d == 14 || d == 15));
                   
    bool isMoed = isRoshChodesh || jCal.isChanukah() || isPurim || m == JewishDate.NISSAN;
    bool sayTachanun = !isMoed && !ChabadDates.isNoTachanunDay(jCal);

    // 1. שחרית עד סוף העמידה
    for (int i = 6; i <= 56; i++) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
    }

    // 2. תחנון וחצי קדיש (רק בימי חול רגילים)
    if (sayTachanun) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 57));
      if (now.weekday == DateTime.monday || now.weekday == DateTime.thursday) {
        for (int i = 58; i <= 62; i++) {
          playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
        }
      }
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 63));
    } else if (!isRoshChodesh) {
      // בימים ללא תחנון (שאינם ראש חודש) - אומרים חצי קדיש אחרי עמידה
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 63));
    }

    // 3. ראש חודש: הלל וקדיש (69-70)
    if (isRoshChodesh) {
      for (int i = 1; i <= 5; i++) {
        playlist.add(PrayerPage(pdfAssetPath: roshChodeshPdf, pageNumber: i));
      }
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 69));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 70));
    }

    // פונקציית עזר לשיר של יום וברכי נפשי
    void addShirShelYomBlock() {
      int weekday = now.weekday;
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 71));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 72));
      
      if (weekday == DateTime.wednesday) {
        playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 73));
      } else if (weekday == DateTime.thursday) {
        playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 73));
        if (!isRoshChodesh) playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 74));
      } else if (weekday == DateTime.friday) {
        if (!isRoshChodesh) playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 74));
      }

      if (isRoshChodesh) {
        playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 74));
        playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 75));
        playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 76));
      }
    }

    if (isRoshChodesh) {
      addShirShelYomBlock();
    }

    // 5. קריאת התורה
    bool isRoshChodeshReal = jCal.isRoshChodesh();
    bool isCholHamoedReal = jCal.isCholHamoed();
    bool isChanukahReal = jCal.isChanukah();
    bool isPurimReal = isPurim;
    bool isFastDayReal = jCal.isTaanis() && 
                         jCal.getYomTovIndex() != JewishCalendar.YOM_KIPPUR && 
                         jCal.getYomTovIndex() != JewishCalendar.TISHA_BEAV;

    bool isTorahDay = now.weekday == DateTime.monday || 
                      now.weekday == DateTime.thursday || 
                      isRoshChodeshReal || 
                      isCholHamoedReal || 
                      isChanukahReal || 
                      isPurimReal || 
                      isFastDayReal;

    if (isTorahDay) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 64));
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: 65));

      if (isRoshChodeshReal) {
        // קריאת ראש חודש
        playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 1));
      } else if (isChanukahReal) {
        // קריאת חנוכה
        int dayOfChanukah = jCal.getDayOfChanukah();
        if (dayOfChanukah == 1) {
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 3));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 4));
        } else if (dayOfChanukah == 2 || dayOfChanukah == 3) {
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 4));
        } else if (dayOfChanukah == 4 || dayOfChanukah == 5) {
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 4));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 5));
        } else if (dayOfChanukah == 6) {
          // יום שישי של חנוכה - תמיד ראש חודש טבת: עמוד 1 ואז עמוד 5
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 1));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 5));
        } else if (dayOfChanukah == 7) {
          // יום שביעי: אם הוא ראש חודש (כסלו בן 30 יום), קוראים עמוד 1 ואז 5. אחרת רק 5.
          if (jCal.isRoshChodesh()) {
            playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 1));
            playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 5));
          } else {
            playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 5));
          }
        } else if (dayOfChanukah == 8) {
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 5));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 6));
        }
      } else if (isPurimReal) {
        // קריאת פורים
        playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 7));
      } else if (isFastDayReal) {
        // קריאת תענית ציבור (ויחל)
        playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 1));
        playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 2));
      } else if (isCholHamoedReal) {
        // קריאת חול המועד
        int yomTovIndex = jCal.getYomTovIndex();
        bool isSukkot = yomTovIndex == JewishCalendar.SUCCOS || 
                        yomTovIndex == JewishCalendar.CHOL_HAMOED_SUCCOS || 
                        yomTovIndex == JewishCalendar.HOSHANA_RABBA;
        if (isSukkot) {
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 11));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 12));
        } else {
          // אחרת, חול המועד פסח
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 26));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 27));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 28));
          playlist.add(PrayerPage(pdfAssetPath: specialReadingsPdf, pageNumber: 29));
        }
      } else {
        // קריאה רגילה של שני וחמישי
        String? parashaKey;
        try {
          int safetyNet = 0;
          JewishCalendar tempCal = JewishCalendar.fromDateTime(now);
          tempCal.inIsrael = isInIsrael;
          while (tempCal.getParshah() == Parsha.NONE && safetyNet < 7) {
            tempCal.forward();
            safetyNet++;
          }
          parashaKey = 'Parsha.${tempCal.getParshah().name}';
        } catch (_) {}

        if (parashaKey != null && parashotMap.containsKey(parashaKey)) {
          for (int page in parashotMap[parashaKey]!.pages) {
            playlist.add(PrayerPage(pdfAssetPath: torahReadingsPdf, pageNumber: page));
          }
        }
      }
    }

    // 6. אשרי ובא לציון (66 עד 70)
    for (int i = 66; i <= 70; i++) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
    }

    // 7. מוסף (בראש חודש)
    if (isRoshChodesh) {
      for (int i = 5; i <= 9; i++) {
        playlist.add(PrayerPage(pdfAssetPath: roshChodeshPdf, pageNumber: i));
      }
    }

    // 8. שיר של יום (בימים רגילים)
    if (!isRoshChodesh) {
      addShirShelYomBlock();
    }

    // 9. סיום (קווה ועלינו)
    for (int i = 76; i <= 81; i++) {
      playlist.add(PrayerPage(pdfAssetPath: baseShacharitPdf, pageNumber: i));
    }

    // 10. תהילים יומי
    try {
      int dayOfMonth = jCal.getJewishDayOfMonth();
      if (tehillimMap.containsKey(dayOfMonth)) {
        for (int p in tehillimMap[dayOfMonth]!) {
          playlist.add(PrayerPage(pdfAssetPath: tehillimPdf, pageNumber: p));
        }
      }
      if (jCal.getDaysInJewishMonth() == 29 && dayOfMonth == 29) {
        if (tehillimMap.containsKey(30)) {
          for (int p in tehillimMap[30]!) {
            playlist.add(PrayerPage(pdfAssetPath: tehillimPdf, pageNumber: p));
          }
        }
      }
    } catch (_) {}

    return playlist;
  }
}

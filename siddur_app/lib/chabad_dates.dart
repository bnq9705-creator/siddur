import 'package:kosher_dart/kosher_dart.dart';

/// מחלקה לניהול תאריכים מיוחדים של חב"ד שבהם לא אומרים תחנון
class ChabadDates {
  static bool isNoTachanunDay(JewishCalendar jCal) {
    int month = jCal.getJewishMonth();
    int day = jCal.getJewishDayOfMonth();

    // רשימת ימים ללא תחנון (חב"ד)
    
    // כסלו
    if (month == JewishDate.KISLEV) {
      if (day == 19 || day == 20) return true; // י"ט-כ' כסלו
    }
    
    // טבת
    if (month == 10) { // שימוש במספר ישיר לטבת כדי למנוע שגיאות קומפילציה
      if (day == 5) return true; // ה' טבת
    }
    
    // שבט
    if (month == JewishDate.SHEVAT) {
      if (day == 10 || day == 22) return true; // י' שבט, כ"ב שבט
    }
    
    // תמוז
    if (month == JewishDate.TAMMUZ) {
      if (day == 12 || day == 13) return true; // י"ב-י"ג תמוז
    }
    
    // אלול
    if (month == JewishDate.ELUL) {
      if (day == 18) return true; // ח"י אלול
    }

    return false;
  }
}

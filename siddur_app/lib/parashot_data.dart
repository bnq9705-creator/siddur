class ParashaData {
  final List<int> pages;
  ParashaData({required this.pages});
}

/// מפת פרשות מעודכנת לפי המספור האמיתי בקובץ torah_readings.pdf
final Map<String, ParashaData> parashotMap = {
  // חומש בראשית
  'Parsha.BERESHIT': ParashaData(pages: [1]),
  'Parsha.NOACH': ParashaData(pages: [1]),
  'Parsha.LECH_LECHA': ParashaData(pages: [1, 2]),
  'Parsha.VAYERA': ParashaData(pages: [2]),
  'Parsha.CHAYEI_SARA': ParashaData(pages: [2, 3]),
  'Parsha.TOLDOT': ParashaData(pages: [3]),
  'Parsha.VAYETZEI': ParashaData(pages: [3, 4]),
  'Parsha.VAYISHLACH': ParashaData(pages: [4]),
  'Parsha.VAYESHEV': ParashaData(pages: [4]),
  'Parsha.MIKETZ': ParashaData(pages: [4, 5]),
  'Parsha.VAYIGASH': ParashaData(pages: [5]),
  'Parsha.VAYECHI': ParashaData(pages: [5]),

  // חומש שמות
  'Parsha.SHEMOT': ParashaData(pages: [5, 6]),
  'Parsha.VAERA': ParashaData(pages: [6]),
  'Parsha.BO': ParashaData(pages: [6, 7]),
  'Parsha.BESHALACH': ParashaData(pages: [7]),
  'Parsha.YITRO': ParashaData(pages: [7]),
  'Parsha.MISHPATIM': ParashaData(pages: [7, 8]),
  'Parsha.TERUMAH': ParashaData(pages: [8]),
  'Parsha.TETZAVEH': ParashaData(pages: [8, 9]),
  'Parsha.KI_TISSA': ParashaData(pages: [9]),
  'Parsha.VAYAKHEL': ParashaData(pages: [9]),
  'Parsha.PEKUDEI': ParashaData(pages: [10]),

  // חומש ויקרא
  'Parsha.VAYIKRA': ParashaData(pages: [10]),
  'Parsha.TZAV': ParashaData(pages: [10, 11]),
  'Parsha.SHMINI': ParashaData(pages: [11]),
  'Parsha.TAZRIA': ParashaData(pages: [11, 12]),
  'Parsha.METZORA': ParashaData(pages: [12]),
  'Parsha.ACHREI_MOT': ParashaData(pages: [12, 13]),
  'Parsha.KEDOSHIM': ParashaData(pages: [13]),
  'Parsha.EMOR': ParashaData(pages: [13]),
  'Parsha.BEHAR': ParashaData(pages: [13, 14]),
  'Parsha.BECHUKOTAI': ParashaData(pages: [14]),

  // חומש במדבר
  'Parsha.BAMIDBAR': ParashaData(pages: [14]),
  'Parsha.NASSO': ParashaData(pages: [14, 15]),
  'Parsha.BEHAALOTCHA': ParashaData(pages: [15]),
  'Parsha.SHLACH': ParashaData(pages: [15]),
  'Parsha.KORACH': ParashaData(pages: [15, 16]),
  'Parsha.CHUKAT': ParashaData(pages: [16]),
  'Parsha.BALAK': ParashaData(pages: [16, 17]),
  'Parsha.PINCHAS': ParashaData(pages: [17]),
  'Parsha.MATOT': ParashaData(pages: [17, 18]),
  'Parsha.MASEI': ParashaData(pages: [18, 19]),

  // חומש דברים
  'Parsha.DEVARIM': ParashaData(pages: [19]),
  'Parsha.VAETCHANAN': ParashaData(pages: [19, 20]),
  'Parsha.EIKEV': ParashaData(pages: [20]),
  'Parsha.REEH': ParashaData(pages: [20, 21]),
  'Parsha.SHOFTIM': ParashaData(pages: [21, 22]),
  'Parsha.KI_TEITZEI': ParashaData(pages: [22]),
  'Parsha.KI_TAVO': ParashaData(pages: [22]),
  'Parsha.NITZAVIM': ParashaData(pages: [23]),
  'Parsha.VAYELECH': ParashaData(pages: [23, 24]),
  'Parsha.HAAZINU': ParashaData(pages: [24]),
  'Parsha.VEZOT_HABERACHA': ParashaData(pages: [24]),
};

class TehillimData {
  final List<int> pages;
  TehillimData({required this.pages});
}

/// פונקציית עזר לייצור רצף עמודים
List<int> range(int start, int end) {
  return [for (var i = start; i <= end; i++) i];
}

/// מפת תהילים יומית מעודכנת (מבוססת על הקובץ שחתכנו, עמודים 1-173)
final Map<int, List<int>> tehillimMap = {
  1: range(1, 9),
  2: range(9, 15),
  3: range(15, 23),
  4: range(23, 29),
  5: range(29, 35),
  6: range(36, 42),
  7: range(42, 47),
  8: range(48, 53),
  9: range(53, 60),
  10: range(60, 66),
  11: range(66, 71),
  12: range(71, 76),
  13: range(76, 80),
  14: range(80, 87),
  15: range(87, 92),
  16: range(93, 97),
  17: range(97, 102),
  18: range(102, 106),
  19: range(106, 113),
  20: range(113, 120),
  21: range(120, 124),
  22: range(124, 130),
  23: range(130, 134),
  24: range(135, 140),
  25: range(140, 145),
  26: range(145, 149),
  27: range(149, 157),
  28: range(157, 163),
  29: range(163, 167),
  30: range(168, 173),
};

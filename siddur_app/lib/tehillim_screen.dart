import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'tehillim_data.dart';
import 'prayer_engine.dart';
import 'pdf_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TehillimScreen extends StatefulWidget {
  final DateTime? simulatedDate;
  const TehillimScreen({super.key, this.simulatedDate});

  @override
  State<TehillimScreen> createState() => _TehillimScreenState();
}

class _TehillimScreenState extends State<TehillimScreen> {
  List<int> pages = [];
  PdfDocument? _document;
  final Map<int, Uint8List> _imageCache = {};
  bool isLoading = true;
  final PageController pageController = PageController();
  int currentSelectedDay = 1;

  double downloadProgress = 0.0;
  bool isDownloading = false;
  int _currentPageIndex = 0;
  bool _showPromptBanner = true;

  final Map<int, List<int>> _dayToChapters = {
    1: [1, 2, 3, 4, 5, 6, 7, 8, 9],
    2: [10, 11, 12, 13, 14, 15, 16, 17],
    3: [18, 19, 20, 21, 22],
    4: [23, 24, 25, 26, 27, 28],
    5: [29, 30, 31, 32, 33, 34],
    6: [35, 36, 37, 38],
    7: [39, 40, 41, 42, 43],
    8: [44, 45, 46, 47, 48],
    9: [49, 50, 51, 52, 53, 54],
    10: [55, 56, 57, 58, 59],
    11: [60, 61, 62, 63, 64, 65],
    12: [66, 67, 68],
    13: [69, 70, 71],
    14: [72, 73, 74, 75, 76],
    15: [77, 78],
    16: [79, 80, 81, 82],
    17: [83, 84, 85, 86, 87],
    18: [88, 89],
    19: [90, 91, 92, 93, 94, 95, 96],
    20: [97, 98, 99, 100, 101, 102, 103],
    21: [104, 105],
    22: [106, 107],
    23: [108, 109, 110, 111, 112],
    24: [113, 114, 115, 116, 117, 118],
    25: [119],
    26: [119],
    27: [120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134],
    28: [135, 136, 137, 138, 139],
    29: [140, 141, 142, 143, 144],
    30: [145, 146, 147, 148, 149, 150],
  };

  void _submitChapterReport(int pdfPageNumber, int chapter) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('tehillim_mappings').add({
        'pageNumber': pdfPageNumber,
        'chapter': chapter,
        'reportedBy': FirebaseAuth.instance.currentUser?.email ?? 'anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('תודה! הדיווח התקבל וייבדק בהקדם.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('שגיאה בשליחת הדיווח: $e')),
      );
    }
  }

  void _reportChapter() {
    final pdfPageNumber = pages[_currentPageIndex];
    final dayChapters = _dayToChapters[currentSelectedDay] ?? [];
    final textController = TextEditingController();
    bool showCustomInput = dayChapters.isEmpty;
    List<int> selectedChapters = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFFFBF8F3),
                title: const Text('מיפוי פרק תהילים', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3B32))),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'איזה פרק תהילים מופיע בעמוד זה?\n(עמוד $pdfPageNumber בקובץ)',
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ניתן לבחור יותר מפרק אחד אם העמוד מכיל שני פרקים.',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                      if (!showCustomInput) ...[
                        Text(
                          'בחר מתוך פרקי היום (יום ${getHebrewDay(currentSelectedDay)} בחודש):',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF8C6D58)),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: dayChapters.map((chapter) {
                            final hebNum = HebrewDateFormatter().formatHebrewNumber(chapter);
                            final isSelected = selectedChapters.contains(chapter);
                            return FilterChip(
                              label: Text('פרק $hebNum ($chapter)'),
                              selected: isSelected,
                              selectedColor: const Color(0xFF8C6D58).withOpacity(0.2),
                              checkmarkColor: const Color(0xFF8C6D58),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF8C6D58) : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedChapters.add(chapter);
                                  } else {
                                    selectedChapters.remove(chapter);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setDialogState(() {
                                showCustomInput = true;
                              });
                            },
                            child: const Text('דווח על פרק אחר...', style: TextStyle(color: Color(0xFF8C6D58), decoration: TextDecoration.underline)),
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: textController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'מספר הפרק (1 עד 150)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8C6D58),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: (showCustomInput || selectedChapters.isNotEmpty)
                        ? () async {
                            Navigator.pop(context);
                            if (showCustomInput) {
                              final text = textController.text.trim();
                              final chapter = int.tryParse(text);
                              if (chapter == null || chapter < 1 || chapter > 150) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('נא להזין מספר פרק תקין בין 1 ל-150')),
                                );
                                return;
                              }
                              _submitChapterReport(pdfPageNumber, chapter);
                            } else {
                              for (final ch in selectedChapters) {
                                _submitChapterReport(pdfPageNumber, ch);
                              }
                            }
                          }
                        : null,
                    child: const Text('שלח', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final now = widget.simulatedDate ?? DateTime.now();
    final jCal = JewishCalendar.fromDateTime(now);
    currentSelectedDay = jCal.getJewishDayOfMonth();
    _initTehillim();
  }

  Future<void> _initTehillim() async {
    setState(() {
      isLoading = true;
      isDownloading = false;
      downloadProgress = 0.0;
    });
    try {
      pages = List.from(tehillimMap[currentSelectedDay] ?? []);
      
      // איפוס המיקום של ה-PageView להתחלה
      if (pageController.hasClients) {
        pageController.jumpToPage(0);
      }

      if (_document == null) {
        final filename = PrayerEngine.tehillimPdf.split('/').last;
        final isDownloaded = await PdfManager.isFileDownloaded(filename);
        if (!isDownloaded) {
          setState(() {
            isDownloading = true;
          });
        }
        final localPath = await PdfManager.getPdfPath(
          filename,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                downloadProgress = progress;
              });
            }
          },
        );
        _document = await PdfDocument.openFile(localPath);
      }
    } catch (e) {
      debugPrint('Error initializing Tehillim: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isDownloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _document?.close();
    _imageCache.clear();
    pageController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _renderPage(int pageNumber) async {
    if (_imageCache.containsKey(pageNumber)) {
      final bytes = _imageCache.remove(pageNumber)!;
      _imageCache[pageNumber] = bytes;
      return bytes;
    }
    if (_document == null) return null;

    try {
      final page = await _document!.getPage(pageNumber);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
        quality: 100,
      );
      await page.close();
      if (pageImage != null) {
        if (_imageCache.length >= 10) {
          _imageCache.remove(_imageCache.keys.first);
        }
        _imageCache[pageNumber] = pageImage.bytes;
        return pageImage.bytes;
      }
    } catch (e) {
      debugPrint('Error rendering Tehillim page $pageNumber: $e');
    }
    return null;
  }

  String getHebrewDay(int day) {
    return HebrewDateFormatter().formatHebrewNumber(day);
  }

  void _changeDay(int delta) {
    int newDay = currentSelectedDay + delta;
    if (newDay < 1) newDay = 30;
    if (newDay > 30) newDay = 1;
    setState(() {
      currentSelectedDay = newDay;
    });
    _initTehillim();
  }

  void _selectDay() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              int day = index + 1;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: day == currentSelectedDay ? const Color(0xFF8C6D58) : const Color(0xFFF5EFEB),
                ),
                onPressed: () {
                  setState(() => currentSelectedDay = day);
                  _initTehillim();
                  Navigator.pop(context);
                },
                child: Text(getHebrewDay(day), style: TextStyle(color: day == currentSelectedDay ? Colors.white : Colors.black)),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _document == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBF8F3),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF8C6D58)),
                const SizedBox(height: 30),
                Text(
                  "טוען תהילים...",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3B32), fontSize: 18),
                ),
                if (isDownloading) ...[
                  const SizedBox(height: 15),
                  LinearProgressIndicator(
                    value: downloadProgress,
                    color: const Color(0xFF8C6D58),
                    backgroundColor: const Color(0xFFE6DFD5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${(downloadProgress * 100).toInt()}%",
                    style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "טעינה ראשונית בלבד - בפעמים הבאות ייפתח מיידית",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _selectDay,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_drop_down, size: 20),
              Text('יום ${getHebrewDay(currentSelectedDay)}'),
              const SizedBox(width: 8),
              const Text('תהילים', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFF8C6D58)),
            onPressed: _reportChapter,
            tooltip: 'דווח על הפרק בעמוד זה',
          ),
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(1)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(-1)),
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              PageView.builder(
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(), // גלילה קפיצית וקלילה יותר
                itemCount: pages.length,
                controller: pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return FutureBuilder<Uint8List?>(
                    future: _renderPage(pages[index]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData) return const Center(child: Text('שגיאה בטעינה'));
                      return Center( // מוודא שהדף יהיה במרכז המסך
                        child: InteractiveViewer(
                          child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                        ),
                      );
                    },
                  );
                },
              ),
              if (_showPromptBanner)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 3,
                    color: Colors.white.withOpacity(0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE6DFD5), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.help_outline, color: Color(0xFF8C6D58), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'עזור לנו: איזה פרק מופיע בעמוד זה (עמוד ${pages[_currentPageIndex]})?',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A3B32)),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF8C6D58),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _reportChapter,
                            child: const Text('בחר פרק', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _showPromptBanner = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: const Color(0xFFEFE9E1).withValues(alpha: 0.9),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Color(0xFF8C6D58), width: 1.5)),
          label: const Text("יחי אדוננו מורנו ורבינו מלך המשיח לעולם ועד", style: TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

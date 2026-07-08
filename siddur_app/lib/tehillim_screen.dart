import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'tehillim_data.dart';
import 'prayer_engine.dart';
import 'pdf_manager.dart';

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
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(1)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(-1)),
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : PageView.builder(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(), // גלילה קפיצית וקלילה יותר
            itemCount: pages.length,
            controller: pageController,
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

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'tehillim_data.dart';
import 'prayer_engine.dart';

class TehillimScreen extends StatefulWidget {
  const TehillimScreen({Key? key}) : super(key: key);

  @override
  _TehillimScreenState createState() => _TehillimScreenState();
}

class _TehillimScreenState extends State<TehillimScreen> {
  List<int> pages = [];
  PdfDocument? _document;
  final Map<int, Uint8List> _imageCache = {};
  bool isLoading = true;
  final PageController pageController = PageController();
  int currentSelectedDay = 1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final jCal = JewishCalendar.fromDateTime(now);
    currentSelectedDay = jCal.getJewishDayOfMonth();
    _initTehillim();
  }

  Future<void> _initTehillim() async {
    setState(() => isLoading = true);
    try {
      // כאן אנחנו משתמשים ביום שנבחר (או היום הנוכחי כברירת מחדל)
      pages = List.from(tehillimMap[currentSelectedDay] ?? []);
      
      // בדיקה אם היום הנבחר הוא כ"ט ויש צורך להוסיף את ל' (במידה והמשתמש בחר "היום" וזה חודש חסר)
      // לצורך הפשטות בבחירה ידנית, ניתן למשתמש לבחור פשוט 1-30.
      
      if (_document == null) {
        _document = await PdfDocument.openAsset(PrayerEngine.tehillimPdf);
      }
    } catch (e) {
      debugPrint('Error initializing Tehillim: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
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
    if (_imageCache.containsKey(pageNumber)) return _imageCache[pageNumber];
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
        return Container(
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                  return InteractiveViewer(
                    child: Image.memory(snapshot.data!, fit: BoxFit.contain),
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
          backgroundColor: const Color(0xFFEFE9E1).withOpacity(0.9),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Color(0xFF8C6D58), width: 1.5)),
          label: const Text("יחי אדוננו מורנו ורבינו מלך המשיח לעולם ועד", style: TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

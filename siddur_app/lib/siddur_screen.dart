import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'prayer_engine.dart'; 
import 'parashot_data.dart';

class SiddurScreen extends StatefulWidget {
  final bool isInIsrael;
  const SiddurScreen({Key? key, this.isInIsrael = true}) : super(key: key);

  @override
  _SiddurScreenState createState() => _SiddurScreenState();
}

class _SiddurScreenState extends State<SiddurScreen> {
  List<PrayerPage> playlist = [];
  final Map<String, PdfDocument> _loadedDocuments = {};
  final Map<String, Uint8List> _imageCache = {};
  bool isLoading = true;
  final PageController pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initSiddur();
    // הקפצה אוטומטית של קיצורים בכניסה
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoadingAndShowShortcuts();
    });
  }

  void _checkLoadingAndShowShortcuts() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (!isLoading) {
          _showShortcutsMenu();
        } else {
          _checkLoadingAndShowShortcuts();
        }
      }
    });
  }

  Future<void> _initSiddur() async {
    try {
      playlist = PrayerEngine.generateShacharitPlaylist(isInIsrael: widget.isInIsrael);
      Set<String> uniquePaths = playlist.map((p) => p.pdfAssetPath).toSet();
      for (String path in uniquePaths) {
        try {
          _loadedDocuments[path] = await PdfDocument.openAsset(path);
        } catch (e) {
          debugPrint('שגיאה בטעינת קובץ PDF ($path): $e');
        }
      }
    } catch (e) {
      debugPrint('שגיאה באתחול הסידור: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var doc in _loadedDocuments.values) {
      doc.close();
    }
    _imageCache.clear();
    pageController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _renderPage(PrayerPage prayerPage) async {
    final cacheKey = '${prayerPage.pdfAssetPath}_${prayerPage.pageNumber}';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey];
    }

    final document = _loadedDocuments[prayerPage.pdfAssetPath];
    if (document == null) return null;

    try {
      final page = await document.getPage(prayerPage.pageNumber);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
        quality: 100,
      );
      await page.close();
      if (pageImage != null) {
        _imageCache[cacheKey] = pageImage.bytes;
        return pageImage.bytes;
      }
    } catch (e) {
      debugPrint('❌ שגיאה ברינדור עמוד ${prayerPage.pageNumber}: $e');
    }
    return null;
  }

  void _showShortcutsMenu() {
    final List<Map<String, dynamic>> shortcuts = [
      {'title': 'טלית ותפילין', 'index': 1},
      {'title': 'תפילת השחר', 'index': 2},
      {'title': 'קורבנות', 'index': 9},
      {'title': 'הודו', 'index': 17},
      {'title': 'ויברך דוד', 'index': 27},
      {'title': 'ברכו', 'index': 32},
      {'title': 'שמונה עשרה', 'index': 40},
      {'title': 'אשרי ובא לציון', 'index': 61},
      {'title': 'קווה אל ה\'', 'index': 68},
      {'title': 'תהילים', 'isTehillim': true},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFFFBF8F3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Center(
              child: Text(
                'קיצורים',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E2520)),
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: shortcuts.length,
                itemBuilder: (context, index) {
                  final shortcut = shortcuts[index];
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5EFEB),
                      foregroundColor: const Color(0xFF4A3B32),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE6DFD5)),
                      ),
                    ),
                    onPressed: () {
                      int targetIndex = -1;
                      
                      if (shortcut['isTehillim'] == true) {
                        targetIndex = playlist.indexWhere((p) => p.pdfAssetPath == PrayerEngine.tehillimPdf);
                      } else {
                        // שימוש באינדקס היחסי (1-based)
                        targetIndex = shortcut['index'] - 1;
                      }
                      
                      if (targetIndex >= 0 && targetIndex < playlist.length) {
                        pageController.jumpToPage(targetIndex);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(
                      shortcut['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('תפילת שחרית'), centerTitle: true),
      body: GestureDetector(
        onLongPress: _showShortcutsMenu,
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: playlist.length,
          controller: pageController,
          itemBuilder: (context, index) {
            final prayerPage = playlist[index];
            return FutureBuilder<Uint8List?>(
              future: _renderPage(prayerPage),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('שגיאה בטעינת העמוד'));
                
                return Stack(
                  children: [
                    InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.0,
                      child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                    ),
                    // תצוגת מספר דף יחסי לסנכרון (1 = דף ראשון באפליקציה)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'דף: ${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: FloatingActionButton.extended(
          onPressed: _showShortcutsMenu,
          backgroundColor: const Color(0xFFEFE9E1).withOpacity(0.9),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Color(0xFF8C6D58), width: 1.5)),
          label: const Text("יחי אדוננו מורנו ורבינו מלך המשיח לעולם ועד", style: TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

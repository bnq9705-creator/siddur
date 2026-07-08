import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'prayer_engine.dart';
import 'pdf_manager.dart';

class SiddurScreen extends StatefulWidget {
  final bool isInIsrael;
  final DateTime? simulatedDate;
  final bool isBirchotHashacharOnly; // דגל למצב ברכות השחר בלבד

  const SiddurScreen({
    super.key, 
    this.isInIsrael = true, 
    this.simulatedDate,
    this.isBirchotHashacharOnly = false,
  });

  @override
  State<SiddurScreen> createState() => _SiddurScreenState();
}

class _SiddurScreenState extends State<SiddurScreen> {
  List<PrayerPage> playlist = [];
  final Map<String, PdfDocument> _loadedDocuments = {};
  final Map<String, Uint8List> _imageCache = {};
  bool isLoading = true;
  bool isDevMode = false; // מצב מפתח כבוי כברירת מחדל
  final PageController pageController = PageController();

  double downloadProgress = 0.0;
  String currentDownloadingFile = "";
  bool isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initSiddur();
    
    if (!widget.isBirchotHashacharOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkLoadingAndShowShortcuts();
      });
    }
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
      if (widget.isBirchotHashacharOnly) {
        playlist = PrayerEngine.generateBirchotHashacharPlaylist();
      } else {
        playlist = PrayerEngine.generateShacharitPlaylist(
          isInIsrael: widget.isInIsrael,
          simulatedDate: widget.simulatedDate,
        );
      }
      
      Set<String> uniquePaths = playlist.map((p) => p.pdfAssetPath).toSet();
      int total = uniquePaths.length;
      int i = 0;
      for (String path in uniquePaths) {
        try {
          final filename = path.split('/').last;
          final isDownloaded = await PdfManager.isFileDownloaded(filename);
          
          if (isDownloaded) {
            final localPath = await PdfManager.getPdfPath(filename);
            _loadedDocuments[path] = await PdfDocument.openFile(localPath);
            i++;
            if (mounted) {
              setState(() {
                downloadProgress = i / total;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                isDownloading = true;
                currentDownloadingFile = filename;
              });
            }
            final localPath = await PdfManager.getPdfPath(
              filename,
              onProgress: (progress) {
                if (mounted) {
                  setState(() {
                    downloadProgress = (i + progress) / total;
                  });
                }
              },
            );
            _loadedDocuments[path] = await PdfDocument.openFile(localPath);
            i++;
          }
        } catch (e) {
          debugPrint('Error loading PDF ($path): $e');
        }
      }
    } catch (e) {
      debugPrint('Error initializing Siddur: $e');
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
    for (var doc in _loadedDocuments.values) {
      doc.close();
    }
    _imageCache.clear();
    pageController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _renderPage(PrayerPage prayerPage) async {
    final cacheKey = '${prayerPage.pdfAssetPath}_${prayerPage.pageNumber}';
    
    // LRU cache hit: move to end of insertion order
    if (_imageCache.containsKey(cacheKey)) {
      final bytes = _imageCache.remove(cacheKey)!;
      _imageCache[cacheKey] = bytes;
      return bytes;
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
        // Enforce cache limit of 10 pages
        if (_imageCache.length >= 10) {
          _imageCache.remove(_imageCache.keys.first);
        }
        _imageCache[cacheKey] = pageImage.bytes;
        return pageImage.bytes;
      }
    } catch (e) {
      debugPrint('Error rendering page ${prayerPage.pageNumber}: $e');
    }
    return null;
  }

  void _showShortcutsMenu() {
    final List<Map<String, dynamic>> shortcuts = [
      {'title': 'טלית ותפילין', 'pdfPage': 6},
      {'title': 'תפילת השחר', 'pdfPage': 7},
      {'title': 'קורבנות', 'pdfPage': 14},
      {'title': 'הודו', 'pdfPage': 22},
      {'title': 'ויברך דוד', 'pdfPage': 32},
      {'title': 'ברכו', 'pdfPage': 37},
      {'title': 'שמונה עשרה', 'pdfPage': 45},
      {'title': 'אשרי ובא לציון', 'pdfPage': 66},
      {'title': 'קווה אל ה\'', 'pdfPage': 76},
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
            title: const Center(child: Text('קיצורים', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E2520)))),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: shortcuts.length,
                itemBuilder: (context, index) {
                  final shortcut = shortcuts[index];
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5EFEB), foregroundColor: const Color(0xFF4A3B32), elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE6DFD5)))),
                    onPressed: () {
                      int targetIndex = -1;
                      if (shortcut['isTehillim'] == true) {
                        targetIndex = playlist.indexWhere((p) => p.pdfAssetPath == PrayerEngine.tehillimPdf);
                      } else {
                        targetIndex = playlist.indexWhere((p) => p.pdfAssetPath == PrayerEngine.baseShacharitPdf && p.pageNumber == shortcut['pdfPage']);
                      }
                      if (targetIndex != -1) {
                        pageController.jumpToPage(targetIndex);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(shortcut['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
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
                  isDownloading ? "מוריד קבצי תפילה..." : "טוען סידור...",
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
          onLongPress: () {
            setState(() {
              isDevMode = !isDevMode;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isDevMode ? 'מצב מפתח הופעל' : 'מצב מפתח כבוי')),
            );
          },
          child: Text(widget.isBirchotHashacharOnly ? 'ברכות השחר' : 'תפילת שחרית'),
        ), 
        centerTitle: true
      ),
      body: GestureDetector(
        onLongPress: widget.isBirchotHashacharOnly ? null : _showShortcutsMenu,
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
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
                    // מירכוז אנכי ואופקי מלא
                    Center(
                      child: InteractiveViewer(
                        minScale: 1.0, 
                        maxScale: 3.0, 
                        child: Image.memory(
                          snapshot.data!, 
                          fit: BoxFit.contain,
                        )
                      ),
                    ),
                    // מונה עמודים - מוצג רק במצב מפתח
                    if (isDevMode)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PDF: ${prayerPage.pageNumber} | Index: $index',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
      floatingActionButton: widget.isBirchotHashacharOnly ? null : Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: FloatingActionButton.extended(
          onPressed: _showShortcutsMenu,
          backgroundColor: const Color(0xFFEFE9E1).withValues(alpha: 0.9),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Color(0xFF8C6D58), width: 1.5)),
          label: const Text("יחי אדוננו מורנו ורבינו מלך המשיח לעולם ועד", style: TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'siddur_screen.dart';
import 'tehillim_screen.dart';
import 'pdf_manager.dart';
import 'auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'סידור אונליין',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBF8F3),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFFBF8F3),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF8C6D58)),
              ),
            );
          }
          if (snapshot.hasData) {
            return const SiddurHomePage();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class SiddurHomePage extends StatefulWidget {
  const SiddurHomePage({super.key});

  @override
  State<SiddurHomePage> createState() => _SiddurHomePageState();
}

class _SiddurHomePageState extends State<SiddurHomePage> {
  bool isInIsrael = true;
  DateTime? testDate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isInIsrael = prefs.getBool('isInIsrael') ?? true;
    });
    // בדיקת עדכונים ברשת ברקע
    PdfManager.checkForUpdates();
  }

  Future<T> _runWithDownloadProgressDialog<T>({
    required Future<T> Function(void Function(double progress) onProgress) task,
    required String message,
  }) async {
    double progress = 0.0;
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          dialogSetState = setModalState;
          return PopScope(
            canPop: false,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFFFBF8F3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF8C6D58)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3B32), fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: progress,
                      color: const Color(0xFF8C6D58),
                      backgroundColor: const Color(0xFFE6DFD5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "הורדה: ${(progress * 100).toInt()}%",
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );

    try {
      final result = await task((p) {
        if (dialogSetState != null) {
          dialogSetState!(() {
            progress = p;
          });
        }
      });
      if (mounted) Navigator.pop(context);
      return result;
    } catch (e) {
      if (mounted) Navigator.pop(context);
      rethrow;
    }
  }

  void _showSettingsBottomSheet() {
    bool isAllDownloaded = false;
    bool isDownloading = false;
    double downloadProgress = 0.0;
    String currentDownloadingFile = "";

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFBF8F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            PdfManager.areAllFilesDownloaded().then((val) {
              if (mounted && isAllDownloaded != val && !isDownloading) {
                setModalState(() {
                  isAllDownloaded = val;
                });
              }
            });

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "הגדרות הסידור",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A3B32)),
                      ),
                    ),
                    const Divider(height: 30, color: Color(0xFFE6DFD5)),
                    
                    ListTile(
                      leading: const Icon(Icons.location_on, color: Color(0xFF8C6D58)),
                      title: const Text("מיקום תפילה", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isInIsrael ? "ארץ ישראל" : "חוץ לארץ"),
                      trailing: Switch(
                        value: isInIsrael,
                        activeThumbColor: const Color(0xFF8C6D58),
                        onChanged: (val) async {
                          await _toggleLocation(val);
                          setModalState(() {});
                        },
                      ),
                    ),
                    
                    ListTile(
                      leading: Icon(Icons.bug_report, color: testDate != null ? Colors.red : const Color(0xFF8C6D58)),
                      title: const Text("מצב בדיקה (הדמיית תאריך)", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(testDate != null 
                        ? "תאריך מסומלץ: ${testDate!.day}/${testDate!.month}/${testDate!.year}"
                        : "משתמש בתאריך הנוכחי"),
                      trailing: IconButton(
                        icon: Icon(testDate != null ? Icons.edit_off : Icons.edit, color: const Color(0xFF8C6D58)),
                        onPressed: () {
                          if (testDate != null) {
                            _clearTestDate();
                            setModalState(() {});
                          } else {
                            Navigator.pop(context);
                            _pickTestDate();
                          }
                        },
                      ),
                    ),
                    const Divider(color: Color(0xFFE6DFD5)),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "שימוש ללא חיבור לאינטרנט",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A3B32)),
                      ),
                    ),

                    if (isDownloading) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: downloadProgress,
                              color: const Color(0xFF8C6D58),
                              backgroundColor: const Color(0xFFE6DFD5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "טוען קבצים: ${(downloadProgress * 100).toInt()}% ($currentDownloadingFile)",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    ] else if (isAllDownloaded) ...[
                      ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: const Text("כל התפילות זמינות במכשיר", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        subtitle: const Text("הסידור מוכן לעבודה מלאה ללא אינטרנט"),
                        trailing: TextButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await PdfManager.clearCache();
                            setModalState(() {
                              isAllDownloaded = false;
                            });
                            messenger.showSnackBar(
                              const SnackBar(content: Text("הקבצים השמורים נמחקו")),
                            );
                          },
                          child: const Text("נקה שטח", style: TextStyle(color: Colors.red)),
                        ),
                      )
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.cloud_download, color: Color(0xFF8C6D58)),
                        title: const Text("הורד את כל התפילות מראש", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("מומלץ כדי למנוע זמני טעינה בבית הכנסת"),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8C6D58),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            setModalState(() {
                              isDownloading = true;
                              downloadProgress = 0.0;
                            });

                            int total = PdfManager.pdfFiles.length;
                            for (int i = 0; i < total; i++) {
                              String file = PdfManager.pdfFiles[i];
                              
                              final isDownloaded = await PdfManager.isFileDownloaded(file);
                              if (isDownloaded) {
                                setModalState(() {
                                  downloadProgress = (i + 1) / total;
                                });
                                continue;
                              }

                              setModalState(() {
                                currentDownloadingFile = file;
                              });

                              try {
                                await PdfManager.getPdfPath(
                                  file,
                                  onProgress: (fileProgress) {
                                    setModalState(() {
                                      downloadProgress = (i + fileProgress) / total;
                                    });
                                  },
                                );
                              } catch (e) {
                                debugPrint("Error pre-downloading $file: $e");
                              }
                            }

                            setModalState(() {
                              isDownloading = false;
                              isAllDownloaded = true;
                            });
                          },
                          child: const Text("הורדה"),
                        ),
                      )
                    ],
                    const Divider(color: Color(0xFFE6DFD5)),
                    ListTile(
                      leading: const Icon(Icons.exit_to_app, color: Colors.red),
                      title: const Text("התנתק מהחשבון", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? ""),
                      onTap: () async {
                        Navigator.pop(context);
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isInIsrael', value);
    setState(() {
      isInIsrael = value;
    });
  }

  void _pickTestDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: testDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'בחר תאריך לבדיקת הסידור',
    );
    if (picked != null) {
      setState(() {
        testDate = picked;
      });
    }
  }

  void _clearTestDate() {
    setState(() {
      testDate = null;
    });
  }

  final List<Map<String, String>> sections = const [
    {"title": "ברכות השחר", "file": "02_shacharit_chol.pdf", "subtitle": "הלכות ציצית ותפילת הבוקר"},
    {"title": "שחרית לחול", "file": "02_shacharit_chol.pdf", "subtitle": "תפילת השחר המלאה"},
    {"title": "מנחה לחול", "file": "03_mincha_chol.pdf", "subtitle": "אשרי, עמידה ועלינו לשבח"},
    {"title": "ערבית לחול", "file": "04_arvit_chol.pdf", "subtitle": "והוא רחום, שמע ועמידה"},
    {"title": "קריאת שמע על המיטה", "file": "05_kriat_shema_mita.pdf", "subtitle": "סדר המפיל ופסוקי השמירה"},
    {"title": "תהילים יומי", "file": "tehillim.pdf", "subtitle": "פרקי התהילים המחולקים לימי החודש"},
    {"title": "ברכת המזון", "file": "birkat_amazon.pdf", "subtitle": "מעין שלוש"},
  ];

  Future<String> preparePdf(String assetName) async {
    return await PdfManager.getPdfPath(assetName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("סידור תהלת ה'", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3B32), fontSize: 24)),
        centerTitle: true,
        backgroundColor: const Color(0xFFEFE9E1),
        elevation: 2,
        leading: testDate != null 
          ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: _clearTestDate, tooltip: 'בטל מצב בדיקה')
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF4A3B32)),
            onPressed: _showSettingsBottomSheet,
            tooltip: 'הגדרות',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListView.builder(
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final item = sections[index];
              return Card(
                color: Colors.white,
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE6DFD5), width: 1)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF5EFEB), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.menu_book, color: Color(0xFF8C6D58))),
                  title: Text(item["title"]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E2520))),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(item["subtitle"]!, style: const TextStyle(fontSize: 14, color: Colors.grey))),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF8C6D58)),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    FirebaseAnalytics.instance.logEvent(
                      name: 'open_section',
                      parameters: {
                        'title': item["title"]!,
                        'file': item["file"] ?? '',
                      },
                    ).catchError((e) => debugPrint("Analytics error: $e"));

                    if (item["title"] == "שחרית לחול") {
                      navigator.push(MaterialPageRoute(builder: (c) => SiddurScreen(isInIsrael: isInIsrael, simulatedDate: testDate)));
                      return;
                    }
                    if (item["title"] == "תהילים יומי") {
                      navigator.push(MaterialPageRoute(builder: (c) => TehillimScreen(simulatedDate: testDate)));
                      return;
                    }
                    if (item["title"] == "ברכות השחר") {
                       navigator.push(MaterialPageRoute(builder: (c) => const SiddurScreen(isBirchotHashacharOnly: true)));
                       return;
                    }

                    final isDownloaded = await PdfManager.isFileDownloaded(item["file"]!);
                    if (isDownloaded) {
                      try {
                        final localPath = await PdfManager.getPdfPath(item["file"]!);
                        navigator.push(MaterialPageRoute(builder: (context) => PdfViewerScreen(title: item["title"]!, filePath: localPath)));
                      } catch (e) {
                        messenger.showSnackBar(const SnackBar(content: Text("שגיאה בפתיחת הקובץ")));
                      }
                    } else {
                      try {
                        final localPath = await _runWithDownloadProgressDialog(
                          task: (onProgress) => PdfManager.getPdfPath(item["file"]!, onProgress: onProgress),
                          message: "טוען תפילה...",
                        );
                        navigator.push(MaterialPageRoute(builder: (context) => PdfViewerScreen(title: item["title"]!, filePath: localPath)));
                      } catch (e) {
                        messenger.showSnackBar(const SnackBar(content: Text("שגיאה בהורדת הקובץ, אנא בדוק חיבור לאינטרנט")));
                      }
                    }
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: const Color(0xFFEFE9E1),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Color(0xFF8C6D58), width: 1.5)),
          label: const Text("יחי אדוננו מורנו ורבינו מלך המשיח לעולם ועד", style: TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String filePath;
  const PdfViewerScreen({super.key, required this.title, required this.filePath});
  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFEFE9E1),
        iconTheme: const IconThemeData(color: Color(0xFF4A3B32)),
      ),
      body: PDFView(
        filePath: widget.filePath,
        autoSpacing: true,
        pageSnap: true,
        pageFling: true,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isLocked = false;
  String _lockMessage = '';
  String _lockStoreUrl = '';

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

    try {
      final manifest = await PdfManager.fetchManifest();
      if (manifest != null) {
        final isDisabled = PdfManager.isAppDisabled();
        final minVersion = PdfManager.getMinVersion();
        if (isDisabled || PdfManager.currentAppVersion < minVersion) {
          setState(() {
            _isLocked = true;
            _lockMessage = PdfManager.getDisableMessage();
            _lockStoreUrl = PdfManager.getStoreUrl();
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking remote config: $e");
    }

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
                    const SizedBox(height: 6),
                    const Text(
                      "טעינה ראשונית בלבד - בפעמים הבאות ייפתח מיד",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
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
    if (_isLocked) {
      return LockoutScreen(message: _lockMessage, storeUrl: _lockStoreUrl);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("סידור תהלת ה' 🌟", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3B32), fontSize: 24)),
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
  int _currentPage = 1;
  late PdfController _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _reportChapter() {
    final pdfPageNumber = _currentPage;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFFFBF8F3),
            title: const Text('דיווח על פרק תהילים', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3B32))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'איזה פרק תהילים מופיע בעמוד זה?\n(עמוד $pdfPageNumber בספר)',
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'מספר הפרק (1 עד 150)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8C6D58)),
                onPressed: () async {
                  final text = controller.text.trim();
                  final chapter = int.tryParse(text);
                  if (chapter == null || chapter < 1 || chapter > 150) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('נא להזין מספר פרק תקין בין 1 ל-150')),
                    );
                    return;
                  }

                  Navigator.pop(context);
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
                },
                child: const Text('שלח', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showReportButton = widget.title.contains('תהילים') || widget.filePath.endsWith('tehillim.pdf');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFEFE9E1),
        iconTheme: const IconThemeData(color: Color(0xFF4A3B32)),
        actions: showReportButton
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Color(0xFF8C6D58)),
                  onPressed: _reportChapter,
                  tooltip: 'דווח על פרק',
                ),
              ]
            : null,
      ),
      body: PdfView(
        controller: _pdfController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
      ),
    );
  }
}

class LockoutScreen extends StatelessWidget {
  final String message;
  final String storeUrl;

  const LockoutScreen({
    super.key,
    required this.message,
    required this.storeUrl,
  });

  Future<void> _launchStore() async {
    if (storeUrl.isNotEmpty) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F3),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "הודעת מערכת",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A3B32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (storeUrl.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8C6D58),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _launchStore,
                      child: const Text(
                        "הורד את הגרסה הרשמית",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

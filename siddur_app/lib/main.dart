import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'siddur_screen.dart';
import 'tehillim_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'סידור הכשר',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBF8F3),
      ),
      home: const SiddurHomePage(),
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
  }

  Future<void> _toggleLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isInIsrael', value);
    setState(() {
      isInIsrael = value;
    });
  }

  final List<Map<String, String>> sections = const [
    {"title": "ברכות השחר", "file": "01_birchot_hashachar.pdf", "subtitle": "הלכות ציצית ותפילת הבוקר"},
    {"title": "שחרית לחול", "file": "02_shacharit_chol.pdf", "subtitle": "תפילת השחר המלאה"},
    {"title": "מנחה לחול", "file": "03_mincha_chol.pdf", "subtitle": "אשרי, עמידה ועלינו לשבח"},
    {"title": "ערבית לחול", "file": "04_arvit_chol.pdf", "subtitle": "והוא רחום, שמע ועמידה"},
    {"title": "קריאת שמע על המיטה", "file": "05_kriat_shema_mita.pdf", "subtitle": "סדר המפיל ופסוקי השמירה"},
    {"title": "תהילים יומי", "file": "tehillim.pdf", "subtitle": "פרקי התהילים המחולקים לימי החודש"},
    {"title": "ברכת המזון", "file": "birkat_amazon.pdf", "subtitle": "מעין שלוש"},
  ];

  Future<String> preparePdf(String assetName) async {
    final assetPath = "assets/pdfs/$assetName";
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$assetName");
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("סידור תהלת ה'", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3B32), fontSize: 24)),
        centerTitle: true,
        backgroundColor: const Color(0xFFEFE9E1),
        elevation: 2,
        actions: [
          Row(
            children: [
              Text(isInIsrael ? "ישראל" : "חו\"ל", style: const TextStyle(color: Color(0xFF4A3B32), fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(value: isInIsrael, onChanged: _toggleLocation, activeColor: const Color(0xFF8C6D58)),
            ],
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
                    if (item["title"] == "שחרית לחול") {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => SiddurScreen(isInIsrael: isInIsrael)));
                      return;
                    }
                    if (item["title"] == "תהילים יומי") {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const TehillimScreen()));
                      return;
                    }
                    try {
                      final localPath = await preparePdf(item["file"]!);
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(title: item["title"]!, filePath: localPath)));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("שגיאה בטעינת הקובץ")));
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

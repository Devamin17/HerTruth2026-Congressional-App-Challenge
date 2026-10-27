import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// HerTruth for Android. The app shows the same HerTruth page as the website and the iPhone app,
/// bundled inside the app, so the check, the scoring and the iron model are identical everywhere.
/// Check answers and photos never leave the phone. Only Find help talks to OpenStreetMap.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: paper,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: paper,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const HerTruthApp());
}

/// The page background (#FFFBFC), so the app looks like one surface.
const paper = Color(0xFFFFFBFC);

class HerTruthApp extends StatelessWidget {
  const HerTruthApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'HerTruth',
        debugShowCheckedModeBanner: false,
        home: HerTruthPage(),
      );
}

class HerTruthPage extends StatefulWidget {
  const HerTruthPage({super.key});

  @override
  State<HerTruthPage> createState() => _HerTruthPageState();
}

class _HerTruthPageState extends State<HerTruthPage> {
  late final WebViewController _web;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(paper)
      // OpenStreetMap's tile policy asks apps to identify themselves
      ..setUserAgent('Mozilla/5.0 (Linux; Android) HerTruth/1.0 (org.thefactorfoundation.hertruth)')
      // The page's Print button: print or save the summary as a PDF with Android's print sheet
      ..addJavaScriptChannel('HerTruthPrint', onMessageReceived: (m) => _print(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _web.runJavaScript(
            'window.print = function () { HerTruthPrint.postMessage(document.documentElement.outerHTML); };'),
        onNavigationRequest: _openOutside,
      ))
      ..loadFlutterAsset('assets/hertruth.html');

    final android = _web.platform;
    if (android is AndroidWebViewController) {
      // "Use my location" on Find help: ask Android for location, then let the page have it
      android.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final status = await Permission.locationWhenInUse.request();
          return GeolocationPermissionsResponse(allow: status.isGranted, retain: false);
        },
      );
      // "Take or add a photo" and "Photo of the lab report": camera or gallery, kept on the phone
      android.setOnShowFileSelector(_pickPhoto);
    }
  }

  /// Keep the app on its own page; web, email and phone links open in the browser, mail or phone app.
  Future<NavigationDecision> _openOutside(NavigationRequest request) async {
    final uri = Uri.parse(request.url);
    if (['http', 'https', 'mailto', 'tel'].contains(uri.scheme)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<List<String>> _pickPhoto(FileSelectorParams params) async {
    final source = params.isCaptureEnabled ? ImageSource.camera : ImageSource.gallery;
    final photo = await _picker.pickImage(source: source, imageQuality: 85);
    return photo == null ? [] : [Uri.file(photo.path).toString()];
  }

  Future<void> _print(String html) => Printing.layoutPdf(
        name: 'HerTruth summary',
        onLayout: (format) => Printing.convertHtml(format: format, html: html),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: paper,
        // Android does not pass safe-area insets to web pages, so keep the page clear of the system bars
        body: SafeArea(child: WebViewWidget(controller: _web)),
      );
}

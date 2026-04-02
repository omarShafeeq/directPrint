import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';

import 'download_stub.dart' if (dart.library.html) 'download_web.dart' as download;
import 'pc_download_stub.dart' if (dart.library.io) 'pc_download_io.dart' as pc_download;
import 'web_print_stub.dart' if (dart.library.html) 'web_print_web.dart' as web_print;
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Uint8List? _pdfData;

  @override
  void initState() {
    super.initState();
    _preloadPdf();
  }

  Future<void> _preloadPdf() async {
    final bytes = await rootBundle.load('assets/tasks.pdf');
    _pdfData = bytes.buffer.asUint8List();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<Uint8List> _loadPdf() async {
    if (_pdfData != null) return _pdfData!;
    final bytes = await rootBundle.load('assets/tasks.pdf');
    return bytes.buffer.asUint8List();
  }

  Future<void> _printPdf() async {
    try {
      final data = await _loadPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => data,
        name: 'مهام عمر.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  /// Prints the bundled asset directly without the OS print dialog.
  Future<void> _silentPrintPdf() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sending to printer…')),
        );
      }

      final data = await _loadPdf();
      bool ok;

      if (kIsWeb) {
        ok = await web_print.silentPrintPdf(data);
      } else {
        final printers = await Printing.listPrinters();
        if (printers.isEmpty) {
          throw Exception('No printers found on this device');
        }
        final printer = printers.firstWhere(
          (p) => p.isDefault,
          orElse: () => printers.first,
        );
        ok = await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => data,
          name: 'مهام عمر.pdf',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Sent to printer.' : 'Printing failed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  /// Prints a PDF from a remote URL directly.
  /// On web: loads the URL in a hidden iframe and calls print() — no download needed.
  /// On desktop: downloads the bytes first, then sends to the default printer.
  Future<void> _silentPrintFromUrl(String pdfUrl) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sending to printer…')),
        );
      }

      bool ok;

      if (kIsWeb) {
        ok = await web_print.silentPrintPdfFromUrl(pdfUrl);
      } else {
        final response = await http.get(Uri.parse(pdfUrl));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Server returned ${response.statusCode}');
        }
        final data = response.bodyBytes;

        final printers = await Printing.listPrinters();
        if (printers.isEmpty) {
          throw Exception('No printers found on this device');
        }
        final printer = printers.firstWhere(
          (p) => p.isDefault,
          orElse: () => printers.first,
        );
        ok = await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => data,
          name: 'report.pdf',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Sent to printer.' : 'Printing failed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  Future<void> _savePdfFromService() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading PDF from server...')),
        );
      }

      final response = await http.get(
        Uri.parse('https://your-api.com/api/report/123'),
        headers: {
          'Authorization': 'Bearer YOUR_TOKEN_HERE',
          'Accept': 'application/pdf',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final data = response.bodyBytes;

      final disposition = response.headers['content-disposition'] ?? '';
      final serverFilename = _parseFilename(disposition) ?? 'report.pdf';

      if (kIsWeb) {
        await download.saveFileWithDialog(data, serverFilename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File downloaded — check your browser\'s Downloads.')),
          );
        }
        return;
      }

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: serverFilename,
        bytes: data,
        type: FileType.any,
      );

      if (path != null && path.isNotEmpty) {
        await OpenFilex.open(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  static String? _parseFilename(String header) {
    if (header.isEmpty) return null;
    final match = RegExp(r'filename[*]?="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
  }

  /// Download the bundled PDF to the user's machine.
  /// Web: opens a Save As dialog so the user picks location & name, then saves on click.
  /// Desktop: saves to the system Downloads folder, then opens the file.
  Future<void> _savePdf() async {
    try {
      // Use pre-loaded data so there is no async gap before showSaveFilePicker.
      // Chrome requires the call to happen synchronously within the user gesture.
      final data = _pdfData ?? (await rootBundle.load('assets/tasks.pdf')).buffer.asUint8List();

      if (kIsWeb) {
        final saved = await download.saveFileWithDialog(data, 'مهام عمر.pdf');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(saved ? 'File saved successfully.' : 'Save cancelled.'),
            ),
          );
        }
        return;
      }

      final path = await pc_download.saveBytesToDownloads(data, 'مهام عمر.pdf');
      if (!mounted) return;

      if (path != null && path.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to your PC:\n$path'),
            duration: const Duration(seconds: 6),
          ),
        );
        final result = await OpenFilex.open(path);
        if (!mounted) return;
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved. ${result.message}')),
          );
        }
        return;
      }

      final String? pickPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF to your PC',
        fileName: 'مهام عمر.pdf',
        bytes: data,
        type: FileType.any,
      );

      if (!mounted) return;
      if (pickPath != null && pickPath.isNotEmpty) {
        final result = await OpenFilex.open(pickPath);
        if (!mounted) return;
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved. ${result.message}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to your PC: $pickPath')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveAndOpenFile() async {
    final String content = '''
Report - ${DateTime.now()}
--------------------
Counter value: $_counter
Saved from Direct Report app.
''';
    final bytes = utf8.encode(content);

    try {
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save report',
        fileName: 'report_${DateTime.now().millisecondsSinceEpoch}.txt',
        bytes: bytes,
        type: FileType.any,
      );

      if (path != null && path.isNotEmpty) {
        final result = await OpenFilex.open(path);
        if (!mounted) return;
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved. Open result: ${result.message}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Save cancelled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            Tooltip(
              message: kIsWeb
                  ? 'Downloads the PDF file via the browser'
                  : 'Downloads the PDF to your Downloads folder',
              child: FilledButton.icon(
                onPressed: _savePdf,
                icon: const Icon(Icons.download),
                label: const Text('Download PDF (مهام عمر)'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _savePdfFromService,
              icon: const Icon(Icons.cloud_download),
              label: const Text('Save PDF from Service'),
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: 'Opens the print dialog with a PDF preview',
              child: FilledButton.tonalIcon(
                onPressed: _printPdf,
                icon: const Icon(Icons.print),
                label: const Text('Print PDF (with dialog)'),
              ),
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: kIsWeb
                  ? 'Silent on web only with Chrome --kiosk-printing flag'
                  : 'Sends directly to the default printer — no dialog',
              child: FilledButton.icon(
                onPressed: _silentPrintPdf,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Silent Print (no dialog)'),
              ),
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: kIsWeb
                  ? 'Loads PDF URL in iframe and prints (silent with --kiosk-printing)'
                  : 'Downloads from URL then sends to default printer',
              child: FilledButton.icon(
                onPressed: () => _silentPrintFromUrl(
                  'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
                ),
                icon: const Icon(Icons.link),
                label: const Text('Print from URL'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saveAndOpenFile,
              icon: const Icon(Icons.save),
              label: const Text('Save & Open report'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Opens the browser's native Save As dialog so the user picks location & name,
/// then saves the file when they click Save.
///
/// Uses an injected `<script>` to call `showSaveFilePicker` directly in the
/// page context, which preserves the user-gesture chain that Chrome requires.
/// Falls back to a normal `<a download>` click on browsers without the API.
Future<bool> saveFileWithDialog(List<int> bytes, String suggestedName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final urlJs = jsonEncode(url);
  final nameJs = jsonEncode(suggestedName);

  final completer = Completer<bool>();

  // Listen for the result posted by the injected script.
  late final html.EventListener listener;
  listener = (html.Event event) {
    final msg = (event as html.MessageEvent).data;
    if (msg == 'saveFileDone' || msg == 'saveFileFallback') {
      html.window.removeEventListener('message', listener);
      completer.complete(true);
    } else if (msg == 'saveFileCancelled') {
      html.window.removeEventListener('message', listener);
      completer.complete(false);
    }
  };
  html.window.addEventListener('message', listener);

  final scriptContent = '''
(function(){
  var url = $urlJs;
  var name = $nameJs;

  if (typeof window.showSaveFilePicker !== 'function') {
    var a = document.createElement('a');
    a.href = url;
    a.download = name;
    a.click();
    window.postMessage('saveFileFallback', '*');
    return;
  }

  window.showSaveFilePicker({
    suggestedName: name,
    types: [{ description: 'PDF Document', accept: { 'application/pdf': ['.pdf'] } }]
  })
  .then(function(handle){ return handle.createWritable(); })
  .then(function(writable){
    return fetch(url)
      .then(function(r){ return r.blob(); })
      .then(function(blob){
        return writable.write(blob).then(function(){ return writable.close(); });
      });
  })
  .then(function(){ window.postMessage('saveFileDone', '*'); })
  .catch(function(){ window.postMessage('saveFileCancelled', '*'); });
})();
''';

  final script = html.ScriptElement()
    ..type = 'text/javascript'
    ..text = scriptContent;
  html.document.body?.append(script);
  script.remove();

  // Clean up the blob URL after a delay.
  Future.delayed(const Duration(seconds: 60), () {
    html.Url.revokeObjectUrl(url);
  });

  return completer.future;
}

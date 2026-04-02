import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Sends [pdfBytes] to the printer via a hidden iframe.
///
/// With Chrome's `--kiosk-printing` flag this prints silently to the
/// default printer (no dialog). Without the flag the browser still
/// shows its native print dialog.
Future<bool> silentPrintPdf(Uint8List pdfBytes) async {
  final completer = Completer<bool>();

  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  const frameId = '__silent_print_frame__';
  const scriptId = '__silent_print_script__';

  html.document.getElementById(frameId)?.remove();
  html.document.getElementById(scriptId)?.remove();

  final frame = html.IFrameElement()
    ..id = frameId
    ..style.position = 'fixed'
    ..style.left = '-9999px'
    ..style.top = '-9999px'
    ..style.width = '1px'
    ..style.height = '1px'
    ..style.opacity = '0'
    ..style.border = 'none'
    ..src = url;

  late final html.EventListener messageListener;
  messageListener = (html.Event event) {
    final data = (event as html.MessageEvent).data;
    if (data == '__silent_print_done__') {
      html.window.removeEventListener('message', messageListener);
      Future.delayed(const Duration(milliseconds: 500), () {
        html.document.getElementById(frameId)?.remove();
        html.document.getElementById(scriptId)?.remove();
        html.Url.revokeObjectUrl(url);
      });
      if (!completer.isCompleted) completer.complete(true);
    }
  };
  html.window.addEventListener('message', messageListener);

  html.document.body?.append(frame);

  frame.onLoad.listen((_) {
    final script = html.ScriptElement()
      ..id = scriptId
      ..type = 'text/javascript'
      ..text = '''
(function() {
  var f = document.getElementById('$frameId');
  if (!f || !f.contentWindow) {
    window.postMessage('__silent_print_done__', '*');
    return;
  }
  f.contentWindow.addEventListener('afterprint', function() {
    window.postMessage('__silent_print_done__', '*');
  });
  try {
    f.contentWindow.focus();
    f.contentWindow.print();
  } catch(e) {
    window.postMessage('__silent_print_done__', '*');
  }
})();
''';
    html.document.body?.append(script);
  });

  Future.delayed(const Duration(seconds: 30), () {
    html.window.removeEventListener('message', messageListener);
    html.document.getElementById(frameId)?.remove();
    html.document.getElementById(scriptId)?.remove();
    html.Url.revokeObjectUrl(url);
    if (!completer.isCompleted) completer.complete(false);
  });

  return completer.future;
}

/// Downloads a PDF from [url] via JS fetch(), converts it to a same-origin
/// blob URL, loads that in a hidden iframe, and prints.
///
/// This avoids cross-origin iframe errors because the blob URL is always
/// same-origin. The remote server must allow CORS for the fetch to succeed.
/// With `--kiosk-printing` this prints silently; otherwise the browser
/// shows its native print dialog.
Future<bool> silentPrintPdfFromUrl(String url) async {
  final completer = Completer<bool>();

  const frameId = '__silent_print_url_frame__';
  const scriptId = '__silent_print_url_script__';

  html.document.getElementById(frameId)?.remove();
  html.document.getElementById(scriptId)?.remove();

  late final html.EventListener messageListener;
  messageListener = (html.Event event) {
    final data = (event as html.MessageEvent).data;
    if (data == '__silent_print_url_done__') {
      html.window.removeEventListener('message', messageListener);
      Future.delayed(const Duration(milliseconds: 500), () {
        html.document.getElementById(frameId)?.remove();
        html.document.getElementById(scriptId)?.remove();
      });
      if (!completer.isCompleted) completer.complete(true);
    } else if (data == '__silent_print_url_error__') {
      html.window.removeEventListener('message', messageListener);
      html.document.getElementById(scriptId)?.remove();
      if (!completer.isCompleted) completer.complete(false);
    }
  };
  html.window.addEventListener('message', messageListener);

  final script = html.ScriptElement()
    ..id = scriptId
    ..type = 'text/javascript'
    ..text = '''
(function() {
  var pdfUrl = ${Uri.encodeComponent(url) != url ? "'${url.replaceAll("'", "\\'")}'" : "'$url'"};

  fetch(pdfUrl)
    .then(function(resp) {
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      return resp.blob();
    })
    .then(function(blob) {
      var blobUrl = URL.createObjectURL(blob);

      var oldFrame = document.getElementById('$frameId');
      if (oldFrame) oldFrame.remove();

      var f = document.createElement('iframe');
      f.id = '$frameId';
      f.style.cssText = 'position:fixed;left:-9999px;top:-9999px;width:1px;height:1px;opacity:0;border:none;';
      f.src = blobUrl;

      f.addEventListener('load', function() {
        try {
          f.contentWindow.addEventListener('afterprint', function() {
            window.postMessage('__silent_print_url_done__', '*');
            URL.revokeObjectURL(blobUrl);
          });
          f.contentWindow.focus();
          f.contentWindow.print();
        } catch(e) {
          window.postMessage('__silent_print_url_done__', '*');
          URL.revokeObjectURL(blobUrl);
        }
      });

      document.body.appendChild(f);
    })
    .catch(function(e) {
      console.error('silentPrintPdfFromUrl failed:', e);
      window.postMessage('__silent_print_url_error__', '*');
    });
})();
''';
  html.document.body?.append(script);

  Future.delayed(const Duration(seconds: 30), () {
    html.window.removeEventListener('message', messageListener);
    html.document.getElementById(frameId)?.remove();
    html.document.getElementById(scriptId)?.remove();
    if (!completer.isCompleted) completer.complete(false);
  });

  return completer.future;
}

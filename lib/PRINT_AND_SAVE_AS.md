# How the Print Button Shows the Save As Dialog (Flutter Web)

## Where the logic lives

The **`printing`** package (in your pub cache) implements the web flow:

- **Package path:** `.../Pub/Cache/hosted/pub.dev/printing-5.14.2/lib/printing_web.dart`
- **Relevant method:** `layoutPdf()` (around lines 153–276)

## What the package does (step by step)

1. **Build PDF bytes**  
   Your app provides PDF bytes via the `onLayout` callback (e.g. from `assets/tasks.pdf`).

2. **Create a Blob and object URL**  
   ```dart
   final pdfFile = web.Blob([result.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
   final pdfUrl = web.URL.createObjectURL(pdfFile);
   ```

3. **Create a hidden iframe**  
   An `<iframe>` is added to the page with `src = pdfUrl`, so the browser loads the PDF inside the iframe.

4. **Inject a small script**  
   A global function is added that:
   - Finds that iframe
   - Focuses it
   - Calls **`iframe.contentWindow.print()`**

5. **When the iframe has loaded**  
   The plugin calls that function, so **`contentWindow.print()`** runs. That opens the **browser’s native Print dialog** (Chrome/Edge/Firefox, etc.).

6. **User chooses “Save as PDF”**  
   In the Print dialog the user picks the destination **“Save as PDF”** (or similar) and confirms. The **browser** then shows the **Save As** dialog (location + file name). The `printing` package does **not** show the Save As dialog itself; the browser does when the user chooses to save as PDF.

So:

- **Print dialog** → triggered by the package (via `contentWindow.print()`).
- **Save As dialog** → triggered by the **browser** when the user selects “Save as PDF” in the Print dialog.

There is no separate “Save As” button inside the package; the only way to get the Save As dialog on web is through this Print → Save as PDF flow (or through the File System Access API `showSaveFilePicker`, which is a different path).

## Technology used in the package

- **`package:web`** – DOM (Window, Document, Blob, URL, iframe, etc.)
- **`dart:js_interop`** and **`dart:js_interop_unsafe`** – to call JS (e.g. `eval`, `callMethod`) and pass data (e.g. `toJS`, `toDart`).

So the “print button” that leads to the Save As dialog is implemented in Flutter/Dart by:

1. Using the **printing** package’s **web** implementation (`printing_web.dart`).
2. Calling **`Printing.layoutPdf(onLayout: ...)`** from your app.
3. Letting the package create the iframe and call **`contentWindow.print()`**, which opens the system Print dialog; the user then chooses “Save as PDF” and the browser shows the Save As dialog.

## Direct Save As in this project (no Print dialog)

This project also implements a **direct** Save As dialog on web (same idea as the printing package: inject a script that calls a browser API):

- **File:** `lib/download_web.dart`
- **Flow:** Create a blob URL from the PDF bytes → inject a script that runs `fetch(url)`, then `window.showSaveFilePicker({ suggestedName, types })` (File System Access API) → user picks location and name → script writes the blob to the chosen file. If `showSaveFilePicker` is not available (e.g. Firefox), the script falls back to an `<a download>` click.
- **Technology:** `dart:html` (Blob, Url, ScriptElement) + `dart:convert` (jsonEncode for safe embedding). No `dart:js_interop` in app code; the script is plain JavaScript injected like the printing package’s `_frameId_print` function.

So **“Save PDF (مهام عمر)”** on web now opens the **Save As** dialog directly in Chrome/Edge (location + file name). No need to go through the Print dialog for that flow.

## In this project

- **“Save PDF (مهام عمر)”** → on web: direct Save As dialog (Chrome/Edge) via `showSaveFilePicker`; on desktop: native save dialog.
- **“Print / Save as PDF”** → Print dialog → user picks “Save as PDF” → browser shows Save As dialog (alternative path).

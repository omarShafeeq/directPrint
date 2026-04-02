// Stub for non-web platforms (save dialog is handled by FilePicker there)
Future<bool> saveFileWithDialog(List<int> bytes, String suggestedName) async {
  throw UnsupportedError('saveFileWithDialog is only used on Flutter web.');
}

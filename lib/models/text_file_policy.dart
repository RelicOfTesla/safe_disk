const Set<String> kKnownTextFileExtensions = {
  'txt',
  'md',
  'json',
  'xml',
  'yaml',
  'yml',
  'csv',
  'bat',
  'cmd',
  'ps1',
  'sh',
  'dart',
  'go',
  'c',
  'h',
  'cc',
  'cpp',
  'rs',
  'py',
  'js',
  'ts',
  'java',
  'kt',
  'swift',
};

String? textFileExtension(String filename) {
  final index = filename.lastIndexOf('.');
  if (index <= 0 || index == filename.length - 1) return null;
  return filename.substring(index + 1).toLowerCase();
}

bool isKnownTextFilename(String filename) {
  final extension = textFileExtension(filename);
  return extension != null && kKnownTextFileExtensions.contains(extension);
}

bool shouldOpenFallbackTextReadOnly(String filename) {
  return !isKnownTextFilename(filename);
}

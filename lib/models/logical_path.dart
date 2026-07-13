String normalizeLogicalPath(String path) {
  var normalized = path.replaceAll('\\', '/');
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String logicalPathBasename(String path) {
  final normalized = normalizeLogicalPath(path);
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

String? logicalParentPath(String path) {
  final normalized = normalizeLogicalPath(path);
  final index = normalized.lastIndexOf('/');
  if (index < 0) return null;
  if (index == 0) return '/';
  // Keep the slash in a Windows drive root, for example C:/vault -> C:/.
  if (index == 2 && normalized.length >= 2 && normalized[1] == ':') {
    return normalized.substring(0, 3);
  }
  return normalized.substring(0, index);
}

bool isSameOrDescendantLogicalPath(String candidate, String parent) {
  final normalizedCandidate = normalizeLogicalPath(candidate);
  final normalizedParent = normalizeLogicalPath(parent);
  return normalizedCandidate == normalizedParent ||
      normalizedCandidate.startsWith('$normalizedParent/');
}

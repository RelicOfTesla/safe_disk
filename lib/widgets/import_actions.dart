import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class ImportActions extends StatelessWidget {
  const ImportActions({
    super.key,
    required this.onImportFile,
    required this.onImportDirectory,
  });

  final VoidCallback onImportFile;
  final VoidCallback onImportDirectory;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.upload_file),
          onPressed: onImportFile,
          tooltip: strings.importFile,
        ),
        IconButton(
          icon: const Icon(Icons.drive_folder_upload),
          onPressed: onImportDirectory,
          tooltip: strings.importDirectory,
        ),
      ],
    );
  }
}

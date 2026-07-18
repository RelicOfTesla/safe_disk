import 'package:flutter/material.dart';

import '../native/bindings.dart';
import '../utils/error_diagnostics.dart';

class NativeLibraryLoadingPage extends StatelessWidget {
  const NativeLibraryLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class NativeLibraryStartupErrorPage extends StatelessWidget {
  const NativeLibraryStartupErrorPage({
    required this.error,
    required this.onRetry,
    required this.showDiagnostics,
    super.key,
  });

  final NativeLibraryException error;
  final VoidCallback onRetry;
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    final isBindingFailure = error.stage == NativeLibraryFailureStage.bind;
    final detail = isBindingFailure
        ? '安全组件版本与应用不匹配，无法启动加密功能。'
        : '无法加载 Safe Disk 安全组件，无法安全访问加密目录。';
    final suggestion = isBindingFailure
        ? '请重新安装同一版本的 Safe Disk 应用后重试。'
        : '请重新安装应用；若问题持续，请检查安全软件是否隔离了应用文件。';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_outlined, size: 44),
                const SizedBox(height: 20),
                Text(
                  '安全组件不可用',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(detail, key: const Key('native-library-error-message')),
                const SizedBox(height: 8),
                Text('建议：$suggestion'),
                if (showDiagnostics) ...[
                  const SizedBox(height: 20),
                  SelectableText(
                    '初始化阶段：${error.operation}\n'
                    '底层错误：${ErrorDiagnostics.sanitize(error.cause.toString())}',
                    key: const Key('native-library-error-diagnostics'),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('native-library-retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

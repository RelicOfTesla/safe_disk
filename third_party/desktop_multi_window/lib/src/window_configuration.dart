class WindowConfiguration {
  const WindowConfiguration({
    required this.arguments,
    this.hiddenAtLaunch = true,
    this.title = '',
    this.width = 1280,
    this.height = 720,
  });

  /// The arguments passed to the new window.
  final String arguments;

  final bool hiddenAtLaunch;
  final String title;
  final int width;
  final int height;

  factory WindowConfiguration.fromJson(Map<String, dynamic> json) {
    return WindowConfiguration(
      arguments: json['arguments'] as String? ?? '',
      hiddenAtLaunch: json['hiddenAtLaunch'] as bool? ?? false,
      title: json['title'] as String? ?? '',
      width: json['width'] as int? ?? 1280,
      height: json['height'] as int? ?? 720,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'arguments': arguments,
      'hiddenAtLaunch': hiddenAtLaunch,
      'title': title,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() {
    return 'WindowConfiguration(arguments: $arguments, hiddenAtLaunch: $hiddenAtLaunch, title: $title, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WindowConfiguration &&
        other.arguments == arguments &&
        other.hiddenAtLaunch == hiddenAtLaunch &&
        other.title == title &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode {
    return Object.hash(arguments, hiddenAtLaunch, title, width, height);
  }
}

# Safe Disk 本地补丁

来源：`desktop_multi_window 0.3.0`。

Safe Disk 暂时 vendor 该依赖，因为其 Linux `destroy` 回调会显式执行
`gtk_container_remove(window, fl_view)`。在当前 Flutter Linux embedder 中，每个
子 engine 的 `FlView` 是 implicit view；显式移除会触发
`FlutterEngineRemoveView(kInvalidArguments)`，随后可能在 X11/GLX 清理阶段崩溃。

Flutter 3.44.6 的 `fl_view_dispose()` 对所有 view 无条件调用 `RemoveView`，但
`fl_view_new()` 创建的是 engine implicit view，embedder 明确拒绝移除它。因此只
删除显式 `gtk_container_remove` 仍不足以修复。

本地差异：

- Linux 窗口开始销毁时先对该子 engine 执行 GObject dispose，使 Dart、GPU、
  messenger 等资源按 engine 顺序关闭；
- 保留已销毁 implicit `FlView` wrapper 的最终引用到进程退出，避免其错误调用
  `RemoveView`；engine 关闭后将 wrapper 从 GTK 容器摘除，额外引用保证 unparent
  不触发 dispose；该 wrapper 对应的 engine 内部资源已经释放；
- 移除每次正常关闭都会输出的 `RemoveWindow` warning；
- 子引擎不再注册 `window_manager`，避免 engine 销毁后遗留的 GTK signal 回调；
- 窗口配置支持原生标题和初始尺寸，并在 Flutter 首帧后才显示；
- `WindowController.close()` 先回复 method call，再在 GTK idle 阶段销毁窗口。

移除 vendor 前必须验证上游 Linux 实现已不再显式移除 implicit view，并完成
Safe Disk 的原生内容窗口反复创建/关闭测试。

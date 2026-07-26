import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePageShortcutActions {
  const HomePageShortcutActions({
    required this.refresh,
    required this.focusFilter,
    required this.paste,
    required this.copy,
    required this.cut,
    required this.selectAll,
    required this.cancelSelection,
    required this.rename,
    required this.showContextMenu,
    required this.moveUp,
    required this.moveDown,
    required this.moveLeft,
    required this.moveRight,
    required this.extendUp,
    required this.extendDown,
    required this.extendLeft,
    required this.extendRight,
    required this.goHome,
    required this.goEnd,
    required this.extendHome,
    required this.extendEnd,
    required this.toggleSelection,
  });

  final VoidCallback refresh;
  final VoidCallback focusFilter;
  final VoidCallback paste;
  final VoidCallback copy;
  final VoidCallback cut;
  final VoidCallback selectAll;
  final VoidCallback cancelSelection;
  final VoidCallback rename;
  final VoidCallback showContextMenu;
  final VoidCallback moveUp;
  final VoidCallback moveDown;
  final VoidCallback moveLeft;
  final VoidCallback moveRight;
  final VoidCallback extendUp;
  final VoidCallback extendDown;
  final VoidCallback extendLeft;
  final VoidCallback extendRight;
  final VoidCallback goHome;
  final VoidCallback goEnd;
  final VoidCallback extendHome;
  final VoidCallback extendEnd;
  final VoidCallback toggleSelection;

  Map<ShortcutActivator, VoidCallback> get bindings => {
        const SingleActivator(LogicalKeyboardKey.f5): refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): refresh,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            focusFilter,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): focusFilter,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): paste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): paste,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): copy,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): copy,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): cut,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): cut,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            selectAll,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): selectAll,
        const SingleActivator(LogicalKeyboardKey.escape): cancelSelection,
        const SingleActivator(LogicalKeyboardKey.f2): rename,
        const SingleActivator(LogicalKeyboardKey.contextMenu): showContextMenu,
        const SingleActivator(LogicalKeyboardKey.f10, shift: true):
            showContextMenu,
        const SingleActivator(LogicalKeyboardKey.arrowUp): moveUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown): moveDown,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): moveLeft,
        const SingleActivator(LogicalKeyboardKey.arrowRight): moveRight,
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
            extendUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
            extendDown,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
            extendLeft,
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
            extendRight,
        const SingleActivator(LogicalKeyboardKey.home): goHome,
        const SingleActivator(LogicalKeyboardKey.end): goEnd,
        const SingleActivator(LogicalKeyboardKey.home, shift: true):
            extendHome,
        const SingleActivator(LogicalKeyboardKey.end, shift: true): extendEnd,
        const SingleActivator(LogicalKeyboardKey.space, control: true):
            toggleSelection,
      };
}

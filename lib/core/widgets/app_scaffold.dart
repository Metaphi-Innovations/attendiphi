import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A consistent scaffold wrapper with safe area handling.
///
/// Provides standard page layout with optional app bar,
/// padding, theme toggle button, and FAB support.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.title,
    this.showBackButton = true,
    this.showThemeToggle = false,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.padding,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final String? title;
  final bool showBackButton;
  final bool showThemeToggle;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveActions = <Widget>[
      ...?actions,
    ];

    final effectiveAppBar = appBar ??
        (title != null
            ? AppBar(
                title: Text(title!),
                automaticallyImplyLeading: showBackButton,
                actions: effectiveActions,
              )
            : null);

    return Scaffold(
      appBar: effectiveAppBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: padding != null
            ? Padding(
                padding: padding!,
                child: body,
              )
            : body,
      ),
    );
  }
}

import 'package:flutter/material.dart';

void showAppToast(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade600 : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

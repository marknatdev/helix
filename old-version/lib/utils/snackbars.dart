import 'package:flutter/material.dart';

void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Coming soon'),
      duration: Duration(seconds: 1),
    ),
  );
}

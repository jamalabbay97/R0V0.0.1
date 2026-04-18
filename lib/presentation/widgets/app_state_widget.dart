import 'package:flutter/material.dart';

/// Reusable UI state shell to reduce boilerplate around async screens.
class AppStateWidget extends StatelessWidget {
  const AppStateWidget({
    super.key,
    required this.isLoading,
    required this.child,
    this.errorMessage,
    this.onRetry,
    this.loadingMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? loadingMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (loadingMessage != null) ...[
              const SizedBox(height: 12),
              Text(loadingMessage!),
            ],
          ],
        ),
      );
    }

    if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return child;
  }
}

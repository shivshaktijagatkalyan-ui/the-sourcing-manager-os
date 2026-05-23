import 'package:flutter/material.dart';

class FollowupCard extends StatelessWidget {
  const FollowupCard({
    super.key,
    required this.title,
    required this.dueAt,
    required this.status,
    this.onComplete,
  });

  final String title;
  final DateTime dueAt;
  final String status;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(dueAt.toLocal().toString()),
        trailing: FilledButton(
          onPressed: onComplete,
          child: Text(status),
        ),
      ),
    );
  }
}

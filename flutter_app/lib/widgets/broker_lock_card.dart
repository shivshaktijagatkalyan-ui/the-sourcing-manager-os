import 'package:flutter/material.dart';

import '../models/broker_lock.dart';
import 'trust_badge.dart';

class BrokerLockCard extends StatelessWidget {
  const BrokerLockCard({
    super.key,
    required this.lock,
  });

  final BrokerLock lock;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Lead ${lock.leadId}'),
        subtitle: Text(lock.expiresAt == null
            ? 'No expiry recorded'
            : 'Expires ${lock.expiresAt!.toLocal()}'),
        trailing: TrustBadge(label: lock.brokerageStatus ?? lock.status),
      ),
    );
  }
}

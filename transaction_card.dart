import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onDecrypt; // Changed to VoidCallback to match original intent

  const TransactionCard({required this.transaction, required this.onDecrypt, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(transaction.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${transaction.transactionId.substring(0, 8)}...'),
            Text('Status: ${transaction.isPaid ? 'Completed' : 'Pending'}'),
            if (transaction.category != null) Text('Category: ${transaction.category}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: onDecrypt, // No need to pass transaction here anymore
        ),
        tileColor: transaction.isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
      ),
    );
  }
}
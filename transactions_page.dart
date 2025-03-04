import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../services/storage_service.dart';

class TransactionsPage extends StatefulWidget {
  final List<Transaction> transactions;

  const TransactionsPage({required this.transactions, super.key});

  @override
  _TransactionsPageState createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late TextEditingController _searchController;
  String? _filterStatus;
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  List<Transaction> _getFilteredTransactions() {
    var filtered = widget.transactions;
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((tx) => tx.title.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
    }
    if (_filterStatus != null) {
      filtered = filtered.where((tx) => tx.isPaid == (_filterStatus == 'Completed')).toList();
    }
    if (_filterCategory != null && _filterCategory != 'All') {
      filtered = filtered.where((tx) => tx.category == _filterCategory).toList();
    }
    return filtered;
  }

  void _exportTransactions() async {
    final json = jsonEncode(widget.transactions.map((tx) => tx.toJson()).toList());
    await StorageService.exportTransactions(json);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transactions exported')));
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();
    // Ensure categories list contains only non-null strings by filtering nulls and converting to non-nullable
    final categories = ['All', ...widget.transactions.map((tx) => tx.category).where((cat) => cat != null).cast<String>().toSet()];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Transactions',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: _filterStatus,
                hint: const Text('Filter by Status'),
                items: [null, 'Pending', 'Completed']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value ?? 'All')))
                    .toList(),
                onChanged: (value) => setState(() => _filterStatus = value),
              ),
              DropdownButton<String>(
                value: _filterCategory,
                hint: const Text('Filter by Category'),
                items: categories.map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                onChanged: (value) => setState(() => _filterCategory = value),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportTransactions,
                tooltip: 'Export Transactions',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(child: Text('No transactions yet', style: Theme.of(context).textTheme.bodyLarge))
                : ListView.builder(
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = filteredTransactions[index];
                      return TransactionCard(
                        transaction: tx,
                        onDecrypt: () => _showDecryptDialog(tx), // Pass transaction directly
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDecryptDialog(Transaction tx) {
    final passwordController = TextEditingController();
    bool showDecryptForm = false;
    String decryptedInput = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Transaction Details'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Date/Time of Signature: ${tx.signatureTimestamp}'),
                    Text('Date/Time of Payment: ${tx.paymentTimestamp ?? 'Not Paid'}'),
                    Text('Fee: ${tx.amountPaid} BTC'),
                    Text('Hash: ${tx.inputHash}'),
                    Text('Title: ${tx.title}'),
                    if (tx.fileName != null) Text('File: ${tx.fileName}'),
                    Text('Category: ${tx.category ?? 'None'}'),
                    const SizedBox(height: 16),
                    if (showDecryptForm && tx.isEncrypted) ...[
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Enter Password'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (decryptedInput.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.red[50],
                          child: Text(decryptedInput, style: const TextStyle(color: Colors.black)),
                        ),
                    ],
                    if (!tx.isEncrypted) Text('Content: ${tx.encryptedInput}'),
                  ],
                ),
              ),
              actions: [
                if (!showDecryptForm && tx.isEncrypted)
                  TextButton(
                    onPressed: () => setState(() => showDecryptForm = true),
                    child: const Text('Decrypt'),
                  ),
                if (showDecryptForm && tx.isEncrypted)
                  TextButton(
                    onPressed: () => setState(() => decryptedInput = _decryptInput(tx.encryptedInput, passwordController.text)),
                    child: const Text('Decrypt Now'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _decryptInput(String encryptedInput, String password) {
    try {
      var parts = encryptedInput.split('|');
      final encrypted = encrypt.Encrypted.fromBase64(parts[0]);
      final iv = encrypt.IV.fromBase64(parts[1]);
      final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return 'Invalid password or data';
    }
  }
}
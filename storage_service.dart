import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Added import
import 'package:file_picker/file_picker.dart';
import '../models/transaction.dart';

class StorageService {
  static Future<List<Transaction>> loadTransactions(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('transactions_$address') ?? [];
    return saved.map((t) {
      var parts = t.split('|');
      return Transaction(
        transactionId: parts[0],
        mainChainTxId: parts[1],
        signatureTimestamp: parts[2],
        paymentTimestamp: parts[3].isEmpty ? null : parts[3],
        amountPaid: parts[4],
        walletAddress: parts[5],
        encryptedInput: parts[6],
        inputHash: parts[7],
        title: parts[8],
        fileName: parts.length > 9 ? parts[9] : null,
        isPaid: parts.length > 10 ? parts[10] == 'true' : false,
        isEncrypted: parts.length > 11 ? parts[11] == 'true' : false,
        category: parts.length > 12 ? parts[12] : null,
      );
    }).toList();
  }

  static Future<void> saveTransactions(String address, List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = transactions
        .map((t) =>
            '${t.transactionId}|${t.mainChainTxId}|${t.signatureTimestamp}|${t.paymentTimestamp ?? ''}|${t.amountPaid}|${t.walletAddress}|${t.encryptedInput}|${t.inputHash}|${t.title}|${t.fileName ?? ''}|${t.isPaid}|${t.isEncrypted}|${t.category ?? ''}')
        .toList();
    await prefs.setStringList('transactions_$address', saved);
  }

  static Future<void> exportTransactions(String json) async {
    if (kIsWeb) {
      // Web export - Simplified logging for now
      print('Exported JSON: $json');
      // TODO: Implement Blob download for web export if needed
    } else {
      String? outputPath = await FilePicker.platform.getDirectoryPath();
      if (outputPath != null) {
        // Implement file saving logic here (requires additional package like path_provider)
        print('Exported to $outputPath: $json');
      }
    }
  }
}
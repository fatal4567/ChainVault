import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:bip32/bip32.dart' as bip32;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:typed_data';
import '../models/transaction.dart';
import '../widgets/custom_button.dart';
import '../widgets/category_picker.dart';

class TransactionCreationPage extends StatefulWidget {
  final bip32.BIP32 wallet;
  final String walletAddress;
  final Function(Transaction) onTransactionAdded;

  const TransactionCreationPage({
    required this.wallet,
    required this.walletAddress,
    required this.onTransactionAdded,
    super.key,
  });

  @override
  _TransactionCreationPageState createState() => _TransactionCreationPageState();
}

class _TransactionCreationPageState extends State<TransactionCreationPage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  PlatformFile? _selectedFile;
  double _calculatedFee = 0.0;
  bool isTextMode = false;
  bool isFileMode = false;
  bool encryptContent = false;
  bool passwordLossUnderstood = false;
  String? _selectedCategory;

  final List<String> _categories = ['Personal', 'Business', 'Travel', 'Other'];

  String _encryptInput(String input, String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.encrypt(input, iv: iv).base64 + '|' + iv.base64;
  }

  String _hashInput(String input) {
    var bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  void _calculateFee() {
    int textSize = _inputController.text.length;
    int fileSize = _selectedFile?.size ?? 0;
    double fee = 0.0001 + (textSize / 1000 * 0.00001) + (fileSize / 1000000 * 0.00005);
    setState(() => _calculatedFee = fee);
  }

  Future<Transaction> _createRealTransaction(String input, String password, String title, {PlatformFile? file}) async {
    String encryptedInput = input;
    bool isEncrypted = encryptContent;
    if (encryptContent && password.isNotEmpty) {
      encryptedInput = file != null && file.bytes != null
          ? _encryptInput(utf8.decode(file.bytes!), password)
          : _encryptInput(input, password);
    }
    String inputHash = _hashInput(encryptedInput);
    String txId = 'testnet_${inputHash.substring(0, 16)}';
    String signatureTime = DateTime.now().toIso8601String();

    return Transaction(
      transactionId: txId,
      mainChainTxId: txId,
      signatureTimestamp: signatureTime,
      paymentTimestamp: null,
      amountPaid: _calculatedFee.toStringAsFixed(5),
      walletAddress: widget.walletAddress,
      encryptedInput: encryptedInput,
      inputHash: inputHash,
      title: title,
      fileName: file?.name,
      isPaid: false,
      isEncrypted: isEncrypted,
      category: _selectedCategory ?? 'Other',
    );
  }

  Future<void> _pickFile() async {
    if (kIsWeb) {
      final uploadInput = html.FileUploadInputElement()..accept = '*/*';
      uploadInput.click();
      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          reader.onLoadEnd.listen((e) {
            setState(() {
              _selectedFile = PlatformFile(
                name: file.name,
                size: file.size,
                bytes: reader.result as Uint8List?,
              );
              _calculateFee();
            });
          });
        }
      });
    } else {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _selectedFile = result.files.single;
          _calculateFee();
        });
      }
    }
  }

  void _signTransaction() {
    if ((!isTextMode && !isFileMode) ||
        (isTextMode && _inputController.text.isEmpty) ||
        (isFileMode && _selectedFile == null) ||
        _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter text/file and a title')));
      return;
    }
    if (encryptContent && !passwordLossUnderstood) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirm you understand password loss risk')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final dialogPasswordController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Sign Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Fee: ${_calculatedFee.toStringAsFixed(5)} BTC (Testnet)'),
              if (encryptContent)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: dialogPasswordController,
                    decoration: const InputDecoration(labelText: 'Password for Encryption'),
                    obscureText: true,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (encryptContent && dialogPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a password for encryption')));
                  return;
                }
                String input = isTextMode ? _inputController.text : _selectedFile!.name;
                Transaction tx = await _createRealTransaction(input, dialogPasswordController.text, _titleController.text, file: isFileMode ? _selectedFile : null);
                widget.onTransactionAdded(tx);
                Navigator.pop(context);
                _resetForm();
              },
              child: const Text('Store'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (encryptContent && dialogPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a password for encryption')));
                  return;
                }
                String input = isTextMode ? _inputController.text : _selectedFile!.name;
                Transaction tx = await _createRealTransaction(input, dialogPasswordController.text, _titleController.text, file: isFileMode ? _selectedFile : null);
                tx.isPaid = true;
                tx.paymentTimestamp = DateTime.now().toIso8601String();
                widget.onTransactionAdded(tx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Paid ${_calculatedFee.toStringAsFixed(5)} BTC (Testnet)!')),
                );
                _resetForm();
              },
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      _inputController.clear();
      _titleController.clear();
      _selectedFile = null;
      _selectedCategory = null;
      isTextMode = false;
      isFileMode = false;
      encryptContent = false;
      passwordLossUnderstood = false;
      _calculatedFee = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Transaction', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Enter Title',
                prefixIcon: Icon(Icons.title),
              ),
              onChanged: (_) => _calculateFee(),
            ),
            const SizedBox(height: 16),
            CategoryPicker(
              categories: _categories,
              selectedCategory: _selectedCategory,
              onSelected: (category) => setState(() => _selectedCategory = category),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomButton(
                  text: 'Text',
                  onPressed: () => setState(() {
                    isTextMode = true;
                    isFileMode = false;
                    _calculateFee();
                  }),
                  isOutlined: !isTextMode,
                ),
                const SizedBox(width: 16),
                CustomButton(
                  text: 'File',
                  onPressed: () => setState(() {
                    isTextMode = false;
                    isFileMode = true;
                    _calculateFee();
                  }),
                  isOutlined: !isFileMode,
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isTextMode
                  ? TextField(
                      controller: _inputController,
                      onChanged: (_) => _calculateFee(),
                      decoration: const InputDecoration(
                        labelText: 'Enter Text (e.g., XYZ123)',
                        prefixIcon: Icon(Icons.text_fields),
                      ),
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                    )
                  : isFileMode
                      ? Column(
                          children: [
                            CustomButton(
                              text: _selectedFile == null ? 'Upload File' : 'File Selected',
                              onPressed: _pickFile,
                              icon: const Icon(Icons.upload_file),
                            ),
                            if (_selectedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('File: ${_selectedFile!.name}', style: Theme.of(context).textTheme.bodyMedium),
                              ),
                          ],
                        )
                      : const SizedBox(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: encryptContent,
                  onChanged: (value) => setState(() => encryptContent = value!),
                ),
                const Text('Encrypt Content'),
              ],
            ),
            if (encryptContent)
              Row(
                children: [
                  Checkbox(
                    value: passwordLossUnderstood,
                    onChanged: (value) => setState(() => passwordLossUnderstood = value!),
                  ),
                  const Expanded(child: Text('I understand that if I lose the password, I lose access')),
                ],
              ),
            const SizedBox(height: 16),
            Text('Fee: ${_calculatedFee.toStringAsFixed(5)} BTC (Testnet)', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Sign Transaction',
              onPressed: _signTransaction,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
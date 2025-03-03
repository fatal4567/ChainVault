import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:http/http.dart' as http;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:pointycastle/digests/ripemd160.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

void main() {
  runApp(const ChainVaultApp());
}

class ChainVaultApp extends StatelessWidget {
  const ChainVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChainVault',
      theme: ThemeData(
        primaryColor: const Color(0xFF1A73E8),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF1A73E8),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF202124), fontSize: 16),
          bodyMedium: TextStyle(color: Color(0xFF5F6368), fontSize: 14),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF202124)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFFDADCE0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFF1A73E8), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A73E8),
          secondary: Color(0xFF34C759),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF202124),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _registerAddressController = TextEditingController();
  final TextEditingController _registerSeedController = TextEditingController();
  final TextEditingController _loginAddressController = TextEditingController();
  final TextEditingController _loginSeedController = TextEditingController();
  bool _registerSeedGenerated = false;
  bool _showRegisterSeed = false;
  bool _walletGenerated = false;
  bool _showWalletSeed = false;
  String? _walletSeed;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _generateSeedAndAddress() {
    setState(() {
      final seed = bip39.generateMnemonic();
      _registerSeedController.text = seed;
      _registerSeedGenerated = true;
      if (_walletGenerated) {
        _deriveAddress(seed);
      }
    });
  }

  void _deriveAddress(String seed) {
    final seedBytes = bip39.mnemonicToSeed(seed);
    final wallet = bip32.BIP32.fromSeed(seedBytes);
    final child = wallet.derivePath("m/44'/1'/0'/0/0");
    final publicKeyHash = hash160(child.publicKey);
    final version = Uint8List.fromList([0x6f]);
    final payload = Uint8List.fromList([...version, ...publicKeyHash]);
    final checksum = sha256.convert(sha256.convert(payload).bytes).bytes.sublist(0, 4);
    _registerAddressController.text = bs58check.encode(Uint8List.fromList([...payload, ...checksum]));
  }

  Uint8List hash160(Uint8List input) {
    final sha256Hash = sha256.convert(input).bytes;
    final ripemd160 = RIPEMD160Digest();
    return ripemd160.process(Uint8List.fromList(sha256Hash));
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChainVault'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Register'),
            Tab(text: 'Login'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Your Account', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _registerAddressController,
                    decoration: const InputDecoration(labelText: 'Public Address (e.g., tb1q…)'),
                  ),
                  const SizedBox(height: 16),
                  if (!_walletGenerated)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          final seed = bip39.generateMnemonic();
                          _walletSeed = seed;
                          _deriveAddress(seed);
                          _walletGenerated = true;
                        });
                      },
                      child: const Text('Generate Wallet'),
                    ),
                  if (_walletGenerated) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Wallet Seed: ${_showWalletSeed ? _walletSeed : '••••••••••••••••••••••••'}',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: Icon(_showWalletSeed ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showWalletSeed = !_showWalletSeed),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _registerSeedController,
                    decoration: InputDecoration(
                      labelText: 'Account Seed Phrase',
                      suffixIcon: IconButton(
                        icon: Icon(_showRegisterSeed ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showRegisterSeed = !_showRegisterSeed),
                      ),
                    ),
                    enabled: false,
                    obscureText: !_showRegisterSeed,
                  ),
                  const SizedBox(height: 16),
                  if (!_registerSeedGenerated)
                    ElevatedButton(
                      onPressed: _generateSeedAndAddress,
                      child: const Text('Generate Seed Phrase'),
                    ),
                  if (_registerSeedGenerated && _registerAddressController.text.isNotEmpty && _registerSeedController.text.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MainScreen(
                              seedPhrase: _registerSeedController.text,
                              publicAddress: _registerAddressController.text,
                            ),
                          ),
                        );
                      },
                      child: const Text('Continue'),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Fixed typo here
                children: [
                  Text('Login to Your Account', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _loginAddressController,
                    decoration: const InputDecoration(labelText: 'Public Address (e.g., tb1q…)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _loginSeedController,
                    decoration: const InputDecoration(labelText: 'Account Seed Phrase'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (_loginAddressController.text.isNotEmpty && _loginSeedController.text.isNotEmpty) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MainScreen(
                              seedPhrase: _loginSeedController.text,
                              publicAddress: _loginAddressController.text,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter both address and seed phrase')),
                        );
                      }
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String seedPhrase;
  final String publicAddress;

  const MainScreen({required this.seedPhrase, required this.publicAddress, super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Transaction> _transactions = [];
  late bip32.BIP32 wallet;
  int _profileTapCount = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _initWallet();
    _loadTransactions();
  }

  void _initWallet() {
    final seed = bip39.mnemonicToSeed(widget.seedPhrase);
    wallet = bip32.BIP32.fromSeed(seed);
  }

  void _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('transactions_${widget.publicAddress}') ?? [];
    setState(() {
      _transactions = saved.map((t) {
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
        );
      }).toList();
    });
  }

  void _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _transactions
        .map((t) =>
            '${t.transactionId}|${t.mainChainTxId}|${t.signatureTimestamp}|${t.paymentTimestamp ?? ''}|${t.amountPaid}|${t.walletAddress}|${t.encryptedInput}|${t.inputHash}|${t.title}|${t.fileName ?? ''}|${t.isPaid}|${t.isEncrypted}')
        .toList();
    await prefs.setStringList('transactions_${widget.publicAddress}', saved);
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wallet Address: ${widget.publicAddress}'),
              const SizedBox(height: 16),
              if (_profileTapCount >= 2)
                Text('Seed Phrase: ${widget.seedPhrase}', style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChainVault'),
        actions: [
          GestureDetector(
            onTap: () {
              setState(() {
                _profileTapCount++;
                if (_profileTapCount >= 2) {
                  _showProfileDialog();
                } else {
                  _showProfileDialog();
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Text(
                  widget.publicAddress.substring(0, 2).toUpperCase(),
                  style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TransactionCreationPage(
            wallet: wallet,
            walletAddress: widget.publicAddress,
            onTransactionAdded: (tx) {
              setState(() {
                _transactions.insert(0, tx);
                _saveTransactions();
              });
            },
          ),
          TransactionsPage(transactions: _transactions),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Transactions'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}

class Transaction {
  final String transactionId;
  final String mainChainTxId;
  final String signatureTimestamp;
  String? paymentTimestamp;
  final String amountPaid;
  final String walletAddress;
  final String encryptedInput;
  final String inputHash;
  final String title;
  final String? fileName;
  bool isPaid;
  final bool isEncrypted;

  Transaction({
    required this.transactionId,
    required this.mainChainTxId,
    required this.signatureTimestamp,
    this.paymentTimestamp,
    required this.amountPaid,
    required this.walletAddress,
    required this.encryptedInput,
    required this.inputHash,
    required this.title,
    this.fileName,
    this.isPaid = false,
    required this.isEncrypted,
  });
}

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
                setState(() {
                  _inputController.clear();
                  _titleController.clear();
                  _selectedFile = null;
                  isTextMode = false;
                  isFileMode = false;
                  encryptContent = false;
                  passwordLossUnderstood = false;
                  _calculatedFee = 0.0;
                });
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
                setState(() {
                  _inputController.clear();
                  _titleController.clear();
                  _selectedFile = null;
                  isTextMode = false;
                  isFileMode = false;
                  encryptContent = false;
                  passwordLossUnderstood = false;
                  _calculatedFee = 0.0;
                });
              },
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );
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
              decoration: const InputDecoration(labelText: 'Enter Title'),
              onChanged: (_) => _calculateFee(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() {
                    isTextMode = true;
                    isFileMode = false;
                    _calculateFee();
                  }),
                  child: const Text('Text'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    isTextMode = false;
                    isFileMode = true;
                    _calculateFee();
                  }),
                  child: const Text('File'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isTextMode)
              TextField(
                controller: _inputController,
                onChanged: (_) => _calculateFee(),
                decoration: const InputDecoration(labelText: 'Enter Text (e.g., XYZ123)'),
                maxLines: 5,
                keyboardType: TextInputType.multiline,
              ),
            if (isFileMode)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _pickFile,
                    child: Text(_selectedFile == null ? 'Upload File' : 'File Selected'),
                  ),
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('File: ${_selectedFile!.name}'),
                    ),
                ],
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
            ElevatedButton(
              onPressed: _signTransaction,
              child: const Text('Sign Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionsPage extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionsPage({required this.transactions, super.key});

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

  void _showTransactionDetails(BuildContext context, Transaction tx) {
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [Tab(text: 'Pending'), Tab(text: 'Completed')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTransactionList(context, false),
                _buildTransactionList(context, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, bool isPaid) {
    List<Transaction> filtered = transactions.where((tx) => tx.isPaid == isPaid).toList();
    if (filtered.isEmpty) {
      return Center(child: Text('No transactions yet', style: Theme.of(context).textTheme.bodyLarge));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final tx = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            title: Text(tx.title),
            subtitle: Text(tx.transactionId, style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showTransactionDetails(context, tx),
            ),
          ),
        );
      },
    );
  }
}

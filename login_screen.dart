import 'package:flutter/material.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:pointycastle/digests/ripemd160.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _registerAddressController = TextEditingController();
  final List<TextEditingController> _seedPhraseControllers = List.generate(12, (_) => TextEditingController());
  final TextEditingController _loginAddressController = TextEditingController();
  final TextEditingController _loginSeedController = TextEditingController();
  bool _seedPhraseGenerated = false; // Tracks if a seed phrase has been generated
  bool _seedPhraseRevealed = false;  // Tracks if the seed phrase has been revealed
  bool _walletGenerated = false;
  bool _showWalletSeed = false;
  String? _walletSeed;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _generateSeedPhrase() {
    setState(() {
      final seed = bip39.generateMnemonic();
      _walletSeed = seed;
      final seedWords = seed.split(' ');
      for (int i = 0; i < seedWords.length; i++) {
        _seedPhraseControllers[i].text = seedWords[i];
      }
      _seedPhraseGenerated = true;
    });
  }

  void _deriveAddress(String seed) {
    final seedBytes = bip39.mnemonicToSeed(seed);
    final wallet = bip32.BIP32.fromSeed(seedBytes);
    final child = wallet.derivePath("m/44'/1'/0'/0/0");
    final publicKeyHash = _hash160(child.publicKey);
    final version = Uint8List.fromList([0x6f]);
    final payload = Uint8List.fromList([...version, ...publicKeyHash]);
    final checksum = sha256.convert(sha256.convert(payload).bytes).bytes.sublist(0, 4);
    _registerAddressController.text = bs58check.encode(Uint8List.fromList([...payload, ...checksum]));
  }

  Uint8List _hash160(Uint8List input) {
    final sha256Hash = sha256.convert(input).bytes;
    final ripemd160 = RIPEMD160Digest();
    return ripemd160.process(Uint8List.fromList(sha256Hash));
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  void _showSeedPhraseWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 32),
            const SizedBox(width: 8),
            const Text('Attention: Seed Phrase Safety'),
          ],
        ),
        content: const Text(
          'Your seed phrase is critical for wallet recovery. Write it down on paper, store it securely, and never share it with anyone. Losing it could result in permanent loss of access to your funds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _seedPhraseRevealed = true; // Lock and reveal the seed phrase
              });
              Navigator.pop(context);
            },
            child: const Text('Reveal'),
          ),
        ],
      ),
    );
  }

  bool _canShowContinue() {
    return _seedPhraseGenerated && _registerAddressController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/cube_keyhole.png', // Cube with keyhole image (transparent background)
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 8),
            const Text('ChainVault'),
          ],
        ),
        centerTitle: false, // Left-align the title
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
                    decoration: const InputDecoration(
                      labelText: 'Public Address (e.g., tb1q…)',
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (!_walletGenerated)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _walletGenerated = true;
                          _deriveAddress(_walletSeed ?? '');
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
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
                  // Seed Phrase Boxes in 4x3 Grid with Reduced Row Spacing
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5, // Box width/height ratio
                      crossAxisSpacing: 8,   // Horizontal spacing
                      mainAxisSpacing: 4,    // Reduced vertical spacing
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          color: Colors.white,
                        ),
                        child: TextField(
                          controller: _seedPhraseControllers[index],
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: '${index + 1}',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            fillColor: Colors.transparent,
                          ),
                          obscureText: !_seedPhraseRevealed,
                          style: const TextStyle(fontSize: 25), // Increased font size for seed phrase words
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_seedPhraseRevealed) // Show "Generate Seed Phrase" until revealed
                        ElevatedButton(
                          onPressed: _generateSeedPhrase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          child: const Text('Generate Seed Phrase'),
                        ),
                      if (!_seedPhraseRevealed) // Show "Reveal Seed Phrase" only until revealed
                        ElevatedButton(
                          onPressed: _showSeedPhraseWarning,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          child: const Text('Reveal Seed Phrase'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_canShowContinue())
                    ElevatedButton(
                      onPressed: () {
                        final seedPhrase = _seedPhraseControllers.map((c) => c.text).join(' ');
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MainScreen(
                              seedPhrase: seedPhrase,
                              publicAddress: _registerAddressController.text,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Login to Your Account', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _loginAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Public Address (e.g., tb1q…)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _loginSeedController,
                    decoration: const InputDecoration(
                      labelText: 'Account Seed Phrase',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
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
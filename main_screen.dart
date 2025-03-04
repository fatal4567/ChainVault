import 'package:flutter/material.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import 'transaction_creation_page.dart';
import 'transactions_page.dart';
import 'settings_page.dart';
import '../services/storage_service.dart';

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
  String _username = 'User';

  @override
  void initState() {
    super.initState();
    _initWallet();
    _loadTransactions();
    _loadProfile();
  }

  void _initWallet() {
    final seed = bip39.mnemonicToSeed(widget.seedPhrase);
    wallet = bip32.BIP32.fromSeed(seed);
  }

  void _loadTransactions() async {
    _transactions = await StorageService.loadTransactions(widget.publicAddress);
    setState(() {});
  }

  void _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username_${widget.publicAddress}') ?? 'User';
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final double totalSpent = _transactions
        .where((tx) => tx.isPaid)
        .fold(0.0, (sum, tx) => sum + double.parse(tx.amountPaid));
    final int allSignatures = _transactions.length; // Total count of all transactions

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
        actions: [
          Padding(
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
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24, color: Color(0xFF1A73E8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _username,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.publicAddress.substring(0, 8) + '...',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Transactions'),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      publicAddress: widget.publicAddress,
                      seedPhrase: widget.seedPhrase,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Spent (BTC)', '${totalSpent.toStringAsFixed(5)}'),
                _buildStatCard('All Signatures', '$allSignatures'),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                TransactionCreationPage(
                  wallet: wallet,
                  walletAddress: widget.publicAddress,
                  onTransactionAdded: (tx) {
                    setState(() {
                      _transactions.insert(0, tx);
                      StorageService.saveTransactions(widget.publicAddress, _transactions);
                    });
                  },
                ),
                TransactionsPage(transactions: _transactions),
              ],
            ),
          ),
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

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
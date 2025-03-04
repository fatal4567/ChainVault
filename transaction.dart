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
  final String? category;

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
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'mainChainTxId': mainChainTxId,
        'signatureTimestamp': signatureTimestamp,
        'paymentTimestamp': paymentTimestamp,
        'amountPaid': amountPaid,
        'walletAddress': walletAddress,
        'encryptedInput': encryptedInput,
        'inputHash': inputHash,
        'title': title,
        'fileName': fileName,
        'isPaid': isPaid,
        'isEncrypted': isEncrypted,
        'category': category,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        transactionId: json['transactionId'],
        mainChainTxId: json['mainChainTxId'],
        signatureTimestamp: json['signatureTimestamp'],
        paymentTimestamp: json['paymentTimestamp'],
        amountPaid: json['amountPaid'],
        walletAddress: json['walletAddress'],
        encryptedInput: json['encryptedInput'],
        inputHash: json['inputHash'],
        title: json['title'],
        fileName: json['fileName'],
        isPaid: json['isPaid'],
        isEncrypted: json['isEncrypted'],
        category: json['category'],
      );
}
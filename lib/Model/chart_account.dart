class ChartAccount {
  final String id;
  final String accountName;

  ChartAccount({required this.id, required this.accountName});

  factory ChartAccount.fromJson(Map<String, dynamic> j) => ChartAccount(
    id: (j['id'] ?? '').toString(),
    accountName: (j['accountName'] ?? '').toString(),
  );

  // Useful for dropdown_search
  @override
  String toString() => accountName;
}

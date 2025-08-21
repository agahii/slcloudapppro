import 'customer_lite.dart';

class PagedCustomers {
  final List<CustomerLite> items;
  final int pageIndex;   // from server (0/1-based depending on API)
  final int pageSize;    // from server
  final int totalRecords;
  final int totalRecordsInResponse;

  const PagedCustomers({
    required this.items,
    required this.pageIndex,
    required this.pageSize,
    required this.totalRecords,
    required this.totalRecordsInResponse,
  });

  /// If server provides totalRecords, we can use it. Otherwise fall back to simple length check.
  bool get hasMore {
    if (totalRecords > 0) {
      // If server's pageIndex is 0-based, adjust math if needed.
      final guessed1BasedPage = (pageIndex <= 0) ? 1 : pageIndex;
      return (guessed1BasedPage * pageSize) < totalRecords;
    }
    // No total given — infer from page fill
    return items.length >= pageSize;
  }
}
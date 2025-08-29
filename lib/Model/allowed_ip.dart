class AllowedIp {
  final String id;
  final String ipAddress;
  final String desc;
  final bool isActive;
  final DateTime? validUntil;

  AllowedIp({
    required this.id,
    required this.ipAddress,
    required this.desc,
    required this.isActive,
    this.validUntil,
  });

  factory AllowedIp.fromJson(Map<String, dynamic> json) {
    return AllowedIp(
      id: json['id']?.toString() ?? '',
      ipAddress: json['ipAddress']?.toString() ?? '',
      desc: json['desc']?.toString() ?? '',
      isActive: json['isActive'] ?? false,
      validUntil: json['validUntil'] != null && json['validUntil'] != ''
          ? DateTime.tryParse(json['validUntil'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ipAddress': ipAddress,
      'desc': desc,
      'isActive': isActive,
      if (validUntil != null) 'validUntil': validUntil!.toIso8601String(),
    };
  }
}

class PagedAllowedIp {
  final List<AllowedIp> items;
  final int pageIndex;
  final int pageSize;
  final int totalRecords;
  final int totalRecordsInResponse;

  const PagedAllowedIp({
    required this.items,
    required this.pageIndex,
    required this.pageSize,
    required this.totalRecords,
    required this.totalRecordsInResponse,
  });

  bool get hasMore {
    if (totalRecords > 0) {
      final guessed1BasedPage = (pageIndex <= 0) ? 1 : pageIndex;
      return (guessed1BasedPage * pageSize) < totalRecords;
    }
    return items.length >= pageSize;
  }
}

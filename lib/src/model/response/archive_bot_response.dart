class ArchiveBotResponse<T> {
  final int code;
  final String message;
  final T data;

  const ArchiveBotResponse({required this.code, required this.message, required this.data});

  factory ArchiveBotResponse.fromJson(Map<String, dynamic> json) {
    return ArchiveBotResponse(
      code: json["retcode"],
      message: json["msg"],
      data: json["data"],
    );
  }

  @override
  String toString() {
    return 'ArchiveBotResponse{code: $code, message: $message, data: $data}';
  }
}

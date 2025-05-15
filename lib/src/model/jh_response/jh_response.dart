class JHResponse<T> {
  final int code;
  final String message;
  final T data;

  const JHResponse({required this.code, required this.message, required this.data});

  factory JHResponse.fromJson(Map<String, dynamic> json) {
    return JHResponse(
      code: json["code"],
      message: json["message"],
      data: json["data"],
    );
  }

  bool get isSuccess => code == 0;

  @override
  String toString() {
    return 'JHResponse{code: $code, message: $message, data: $data}';
  }
}

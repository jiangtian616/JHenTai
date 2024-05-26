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
}

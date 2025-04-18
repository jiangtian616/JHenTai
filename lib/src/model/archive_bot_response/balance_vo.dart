class BalanceVO {
  int gp;

  BalanceVO({required this.gp});

  factory BalanceVO.fromResponse(Map<String, dynamic> json) {
    return BalanceVO(
      gp: json["current_GP"],
    );
  }
}

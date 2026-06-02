class BalanceVO {
  int gp;

  BalanceVO({required this.gp});

  factory BalanceVO.fromEhArBotResponse(Map<String, dynamic> json) {
    return BalanceVO(
      gp: json["current_GP"],
    );
  }

  factory BalanceVO.fromArchiveAtHomeResponse(Map<String, dynamic> json) {
    return BalanceVO(
      gp: json["balance"],
    );
  }
}

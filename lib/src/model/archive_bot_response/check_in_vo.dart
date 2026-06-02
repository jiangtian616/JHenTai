class CheckInVO {
  int getGP;
  int currentGP;

  CheckInVO({required this.getGP, required this.currentGP});

  factory CheckInVO.fromEhArBotResponse(Map<String, dynamic> json) {
    return CheckInVO(
      getGP: json["get_GP"],
      currentGP: json["current_GP"],
    );
  }

  factory CheckInVO.fromArchiveAtHomeResponse(Map<String, dynamic> json) {
    return CheckInVO(
      getGP: json["reward"],
      currentGP: json["balance"],
    );
  }
}

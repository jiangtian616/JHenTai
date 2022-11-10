import 'package:flutter/material.dart';

class EHCommentScoreDetailsDialog extends StatelessWidget {
  final List<String> scoreDetails;

  const EHCommentScoreDetailsDialog({Key? key, required this.scoreDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: scoreDetails
          .map(
            (detail) => Center(
              child: Text(detail),
            ),
          )
          .toList(),
    );
  }
}

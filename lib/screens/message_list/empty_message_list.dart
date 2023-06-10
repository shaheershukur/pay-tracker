import 'package:flutter/material.dart';
import 'package:pay_tracker/constants/app_constants.dart';
import 'package:pay_tracker/screens/message_list/empty_message_list_sample_sms.dart';

class EmptyMessageList extends StatelessWidget {
  const EmptyMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.inbox_outlined,
              size: 48,
            ),
            SizedBox(
              height: 18,
            ),
            Text(
              textAlign: TextAlign.center,
              noSmsFoundText,
            ),
            EmptyMessageListSampleSms(),
          ],
        ),
      ),
    );
  }
}

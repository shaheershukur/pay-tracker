import 'package:pay_tracker/types/date_grouped_sms.dart';
import 'package:pay_tracker/types/monthly_spending.dart';

class MonthlyAnalytics {
  /// eg: { ... "Sep 2023":{MonthlySpending}, "Oct 2023":{MonthlySpending} ... }
  late Map<String, MonthlySpending> monthlySpending;

  MonthlyAnalytics(
      List<DateGroupedSms> dateGroupedMessages, List<String> monthsList) {
    Map<String, List<DateGroupedSms>> yearlySpending = Map.fromEntries(
        monthsList.map((monthAndYear) => MapEntry(monthAndYear, [])));

    for (var dateGroupedMessage in dateGroupedMessages) {
      List<String> dateSplit = dateGroupedMessage.date.split(" ");
      String dateSplitMonthAndYear = '${dateSplit[2]} ${dateSplit[3]}';
      yearlySpending[dateSplitMonthAndYear]?.add(dateGroupedMessage);
    }

    monthlySpending = Map.fromEntries(
      monthsList.map(
        (monthAndYear) => MapEntry(
          monthAndYear,
          MonthlySpending(
            yearlySpending,
            monthAndYear,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay_tracker/constants/identifier_constants.dart';
import 'package:pay_tracker/constants/image_constants.dart';
import 'package:pay_tracker/constants/sms_reader_constants.dart';
import 'package:pay_tracker/screens/insights_screen/monthly_graph/monthly_graph_constants.dart';
import 'package:pay_tracker/types/date_grouped_sms.dart';
import 'package:pay_tracker/types/displayed_sms.dart';
import 'package:pay_tracker/types/inbox_sms_message.dart';
import 'package:pay_tracker/types/insights_screen/spending_analytics/places_spent.dart';
import 'package:pay_tracker/types/monthly_analytics.dart';
import 'package:pay_tracker/types/monthly_spending.dart';
import 'package:pay_tracker/types/monthly_total_spending.dart';
import 'package:pay_tracker/types/year_grouped_sms.dart';
import 'package:pay_tracker/utilities/readers/message_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageStoreModel extends ChangeNotifier {
  Exception exception = Exception('');
  bool smsPermissionFailed = false;
  bool exceptionOccurred = false;

  String _year = '';
  String month = '';
  String _day = '';
  String _currencyName = '';

  String monthlyGraphRange = MonthlyGraphConstants.allTime;

  final List<DateGroupedSms> _dateGroupedSms = [];
  late YearGroupedSms _yearGroupedSms = YearGroupedSms([]);
  final Map<String, List<String>> _cardTypesAndNumbers = {};
  late MonthlyAnalytics _monthlyAnalytics = MonthlyAnalytics([], []);
  final Map<String, int> _dailyCardLimits = {};
  final Map<String, String> _cardCoverImages = {};

  MessageStoreModel() {
    fetchMessagesFromInbox();
  }

  String get year => _year;
  String get day => _day;
  String get selectedMonthAndYear => '$month $year';
  set selectedMonthAndYear(String monthAndYear) {
    List<String> monthAndYearSplit = monthAndYear.split(' ');
    month = monthAndYearSplit[0];
    _year = monthAndYearSplit[1];
  }

  String get currencyName => _currencyName;
  List<DateGroupedSms> get groupedMessages => _dateGroupedSms;
  Map<String, List<String>> get cardTypesAndNumbers => _cardTypesAndNumbers;
  List<String> get yearsList => _yearGroupedSms.yearsList;
  List<String> get monthsList => _yearGroupedSms.monthsList;
  List<MonthlyTotalSpending> get monthlyTotalSpendings =>
      _yearGroupedSms.monthlyTotalSpendingsList.reversed.toList();

  MonthlySpending getMonthlySpending(String monthAndYear) {
    MonthlySpending? monthlySpending =
        _monthlyAnalytics.monthlySpending[monthAndYear];
    if (monthlySpending != null) {
      return monthlySpending;
    } else {
      return MonthlySpending.empty();
    }
  }

  PlacesSpent getPlacesSpent(String monthAndYear) {
    PlacesSpent? placesSpent = _monthlyAnalytics.placesSpent[monthAndYear];
    if (placesSpent != null) {
      return placesSpent;
    } else {
      return PlacesSpent.empty();
    }
  }

  void _setDateAndCurrencyFromLatestSMS() {
    _year = _dateGroupedSms[0].year;
    month = _dateGroupedSms[0].month;
    _day = _dateGroupedSms[0].day;
    _currencyName = _dateGroupedSms[0].currencyName;
  }

  void _generateYearGroupedSms() {
    _yearGroupedSms = YearGroupedSms(_dateGroupedSms);
  }

  void _generateMonthlyAnalytics() {
    _monthlyAnalytics =
        MonthlyAnalytics(_dateGroupedSms, _yearGroupedSms.monthsList);
  }

  Future<void> fetchMessagesFromInbox() async {
    List<InboxSmsMessage> inboxMessages = [];
    try {
      inboxMessages = await getInboxMessages();
    } on PlatformException {
      smsPermissionFailed = true;
    } on Exception catch (e) {
      exceptionOccurred = true;
      exception = e;
    }
    if (smsPermissionFailed || exceptionOccurred) return;
    await addInboxMessagesToStore(inboxMessages);
    await loadCardLimits();
    await loadCardCoverImages();
    notifyListeners();
  }

  Future<void> addInboxMessagesToStore(
      List<InboxSmsMessage> inboxMessages) async {
    _dateGroupedSms.clear();
    List<DisplayedSms> displayedSms = [];
    for (var inboxMessage in inboxMessages) {
      RegExpMatch? regexMatch = regExp.firstMatch(inboxMessage.body);
      if (regexMatch != null) {
        DisplayedSms displayedSmsObject =
            DisplayedSms(regexMatch, inboxMessage);
        displayedSms.add(displayedSmsObject);
        if (_cardTypesAndNumbers.containsKey(displayedSmsObject.cardType)) {
          if (!(_cardTypesAndNumbers[displayedSmsObject.cardType]
                  ?.contains(displayedSmsObject.cardNumber) ??
              false)) {
            _cardTypesAndNumbers[displayedSmsObject.cardType]
                ?.add(displayedSmsObject.cardNumber);
          }
        } else {
          _cardTypesAndNumbers[displayedSmsObject.cardType] = [
            displayedSmsObject.cardNumber
          ];
        }
      }
    }

    String? dateStamp = displayedSms.isNotEmpty
        ? '${displayedSms[0].day}-${displayedSms[0].month}-${displayedSms[0].year}'
        : null;
    List<DisplayedSms> dateStampMessages =
        displayedSms.isNotEmpty ? [displayedSms[0]] : [];
    for (var i = 1; i < displayedSms.length; i++) {
      DisplayedSms sms = displayedSms[i];
      String currentDateStamp = '${sms.day}-${sms.month}-${sms.year}';
      if (dateStamp == currentDateStamp) {
        dateStampMessages.add(sms);
      } else {
        _dateGroupedSms.add(DateGroupedSms(dateStampMessages));
        dateStamp = currentDateStamp;
        dateStampMessages = [sms];
      }
    }
    if (dateStampMessages.isNotEmpty) {
      _dateGroupedSms.add(DateGroupedSms(dateStampMessages));
    }
    _setDateAndCurrencyFromLatestSMS();
    _generateYearGroupedSms();
    _generateMonthlyAnalytics();
  }

  String _generateCardSignature(String cardType, String cardNumber) {
    return '$cardLimitKey$cardType$cardNumber';
  }

  Future<void> loadCardLimits() async {
    final preferences = await SharedPreferences.getInstance();
    cardTypesAndNumbers.forEach(
      (cardType, cardNumbers) {
        for (var cardNumber in cardNumbers) {
          String cardSignature = _generateCardSignature(cardType, cardNumber);
          _dailyCardLimits[cardSignature] =
              preferences.getInt('cardLimit$cardSignature') ?? 0;
        }
      },
    );
    notifyListeners();
  }

  Future<void> saveCardLimit(
      String cardType, String cardNumber, int limit) async {
    final preferences = await SharedPreferences.getInstance();
    String cardSignature = _generateCardSignature(cardType, cardNumber);
    preferences.setInt('cardLimit$cardSignature', limit);
    await loadCardLimits();
  }

  int getCardLimit(String cardType, String cardNumber) {
    String cardSignature = _generateCardSignature(cardType, cardNumber);
    return _dailyCardLimits[cardSignature] ?? 0;
  }

  Future<void> loadCardCoverImages() async {
    final preferences = await SharedPreferences.getInstance();
    cardTypesAndNumbers.forEach(
      (cardType, cardNumbers) {
        for (var cardNumber in cardNumbers) {
          String cardSignature = _generateCardSignature(cardType, cardNumber);
          _cardCoverImages[cardSignature] =
              preferences.getString('cardCoverImage$cardSignature') ?? '';
        }
      },
    );
    notifyListeners();
  }

  Future<void> saveCardCoverImage(String cardType, String cardNumber,
      String cardCoverImageIdentifier) async {
    final preferences = await SharedPreferences.getInstance();
    String cardSignature = _generateCardSignature(cardType, cardNumber);
    preferences.setString(
        'cardCoverImage$cardSignature', cardCoverImageIdentifier);
    await loadCardCoverImages();
  }

  String getCardCoverImage(
      String cardType, String cardNumber, String? themeModeIdentifier,
      {bool onlyCardCoverImageIdentifier = false}) {
    String cardSignature = _generateCardSignature(cardType, cardNumber);
    String cardCoverImageIdentifier = _cardCoverImages[cardSignature] ?? '';
    return onlyCardCoverImageIdentifier
        ? cardCoverImageIdentifier
        : '$cardCoverPath$cardCoverImageIdentifier$themeModeIdentifier$cardCoverFileType';
  }

  void changeMonthlyGraphRange(String selectedMonthlyGraphRange) {
    monthlyGraphRange = selectedMonthlyGraphRange;
    notifyListeners();
  }
}

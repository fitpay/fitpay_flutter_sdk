import 'package:fitpay_flutter_sdk/fitpay_flutter_sdk.dart';
import 'package:fitpay_flutter_sdk/src/models.dart';
import 'models.dart';
import 'dart:math';

List<GPRTransaction> getGPRTransactions() {
  // Boiler plate for the transaction
  Map<String, dynamic> mockTransactionMap = {
    "_links": {
      "self": {
        "href": "http://localhost:56912/users/69fe7726-d4e8-4857-a7c2-4d7032e4e3bf/creditCards/da5f93f6-b2cb-4243-b459-26ed2a9f4dc7/transactions/bb8b64a2-8442-443f-b8ed-a1415a381260"
      }
    },
    "transactionId": "bb8b64a2-8442-443f-b8ed-a1415a381260",
    "transactionType": "PURCHASE",
    "amount": 0.00,
    "currencyCode": "USD",
    "authorizationStatus": "AUTHORIZED",
    "transactionTime": "2016-03-09T05:38:00.788Z",
    "transactionTimeEpoch": 1457501880788,
    "merchantName": "",
    "merchantCode": "8661",
    "merchantType": "Religious Organizations"
  };

  List<String> merchants = ["Safeway", "King Soopers", "IHOP", "Taco Bell", "Century Theater", "Conoco Gas"];
  List<String> times = ["2016-03-09T05:38:00.788Z", "2016-03-10T05:38:00.788Z", "2016-03-11T05:38:00.788Z"];

  // Create Ten Fake Transactions by initializing the vlaue of the price randomly
  List<GPRTransaction> gprTransactions = [];
  var rng = new Random();
  const int copies = 10;
  for (int i = 0; i < copies; i++) {
    mockTransactionMap['amount'] = double.parse((rng.nextDouble()*50).toStringAsFixed(2));
    mockTransactionMap['merchantName'] = merchants[rng.nextInt(merchants.length)];
    mockTransactionMap['transactionTime'] = times[rng.nextInt(times.length)];
    gprTransactions.add(GPRTransaction.fromJson(mockTransactionMap));
  }
  return gprTransactions;
}
// Fake Page of Transactions
Page<GPRTransaction> mockTransactions = Page<GPRTransaction>(
  limit: 10,
  offset: 0,
  totalResults: 30,
  links: {
    'self': Link(href: "http://localhost:56912/users/69fe7726-d4e8-4857-a7c2-4d7032e4e3bf/creditCards/da5f93f6-b2cb-4243-b459-26ed2a9f4dc7/transactions?limit=2&offset=0"),
    'last': Link(href: "http://localhost:56912/users/69fe7726-d4e8-4857-a7c2-4d7032e4e3bf/creditCards/da5f93f6-b2cb-4243-b459-26ed2a9f4dc7/transactions?limit=2&offset=10"),
    'next': Link(href: "http://www.mocky.io/v2/5d49ea5d320000e47d600f31")
  },
  results: getGPRTransactions()
);
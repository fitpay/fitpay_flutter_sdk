import 'models.dart';

// class MockGPRAccount extends GPRAccount {
//   final String accountId = "f1b53bd9-5d56-4480-a15a-1eed06cdc203";
//   final String cardReferenceId = "123456789123";
//   final String deviceSerialNumber = "12345678";
//   final String state = "INACTIVE";
//   final String lastTransferId = "";
//   final String programUserId = "";
//   final String programAccountReferenceId = "";
//   final String i2cCardProgramId = "";
//   final List<String> programCardReferenceIds = [];
//   final double transferLimit = 0.0;
//   final List<String> errors = [];
//   final String createdTsEpoch = "2018-06-06 21:10:32.642";
//   final String lastModifiedTsEpoch = "2018-04-18 09:19:23";
// }

GPRAccount mockGPRAccount = GPRAccount(
    accountId: "f1b53bd9-5d56-4480-a15a-1eed06cdc203",
    cardReferenceId: "123456789123",
    deviceSerialNumber: "12345678",
    state: "INACTIVE",
    lastTransferId: "",
    programUserId: "",
    programAccountReferenceId: "",
    i2cCardProgramId: "",
    programCardReferenceIds: [],
    currentBalance: 786,
    transferLimit: 0.0,
    accountType: GprAccountType.GPR,
    errors: [],
    createdTsEpoch: "2018-06-06 21:10:32.642",
    lastModifiedTsEpoch: "2018-04-18 09:19:23",
    links: {
      'self': Link(href: "https://api.fit-pay.com/accounts/f1b53bd9-5d56-4480-a15a-1eed06cdc203"),
      'activate': Link(href: "http://www.mocky.io/v2/5d07c0813400004d005d94a1"),
      'convert': Link(href: "http://www.mocky.io/v2/5d07c0813400004d005d94a1")
    });

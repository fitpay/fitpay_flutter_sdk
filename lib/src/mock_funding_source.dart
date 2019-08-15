import 'models.dart';

FundingSource mockFundingSource = FundingSource(accountNumber: "12345678",
                                                routingNumber: "123456789",
                                                nameOnAccount: "John Doe",
                                                userId: "123456",
                                                fundingType: FundingType.ach,
                                                displayName: "John's Checkings",
                                                accountId: "f1b53bd9-5d56-4480-a15a-1eed06cdc203",); 

Page<FundingSource> mockFundingSources = Page<FundingSource>(
  limit: 10,
  offset: 0,
  totalResults: 1,
  results: [mockFundingSource],
  links: {"self": Link(href: "https://api.fit-pay.com/fundingSources")}
  );

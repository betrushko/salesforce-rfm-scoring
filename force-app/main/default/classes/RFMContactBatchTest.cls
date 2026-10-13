@IsTest
private class RFMContactBatchTest {
    @IsTest
    static void mapsDonorTypeAndHybridScores() {
        RFMContactMetricsBatch.Metrics oneTimeMetrics = new RFMContactMetricsBatch.Metrics();
        oneTimeMetrics.lifetimeSuccessfulDonations = 1;
        oneTimeMetrics.totalSuccessfulDonations24M = 1;
        System.assertEquals('One-Time Only', RFMContactMetricsBatch.donorTypeFor(0, oneTimeMetrics));
        System.assertEquals(3, RFMContactMetricsBatch.recencyScoreFor('One-Time Only', 365));
        System.assertEquals(1, RFMContactMetricsBatch.frequencyScoreFor('One-Time Only', 0, null, 1, 1));
        System.assertEquals(2, RFMContactMetricsBatch.frequencyScoreFor('One-Time Only', 0, null, 2, 2));
        System.assertEquals(3, RFMContactMetricsBatch.frequencyScoreFor('One-Time Only', 0, null, 3, 3));
        System.assertEquals(4, RFMContactMetricsBatch.frequencyScoreFor('One-Time Only', 0, null, 4, 4));
        System.assertEquals(5, RFMContactMetricsBatch.frequencyScoreFor('One-Time Only', 0, null, 5, 5));
        System.assertEquals(1, RFMContactMetricsBatch.frequencyScoreFor('One-Time Only', 0, null, 0, 1));
        System.assertEquals(0, RFMContactMetricsBatch.frequencyScoreFor('One-Time Only', 0, null, 0, 0));

        RFMContactMetricsBatch.Metrics mixedMetrics = new RFMContactMetricsBatch.Metrics();
        mixedMetrics.lifetimeSuccessfulDonations = 2;
        mixedMetrics.hasOneTimeSuccessfulDonation = true;
        System.assertEquals('Mixed', RFMContactMetricsBatch.donorTypeFor(1, mixedMetrics));
        System.assertEquals(4, RFMContactMetricsBatch.recencyScoreFor('Mixed', 65));
        System.assertEquals(5, RFMContactMetricsBatch.frequencyScoreFor('Mixed', 12, 1.00, 12, 12));

        System.assertEquals('No Successful Donations', RFMContactMetricsBatch.donorTypeFor(1, new RFMContactMetricsBatch.Metrics()));
        System.assertEquals(0, RFMContactMetricsBatch.recencyScoreFor('No Successful Donations', null));
    }

    @IsTest
    static void buildsContactMetricUpdatesWithoutTouchingExistingRollups() {
        Id contactId = fakeId('003', 1);
        Contact contactRecord = (Contact) JSON.deserialize(
            '{"attributes":{"type":"Contact"},"Id":"' + contactId + '"}',
            Contact.class
        );

        RFMContactMetricsBatch.Metrics metrics = new RFMContactMetricsBatch.Metrics();
        metrics.firstSuccessfulDonationDate = Date.newInstance(2025, 7, 6);
        metrics.lastSuccessfulDonationDate = Date.newInstance(2026, 7, 1);
        metrics.paidAmount12M = 1200;
        metrics.paidAmount24M = 1400;
        metrics.lifetimePaidAmount = 2000;
        metrics.totalSuccessfulDonations12M = 12;
        metrics.totalSuccessfulDonations24M = 14;
        metrics.lifetimeSuccessfulDonations = 14;
        metrics.recurringPayments12M = 12;

        Map<Id, RFMContactMetricsBatch.Metrics> metricsByContactId = new Map<Id, RFMContactMetricsBatch.Metrics>{
            contactId => metrics
        };
        Map<Id, List<RFMContactMetricsBatch.RecurringDonationWindow>> windowsByContactId = new Map<Id, List<RFMContactMetricsBatch.RecurringDonationWindow>>{
            contactId => new List<RFMContactMetricsBatch.RecurringDonationWindow>{
                new RFMContactMetricsBatch.RecurringDonationWindow(Date.newInstance(2025, 7, 6), null, 'Monthly', 'Open')
            }
        };

        List<Contact> updates = RFMContactMetricsBatch.buildUpdates(
            new List<Contact>{ contactRecord },
            metricsByContactId,
            windowsByContactId,
            Date.newInstance(2026, 7, 6)
        );

        System.assertEquals(1, updates.size());
        System.assertEquals('Recurring Only', updates[0].RFM_Donor_Type__c);
        System.assertEquals('Qualified', updates[0].RFM_Qualification_Status__c);
        System.assertEquals(Date.newInstance(2025, 7, 6), updates[0].RFM_First_Successful_Donation_Date__c);
        System.assertEquals(Date.newInstance(2026, 7, 1), updates[0].RFM_Last_Successful_Donation_Date__c);
        System.assertEquals(5, updates[0].RFM_Days_Since_Last_Donation__c);
        System.assertEquals(12, updates[0].RFM_Expected_Payments_12M__c);
        System.assertEquals(100.00, updates[0].RFM_Payment_Rate_12M__c);
        System.assertEquals(5, updates[0].RFM_Recency_Score__c);
        System.assertEquals(5, updates[0].RFM_Frequency_Score__c);
    }

    @IsTest
    static void expectedPaymentsProratesClosedRecurringDonations() {
        Date runDate = Date.newInstance(2026, 7, 6);
        List<RFMContactMetricsBatch.RecurringDonationWindow> windows = new List<RFMContactMetricsBatch.RecurringDonationWindow>{
            new RFMContactMetricsBatch.RecurringDonationWindow(Date.newInstance(2026, 1, 1), Date.newInstance(2026, 3, 15), 'Monthly', 'Closed'),
            new RFMContactMetricsBatch.RecurringDonationWindow(Date.newInstance(2024, 1, 1), Date.newInstance(2025, 1, 1), 'Monthly', 'Closed'),
            new RFMContactMetricsBatch.RecurringDonationWindow(Date.newInstance(2026, 4, 1), null, 'Quarterly', 'Paused')
        };

        System.assertEquals(5, RFMContactMetricsBatch.expectedPayments(windows, runDate));
    }

    @IsTest
    static void loadMetricsAggregatesContactOpportunities() {
        Account account = new Account(Name = 'RFM Contact Account');
        insert account;
        Contact contactRecord = new Contact(LastName = 'RFM Contact', AccountId = account.Id);
        insert contactRecord;
        npe03__Recurring_Donation__c recurringDonation = new npe03__Recurring_Donation__c(
            Name = 'RFM Contact RD',
            npe03__Contact__c = contactRecord.Id,
            npe03__Amount__c = 100,
            npe03__Date_Established__c = Date.today().addMonths(-18),
            npe03__Installment_Period__c = 'Monthly',
            npe03__Open_Ended_Status__c = 'Open'
        );
        insert recurringDonation;

        insert new List<Opportunity>{
            new Opportunity(
                Name = 'Recurring Payment',
                AccountId = account.Id,
                ContactId = contactRecord.Id,
                StageName = 'Closed Won',
                CloseDate = Date.today().addDays(-20),
                Amount = 100,
                npe03__Recurring_Donation__c = recurringDonation.Id
            ),
            new Opportunity(
                Name = 'One Time Donation',
                AccountId = account.Id,
                ContactId = contactRecord.Id,
                StageName = 'Closed Won',
                CloseDate = Date.today().addDays(-40),
                Amount = 50
            ),
            new Opportunity(
                Name = 'Ignored Open Donation',
                AccountId = account.Id,
                ContactId = contactRecord.Id,
                StageName = 'Pledged',
                CloseDate = Date.today().addDays(-10),
                Amount = 1000
            )
        };

        Map<Id, RFMContactMetricsBatch.Metrics> metricsByContactId = RFMContactMetricsBatch.loadOpportunityMetrics(
            new Set<Id>{ contactRecord.Id },
            Date.today()
        );

        RFMContactMetricsBatch.Metrics metrics = metricsByContactId.get(contactRecord.Id);
        System.assertEquals(2, metrics.lifetimeSuccessfulDonations);
        System.assertEquals(150, metrics.lifetimePaidAmount);
        System.assertEquals(1, metrics.recurringPayments12M);
        System.assertEquals(1, metrics.oneTimeDonations12M);
        System.assertEquals(true, metrics.hasOneTimeSuccessfulDonation);
    }

    @IsTest
    static void calculatesContactMonetaryPercentilesAndScores() {
        System.assertEquals(0.00, RFMContactMonetaryPercentileBatch.percentileForRank(1, 4));
        System.assertEquals(33.33, RFMContactMonetaryPercentileBatch.percentileForRank(2, 4));
        System.assertEquals(100.00, RFMContactMonetaryPercentileBatch.percentileForRank(4, 4));
        System.assertEquals(5, RFMContactMonetaryPercentileBatch.monetaryScoreFor(100, 80));
        System.assertEquals(0, RFMContactMonetaryPercentileBatch.monetaryScoreFor(0, 100));
        System.assertEquals(0, RFMContactMonetaryPercentileBatch.monetaryScoreFor(100, null));
    }

    @IsTest
    static void statusUsesEliteProtectionAndNoStrongSegment() {
        System.assertEquals(5.00, RFMContactStatusBatch.scoreFor(5, 5, 5));
        System.assertEquals(3.75, RFMContactStatusBatch.scoreFor(4, 4, 3));
        System.assertEquals('Unqualified', RFMContactStatusBatch.statusFor('No Successful Donations', 5, 5, 5));
        System.assertEquals('Elite', RFMContactStatusBatch.statusFor('Qualified', 4.50, 4, 4));
        System.assertEquals('Stable', RFMContactStatusBatch.statusFor('Qualified', 4.49, 4, 4));
        System.assertEquals('Stable', RFMContactStatusBatch.statusFor('Qualified', 4.50, 4, 3));
        System.assertEquals('Stable', RFMContactStatusBatch.statusFor('Qualified', 4.50, 3, 4));
        System.assertEquals('Stable', RFMContactStatusBatch.statusFor('Qualified', 4.00, 5, 5));
        System.assertEquals('At Risk', RFMContactStatusBatch.statusFor('Qualified', 2.50, 3, 3));
        System.assertEquals('Critical', RFMContactStatusBatch.statusFor('Qualified', 1.99, 2, 2));
    }

    @IsTest
    static void batchEntrypointsHandleEmptyScopes() {
        Test.startTest();
        new RFMContactMetricsBatch().execute((Database.BatchableContext) null, new List<Contact>());
        new RFMContactStatusBatch().execute((Database.BatchableContext) null, new List<Contact>());
        new RFMContactMetricsBatch().execute((SchedulableContext) null);
        new RFMContactStatusBatch().execute((SchedulableContext) null);
        Test.stopTest();
    }

    @IsTest
    static void metricsBatchExecuteUpdatesInsertedContact() {
        Contact contactRecord = new Contact(LastName = 'Metrics Execute');
        insert contactRecord;

        RFMContactMetricsBatch.Metrics metrics = new RFMContactMetricsBatch.Metrics();
        metrics.firstSuccessfulDonationDate = Date.today().addMonths(-14);
        metrics.lastSuccessfulDonationDate = Date.today().addDays(-10);
        metrics.paidAmount12M = 1200;
        metrics.paidAmount24M = 1400;
        metrics.lifetimePaidAmount = 1500;
        metrics.totalSuccessfulDonations12M = 12;
        metrics.totalSuccessfulDonations24M = 14;
        metrics.lifetimeSuccessfulDonations = 14;
        metrics.recurringPayments12M = 12;

        RFMContactMetricsBatch.metricsOverride = new Map<Id, RFMContactMetricsBatch.Metrics>{
            contactRecord.Id => metrics
        };
        RFMContactMetricsBatch.recurringDonationOverride = new Map<Id, List<RFMContactMetricsBatch.RecurringDonationWindow>>{
            contactRecord.Id => new List<RFMContactMetricsBatch.RecurringDonationWindow>{
                new RFMContactMetricsBatch.RecurringDonationWindow(Date.today().addMonths(-14), null, 'Monthly', 'Open')
            }
        };

        Test.startTest();
        new RFMContactMetricsBatch().execute((Database.BatchableContext) null, new List<Contact>{
            [
                SELECT Id,
                    RFM_Donor_Type__c,
                    RFM_Qualification_Status__c,
                    RFM_First_Successful_Donation_Date__c,
                    RFM_Last_Successful_Donation_Date__c,
                    RFM_Days_Since_Last_Donation__c,
                    RFM_Paid_Amount_12M__c,
                    RFM_Paid_Amount_24M__c,
                    RFM_Lifetime_Paid_Amount__c,
                    RFM_Donor_Age_Months__c,
                    RFM_Avg_Monthly_Value_12M__c,
                    RFM_Avg_Monthly_Value_Lifetime__c,
                    RFM_Total_Successful_Donations_12M__c,
                    RFM_Total_Successful_Donations_24M__c,
                    RFM_Lifetime_Successful_Donations__c,
                    RFM_One_Time_Donations_12M__c,
                    RFM_One_Time_Donations_24M__c,
                    RFM_Expected_Payments_12M__c,
                    RFM_Successful_Payments_12M__c,
                    RFM_Payment_Rate_12M__c,
                    RFM_Recency_Score__c,
                    RFM_Frequency_Score__c
                FROM Contact
                WHERE Id = :contactRecord.Id
            ]
        });
        Test.stopTest();

        Contact updatedContact = [
            SELECT RFM_Donor_Type__c, RFM_Frequency_Score__c
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];
        System.assertEquals('Recurring Only', updatedContact.RFM_Donor_Type__c);
        System.assertEquals(5, updatedContact.RFM_Frequency_Score__c);

        RFMContactMetricsBatch.metricsOverride = null;
        RFMContactMetricsBatch.recurringDonationOverride = null;
    }

    @IsTest
    static void monetaryFinishUpdatesPercentilesAndChainsStatus() {
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'P1', RFM_Paid_Amount_12M__c = 0, RFM_Lifetime_Paid_Amount__c = 100, RFM_Donor_Age_Months__c = 6),
            new Contact(LastName = 'P2', RFM_Paid_Amount_12M__c = 100, RFM_Lifetime_Paid_Amount__c = 200, RFM_Donor_Age_Months__c = 6),
            new Contact(LastName = 'P3', RFM_Paid_Amount_12M__c = 100, RFM_Lifetime_Paid_Amount__c = 300, RFM_Donor_Age_Months__c = 6),
            new Contact(LastName = 'P4', RFM_Paid_Amount_12M__c = 400, RFM_Lifetime_Paid_Amount__c = 400, RFM_Donor_Age_Months__c = 6)
        };
        insert contacts;
        Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();

        Test.startTest();
        RFMContactMonetaryPercentileBatch recentBatch = new RFMContactMonetaryPercentileBatch(true);
        recentBatch.totalRecords = contacts.size();
        recentBatch.execute((Database.BatchableContext) null, [
            SELECT Id,
                RFM_Paid_Amount_12M__c,
                RFM_Recent_Monetary_Percentile__c
            FROM Contact
            WHERE Id IN :contactIds
            ORDER BY RFM_Paid_Amount_12M__c ASC, Id ASC
        ]);

        RFMContactMonetaryPercentileBatch historicalBatch = new RFMContactMonetaryPercentileBatch(false);
        historicalBatch.totalRecords = contacts.size();
        historicalBatch.execute((Database.BatchableContext) null, [
            SELECT Id,
                RFM_Lifetime_Paid_Amount__c,
                RFM_Donor_Age_Months__c,
                RFM_Recent_Monetary_Percentile__c,
                RFM_Historical_Monetary_Percentile__c,
                RFM_Balanced_Monetary_Percentile__c,
                RFM_Monetary_Score__c,
                RFM_Rising_Star_Flag__c
            FROM Contact
            WHERE Id IN :contactIds
            ORDER BY RFM_Lifetime_Paid_Amount__c ASC, Id ASC
        ]);
        Test.stopTest();

        Contact topContact = [
            SELECT RFM_Recent_Monetary_Percentile__c,
                RFM_Historical_Monetary_Percentile__c,
                RFM_Balanced_Monetary_Percentile__c,
                RFM_Monetary_Score__c,
                RFM_Rising_Star_Flag__c
            FROM Contact
            WHERE Id = :contacts[3].Id
        ];
        System.assertEquals(100.00, topContact.RFM_Recent_Monetary_Percentile__c);
        System.assertEquals(100.00, topContact.RFM_Historical_Monetary_Percentile__c);
        System.assertEquals(100.00, topContact.RFM_Balanced_Monetary_Percentile__c);
        System.assertEquals(5, topContact.RFM_Monetary_Score__c);
        System.assertEquals(true, topContact.RFM_Rising_Star_Flag__c);
    }

    @IsTest
    static void statusBuildsAndExecutesUpdates() {
        Id contactId = fakeId('003', 9);
        Contact contactRecord = (Contact) JSON.deserialize(
            '{"attributes":{"type":"Contact"},"Id":"' + contactId + '","RFM_Qualification_Status__c":"Qualified","RFM_Recency_Score__c":5,"RFM_Frequency_Score__c":5,"RFM_Monetary_Score__c":5,"RFM_Final_Score__c":1,"RFM_Status__c":"Critical"}',
            Contact.class
        );

        List<Contact> updates = RFMContactStatusBatch.buildUpdates(new List<Contact>{ contactRecord });
        System.assertEquals(1, updates.size());
        System.assertEquals(5.00, updates[0].RFM_Final_Score__c);
        System.assertEquals('Elite', updates[0].RFM_Status__c);

        Contact insertedContact = new Contact(
            LastName = 'Status Execute',
            RFM_Qualification_Status__c = 'Qualified',
            RFM_Recency_Score__c = 5,
            RFM_Frequency_Score__c = 5,
            RFM_Monetary_Score__c = 5
        );
        insert insertedContact;

        Test.startTest();
        new RFMContactStatusBatch().execute((Database.BatchableContext) null, [
            SELECT Id,
                RFM_Qualification_Status__c,
                RFM_Recency_Score__c,
                RFM_Frequency_Score__c,
                RFM_Monetary_Score__c,
                RFM_Final_Score__c,
                RFM_Status__c
            FROM Contact
            WHERE Id = :insertedContact.Id
        ]);
        Test.stopTest();

        Contact updatedContact = [
            SELECT RFM_Final_Score__c, RFM_Status__c
            FROM Contact
            WHERE Id = :insertedContact.Id
        ];
        System.assertEquals(5.00, updatedContact.RFM_Final_Score__c);
        System.assertEquals('Elite', updatedContact.RFM_Status__c);
    }

    private static Id fakeId(String prefix, Integer index) {
        return (Id) (prefix + String.valueOf(index).leftPad(12, '0') + 'AAA');
    }
}

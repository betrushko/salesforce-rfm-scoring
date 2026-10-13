@IsTest
private class RFMRawMetricsBatchTest {
    @IsTest
    static void buildsUpdatesFromAggregatedMetrics() {
        Id recurringDonationId = fakeId('a09', 1);
        npe03__Recurring_Donation__c recurringDonation = (npe03__Recurring_Donation__c) JSON.deserialize(
            '{"attributes":{"type":"npe03__Recurring_Donation__c"},"Id":"' + recurringDonationId + '"}',
            npe03__Recurring_Donation__c.class
        );

        RFMRawMetricsBatch.Metrics metrics = new RFMRawMetricsBatch.Metrics();
        metrics.lastSuccessfulPaymentDate = Date.newInstance(2026, 6, 1);
        metrics.successfulPayments12M = 11;
        metrics.paidAmount12M = 1100;
        metrics.lifetimePaidAmount = 2500;

        Map<Id, RFMRawMetricsBatch.Metrics> metricsById = new Map<Id, RFMRawMetricsBatch.Metrics>{
            recurringDonationId => metrics
        };

        List<npe03__Recurring_Donation__c> updates = RFMRawMetricsBatch.buildUpdates(
            new List<npe03__Recurring_Donation__c>{ recurringDonation },
            metricsById
        );

        System.assertEquals(1, updates.size());
        System.assertEquals(Date.newInstance(2026, 6, 1), updates[0].Last_Successful_Payment_Date__c);
        System.assertEquals(11, updates[0].Successful_Payments_12M__c);
        System.assertEquals(1100, updates[0].Paid_Amount_12M__c);
        System.assertEquals(2500, updates[0].Lifetime_Paid_Amount__c);
    }

    @IsTest
    static void setsZeroMetricsWhenNoPaymentsExist() {
        Id recurringDonationId = fakeId('a09', 2);
        npe03__Recurring_Donation__c recurringDonation = (npe03__Recurring_Donation__c) JSON.deserialize(
            '{"attributes":{"type":"npe03__Recurring_Donation__c"},"Id":"' + recurringDonationId + '","Successful_Payments_12M__c":5,"Paid_Amount_12M__c":500,"Lifetime_Paid_Amount__c":900}',
            npe03__Recurring_Donation__c.class
        );

        List<npe03__Recurring_Donation__c> updates = RFMRawMetricsBatch.buildUpdates(
            new List<npe03__Recurring_Donation__c>{ recurringDonation },
            new Map<Id, RFMRawMetricsBatch.Metrics>()
        );

        System.assertEquals(1, updates.size());
        System.assertEquals(null, updates[0].Last_Successful_Payment_Date__c);
        System.assertEquals(0, updates[0].Successful_Payments_12M__c);
        System.assertEquals(0, updates[0].Paid_Amount_12M__c);
        System.assertEquals(0, updates[0].Lifetime_Paid_Amount__c);
    }

    @IsTest
    static void calculatesPercentRankForMonetaryPercentile() {
        System.assertEquals(null, RFMMonetaryPercentileBatch.percentileForRank(null, 10));
        System.assertEquals(null, RFMMonetaryPercentileBatch.percentileForRank(1, 0));
        System.assertEquals(100, RFMMonetaryPercentileBatch.percentileForRank(1, 1));
        System.assertEquals(0.00, RFMMonetaryPercentileBatch.percentileForRank(1, 5));
        System.assertEquals(50.00, RFMMonetaryPercentileBatch.percentileForRank(3, 5));
        System.assertEquals(100.00, RFMMonetaryPercentileBatch.percentileForRank(5, 5));
    }

    @IsTest
    static void rawBatchHandlesEmptyScope() {
        new RFMRawMetricsBatch().execute(
            (Database.BatchableContext) null,
            new List<npe03__Recurring_Donation__c>()
        );
    }

    @IsTest
    static void rawBatchExecuteUsesLoadedMetrics() {
        Id recurringDonationId = fakeId('a09', 3);
        npe03__Recurring_Donation__c recurringDonation = (npe03__Recurring_Donation__c) JSON.deserialize(
            '{"attributes":{"type":"npe03__Recurring_Donation__c"},"Id":"' + recurringDonationId + '","Last_Successful_Payment_Date__c":"2026-06-01","Successful_Payments_12M__c":11,"Paid_Amount_12M__c":1100,"Lifetime_Paid_Amount__c":2500}',
            npe03__Recurring_Donation__c.class
        );

        RFMRawMetricsBatch.Metrics metrics = new RFMRawMetricsBatch.Metrics();
        metrics.lastSuccessfulPaymentDate = Date.newInstance(2026, 6, 1);
        metrics.successfulPayments12M = 11;
        metrics.paidAmount12M = 1100;
        metrics.lifetimePaidAmount = 2500;

        RFMRawMetricsBatch.metricsOverride = new Map<Id, RFMRawMetricsBatch.Metrics>{
            recurringDonationId => metrics
        };

        new RFMRawMetricsBatch().execute(
            (Database.BatchableContext) null,
            new List<npe03__Recurring_Donation__c>{ recurringDonation }
        );

        RFMRawMetricsBatch.metricsOverride = null;
    }

    @IsTest
    static void loadMetricsAggregatesClosedWonOpportunities() {
        Account account = new Account(Name = 'RFM Test Account');
        insert account;

        npe03__Recurring_Donation__c recurringDonation = new npe03__Recurring_Donation__c(
            Name = 'RFM Test Recurring Donation',
            npe03__Organization__c = account.Id,
            npe03__Amount__c = 100,
            npe03__Date_Established__c = Date.today().addMonths(-18),
            npe03__Installment_Period__c = 'Monthly',
            npe03__Open_Ended_Status__c = 'Open'
        );
        insert recurringDonation;

        insert new List<Opportunity>{
            new Opportunity(
                Name = 'RFM Test Current Payment',
                AccountId = account.Id,
                StageName = 'Closed Won',
                CloseDate = Date.today().addDays(-30),
                Amount = 100,
                npe03__Recurring_Donation__c = recurringDonation.Id
            ),
            new Opportunity(
                Name = 'RFM Test Previous Payment',
                AccountId = account.Id,
                StageName = 'Closed Won',
                CloseDate = Date.today().addDays(-400),
                Amount = 200,
                npe03__Recurring_Donation__c = recurringDonation.Id
            )
        };

        Map<Id, RFMRawMetricsBatch.Metrics> metricsById = RFMRawMetricsBatch.loadMetrics(
            new Set<Id>{ recurringDonation.Id },
            Date.today().addDays(-365)
        );

        System.assertEquals(1, metricsById.size());
        System.assertEquals(Date.today().addDays(-30), metricsById.get(recurringDonation.Id).lastSuccessfulPaymentDate);
        System.assertEquals(1, metricsById.get(recurringDonation.Id).successfulPayments12M);
        System.assertEquals(100, metricsById.get(recurringDonation.Id).paidAmount12M);
        System.assertEquals(300, metricsById.get(recurringDonation.Id).lifetimePaidAmount);
    }

    @IsTest
    static void percentileBatchProcessesOrderedScopeWithoutUpdates() {
        RFMMonetaryPercentileBatch recentBatch = new RFMMonetaryPercentileBatch(true);
        recentBatch.totalRecords = 5;

        List<npe03__Recurring_Donation__c> scope = new List<npe03__Recurring_Donation__c>{
            percentileRecord(1, 0, 100, 0, null, null, null),
            percentileRecord(2, 10, 200, 25, null, null, null),
            percentileRecord(3, 10, 300, 25, null, null, null),
            percentileRecord(4, 20, 400, 75, null, null, null),
            percentileRecord(5, 30, 500, 100, null, null, null)
        };

        recentBatch.execute((Database.BatchableContext) null, scope);

        System.assertEquals(5, recentBatch.processedRecords);
        System.assertEquals(30, recentBatch.currentAmount);
        System.assertEquals(5, recentBatch.currentTieStartRank);

        RFMMonetaryPercentileBatch historicalBatch = new RFMMonetaryPercentileBatch(false);
        historicalBatch.totalRecords = 5;
        historicalBatch.execute((Database.BatchableContext) null, new List<npe03__Recurring_Donation__c>{
            percentileRecord(1, 0, 100, 0, 0, 0, 0),
            percentileRecord(2, 10, 200, 25, 25, 25, 25),
            percentileRecord(3, 10, 300, 25, 50, 37.50, 37.50),
            percentileRecord(4, 20, 400, 75, 75, 75, 75),
            percentileRecord(5, 30, 500, 100, 100, 100, 100)
        });

        System.assertEquals(5, historicalBatch.processedRecords);
        System.assertEquals(500, historicalBatch.currentAmount);
        System.assertEquals(5, historicalBatch.currentTieStartRank);
    }

    @IsTest
    static void scheduleEntrypointStartsRawBatch() {
        Test.startTest();
        new RFMRawMetricsBatch().execute((SchedulableContext) null);
        Test.stopTest();
    }

    private static Id fakeId(String prefix, Integer index) {
        return (Id) (prefix + String.valueOf(index).leftPad(12, '0') + 'AAA');
    }

    private static npe03__Recurring_Donation__c percentileRecord(
        Integer index,
        Decimal paidAmount12M,
        Decimal lifetimePaidAmount,
        Decimal recentPercentile,
        Decimal historicalPercentile,
        Decimal balancedPercentile,
        Decimal monetaryPercentile
    ) {
        return (npe03__Recurring_Donation__c) JSON.deserialize(
            '{"attributes":{"type":"npe03__Recurring_Donation__c"},"Id":"' + fakeId('a09', index) + '","Paid_Amount_12M__c":' + paidAmount12M + ',"Lifetime_Paid_Amount__c":' + lifetimePaidAmount + ',"Recent_Monetary_Percentile__c":' + recentPercentile + ',"Historical_Monetary_Percentile__c":' + historicalPercentile + ',"Balanced_Monetary_Percentile__c":' + balancedPercentile + ',"Monetary_Percentile__c":' + monetaryPercentile + '}',
            npe03__Recurring_Donation__c.class
        );
    }
}

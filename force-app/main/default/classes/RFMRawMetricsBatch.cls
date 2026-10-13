public with sharing class RFMRawMetricsBatch implements Database.Batchable<SObject>, Schedulable {
    @TestVisible
    private static Map<Id, Metrics> metricsOverride;

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                Last_Successful_Payment_Date__c,
                Successful_Payments_12M__c,
                Paid_Amount_12M__c,
                Lifetime_Paid_Amount__c
            FROM npe03__Recurring_Donation__c
        ]);
    }

    public void execute(Database.BatchableContext context, List<npe03__Recurring_Donation__c> scope) {
        Set<Id> recurringDonationIds = new Set<Id>();
        for (npe03__Recurring_Donation__c recurringDonation : scope) {
            recurringDonationIds.add(recurringDonation.Id);
        }

        Map<Id, Metrics> metricsByRecurringDonationId = loadMetrics(recurringDonationIds, Date.today().addDays(-365));
        List<npe03__Recurring_Donation__c> updates = buildUpdates(scope, metricsByRecurringDonationId);

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext context) {
        Database.executeBatch(new RFMMonetaryPercentileBatch(), 200);
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new RFMRawMetricsBatch(), 200);
    }

    @TestVisible
    private static Map<Id, Metrics> loadMetrics(Set<Id> recurringDonationIds, Date cutoffDate) {
        if (Test.isRunningTest() && metricsOverride != null) {
            return metricsOverride;
        }
        Map<Id, Metrics> metricsByRecurringDonationId = new Map<Id, Metrics>();
        if (recurringDonationIds.isEmpty()) {
            return metricsByRecurringDonationId;
        }

        for (AggregateResult aggregateRow : [
            SELECT npe03__Recurring_Donation__c recurringDonationId,
                MAX(CloseDate) lastSuccessfulPaymentDate,
                SUM(Amount) lifetimePaidAmount
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND npe03__Recurring_Donation__c IN :recurringDonationIds
            GROUP BY npe03__Recurring_Donation__c
        ]) {
            Id recurringDonationId = (Id) aggregateRow.get('recurringDonationId');
            Metrics metrics = getOrCreateMetrics(metricsByRecurringDonationId, recurringDonationId);
            metrics.lastSuccessfulPaymentDate = (Date) aggregateRow.get('lastSuccessfulPaymentDate');
            metrics.lifetimePaidAmount = decimalValue(aggregateRow.get('lifetimePaidAmount'));
        }

        for (AggregateResult aggregateRow : [
            SELECT npe03__Recurring_Donation__c recurringDonationId,
                COUNT(Id) successfulPayments12M,
                SUM(Amount) paidAmount12M
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND CloseDate >= :cutoffDate
            AND npe03__Recurring_Donation__c IN :recurringDonationIds
            GROUP BY npe03__Recurring_Donation__c
        ]) {
            Id recurringDonationId = (Id) aggregateRow.get('recurringDonationId');
            Metrics metrics = getOrCreateMetrics(metricsByRecurringDonationId, recurringDonationId);
            metrics.successfulPayments12M = integerValue(aggregateRow.get('successfulPayments12M'));
            metrics.paidAmount12M = decimalValue(aggregateRow.get('paidAmount12M'));
        }

        return metricsByRecurringDonationId;
    }

    @TestVisible
    private static List<npe03__Recurring_Donation__c> buildUpdates(
        List<npe03__Recurring_Donation__c> scope,
        Map<Id, Metrics> metricsByRecurringDonationId
    ) {
        List<npe03__Recurring_Donation__c> updates = new List<npe03__Recurring_Donation__c>();
        for (npe03__Recurring_Donation__c recurringDonation : scope) {
            Metrics metrics = metricsByRecurringDonationId.get(recurringDonation.Id);
            Date nextLastSuccessfulPaymentDate = metrics == null ? null : metrics.lastSuccessfulPaymentDate;
            Decimal nextSuccessfulPayments12M = metrics == null ? 0 : metrics.successfulPayments12M;
            Decimal nextPaidAmount12M = metrics == null ? 0 : metrics.paidAmount12M;
            Decimal nextLifetimePaidAmount = metrics == null ? 0 : metrics.lifetimePaidAmount;

            if (
                recurringDonation.Last_Successful_Payment_Date__c != nextLastSuccessfulPaymentDate ||
                recurringDonation.Successful_Payments_12M__c != nextSuccessfulPayments12M ||
                recurringDonation.Paid_Amount_12M__c != nextPaidAmount12M ||
                recurringDonation.Lifetime_Paid_Amount__c != nextLifetimePaidAmount
            ) {
                updates.add(new npe03__Recurring_Donation__c(
                    Id = recurringDonation.Id,
                    Last_Successful_Payment_Date__c = nextLastSuccessfulPaymentDate,
                    Successful_Payments_12M__c = nextSuccessfulPayments12M,
                    Paid_Amount_12M__c = nextPaidAmount12M,
                    Lifetime_Paid_Amount__c = nextLifetimePaidAmount
                ));
            }
        }
        return updates;
    }

    private static Metrics getOrCreateMetrics(Map<Id, Metrics> metricsByRecurringDonationId, Id recurringDonationId) {
        if (!metricsByRecurringDonationId.containsKey(recurringDonationId)) {
            metricsByRecurringDonationId.put(recurringDonationId, new Metrics());
        }
        return metricsByRecurringDonationId.get(recurringDonationId);
    }

    private static Decimal decimalValue(Object value) {
        return value == null ? 0 : (Decimal) value;
    }

    private static Integer integerValue(Object value) {
        return value == null ? 0 : (Integer) value;
    }

    public class Metrics {
        public Date lastSuccessfulPaymentDate;
        public Integer successfulPayments12M = 0;
        public Decimal paidAmount12M = 0;
        public Decimal lifetimePaidAmount = 0;
    }
}

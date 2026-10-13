public with sharing class RFMStatusBatch implements Database.Batchable<SObject>, Schedulable {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                Recency_Score__c,
                Frequency_Score__c,
                Monetary_Score__c,
                RFM_Score__c,
                RFM_Status__c
            FROM npe03__Recurring_Donation__c
        ]);
    }

    public void execute(Database.BatchableContext context, List<npe03__Recurring_Donation__c> scope) {
        List<npe03__Recurring_Donation__c> updates = buildUpdates(scope);

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    @TestVisible
    private static List<npe03__Recurring_Donation__c> buildUpdates(List<npe03__Recurring_Donation__c> scope) {
        List<npe03__Recurring_Donation__c> updates = new List<npe03__Recurring_Donation__c>();
        for (npe03__Recurring_Donation__c recurringDonation : scope) {
            Decimal nextScore = scoreFor(
                recurringDonation.Recency_Score__c,
                recurringDonation.Frequency_Score__c,
                recurringDonation.Monetary_Score__c
            );
            String nextStatus = statusFor(
                nextScore,
                recurringDonation.Recency_Score__c,
                recurringDonation.Frequency_Score__c
            );
            if (nextScore != recurringDonation.RFM_Score__c || nextStatus != recurringDonation.RFM_Status__c) {
                updates.add(new npe03__Recurring_Donation__c(
                    Id = recurringDonation.Id,
                    RFM_Score__c = nextScore,
                    RFM_Status__c = nextStatus
                ));
            }
        }
        return updates;
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new RFMStatusBatch(), 200);
    }

    public static String statusFor(Decimal score, Decimal recencyScore, Decimal frequencyScore) {
        if (score == null) {
            return null;
        }
        if (score >= 4.25 && recencyScore >= 4 && frequencyScore >= 3) {
            return 'Elite';
        }
        if (score >= 3) {
            return 'Stable';
        }
        if (score >= 2) {
            return 'At Risk';
        }
        return 'Critical';
    }

    public static Decimal scoreFor(Decimal recencyScore, Decimal frequencyScore, Decimal monetaryScore) {
        if (recencyScore == null || frequencyScore == null || monetaryScore == null) {
            return null;
        }
        return ((0.40 * recencyScore) + (0.35 * frequencyScore) + (0.25 * monetaryScore)).setScale(2);
    }
}

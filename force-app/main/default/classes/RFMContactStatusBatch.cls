public with sharing class RFMContactStatusBatch implements Database.Batchable<SObject>, Schedulable {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                RFM_Qualification_Status__c,
                RFM_Recency_Score__c,
                RFM_Frequency_Score__c,
                RFM_Monetary_Score__c,
                RFM_Final_Score__c,
                RFM_Status__c
            FROM Contact
        ]);
    }

    public void execute(Database.BatchableContext context, List<Contact> scope) {
        List<Contact> updates = buildUpdates(scope);
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new RFMContactStatusBatch(), 200);
    }

    @TestVisible
    private static List<Contact> buildUpdates(List<Contact> scope) {
        List<Contact> updates = new List<Contact>();
        for (Contact contactRecord : scope) {
            Decimal nextScore = scoreFor(
                contactRecord.RFM_Recency_Score__c,
                contactRecord.RFM_Frequency_Score__c,
                contactRecord.RFM_Monetary_Score__c
            );
            String nextStatus = statusFor(
                contactRecord.RFM_Qualification_Status__c,
                nextScore,
                contactRecord.RFM_Recency_Score__c,
                contactRecord.RFM_Frequency_Score__c
            );
            if (contactRecord.RFM_Final_Score__c != nextScore || contactRecord.RFM_Status__c != nextStatus) {
                updates.add(new Contact(
                    Id = contactRecord.Id,
                    RFM_Final_Score__c = nextScore,
                    RFM_Status__c = nextStatus
                ));
            }
        }
        return updates;
    }

    public static Decimal scoreFor(Decimal recencyScore, Decimal frequencyScore, Decimal monetaryScore) {
        if (recencyScore == null || frequencyScore == null || monetaryScore == null) {
            return null;
        }
        return ((0.40 * recencyScore) + (0.35 * frequencyScore) + (0.25 * monetaryScore)).setScale(2);
    }

    public static String statusFor(String qualificationStatus, Decimal finalScore, Decimal recencyScore, Decimal frequencyScore) {
        if (qualificationStatus != 'Qualified' || finalScore == null) {
            return 'Unqualified';
        }
        if (finalScore >= 4.50 && recencyScore >= 4 && frequencyScore >= 4) {
            return 'Elite';
        }
        if (finalScore >= 3.00) {
            return 'Stable';
        }
        if (finalScore >= 2.00) {
            return 'At Risk';
        }
        return 'Critical';
    }
}

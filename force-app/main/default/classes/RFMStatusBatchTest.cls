@IsTest
private class RFMStatusBatchTest {
    @IsTest
    static void mapsScoreToStatus() {
        System.assertEquals(null, RFMStatusBatch.statusFor(null, 5, 5));
        System.assertEquals('Critical', RFMStatusBatch.statusFor(1.99, 5, 5));
        System.assertEquals('At Risk', RFMStatusBatch.statusFor(2, 5, 5));
        System.assertEquals('Stable', RFMStatusBatch.statusFor(3, 5, 5));
        System.assertEquals('Stable', RFMStatusBatch.statusFor(4.24, 5, 5));
        System.assertEquals('Stable', RFMStatusBatch.statusFor(4.5, 3, 5));
        System.assertEquals('Stable', RFMStatusBatch.statusFor(4.5, 5, 2));
        System.assertEquals('Elite', RFMStatusBatch.statusFor(4.25, 4, 3));
    }

    @IsTest
    static void calculatesWeightedScore() {
        System.assertEquals(null, RFMStatusBatch.scoreFor(null, 5, 5));
        System.assertEquals(5.00, RFMStatusBatch.scoreFor(5, 5, 5));
        System.assertEquals(3.75, RFMStatusBatch.scoreFor(4, 4, 3));
    }

    @IsTest
    static void buildsUpdatesWhenScoreOrStatusChanges() {
        npe03__Recurring_Donation__c changedRecord = (npe03__Recurring_Donation__c) JSON.deserialize(
            '{"attributes":{"type":"npe03__Recurring_Donation__c"},"Recency_Score__c":4,"Frequency_Score__c":4,"Monetary_Score__c":3,"RFM_Score__c":1,"RFM_Status__c":"Critical"}',
            npe03__Recurring_Donation__c.class
        );
        npe03__Recurring_Donation__c unchangedRecord = (npe03__Recurring_Donation__c) JSON.deserialize(
            '{"attributes":{"type":"npe03__Recurring_Donation__c"},"Recency_Score__c":4,"Frequency_Score__c":4,"Monetary_Score__c":3,"RFM_Score__c":3.75,"RFM_Status__c":"Stable"}',
            npe03__Recurring_Donation__c.class
        );

        List<npe03__Recurring_Donation__c> updates = RFMStatusBatch.buildUpdates(new List<npe03__Recurring_Donation__c>{
            changedRecord,
            unchangedRecord
        });

        System.assertEquals(1, updates.size());
        System.assertEquals(3.75, updates[0].RFM_Score__c);
        System.assertEquals('Stable', updates[0].RFM_Status__c);
    }

    @IsTest
    static void handlesEmptyBatchScopeAndScheduleEntryPoint() {
        Test.startTest();
        new RFMStatusBatch().execute((Database.BatchableContext) null, new List<npe03__Recurring_Donation__c>());
        new RFMStatusBatch().execute((SchedulableContext) null);
        Test.stopTest();
    }
}

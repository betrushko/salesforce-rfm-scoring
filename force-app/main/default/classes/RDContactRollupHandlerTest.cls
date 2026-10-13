@IsTest
private class RDContactRollupHandlerTest {
    @IsTest
    static void ignoresUpdatesThatDoNotAffectContactRollup() {
        Id contactId = fakeId('003', 1);
        npe03__Recurring_Donation__c oldRecord = recurringDonation(contactId, 'Open', null);
        npe03__Recurring_Donation__c newRecord = recurringDonation(contactId, 'Open', null);
        newRecord.Last_Successful_Payment_Date__c = Date.today();
        newRecord.Successful_Payments_12M__c = 12;
        newRecord.Paid_Amount_12M__c = 1200;
        newRecord.Lifetime_Paid_Amount__c = 2400;
        newRecord.Monetary_Percentile__c = 80;

        Set<Id> contactIds = RecurringDonationContactRollupHandler.collectAffectedContactIds(
            new List<npe03__Recurring_Donation__c>{ newRecord },
            new List<npe03__Recurring_Donation__c>{ oldRecord }
        );

        System.assertEquals(0, contactIds.size());
    }

    @IsTest
    static void includesContactWhenRollupFieldsChange() {
        Id contactId = fakeId('003', 2);
        npe03__Recurring_Donation__c oldRecord = recurringDonation(contactId, 'Open', null);
        npe03__Recurring_Donation__c newRecord = recurringDonation(contactId, 'Closed', 'Regla de negocios');

        Set<Id> contactIds = RecurringDonationContactRollupHandler.collectAffectedContactIds(
            new List<npe03__Recurring_Donation__c>{ newRecord },
            new List<npe03__Recurring_Donation__c>{ oldRecord }
        );

        System.assertEquals(new Set<Id>{ contactId }, contactIds);
    }

    @IsTest
    static void runReturnsNoContactUpdatesForRfmOnlyUpdates() {
        Id contactId = fakeId('003', 3);
        npe03__Recurring_Donation__c oldRecord = recurringDonation(contactId, 'Open', null);
        npe03__Recurring_Donation__c newRecord = recurringDonation(contactId, 'Open', null);
        newRecord.Monetary_Percentile__c = 50;

        npsp.TDTM_Runnable.DmlWrapper wrapper = new RecurringDonationContactRollupHandler().run(
            new List<SObject>{ newRecord },
            new List<SObject>{ oldRecord },
            npsp.TDTM_Runnable.Action.AfterUpdate,
            npe03__Recurring_Donation__c.SObjectType.getDescribe()
        );

        System.assertEquals(0, wrapper.objectsToUpdate.size());
    }

    @IsTest
    static void runBuildsContactUpdateForInsert() {
        Id contactId = fakeId('003', 4);
        npe03__Recurring_Donation__c newRecord = recurringDonation(contactId, 'Open', null);

        npsp.TDTM_Runnable.DmlWrapper wrapper = new RecurringDonationContactRollupHandler().run(
            new List<SObject>{ newRecord },
            null,
            npsp.TDTM_Runnable.Action.AfterInsert,
            npe03__Recurring_Donation__c.SObjectType.getDescribe()
        );

        System.assertEquals(1, wrapper.objectsToUpdate.size());
        System.assertEquals(contactId, ((Contact) wrapper.objectsToUpdate[0]).Id);
    }

    @IsTest
    static void runBuildsContactUpdateForDelete() {
        Id contactId = fakeId('003', 5);
        npe03__Recurring_Donation__c oldRecord = recurringDonation(contactId, 'Closed', null);

        npsp.TDTM_Runnable.DmlWrapper wrapper = new RecurringDonationContactRollupHandler().run(
            null,
            new List<SObject>{ oldRecord },
            npsp.TDTM_Runnable.Action.AfterDelete,
            npe03__Recurring_Donation__c.SObjectType.getDescribe()
        );

        System.assertEquals(1, wrapper.objectsToUpdate.size());
        System.assertEquals(contactId, ((Contact) wrapper.objectsToUpdate[0]).Id);
    }

    @IsTest
    static void buildContactUpdatesHandlesBlankInput() {
        System.assertEquals(0, RecurringDonationContactRollupHandler.buildContactUpdates(null).size());
        System.assertEquals(0, RecurringDonationContactRollupHandler.buildContactUpdates(new Set<Id>()).size());
    }

    private static npe03__Recurring_Donation__c recurringDonation(Id contactId, String status, String closureReason) {
        return new npe03__Recurring_Donation__c(
            Id = fakeId('a09', 1),
            npe03__Contact__c = contactId,
            npe03__Open_Ended_Status__c = status,
            Motivo_de_cierre_de_DDRR__c = closureReason
        );
    }

    private static Id fakeId(String prefix, Integer index) {
        return (Id) (prefix + String.valueOf(index).leftPad(12, '0') + 'AAA');
    }
}

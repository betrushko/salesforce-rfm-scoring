List<Contact> updates = new List<Contact>();

for (Contact contactRecord : [
    SELECT Id,
        RFM_Expected_Payments_12M__c,
        RFM_Successful_Payments_12M__c,
        RFM_Payment_Rate_12M__c
    FROM Contact
    WHERE RFM_Expected_Payments_12M__c > 0
    AND RFM_Successful_Payments_12M__c > 0
]) {
    Decimal nextRate = (
        contactRecord.RFM_Successful_Payments_12M__c /
        contactRecord.RFM_Expected_Payments_12M__c *
        100
    ).setScale(2);

    if (contactRecord.RFM_Payment_Rate_12M__c != nextRate) {
        updates.add(new Contact(
            Id = contactRecord.Id,
            RFM_Payment_Rate_12M__c = nextRate
        ));
    }
}

if (!updates.isEmpty()) {
    update updates;
}

System.debug('Updated Contact RFM payment rates: ' + updates.size());

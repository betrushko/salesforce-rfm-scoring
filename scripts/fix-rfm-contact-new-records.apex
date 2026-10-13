List<Contact> metricScope = [
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
    WHERE RFM_Qualification_Status__c = null
    LIMIT 200
];

new RFMContactMetricsBatch().execute(null, metricScope);

Set<Id> contactIds = new Map<Id, Contact>(metricScope).keySet();
if (!contactIds.isEmpty()) {
    List<Contact> statusScope = [
        SELECT Id,
            RFM_Qualification_Status__c,
            RFM_Recency_Score__c,
            RFM_Frequency_Score__c,
            RFM_Monetary_Score__c,
            RFM_Final_Score__c,
            RFM_Status__c
        FROM Contact
        WHERE Id IN :contactIds
    ];
    new RFMContactStatusBatch().execute(null, statusScope);
}

System.debug('RFM_CONTACT_NEW_RECORD_FIX processed=' + metricScope.size());

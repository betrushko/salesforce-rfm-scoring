Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
List<String> fieldNames = new List<String>{
    'RFM_Donor_Type__c',
    'RFM_Qualification_Status__c',
    'RFM_Lifetime_Successful_Donations__c',
    'RFM_Status__c',
    'RFM_Final_Score__c'
};

for (String fieldName : fieldNames) {
    System.debug('RFM_CONTACT_FIELD_EXISTS ' + fieldName + '=' + contactFields.containsKey(fieldName));
}

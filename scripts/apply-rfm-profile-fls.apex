Map<String, Boolean> editableByField = new Map<String, Boolean>();

for (String fieldName : new List<String>{
    'Last_Successful_Payment_Date__c',
    'Successful_Payments_12M__c',
    'Paid_Amount_12M__c',
    'Lifetime_Paid_Amount__c',
    'Monetary_Percentile__c'
}) {
    editableByField.put('npe03__Recurring_Donation__c.' + fieldName, true);
}

for (String fieldName : new List<String>{
    'Days_Since_Last_Payment__c',
    'Expected_Cadence_Days__c',
    'Adjusted_Recency__c',
    'Recency_Score__c',
    'Expected_Payments_12M__c',
    'Payment_Rate__c',
    'Frequency_Score__c',
    'Weighted_Monetary__c',
    'Recent_Monetary_Percentile__c',
    'Historical_Monetary_Percentile__c',
    'Balanced_Monetary_Percentile__c',
    'Monetary_Score__c',
    'RFM_Score__c',
    'RFM_Status__c'
}) {
    editableByField.put('npe03__Recurring_Donation__c.' + fieldName, false);
}

for (String fieldName : new List<String>{
    'RFM_Avg_Monthly_Value_12M__c',
    'RFM_Avg_Monthly_Value_Lifetime__c',
    'RFM_Balanced_Monetary_Percentile__c',
    'RFM_Days_Since_Last_Donation__c',
    'RFM_Donor_Age_Months__c',
    'RFM_Donor_Type__c',
    'RFM_Expected_Payments_12M__c',
    'RFM_Final_Score__c',
    'RFM_First_Successful_Donation_Date__c',
    'RFM_Frequency_Score__c',
    'RFM_Historical_Monetary_Percentile__c',
    'RFM_Last_Successful_Donation_Date__c',
    'RFM_Lifetime_Paid_Amount__c',
    'RFM_Lifetime_Successful_Donations__c',
    'RFM_Monetary_Score__c',
    'RFM_One_Time_Donations_12M__c',
    'RFM_One_Time_Donations_24M__c',
    'RFM_Paid_Amount_12M__c',
    'RFM_Paid_Amount_24M__c',
    'RFM_Payment_Rate_12M__c',
    'RFM_Qualification_Status__c',
    'RFM_Recent_Monetary_Percentile__c',
    'RFM_Recency_Score__c',
    'RFM_Rising_Star_Flag__c',
    'RFM_Status__c',
    'RFM_Successful_Payments_12M__c',
    'RFM_Total_Successful_Donations_12M__c',
    'RFM_Total_Successful_Donations_24M__c'
}) {
    editableByField.put('Contact.' + fieldName, false);
}

List<PermissionSet> profilePermissionSets = [
    SELECT Id, Name, Profile.Name
    FROM PermissionSet
    WHERE IsOwnedByProfile = true
    ORDER BY Profile.Name
];

Set<Id> parentIds = new Set<Id>();
for (PermissionSet permissionSetRecord : profilePermissionSets) {
    parentIds.add(permissionSetRecord.Id);
}

Map<String, Set<String>> fieldsByObject = new Map<String, Set<String>>();
for (String fieldApiName : editableByField.keySet()) {
    List<String> parts = fieldApiName.split('\\.');
    if (!fieldsByObject.containsKey(parts[0])) {
        fieldsByObject.put(parts[0], new Set<String>());
    }
    fieldsByObject.get(parts[0]).add(fieldApiName);
}

Map<String, FieldPermissions> existingByParentAndField = new Map<String, FieldPermissions>();
for (String sobjectType : fieldsByObject.keySet()) {
    for (FieldPermissions existingPermission : [
        SELECT Id, ParentId, Field, PermissionsRead, PermissionsEdit
        FROM FieldPermissions
        WHERE ParentId IN :parentIds
        AND SobjectType = :sobjectType
        AND Field IN :fieldsByObject.get(sobjectType)
    ]) {
        existingByParentAndField.put(existingPermission.ParentId + ':' + existingPermission.Field, existingPermission);
    }
}

List<FieldPermissions> toInsert = new List<FieldPermissions>();
List<FieldPermissions> toUpdate = new List<FieldPermissions>();

for (PermissionSet permissionSetRecord : profilePermissionSets) {
    for (String fieldApiName : editableByField.keySet()) {
        String key = permissionSetRecord.Id + ':' + fieldApiName;
        String sobjectType = fieldApiName.substringBefore('.');
        Boolean shouldEdit = editableByField.get(fieldApiName);
        if (existingByParentAndField.containsKey(key)) {
            FieldPermissions existingPermission = existingByParentAndField.get(key);
            if (existingPermission.PermissionsRead != true || existingPermission.PermissionsEdit != shouldEdit) {
                existingPermission.PermissionsRead = true;
                existingPermission.PermissionsEdit = shouldEdit;
                toUpdate.add(existingPermission);
            }
        } else {
            toInsert.add(new FieldPermissions(
                ParentId = permissionSetRecord.Id,
                SobjectType = sobjectType,
                Field = fieldApiName,
                PermissionsRead = true,
                PermissionsEdit = shouldEdit
            ));
        }
    }
}

Database.SaveResult[] insertResults = Database.insert(toInsert, false);
Database.SaveResult[] updateResults = Database.update(toUpdate, false);

Integer insertSuccess = 0;
Integer updateSuccess = 0;
Integer failures = 0;

for (Integer i = 0; i < insertResults.size(); i++) {
    if (insertResults[i].isSuccess()) {
        insertSuccess++;
    } else {
        failures++;
        System.debug('INSERT_FAILED ' + toInsert[i].ParentId + ' ' + toInsert[i].Field + ': ' + insertResults[i].getErrors()[0].getMessage());
    }
}

for (Integer i = 0; i < updateResults.size(); i++) {
    if (updateResults[i].isSuccess()) {
        updateSuccess++;
    } else {
        failures++;
        System.debug('UPDATE_FAILED ' + toUpdate[i].ParentId + ' ' + toUpdate[i].Field + ': ' + updateResults[i].getErrors()[0].getMessage());
    }
}

System.debug('RFM_PROFILE_FLS_RESULT profiles=' + profilePermissionSets.size() + ', fields=' + editableByField.size() + ', inserted=' + insertSuccess + ', updated=' + updateSuccess + ', failures=' + failures);

Set<String> apexClassNames = new Set<String>{
    'RFMRawMetricsBatch',
    'RFMMonetaryPercentileBatch',
    'RFMStatusBatch',
    'RFMContactMetricsBatch',
    'RFMContactMonetaryPercentileBatch',
    'RFMContactStatusBatch'
};

Map<String, ApexClass> apexClassByName = new Map<String, ApexClass>();
for (ApexClass apexClassRecord : [
    SELECT Id, Name
    FROM ApexClass
    WHERE Name IN :apexClassNames
]) {
    apexClassByName.put(apexClassRecord.Name, apexClassRecord);
}

Set<Id> apexClassIds = new Set<Id>();
for (ApexClass apexClassRecord : apexClassByName.values()) {
    apexClassIds.add(apexClassRecord.Id);
}

Map<String, SetupEntityAccess> existingClassAccessByParentAndClass = new Map<String, SetupEntityAccess>();
for (SetupEntityAccess existingAccess : [
    SELECT Id, ParentId, SetupEntityId
    FROM SetupEntityAccess
    WHERE ParentId IN :parentIds
    AND SetupEntityId IN :apexClassIds
]) {
    existingClassAccessByParentAndClass.put(existingAccess.ParentId + ':' + existingAccess.SetupEntityId, existingAccess);
}

List<SetupEntityAccess> classAccessToInsert = new List<SetupEntityAccess>();

for (PermissionSet permissionSetRecord : profilePermissionSets) {
    for (ApexClass apexClassRecord : apexClassByName.values()) {
        String key = permissionSetRecord.Id + ':' + apexClassRecord.Id;
        if (!existingClassAccessByParentAndClass.containsKey(key)) {
            classAccessToInsert.add(new SetupEntityAccess(
                ParentId = permissionSetRecord.Id,
                SetupEntityId = apexClassRecord.Id
            ));
        }
    }
}

Database.SaveResult[] classInsertResults = Database.insert(classAccessToInsert, false);

Integer classInsertSuccess = 0;
Integer classFailures = 0;

for (Integer i = 0; i < classInsertResults.size(); i++) {
    if (classInsertResults[i].isSuccess()) {
        classInsertSuccess++;
    } else {
        classFailures++;
        System.debug('CLASS_ACCESS_INSERT_FAILED ' + classAccessToInsert[i].ParentId + ' ' + classAccessToInsert[i].SetupEntityId + ': ' + classInsertResults[i].getErrors()[0].getMessage());
    }
}

System.debug('RFM_PROFILE_CLASS_ACCESS_RESULT profiles=' + profilePermissionSets.size() + ', classes=' + apexClassByName.size() + ', inserted=' + classInsertSuccess + ', failures=' + classFailures);

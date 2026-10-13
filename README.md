# Salesforce RFM scoring

Cadence-adjusted recency, frequency and monetary scoring for recurring donations and Contacts, with batch automation, percentile calculations and a synthetic Excel heatmap generator.

**Stack:** Apex, Salesforce DX, Python, openpyxl.

## What this demonstrates

Reusable implementation patterns for data integration, validation and maintainable automation. This is a curated, generalized portfolio edition. It contains no production exports, deployment history, internal access inventory or credentials. API names and source labels have been generalized where needed; configure the matching schema in your own sandbox before use.

## Getting started

For Salesforce work, use Salesforce CLI and a dedicated sandbox with the required schema and NPSP dependencies. Inspect `manifest/package.xml`, then validate with `sf project deploy start --dry-run --manifest manifest/package.xml --target-org DEMO_SANDBOX`. This repository has not been deployed or tested against a live org during portfolio preparation. 

## Source map

- `README.md`
- `force-app/main/default/classes/RDContactRollupHandlerTest.cls`
- `force-app/main/default/classes/RDContactRollupHandlerTest.cls-meta.xml`
- `force-app/main/default/classes/RFMContactBatchTest.cls`
- `force-app/main/default/classes/RFMContactBatchTest.cls-meta.xml`
- `force-app/main/default/classes/RFMContactMetricsBatch.cls`
- `force-app/main/default/classes/RFMContactMetricsBatch.cls-meta.xml`
- `force-app/main/default/classes/RFMContactMonetaryPercentileBatch.cls`
- `force-app/main/default/classes/RFMContactMonetaryPercentileBatch.cls-meta.xml`
- `force-app/main/default/classes/RFMContactStatusBatch.cls`
- `force-app/main/default/classes/RFMContactStatusBatch.cls-meta.xml`
- `force-app/main/default/classes/RFMMonetaryPercentileBatch.cls`
- `force-app/main/default/classes/RFMMonetaryPercentileBatch.cls-meta.xml`
- `force-app/main/default/classes/RFMRawMetricsBatch.cls`
- `force-app/main/default/classes/RFMRawMetricsBatch.cls-meta.xml`
- `force-app/main/default/classes/RFMRawMetricsBatchTest.cls`
- `force-app/main/default/classes/RFMRawMetricsBatchTest.cls-meta.xml`
- `force-app/main/default/classes/RFMStatusBatch.cls`
- `force-app/main/default/classes/RFMStatusBatch.cls-meta.xml`
- `force-app/main/default/classes/RFMStatusBatchTest.cls`
- `force-app/main/default/classes/RFMStatusBatchTest.cls-meta.xml`
- `force-app/main/default/classes/RecurringDonationContactRollupHandler.cls`
- `force-app/main/default/classes/RecurringDonationContactRollupHandler.cls-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Avg_Monthly_Value_12M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Avg_Monthly_Value_Lifetime__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Balanced_Monetary_Percentile__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Days_Since_Last_Donation__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Donor_Age_Months__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Donor_Type__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Expected_Payments_12M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Final_Score__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_First_Successful_Donation_Date__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Frequency_Score__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Historical_Monetary_Percentile__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Last_Successful_Donation_Date__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Lifetime_Paid_Amount__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Lifetime_Successful_Donations__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Monetary_Score__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_One_Time_Donations_12M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_One_Time_Donations_24M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Paid_Amount_12M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Paid_Amount_24M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Payment_Rate_12M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Qualification_Status__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Recency_Score__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Recent_Monetary_Percentile__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Rising_Star_Flag__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Status__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Successful_Payments_12M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Total_Successful_Donations_12M__c.field-meta.xml`
- `force-app/main/default/objects/Contact/fields/RFM_Total_Successful_Donations_24M__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Adjusted_Recency__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Balanced_Monetary_Percentile__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Days_Since_Last_Payment__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Expected_Cadence_Days__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Expected_Payments_12M__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Frequency_Score__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Historical_Monetary_Percentile__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Last_Successful_Payment_Date__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Lifetime_Paid_Amount__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Monetary_Percentile__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Monetary_Score__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Paid_Amount_12M__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Payment_Rate__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/RFM_Score__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/RFM_Status__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Recency_Score__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Recent_Monetary_Percentile__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Successful_Payments_12M__c.field-meta.xml`
- `force-app/main/default/objects/npe03__Recurring_Donation__c/fields/Weighted_Monetary__c.field-meta.xml`
- `force-app/main/default/permissionsets/RFM_Scoring_Access.permissionset-meta.xml`
- `manifest/package.xml`
- `scripts/apply-rfm-profile-fls.apex`
- `scripts/build_rfm_contact_heatmap.py`
- `scripts/check-fieldpermissions.apex`
- `scripts/check-rfm-contact-fields.apex`
- `scripts/fix-rfm-contact-new-records.apex`
- `scripts/fix-rfm-contact-payment-rate-scale.apex`
- `scripts/run-rfm-contact-metrics-batch.apex`
- `scripts/run-rfm-contact-percentile-batch.apex`
- `scripts/run-rfm-contact-status-batch.apex`
- `scripts/run-rfm-raw-metrics-batch.apex`
- `scripts/run-rfm-status-batch.apex`
- `scripts/schedule-rfm-contact-metrics-batch.apex`
- `scripts/schedule-rfm-contact-status-batch.apex`
- `scripts/schedule-rfm-raw-metrics-batch.apex`
- `scripts/schedule-rfm-status-batch.apex`
- `sfdx-project.json`

## Validation

Python sources and JSON/XML configuration are checked locally. Apex test classes are retained where present; executing them requires a compatible sandbox. No Salesforce query, deployment, backfill or record mutation was performed during preparation. See [SECURITY.md](SECURITY.md) for data handling.

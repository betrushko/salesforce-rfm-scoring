public with sharing class RFMContactMetricsBatch implements Database.Batchable<SObject>, Schedulable {
    private static final String DONOR_RECURRING_ONLY = 'Recurring Only';
    private static final String DONOR_ONE_TIME_ONLY = 'One-Time Only';
    private static final String DONOR_MIXED = 'Mixed';
    private static final String DONOR_NO_SUCCESS = 'No Successful Donations';

    private static final String QUALIFIED = 'Qualified';
    private static final String NO_SUCCESSFUL_DONATIONS = 'No Successful Donations';

    private static final Set<String> ACTIVE_EXPECTED_STATUSES = new Set<String>{
        'Open',
        'Operational',
        'Paused',
        'Suspended'
    };

    @TestVisible
    private static Map<Id, Metrics> metricsOverride;
    @TestVisible
    private static Map<Id, List<RecurringDonationWindow>> recurringDonationOverride;
    @TestVisible
    private static Date todayOverride;

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
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
        ]);
    }

    public void execute(Database.BatchableContext context, List<Contact> scope) {
        Set<Id> contactIds = new Set<Id>();
        for (Contact contactRecord : scope) {
            contactIds.add(contactRecord.Id);
        }

        Date runDate = currentDate();
        Map<Id, Metrics> metricsByContactId = loadOpportunityMetrics(contactIds, runDate);
        Map<Id, List<RecurringDonationWindow>> windowsByContactId = loadRecurringDonationWindows(contactIds);
        List<Contact> updates = buildUpdates(scope, metricsByContactId, windowsByContactId, runDate);

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext context) {
        Database.executeBatch(new RFMContactMonetaryPercentileBatch(), 200);
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new RFMContactMetricsBatch(), 200);
    }

    @TestVisible
    private static List<Contact> buildUpdates(
        List<Contact> scope,
        Map<Id, Metrics> metricsByContactId,
        Map<Id, List<RecurringDonationWindow>> windowsByContactId,
        Date runDate
    ) {
        List<Contact> updates = new List<Contact>();
        for (Contact contactRecord : scope) {
            Metrics metrics = metricsByContactId.get(contactRecord.Id);
            if (metrics == null) {
                metrics = new Metrics();
            }

            List<RecurringDonationWindow> windows = windowsByContactId.get(contactRecord.Id);
            Integer recurringDonationCount = windows == null ? 0 : windows.size();
            Decimal expectedPayments12M = expectedPayments(windows, runDate);
            Decimal paymentRate = expectedPayments12M == 0 ? null : (Decimal.valueOf(metrics.recurringPayments12M) / expectedPayments12M).setScale(4);
            Decimal paymentRatePercent = paymentRate == null ? null : (paymentRate * 100).setScale(2);
            String donorType = donorTypeFor(recurringDonationCount, metrics);
            Integer daysSinceLastDonation = metrics.lastSuccessfulDonationDate == null
                ? null
                : metrics.lastSuccessfulDonationDate.daysBetween(runDate);
            Integer donorAgeMonths = donorAgeMonths(metrics.firstSuccessfulDonationDate, runDate);
            Decimal avgMonthlyValue12M = (metrics.paidAmount12M / 12).setScale(2);
            Decimal avgMonthlyValueLifetime = donorAgeMonths == 0
                ? 0
                : (metrics.lifetimePaidAmount / Decimal.valueOf(Math.max(donorAgeMonths, 12))).setScale(2);
            Decimal recencyScore = recencyScoreFor(donorType, daysSinceLastDonation);
            Decimal frequencyScore = frequencyScoreFor(
                donorType,
                expectedPayments12M,
                paymentRate,
                metrics.totalSuccessfulDonations24M,
                metrics.lifetimeSuccessfulDonations
            );
            String qualificationStatus = metrics.lifetimeSuccessfulDonations > 0 ? QUALIFIED : NO_SUCCESSFUL_DONATIONS;

            Contact nextContact = new Contact(
                Id = contactRecord.Id,
                RFM_Donor_Type__c = donorType,
                RFM_Qualification_Status__c = qualificationStatus,
                RFM_First_Successful_Donation_Date__c = metrics.firstSuccessfulDonationDate,
                RFM_Last_Successful_Donation_Date__c = metrics.lastSuccessfulDonationDate,
                RFM_Days_Since_Last_Donation__c = daysSinceLastDonation,
                RFM_Paid_Amount_12M__c = metrics.paidAmount12M,
                RFM_Paid_Amount_24M__c = metrics.paidAmount24M,
                RFM_Lifetime_Paid_Amount__c = metrics.lifetimePaidAmount,
                RFM_Donor_Age_Months__c = donorAgeMonths,
                RFM_Avg_Monthly_Value_12M__c = avgMonthlyValue12M,
                RFM_Avg_Monthly_Value_Lifetime__c = avgMonthlyValueLifetime,
                RFM_Total_Successful_Donations_12M__c = metrics.totalSuccessfulDonations12M,
                RFM_Total_Successful_Donations_24M__c = metrics.totalSuccessfulDonations24M,
                RFM_Lifetime_Successful_Donations__c = metrics.lifetimeSuccessfulDonations,
                RFM_One_Time_Donations_12M__c = metrics.oneTimeDonations12M,
                RFM_One_Time_Donations_24M__c = metrics.oneTimeDonations24M,
                RFM_Expected_Payments_12M__c = expectedPayments12M,
                RFM_Successful_Payments_12M__c = metrics.recurringPayments12M,
                RFM_Payment_Rate_12M__c = paymentRatePercent,
                RFM_Recency_Score__c = recencyScore,
                RFM_Frequency_Score__c = frequencyScore
            );

            if (hasChanged(contactRecord, nextContact)) {
                updates.add(nextContact);
            }
        }
        return updates;
    }

    @TestVisible
    private static Map<Id, Metrics> loadOpportunityMetrics(Set<Id> contactIds, Date runDate) {
        if (Test.isRunningTest() && metricsOverride != null) {
            return metricsOverride;
        }

        Map<Id, Metrics> metricsByContactId = new Map<Id, Metrics>();
        if (contactIds.isEmpty()) {
            return metricsByContactId;
        }

        Date cutoff12M = runDate.addDays(-365);
        Date cutoff24M = runDate.addDays(-730);

        for (Opportunity opportunityRecord : [
            SELECT Id, ContactId, CloseDate, Amount, npe03__Recurring_Donation__c
            FROM Opportunity
            WHERE ContactId IN :contactIds
            AND StageName = 'Closed Won'
            AND Amount > 0
            AND CloseDate != null
        ]) {
            Metrics metrics = getOrCreateMetrics(metricsByContactId, opportunityRecord.ContactId);
            Boolean isOneTime = opportunityRecord.npe03__Recurring_Donation__c == null;
            Boolean isRecurringPayment = opportunityRecord.npe03__Recurring_Donation__c != null;
            Date closeDate = opportunityRecord.CloseDate;
            Decimal amount = opportunityRecord.Amount == null ? 0 : opportunityRecord.Amount;

            metrics.hasOneTimeSuccessfulDonation = metrics.hasOneTimeSuccessfulDonation || isOneTime;
            metrics.lifetimeSuccessfulDonations++;
            metrics.lifetimePaidAmount += amount;
            metrics.firstSuccessfulDonationDate = earlierDate(metrics.firstSuccessfulDonationDate, closeDate);
            metrics.lastSuccessfulDonationDate = laterDate(metrics.lastSuccessfulDonationDate, closeDate);

            if (closeDate >= cutoff24M) {
                metrics.totalSuccessfulDonations24M++;
                metrics.paidAmount24M += amount;
                if (isOneTime) {
                    metrics.oneTimeDonations24M++;
                }
            }
            if (closeDate >= cutoff12M) {
                metrics.totalSuccessfulDonations12M++;
                metrics.paidAmount12M += amount;
                if (isOneTime) {
                    metrics.oneTimeDonations12M++;
                }
                if (isRecurringPayment) {
                    metrics.recurringPayments12M++;
                }
            }
        }

        return metricsByContactId;
    }

    @TestVisible
    private static Map<Id, List<RecurringDonationWindow>> loadRecurringDonationWindows(Set<Id> contactIds) {
        if (Test.isRunningTest() && recurringDonationOverride != null) {
            return recurringDonationOverride;
        }

        Map<Id, List<RecurringDonationWindow>> windowsByContactId = new Map<Id, List<RecurringDonationWindow>>();
        if (contactIds.isEmpty()) {
            return windowsByContactId;
        }

        for (npe03__Recurring_Donation__c recurringDonation : [
            SELECT npe03__Contact__c,
                npe03__Date_Established__c,
                npe03__Installment_Period__c,
                npe03__Open_Ended_Status__c,
                Fecha_de_cierre_de_DDRR__c
            FROM npe03__Recurring_Donation__c
            WHERE npe03__Contact__c IN :contactIds
        ]) {
            if (!windowsByContactId.containsKey(recurringDonation.npe03__Contact__c)) {
                windowsByContactId.put(recurringDonation.npe03__Contact__c, new List<RecurringDonationWindow>());
            }
            windowsByContactId.get(recurringDonation.npe03__Contact__c).add(new RecurringDonationWindow(
                recurringDonation.npe03__Date_Established__c,
                recurringDonation.Fecha_de_cierre_de_DDRR__c,
                recurringDonation.npe03__Installment_Period__c,
                recurringDonation.npe03__Open_Ended_Status__c
            ));
        }

        return windowsByContactId;
    }

    @TestVisible
    private static String donorTypeFor(Integer recurringDonationCount, Metrics metrics) {
        if (metrics == null || metrics.lifetimeSuccessfulDonations == 0) {
            return DONOR_NO_SUCCESS;
        }
        Boolean hasRecurringDonation = recurringDonationCount != null && recurringDonationCount > 0;
        if (hasRecurringDonation && metrics.hasOneTimeSuccessfulDonation) {
            return DONOR_MIXED;
        }
        if (hasRecurringDonation) {
            return DONOR_RECURRING_ONLY;
        }
        return DONOR_ONE_TIME_ONLY;
    }

    @TestVisible
    private static Decimal recencyScoreFor(String donorType, Integer daysSince) {
        if (daysSince == null) {
            return 0;
        }
        if (donorType == DONOR_RECURRING_ONLY || donorType == DONOR_MIXED) {
            if (daysSince <= 35) {
                return 5;
            }
            if (daysSince <= 65) {
                return 4;
            }
            if (daysSince <= 95) {
                return 3;
            }
            if (daysSince <= 180) {
                return 2;
            }
            return 1;
        }
        if (donorType == DONOR_ONE_TIME_ONLY) {
            if (daysSince <= 90) {
                return 5;
            }
            if (daysSince <= 180) {
                return 4;
            }
            if (daysSince <= 365) {
                return 3;
            }
            if (daysSince <= 730) {
                return 2;
            }
            return 1;
        }
        return 0;
    }

    @TestVisible
    private static Decimal frequencyScoreFor(
        String donorType,
        Decimal expectedPayments12M,
        Decimal paymentRate,
        Integer totalSuccessfulDonations24M,
        Integer lifetimeSuccessfulDonations
    ) {
        if (donorType == DONOR_RECURRING_ONLY || donorType == DONOR_MIXED) {
            if (expectedPayments12M == null || expectedPayments12M == 0) {
                return totalSuccessfulDonations24M > 0 ? 2 : 0;
            }
            if (paymentRate >= 0.98) {
                return 5;
            }
            if (paymentRate >= 0.90) {
                return 4;
            }
            if (paymentRate >= 0.75) {
                return 3;
            }
            if (paymentRate >= 0.50) {
                return 2;
            }
            return 1;
        }
        if (donorType == DONOR_ONE_TIME_ONLY) {
            if (totalSuccessfulDonations24M > 4) {
                return 5;
            }
            if (totalSuccessfulDonations24M == 4) {
                return 4;
            }
            if (totalSuccessfulDonations24M == 3) {
                return 3;
            }
            if (totalSuccessfulDonations24M == 2) {
                return 2;
            }
            if (lifetimeSuccessfulDonations > 0) {
                return 1;
            }
        }
        return 0;
    }

    @TestVisible
    private static Decimal expectedPayments(List<RecurringDonationWindow> windows, Date runDate) {
        if (windows == null || windows.isEmpty()) {
            return 0;
        }

        Decimal expected = 0;
        Date cutoff = runDate.addDays(-365);
        for (RecurringDonationWindow window : windows) {
            Integer cadenceDays = cadenceDaysFor(window.installmentPeriod);
            if (cadenceDays == 0) {
                continue;
            }

            Date activeStart = window.establishedDate == null || window.establishedDate < cutoff
                ? cutoff
                : window.establishedDate;
            Date activeEnd = runDate;

            if (window.status == 'Closed') {
                if (window.closedDate == null || window.closedDate < cutoff) {
                    continue;
                }
                activeEnd = window.closedDate > runDate ? runDate : window.closedDate;
            } else if (!ACTIVE_EXPECTED_STATUSES.contains(window.status)) {
                continue;
            }

            if (activeEnd < activeStart) {
                continue;
            }

            Integer activeDays = activeStart.daysBetween(activeEnd) + 1;
            Decimal expectedForWindow = Math.ceil(Decimal.valueOf(activeDays) / Decimal.valueOf(cadenceDays));
            expectedForWindow = Math.max(Decimal.valueOf(1), expectedForWindow);
            expected += Math.min(Decimal.valueOf(maxExpectedFor(cadenceDays)), expectedForWindow);
        }
        return expected;
    }

    @TestVisible
    private static Integer cadenceDaysFor(String installmentPeriod) {
        if (installmentPeriod == 'Monthly') {
            return 30;
        }
        if (installmentPeriod == 'Quarterly') {
            return 90;
        }
        if (installmentPeriod == 'Annual' || installmentPeriod == 'Yearly') {
            return 365;
        }
        return 0;
    }

    private static Integer maxExpectedFor(Integer cadenceDays) {
        if (cadenceDays == 30) {
            return 12;
        }
        if (cadenceDays == 90) {
            return 4;
        }
        return 1;
    }

    private static Integer donorAgeMonths(Date firstDonationDate, Date runDate) {
        if (firstDonationDate == null) {
            return 0;
        }
        Integer months = ((runDate.year() - firstDonationDate.year()) * 12) + (runDate.month() - firstDonationDate.month());
        if (runDate.day() < firstDonationDate.day()) {
            months--;
        }
        return Math.max(0, months);
    }

    private static Date currentDate() {
        return Test.isRunningTest() && todayOverride != null ? todayOverride : Date.today();
    }

    private static Metrics getOrCreateMetrics(Map<Id, Metrics> metricsByContactId, Id contactId) {
        if (!metricsByContactId.containsKey(contactId)) {
            metricsByContactId.put(contactId, new Metrics());
        }
        return metricsByContactId.get(contactId);
    }

    private static Date earlierDate(Date currentValue, Date candidate) {
        if (currentValue == null || candidate < currentValue) {
            return candidate;
        }
        return currentValue;
    }

    private static Date laterDate(Date currentValue, Date candidate) {
        if (currentValue == null || candidate > currentValue) {
            return candidate;
        }
        return currentValue;
    }

    private static Boolean hasChanged(Contact currentContact, Contact nextContact) {
        return currentContact.RFM_Donor_Type__c != nextContact.RFM_Donor_Type__c
            || currentContact.RFM_Qualification_Status__c != nextContact.RFM_Qualification_Status__c
            || currentContact.RFM_First_Successful_Donation_Date__c != nextContact.RFM_First_Successful_Donation_Date__c
            || currentContact.RFM_Last_Successful_Donation_Date__c != nextContact.RFM_Last_Successful_Donation_Date__c
            || currentContact.RFM_Days_Since_Last_Donation__c != nextContact.RFM_Days_Since_Last_Donation__c
            || currentContact.RFM_Paid_Amount_12M__c != nextContact.RFM_Paid_Amount_12M__c
            || currentContact.RFM_Paid_Amount_24M__c != nextContact.RFM_Paid_Amount_24M__c
            || currentContact.RFM_Lifetime_Paid_Amount__c != nextContact.RFM_Lifetime_Paid_Amount__c
            || currentContact.RFM_Donor_Age_Months__c != nextContact.RFM_Donor_Age_Months__c
            || currentContact.RFM_Avg_Monthly_Value_12M__c != nextContact.RFM_Avg_Monthly_Value_12M__c
            || currentContact.RFM_Avg_Monthly_Value_Lifetime__c != nextContact.RFM_Avg_Monthly_Value_Lifetime__c
            || currentContact.RFM_Total_Successful_Donations_12M__c != nextContact.RFM_Total_Successful_Donations_12M__c
            || currentContact.RFM_Total_Successful_Donations_24M__c != nextContact.RFM_Total_Successful_Donations_24M__c
            || currentContact.RFM_Lifetime_Successful_Donations__c != nextContact.RFM_Lifetime_Successful_Donations__c
            || currentContact.RFM_One_Time_Donations_12M__c != nextContact.RFM_One_Time_Donations_12M__c
            || currentContact.RFM_One_Time_Donations_24M__c != nextContact.RFM_One_Time_Donations_24M__c
            || currentContact.RFM_Expected_Payments_12M__c != nextContact.RFM_Expected_Payments_12M__c
            || currentContact.RFM_Successful_Payments_12M__c != nextContact.RFM_Successful_Payments_12M__c
            || currentContact.RFM_Payment_Rate_12M__c != nextContact.RFM_Payment_Rate_12M__c
            || currentContact.RFM_Recency_Score__c != nextContact.RFM_Recency_Score__c
            || currentContact.RFM_Frequency_Score__c != nextContact.RFM_Frequency_Score__c;
    }

    public class Metrics {
        public Boolean hasOneTimeSuccessfulDonation = false;
        public Date firstSuccessfulDonationDate;
        public Date lastSuccessfulDonationDate;
        public Decimal paidAmount12M = 0;
        public Decimal paidAmount24M = 0;
        public Decimal lifetimePaidAmount = 0;
        public Integer totalSuccessfulDonations12M = 0;
        public Integer totalSuccessfulDonations24M = 0;
        public Integer lifetimeSuccessfulDonations = 0;
        public Integer oneTimeDonations12M = 0;
        public Integer oneTimeDonations24M = 0;
        public Integer recurringPayments12M = 0;
    }

    public class RecurringDonationWindow {
        public Date establishedDate;
        public Date closedDate;
        public String installmentPeriod;
        public String status;

        public RecurringDonationWindow(Date establishedDate, Date closedDate, String installmentPeriod, String status) {
            this.establishedDate = establishedDate;
            this.closedDate = closedDate;
            this.installmentPeriod = installmentPeriod;
            this.status = status;
        }
    }
}

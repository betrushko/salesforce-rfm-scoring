public with sharing class RFMMonetaryPercentileBatch implements Database.Batchable<SObject>, Database.Stateful {
    @TestVisible private Boolean recentPass;
    @TestVisible private Integer totalRecords;
    @TestVisible private Integer processedRecords = 0;
    @TestVisible private Decimal currentAmount;
    @TestVisible private Integer currentTieStartRank = 1;

    public RFMMonetaryPercentileBatch() {
        this(true);
    }

    public RFMMonetaryPercentileBatch(Boolean recentPass) {
        this.recentPass = recentPass;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        totalRecords = [
            SELECT COUNT()
            FROM npe03__Recurring_Donation__c
            WHERE Lifetime_Paid_Amount__c > 0
        ];

        if (recentPass) {
            return Database.getQueryLocator([
                SELECT Id,
                    Paid_Amount_12M__c,
                    Recent_Monetary_Percentile__c
                FROM npe03__Recurring_Donation__c
                WHERE Lifetime_Paid_Amount__c > 0
                ORDER BY Paid_Amount_12M__c ASC NULLS FIRST, Id ASC
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id,
                Lifetime_Paid_Amount__c,
                Recent_Monetary_Percentile__c,
                Historical_Monetary_Percentile__c,
                Balanced_Monetary_Percentile__c,
                Monetary_Percentile__c
            FROM npe03__Recurring_Donation__c
            WHERE Lifetime_Paid_Amount__c > 0
            ORDER BY Lifetime_Paid_Amount__c ASC NULLS FIRST, Id ASC
        ]);
    }

    public void execute(Database.BatchableContext context, List<npe03__Recurring_Donation__c> scope) {
        List<npe03__Recurring_Donation__c> updates = new List<npe03__Recurring_Donation__c>();
        for (npe03__Recurring_Donation__c recurringDonation : scope) {
            processedRecords++;

            Decimal amount = recentPass
                ? recurringDonation.Paid_Amount_12M__c
                : recurringDonation.Lifetime_Paid_Amount__c;
            amount = amount == null ? 0 : amount;
            if (currentAmount == null || currentAmount != amount) {
                currentAmount = amount;
                currentTieStartRank = processedRecords;
            }

            Decimal percentile = percentileForRank(currentTieStartRank, totalRecords);
            if (recentPass) {
                if (recurringDonation.Recent_Monetary_Percentile__c != percentile) {
                    updates.add(new npe03__Recurring_Donation__c(
                        Id = recurringDonation.Id,
                        Recent_Monetary_Percentile__c = percentile
                    ));
                }
            } else {
                Decimal recentPercentile = recurringDonation.Recent_Monetary_Percentile__c;
                Decimal historicalPercentile = percentile;
                Decimal balancedPercentile = recentPercentile == null
                    ? null
                    : ((recentPercentile * 0.50) + (historicalPercentile * 0.50)).setScale(2);

                if (
                    recurringDonation.Historical_Monetary_Percentile__c != historicalPercentile ||
                    recurringDonation.Balanced_Monetary_Percentile__c != balancedPercentile ||
                    recurringDonation.Monetary_Percentile__c != balancedPercentile
                ) {
                    updates.add(new npe03__Recurring_Donation__c(
                        Id = recurringDonation.Id,
                        Historical_Monetary_Percentile__c = historicalPercentile,
                        Balanced_Monetary_Percentile__c = balancedPercentile,
                        Monetary_Percentile__c = balancedPercentile
                    ));
                }
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext context) {
        if (recentPass) {
            Database.executeBatch(new RFMMonetaryPercentileBatch(false), 200);
        } else {
            Database.executeBatch(new RFMStatusBatch(), 200);
        }
    }

    @TestVisible
    private static Decimal percentileForRank(Integer rank, Integer total) {
        if (total == null || total <= 0 || rank == null) {
            return null;
        }
        if (total == 1) {
            return 100;
        }
        return ((Decimal.valueOf(rank - 1) / Decimal.valueOf(total - 1)) * 100).setScale(2);
    }
}

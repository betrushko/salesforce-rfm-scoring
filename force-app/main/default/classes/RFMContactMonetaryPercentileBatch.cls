public with sharing class RFMContactMonetaryPercentileBatch implements Database.Batchable<SObject>, Database.Stateful {
    @TestVisible private Boolean recentPass;
    @TestVisible private Integer totalRecords;
    @TestVisible private Integer processedRecords = 0;
    @TestVisible private Decimal currentAmount;
    @TestVisible private Integer currentTieStartRank = 1;

    public RFMContactMonetaryPercentileBatch() {
        this(true);
    }

    public RFMContactMonetaryPercentileBatch(Boolean recentPass) {
        this.recentPass = recentPass;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        totalRecords = [
            SELECT COUNT()
            FROM Contact
            WHERE RFM_Lifetime_Paid_Amount__c > 0
        ];

        if (recentPass) {
            return Database.getQueryLocator([
                SELECT Id,
                    RFM_Paid_Amount_12M__c,
                    RFM_Recent_Monetary_Percentile__c
                FROM Contact
                WHERE RFM_Lifetime_Paid_Amount__c > 0
                ORDER BY RFM_Paid_Amount_12M__c ASC NULLS FIRST, Id ASC
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id,
                RFM_Lifetime_Paid_Amount__c,
                RFM_Donor_Age_Months__c,
                RFM_Recent_Monetary_Percentile__c,
                RFM_Historical_Monetary_Percentile__c,
                RFM_Balanced_Monetary_Percentile__c,
                RFM_Monetary_Score__c,
                RFM_Rising_Star_Flag__c
            FROM Contact
            WHERE RFM_Lifetime_Paid_Amount__c > 0
            ORDER BY RFM_Lifetime_Paid_Amount__c ASC NULLS FIRST, Id ASC
        ]);
    }

    public void execute(Database.BatchableContext context, List<Contact> scope) {
        List<Contact> updates = new List<Contact>();
        for (Contact contactRecord : scope) {
            processedRecords++;

            Decimal amount = recentPass
                ? contactRecord.RFM_Paid_Amount_12M__c
                : contactRecord.RFM_Lifetime_Paid_Amount__c;
            amount = amount == null ? 0 : amount;
            if (currentAmount == null || currentAmount != amount) {
                currentAmount = amount;
                currentTieStartRank = processedRecords;
            }

            Decimal percentile = percentileForRank(currentTieStartRank, totalRecords);
            if (recentPass) {
                if (contactRecord.RFM_Recent_Monetary_Percentile__c != percentile) {
                    updates.add(new Contact(
                        Id = contactRecord.Id,
                        RFM_Recent_Monetary_Percentile__c = percentile
                    ));
                }
            } else {
                Decimal recentPercentile = contactRecord.RFM_Recent_Monetary_Percentile__c;
                Decimal historicalPercentile = percentile;
                Decimal balancedPercentile = recentPercentile == null
                    ? null
                    : ((recentPercentile * 0.50) + (historicalPercentile * 0.50)).setScale(2);
                Decimal monetaryScore = monetaryScoreFor(contactRecord.RFM_Lifetime_Paid_Amount__c, balancedPercentile);
                Boolean risingStar = contactRecord.RFM_Donor_Age_Months__c != null
                    && contactRecord.RFM_Donor_Age_Months__c <= 12
                    && recentPercentile != null
                    && recentPercentile >= 80;

                if (
                    contactRecord.RFM_Historical_Monetary_Percentile__c != historicalPercentile ||
                    contactRecord.RFM_Balanced_Monetary_Percentile__c != balancedPercentile ||
                    contactRecord.RFM_Monetary_Score__c != monetaryScore ||
                    contactRecord.RFM_Rising_Star_Flag__c != risingStar
                ) {
                    updates.add(new Contact(
                        Id = contactRecord.Id,
                        RFM_Historical_Monetary_Percentile__c = historicalPercentile,
                        RFM_Balanced_Monetary_Percentile__c = balancedPercentile,
                        RFM_Monetary_Score__c = monetaryScore,
                        RFM_Rising_Star_Flag__c = risingStar
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
            Database.executeBatch(new RFMContactMonetaryPercentileBatch(false), 200);
        } else {
            Database.executeBatch(new RFMContactStatusBatch(), 200);
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

    @TestVisible
    private static Decimal monetaryScoreFor(Decimal lifetimePaidAmount, Decimal balancedPercentile) {
        if (lifetimePaidAmount == null || lifetimePaidAmount <= 0 || balancedPercentile == null) {
            return 0;
        }
        if (balancedPercentile >= 80) {
            return 5;
        }
        if (balancedPercentile >= 60) {
            return 4;
        }
        if (balancedPercentile >= 40) {
            return 3;
        }
        if (balancedPercentile >= 20) {
            return 2;
        }
        return 1;
    }
}

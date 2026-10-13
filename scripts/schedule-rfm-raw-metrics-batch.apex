String jobName = 'RFM Raw Metrics Daily Refresh';

for (CronTrigger scheduledJob : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = :jobName
]) {
    System.abortJob(scheduledJob.Id);
}

System.schedule(jobName, '0 30 2 * * ?', new RFMRawMetricsBatch());

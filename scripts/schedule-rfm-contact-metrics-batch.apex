String jobName = 'RFM Contact Metrics Daily Refresh';
for (CronTrigger existingJob : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = :jobName
]) {
    System.abortJob(existingJob.Id);
}

System.schedule(jobName, '0 15 3 * * ?', new RFMContactMetricsBatch());

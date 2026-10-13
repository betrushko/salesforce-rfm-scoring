String jobName = 'RFM Status Daily Refresh';
for (CronTrigger scheduledJob : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = :jobName
]) {
    System.abortJob(scheduledJob.Id);
}

System.schedule(jobName, '0 0 3 * * ?', new RFMStatusBatch());

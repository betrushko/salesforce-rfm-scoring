String jobName = 'RFM Contact Status Daily Refresh';
for (CronTrigger existingJob : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = :jobName
]) {
    System.abortJob(existingJob.Id);
}

System.schedule(jobName, '0 45 3 * * ?', new RFMContactStatusBatch());

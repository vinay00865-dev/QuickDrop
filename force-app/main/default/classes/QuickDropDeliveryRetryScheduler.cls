public with sharing class QuickDropDeliveryRetryScheduler
    implements Schedulable {

    public void execute(SchedulableContext context) {

        Datetime currentTime = System.now();

        List<QuickDrop_Integration_Log__c> dueLogs = [
            SELECT Id,
                   Customer_Order__c,
                   Integration_Status__c,
                   Next_Retry_At__c
            FROM QuickDrop_Integration_Log__c
            WHERE Integration_Status__c = 'Retry Scheduled'
              AND Next_Retry_At__c <= :currentTime
              AND Customer_Order__c != null
            ORDER BY Next_Retry_At__c ASC
            LIMIT 1
        ];

        if (dueLogs.isEmpty()) {
            return;
        }

        QuickDrop_Integration_Log__c logRecord = dueLogs[0];

        // Mark the request as pending before enqueueing the retry.
        logRecord.Integration_Status__c = 'Pending';
        logRecord.Next_Retry_At__c = null;

        update logRecord;

        System.enqueueJob(
            new QuickDropDeliveryApiQueueable(
                logRecord.Customer_Order__c
            )
        );
    }
}
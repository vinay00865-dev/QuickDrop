public with sharing class QuickDropDeliveryApiQueueable
    implements Queueable, Database.AllowsCallouts {

    private List<Id> orderIds;

    private static final Integer MAX_ATTEMPTS = 3;

    public QuickDropDeliveryApiQueueable(Id orderId) {
        orderIds = new List<Id>();

        if (orderId != null) {
            orderIds.add(orderId);
        }
    }

    public QuickDropDeliveryApiQueueable(List<Id> orderIds) {
        this.orderIds = new List<Id>();

        if (orderIds != null) {
            this.orderIds.addAll(orderIds);
        }
    }

    public void execute(QueueableContext context) {

        if (orderIds == null || orderIds.isEmpty()) {
            return;
        }

        Set<Id> uniqueOrderIds = new Set<Id>(orderIds);
        Set<String> requestKeys = new Set<String>();

        for (Id orderId : uniqueOrderIds) {
            if (orderId != null) {
                requestKeys.add(buildRequestKey(orderId));
            }
        }

        if (requestKeys.isEmpty()) {
            return;
        }

        Map<String, QuickDrop_Integration_Log__c>
            logsByRequestKey =
                new Map<String, QuickDrop_Integration_Log__c>();

        for (QuickDrop_Integration_Log__c logRecord : [
            SELECT Id,
                   Customer_Order__c,
                   Request_Key__c,
                   Attempt_Count__c
            FROM QuickDrop_Integration_Log__c
            WHERE Request_Key__c IN :requestKeys
        ]) {
            logsByRequestKey.put(
                logRecord.Request_Key__c,
                logRecord
            );
        }

        List<QuickDrop_Integration_Log__c> logsToUpsert =
            new List<QuickDrop_Integration_Log__c>();

        // Make callouts before performing DML.
        for (Id orderId : uniqueOrderIds) {

            if (orderId == null) {
                continue;
            }

            String requestKey = buildRequestKey(orderId);

            QuickDropDeliveryApiService.DeliveryApiResult result;

            try {
                result =
                    QuickDropDeliveryApiService.createDeliveryRequest(
                        orderId
                    );
            } catch (Exception e) {

                result =
                    new QuickDropDeliveryApiService.DeliveryApiResult();

                result.success = false;
                result.errorMessage = e.getMessage();
            }

            QuickDrop_Integration_Log__c logRecord =
                logsByRequestKey.get(requestKey);

            if (logRecord == null) {
                logRecord = new QuickDrop_Integration_Log__c();
                logRecord.Request_Key__c = requestKey;
                logRecord.Customer_Order__c = orderId;
                logRecord.Attempt_Count__c = 0;
            }

            Integer previousAttempts =
                logRecord.Attempt_Count__c == null
                    ? 0
                    : Integer.valueOf(
                        logRecord.Attempt_Count__c
                    );

            Integer attemptCount = previousAttempts + 1;

            logRecord.Attempt_Count__c = attemptCount;
            logRecord.Last_Attempt_At__c = System.now();

            logRecord.HTTP_Status_Code__c =
                result == null ? null : result.statusCode;

            logRecord.External_Delivery_ID__c =
                result == null ? null : result.deliveryId;

            if (result != null && result.success == true) {

                logRecord.Integration_Status__c = 'Success';
                logRecord.Last_Error__c = null;
                logRecord.Next_Retry_At__c = null;

            } else {

                logRecord.Last_Error__c =
                    result == null ||
                    String.isBlank(result.errorMessage)
                        ? 'Unknown delivery integration error.'
                        : result.errorMessage;

                if (
                    isRetryable(result) &&
                    attemptCount < MAX_ATTEMPTS
                ) {
                    logRecord.Integration_Status__c =
                        'Retry Scheduled';

                    logRecord.Next_Retry_At__c =
                        System.now().addMinutes(
                            getRetryDelayMinutes(attemptCount)
                        );

                } else {
                    logRecord.Integration_Status__c = 'Failed';
                    logRecord.Next_Retry_At__c = null;
                }
            }

            logsToUpsert.add(logRecord);
        }

        if (!logsToUpsert.isEmpty()) {
            upsert logsToUpsert Request_Key__c;
        }
    }

    private static String buildRequestKey(Id orderId) {
        return 'QD-DELIVERY-' + String.valueOf(orderId);
    }

    private static Boolean isRetryable(
        QuickDropDeliveryApiService.DeliveryApiResult result
    ) {
        if (result == null || result.statusCode == null) {
            return true;
        }

        Integer code = result.statusCode;

        return code == 408 ||
               code == 429 ||
               (code >= 500 && code < 600);
    }

    private static Integer getRetryDelayMinutes(
        Integer attemptCount
    ) {
        if (attemptCount <= 1) {
            return 5;
        }

        return 15;
    }
}
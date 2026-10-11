@IsTest
private class QuickDropDeliveryRetrySchedulerTest {

    @TestSetup
    static void createTestData() {

        Zone__c zone =
            QuickDropTestDataFactory.createZone();
        insert zone;

        Store__c store =
            QuickDropTestDataFactory.createStore(zone.Id);
        insert store;

        Customer__c customer =
            QuickDropTestDataFactory.createCustomer();
        insert customer;

        Customer_Address__c address =
            QuickDropTestDataFactory.createAddress(
                customer.Id,
                zone.Id
            );
        insert address;

        Customer_Order__c order =
            QuickDropTestDataFactory.createOrder(
                customer.Id,
                store.Id,
                address.Id
            );
        insert order;
    }

    @IsTest
    static void testDueRetryIsProcessed() {

        Customer_Order__c order = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        String requestKey =
            'QD-DELIVERY-' + String.valueOf(order.Id);

        QuickDrop_Integration_Log__c logRecord =
            new QuickDrop_Integration_Log__c(
                Customer_Order__c = order.Id,
                Request_Key__c = requestKey,
                Integration_Status__c = 'Retry Scheduled',
                Attempt_Count__c = 1,
                Last_Error__c = 'HTTP 500',
                Next_Retry_At__c = System.now().addMinutes(-1)
            );

        insert logRecord;

        Test.setMock(
            HttpCalloutMock.class,
            new QuickDropDeliveryApiMock(
                201,
                '{"deliveryId":"EXT-DLV-1001",' +
                '"status":"Accepted"}'
            )
        );

        Test.startTest();

        new QuickDropDeliveryRetryScheduler().execute(null);

        Test.stopTest();

        QuickDrop_Integration_Log__c updatedLog = [
            SELECT Integration_Status__c,
                   Attempt_Count__c,
                   HTTP_Status_Code__c,
                   External_Delivery_ID__c,
                   Last_Error__c,
                   Next_Retry_At__c
            FROM QuickDrop_Integration_Log__c
            WHERE Id = :logRecord.Id
            LIMIT 1
        ];

        System.assertEquals(
            'Success',
            updatedLog.Integration_Status__c,
            'The retry should succeed.'
        );

        System.assertEquals(
            Decimal.valueOf('2'),
            updatedLog.Attempt_Count__c,
            'The attempt count should increase to 2.'
        );

        System.assertEquals(
            Decimal.valueOf('201'),
            updatedLog.HTTP_Status_Code__c,
            'HTTP 201 should be recorded.'
        );

        System.assertEquals(
            'EXT-DLV-1001',
            updatedLog.External_Delivery_ID__c,
            'The delivery ID should be stored.'
        );

        System.assertEquals(
            null,
            updatedLog.Next_Retry_At__c,
            'The retry time should be cleared.'
        );

        System.assertEquals(
            null,
            updatedLog.Last_Error__c,
            'The previous error should be cleared.'
        );
    }
}
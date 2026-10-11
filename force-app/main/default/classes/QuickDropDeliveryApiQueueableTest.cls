@IsTest
private class QuickDropDeliveryApiQueueableTest {

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
    static void testQueueableCalloutSuccess() {

        Customer_Order__c order = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.setMock(
            HttpCalloutMock.class,
            new QuickDropDeliveryApiMock(
                201,
                '{"deliveryId":"EXT-DLV-1001",' +
                '"status":"Accepted"}'
            )
        );

        Test.startTest();

        Id jobId = System.enqueueJob(
            new QuickDropDeliveryApiQueueable(order.Id)
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals(
            'Completed',
            job.Status,
            'The Queueable job should complete.'
        );

        System.assertEquals(
            0,
            job.NumberOfErrors,
            'The Queueable job should have no unhandled errors.'
        );

        String requestKey =
            'QD-DELIVERY-' + String.valueOf(order.Id);

        QuickDrop_Integration_Log__c logRecord = [
            SELECT Integration_Status__c,
                   Attempt_Count__c,
                   HTTP_Status_Code__c,
                   External_Delivery_ID__c,
                   Next_Retry_At__c
            FROM QuickDrop_Integration_Log__c
            WHERE Request_Key__c = :requestKey
            LIMIT 1
        ];

        System.assertEquals('Success', logRecord.Integration_Status__c);
        System.assertEquals(Decimal.valueOf('1'), logRecord.Attempt_Count__c);
        System.assertEquals(Decimal.valueOf('201'), logRecord.HTTP_Status_Code__c);
        System.assertEquals('EXT-DLV-1001', logRecord.External_Delivery_ID__c);
        System.assertEquals(null, logRecord.Next_Retry_At__c);
    }

    @IsTest
    static void testServerErrorSchedulesRetry() {

        Customer_Order__c order = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.setMock(
            HttpCalloutMock.class,
            new QuickDropDeliveryApiMock(
                500,
                '{"error":"Internal Server Error"}'
            )
        );

        Test.startTest();

        System.enqueueJob(
            new QuickDropDeliveryApiQueueable(order.Id)
        );

        Test.stopTest();

        String requestKey =
            'QD-DELIVERY-' + String.valueOf(order.Id);

        QuickDrop_Integration_Log__c logRecord = [
            SELECT Integration_Status__c,
                   Attempt_Count__c,
                   HTTP_Status_Code__c,
                   Last_Error__c,
                   Next_Retry_At__c
            FROM QuickDrop_Integration_Log__c
            WHERE Request_Key__c = :requestKey
            LIMIT 1
        ];

        System.assertEquals(
            'Retry Scheduled',
            logRecord.Integration_Status__c
        );

        System.assertEquals(
            Decimal.valueOf('1'),
            logRecord.Attempt_Count__c
        );

        System.assertEquals(
            Decimal.valueOf('500'),
            logRecord.HTTP_Status_Code__c
        );

        System.assertNotEquals(
            null,
            logRecord.Next_Retry_At__c
        );

        System.assert(
            logRecord.Last_Error__c.contains('HTTP 500')
        );
    }

    @IsTest
    static void testBadRequestIsNotRetried() {

        Customer_Order__c order = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.setMock(
            HttpCalloutMock.class,
            new QuickDropDeliveryApiMock(
                400,
                '{"error":"Bad Request"}'
            )
        );

        Test.startTest();

        System.enqueueJob(
            new QuickDropDeliveryApiQueueable(order.Id)
        );

        Test.stopTest();

        String requestKey =
            'QD-DELIVERY-' + String.valueOf(order.Id);

        QuickDrop_Integration_Log__c logRecord = [
            SELECT Integration_Status__c,
                   Attempt_Count__c,
                   Next_Retry_At__c
            FROM QuickDrop_Integration_Log__c
            WHERE Request_Key__c = :requestKey
            LIMIT 1
        ];

        System.assertEquals('Failed', logRecord.Integration_Status__c);
        System.assertEquals(Decimal.valueOf('1'), logRecord.Attempt_Count__c);
        System.assertEquals(null, logRecord.Next_Retry_At__c);
    }
}
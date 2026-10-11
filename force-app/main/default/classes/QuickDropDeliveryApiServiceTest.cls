@IsTest
public class QuickDropDeliveryApiServiceTest {

    // =========================================================
    // TEST DATA
    // =========================================================

    @TestSetup
    static void createTestData() {

        Zone__c zone =
            QuickDropTestDataFactory.createZone();

        insert zone;

        Store__c store =
            QuickDropTestDataFactory.createStore(
                zone.Id
            );

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


    // =========================================================
    // TEST SUCCESSFUL API RESPONSE
    // =========================================================

    @IsTest
    static void testSuccessfulDeliveryRequest() {

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

        QuickDropDeliveryApiService.DeliveryApiResult result =
            QuickDropDeliveryApiService.createDeliveryRequest(
                order.Id
            );

        Test.stopTest();

        System.assertEquals(
            true,
            result.success,
            'The API request should succeed.'
        );

        System.assertEquals(
            201,
            result.statusCode,
            'Expected HTTP 201.'
        );

        System.assertEquals(
            'EXT-DLV-1001',
            result.deliveryId,
            'The external delivery ID should be returned.'
        );

        System.assertEquals(
            'Accepted',
            result.deliveryStatus,
            'The delivery status should be returned.'
        );
    }


    // =========================================================
    // TEST HTTP 500 RESPONSE
    // =========================================================

    @IsTest
    static void testDeliveryApiServerError() {

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

        QuickDropDeliveryApiService.DeliveryApiResult result =
            QuickDropDeliveryApiService.createDeliveryRequest(
                order.Id
            );

        Test.stopTest();

        System.assertEquals(
            false,
            result.success,
            'The API request should be reported as failed.'
        );

        System.assertEquals(
            500,
            result.statusCode,
            'The HTTP status should be 500.'
        );

        System.assert(
            result.errorMessage.contains('HTTP 500'),
            'The error message should include HTTP 500.'
        );
    }


    // =========================================================
    // TEST INVALID ORDER ID
    // =========================================================

    @IsTest
    static void testNullOrderId() {

        Boolean exceptionThrown = false;

        try {
            QuickDropDeliveryApiService.createDeliveryRequest(
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'A null Order Id should raise an exception.'
        );
    }
}
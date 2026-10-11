@IsTest
public class QuickDropOrderServiceTest {

    // =========================================================
    // COMMON TEST DATA
    // =========================================================

    @TestSetup
    static void createTestData() {

        // Zone
        Zone__c zone =
            QuickDropTestDataFactory.createZone();

        insert zone;


        // Store
        Store__c store =
            QuickDropTestDataFactory.createStore(
                zone.Id
            );

        insert store;


        // Customer
        Customer__c customer =
            QuickDropTestDataFactory.createCustomer();

        insert customer;


        // Address
        Customer_Address__c address =
            QuickDropTestDataFactory.createAddress(
                customer.Id,
                zone.Id
            );

        insert address;


        // Order
        Customer_Order__c order =
            QuickDropTestDataFactory.createOrder(
                customer.Id,
                store.Id,
                address.Id
            );

        insert order;
    }


    // =========================================================
    // TEST GET ORDER
    // =========================================================

    @IsTest
    static void testGetOrder() {

        Customer_Order__c testOrder = [
            SELECT Id, Name, Status__c
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.startTest();

        Customer_Order__c result =
            QuickDropOrderService.getOrder(
                testOrder.Id
            );

        Test.stopTest();


        System.assertNotEquals(
            null,
            result,
            'Order should be returned.'
        );

        System.assertEquals(
            testOrder.Id,
            result.Id,
            'Returned Order Id should match.'
        );
    }


    // =========================================================
    // TEST GET CUSTOMER ORDERS
    // =========================================================

    @IsTest
    static void testGetCustomerOrders() {

        Customer__c customer = [
            SELECT Id
            FROM Customer__c
            WHERE Name = 'Test QuickDrop Customer'
            LIMIT 1
        ];

        Test.startTest();

        List<Customer_Order__c> results =
            QuickDropOrderService.getCustomerOrders(
                customer.Id
            );

        Test.stopTest();


        System.assertEquals(
            1,
            results.size(),
            'Customer should have one test order.'
        );
    }


    // =========================================================
    // TEST UPDATE ORDER STATUS
    // =========================================================

    @IsTest
    static void testUpdateOrderStatus() {

        Customer_Order__c testOrder = [
            SELECT Id, Status__c
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.startTest();

        QuickDropOrderService.updateOrderStatus(
            testOrder.Id,
            'Confirmed'
        );

        Test.stopTest();


        Customer_Order__c updatedOrder = [
            SELECT Id, Status__c
            FROM Customer_Order__c
            WHERE Id = :testOrder.Id
        ];


        System.assertEquals(
            'Confirmed',
            updatedOrder.Status__c,
            'Order status should be updated.'
        );
    }


    // =========================================================
    // TEST INVALID ORDER ID
    // =========================================================

    @IsTest
    static void testInvalidOrderId() {

        Boolean exceptionThrown = false;

        try {

            Test.startTest();

            QuickDropOrderService.getOrder(null);

            Test.stopTest();

        } catch (Exception e) {

            exceptionThrown = true;
        }


        System.assertEquals(
            true,
            exceptionThrown,
            'Exception should be thrown for null Order Id.'
        );
    }
}
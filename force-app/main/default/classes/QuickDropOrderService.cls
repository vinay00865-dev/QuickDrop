public with sharing class QuickDropOrderService {

    // =========================================================
    // GET ORDER
    // =========================================================

    public static Customer_Order__c getOrder(Id orderId) {

        if (orderId == null) {
            throw new AuraHandledException(
                'Order Id is required.'
            );
        }

        List<Customer_Order__c> orders = [
            SELECT Id,
                   Name,
                   Customer__c,
                   Customer__r.Name,
                   Store__c,
                   Store__r.Name,
                   Delivery_Address__c,
                   Delivery_Address__r.Name,
                   Order_Date__c,
                   Status__c,
                   Payment_Status__c,
                   Subtotal__c,
                   Tax__c,
                   Delivery_Fee__c,
                   Discount__c,
                   Grand_Total__c,
                   Estimated_Delivery_Time__c
            FROM Customer_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException(
                'Order not found.'
            );
        }

        return orders[0];
    }


    // =========================================================
    // GET CUSTOMER ORDERS
    // =========================================================

    public static List<Customer_Order__c>
        getCustomerOrders(Id customerId) {

        if (customerId == null) {
            return new List<Customer_Order__c>();
        }

        return [
            SELECT Id,
                   Name,
                   Customer__c,
                   Customer__r.Name,
                   Store__c,
                   Store__r.Name,
                   Delivery_Address__c,
                   Delivery_Address__r.Name,
                   Order_Date__c,
                   Status__c,
                   Payment_Status__c,
                   Subtotal__c,
                   Tax__c,
                   Delivery_Fee__c,
                   Discount__c,
                   Grand_Total__c,
                   Estimated_Delivery_Time__c
            FROM Customer_Order__c
            WHERE Customer__c = :customerId
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }


    // =========================================================
    // UPDATE ORDER STATUS
    // =========================================================

    public static void updateOrderStatus(
        Id orderId,
        String newStatus
    ) {

        if (orderId == null) {
            throw new AuraHandledException(
                'Order Id is required.'
            );
        }

        if (String.isBlank(newStatus)) {
            throw new AuraHandledException(
                'Order status is required.'
            );
        }

        Customer_Order__c order =
            getOrder(orderId);

        order.Status__c = newStatus;

        update order;
    }
}
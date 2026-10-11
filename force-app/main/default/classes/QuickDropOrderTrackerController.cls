public with sharing class QuickDropOrderTrackerController {

    @AuraEnabled(cacheable=true)
    public static List<Customer_Order__c> getCurrentCustomerOrders() {
        Id currentUserId = UserInfo.getUserId();

        List<Customer__c> customers = [
            SELECT Id, Name
            FROM Customer__c
            WHERE Salesforce_User__c = :currentUserId
              AND Active__c = true
            LIMIT 1
        ];

        if (customers.isEmpty()) {
            throw new AuraHandledException(
                'No active QuickDrop customer is linked to your Salesforce user.'
            );
        }

        Id customerId = customers[0].Id;

        return [
            SELECT Id, Name,
                   Customer__c, Customer__r.Name,
                   Store__c, Store__r.Name,
                   Delivery_Address__c, Delivery_Address__r.Name,
                   Order_Date__c, Status__c, Payment_Status__c,
                   Subtotal__c, Tax__c, Delivery_Fee__c,
                   Discount__c, Grand_Total__c,
                   Estimated_Delivery_Time__c
            FROM Customer_Order__c
            WHERE Customer__c = :customerId
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }


    @AuraEnabled(cacheable=true)
    public static Customer_Order__c getOrder(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        List<Customer_Order__c> orders = [
            SELECT Id, Name,
                   Customer__c, Customer__r.Name,
                   Store__c, Store__r.Name,
                   Delivery_Address__c, Delivery_Address__r.Name,
                   Order_Date__c, Status__c, Payment_Status__c,
                   Subtotal__c, Tax__c, Delivery_Fee__c,
                   Discount__c, Grand_Total__c,
                   Estimated_Delivery_Time__c
            FROM Customer_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException('Order not found.');
        }

        return orders[0];
    }
}
public with sharing class QuickDropDeliveryTrackerController {

    @AuraEnabled(cacheable=true)
    public static List<Customer__c> getCustomers() {
        return [
            SELECT Id, Name
            FROM Customer__c
            WHERE Active__c = true
            ORDER BY Name
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Customer_Order__c> getOrders(Id customerId) {

        if (customerId == null) {
            return new List<Customer_Order__c>();
        }

        return [
            SELECT Id,
                   Name,
                   Order_Date__c,
                   Status__c,
                   Payment_Status__c,
                   Grand_Total__c
            FROM Customer_Order__c
            WHERE Customer__c = :customerId
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    @AuraEnabled
    public static Delivery__c getDelivery(Id orderId) {

        if (orderId == null) {
            throw new AuraHandledException(
                'Order Id is required.'
            );
        }

        List<Delivery__c> deliveries = [
            SELECT Id,
                   Name,
                   Order__c,
                   Order__r.Name,
                   Delivery_Agent__c,
                   Delivery_Agent__r.Name,
                   Delivery_Agent__r.Agent_Name__c,
                   Pickup_Store__c,
                   Pickup_Store__r.Name,
                   Status__c,
                   Assigned_Time__c,
                   Pickup_Time__c,
                   Out_for_Delivery_Time__c,
                   Delivered_Time__c,
                   ETA__c,
                   Current_Latitude__c,
                   Current_Longitude__c
            FROM Delivery__c
            WHERE Order__c = :orderId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (deliveries.isEmpty()) {
            throw new AuraHandledException(
                'No delivery has been assigned to this order yet.'
            );
        }

        return deliveries[0];
    }
}
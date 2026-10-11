public with sharing class QuickDropCollectionDemo {

    public static void demonstrateCollections() {

        // =====================================================
        // 1. LIST
        // =====================================================

        List<Customer_Order__c> orders = [
            SELECT Id,
                   Name,
                   Customer__c,
                   Status__c,
                   Grand_Total__c
            FROM Customer_Order__c
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        System.debug('Total Orders: ' + orders.size());


        // =====================================================
        // 2. SET
        // =====================================================

        Set<Id> customerIds = new Set<Id>();

        for (Customer_Order__c order : orders) {

            if (order.Customer__c != null) {
                customerIds.add(order.Customer__c);
            }
        }

        System.debug(
            'Unique Customer IDs: ' +
            customerIds.size()
        );


        // =====================================================
        // 3. ONE SOQL QUERY
        // =====================================================

        List<Customer__c> customers = [
            SELECT Id,
                   Name,
                   Email__c,
                   Phone__c
            FROM Customer__c
            WHERE Id IN :customerIds
        ];


        // =====================================================
        // 4. MAP
        // =====================================================

        Map<Id, Customer__c> customersById =
            new Map<Id, Customer__c>(customers);


        // =====================================================
        // 5. MAP LOOKUP
        // =====================================================

        for (Customer_Order__c order : orders) {

            Customer__c customer =
                customersById.get(order.Customer__c);

            if (customer != null) {

                System.debug(
                    'Order: ' + order.Name +
                    ' | Customer: ' + customer.Name +
                    ' | Status: ' + order.Status__c +
                    ' | Total: ' + order.Grand_Total__c
                );
            }
        }
    }
}
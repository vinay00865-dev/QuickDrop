public with sharing class QuickDropStoreContextController {

    // =========================================================
    // CUSTOMER CONTEXT WRAPPER
    // =========================================================

    public class StoreContext {

        @AuraEnabled
        public Id customerId;

        @AuraEnabled
        public String customerName;

        @AuraEnabled
        public Id addressId;

        @AuraEnabled
        public String addressLabel;

        @AuraEnabled
        public String addressLine;

        @AuraEnabled
        public String city;

        @AuraEnabled
        public String state;

        @AuraEnabled
        public String pincode;

        @AuraEnabled
        public Id zoneId;

        @AuraEnabled
        public String zoneName;

        @AuraEnabled
        public Id storeId;

        @AuraEnabled
        public String storeName;
    }


    // =========================================================
    // GET CURRENT LOGGED-IN CUSTOMER CONTEXT
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static StoreContext getCurrentContext() {

        Id currentUserId = UserInfo.getUserId();


        // -----------------------------------------------------
        // FIND CUSTOMER LINKED TO CURRENT SALESFORCE USER
        // -----------------------------------------------------

        List<Customer__c> customers = [
            SELECT Id,
                   Name
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


        Customer__c customer =
            customers[0];


        // -----------------------------------------------------
        // FIND DEFAULT ACTIVE ADDRESS
        // -----------------------------------------------------

        List<Customer_Address__c> addresses = [
            SELECT Id,
                   Name,
                   Address_Label__c,
                   Address_Line__c,
                   City__c,
                   State__c,
                   Pincode__c,
                   Zone__c,
                   Zone__r.Name
            FROM Customer_Address__c
            WHERE Customer__c = :customer.Id
              AND Default_Address__c = true
              AND Active__c = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];


        if (addresses.isEmpty()) {

            throw new AuraHandledException(
                'No default delivery address is configured for your QuickDrop account.'
            );
        }


        Customer_Address__c address =
            addresses[0];


        if (address.Zone__c == null) {

            throw new AuraHandledException(
                'Your delivery address is not mapped to a QuickDrop Zone.'
            );
        }


        // -----------------------------------------------------
        // FIND ACTIVE STORE IN THAT ZONE
        // -----------------------------------------------------

        List<Store__c> stores = [
            SELECT Id,
                   Name,
                   Zone__c
            FROM Store__c
            WHERE Zone__c = :address.Zone__c
              AND Active__c = true
            ORDER BY Name
            LIMIT 1
        ];


        if (stores.isEmpty()) {

            throw new AuraHandledException(
                'No active QuickDrop store is available in your delivery zone.'
            );
        }


        Store__c store =
            stores[0];


        // -----------------------------------------------------
        // BUILD RESPONSE
        // -----------------------------------------------------

        StoreContext context =
            new StoreContext();


        context.customerId =
            customer.Id;

        context.customerName =
            customer.Name;


        context.addressId =
            address.Id;

        context.addressLabel =
            address.Address_Label__c;

        context.addressLine =
            address.Address_Line__c;

        context.city =
            address.City__c;

        context.state =
            address.State__c;

        context.pincode =
            address.Pincode__c != null
                ? String.valueOf(address.Pincode__c)
                : null;


        context.zoneId =
            address.Zone__c;

        context.zoneName =
            address.Zone__r != null
                ? address.Zone__r.Name
                : null;


        context.storeId =
            store.Id;

        context.storeName =
            store.Name;


        return context;
    }
}
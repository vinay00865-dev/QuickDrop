@IsTest
public class QuickDropTestDataFactory {

    // =========================================================
    // CREATE ZONE
    // =========================================================

    public static Zone__c createZone() {

        return new Zone__c(
            Name = 'Test Zone',
            Zone_Code__c = 'TEST01',
            Pincode_Start__c = 500001,
            Pincode_End__c = 500999,
            Active__c = true
        );
    }


    // =========================================================
    // CREATE STORE
    // =========================================================

    public static Store__c createStore(Id zoneId) {

        return new Store__c(
            Name = 'Test QuickDrop Store',
            Store_Code__c = 'TESTSTORE',
            Zone__c = zoneId,
            Address__c = 'Test Store Address, Hyderabad',
            Pincode__c = 500034,
            Phone__c = '9876543210',
            Closing_Time__c = Time.newInstance(22, 0, 0, 0),
            Active__c = true
        );
    }


    // =========================================================
    // CREATE CUSTOMER
    // =========================================================

    public static Customer__c createCustomer() {

        return new Customer__c(
            Name = 'Test QuickDrop Customer',
            Email__c = 'testcustomer@quickdrop.com',
            Registration_Date__c = Date.today(),
            Active__c = true
        );
    }


    // =========================================================
    // CREATE CUSTOMER ADDRESS
    // =========================================================

    public static Customer_Address__c createAddress(
        Id customerId,
        Id zoneId
    ) {

        return new Customer_Address__c(
            Customer__c = customerId,
            Address_Label__c = 'Home',
            Address_Line__c = 'Test Address',
            City__c = 'Hyderabad',
            State__c = 'Telangana',
            Pincode__c = 500034,
            Zone__c = zoneId,
            Default_Address__c = true,
            Active__c = true
        );
    }


    // =========================================================
    // CREATE CUSTOMER ORDER
    // =========================================================

    public static Customer_Order__c createOrder(
        Id customerId,
        Id storeId,
        Id addressId
    ) {

        return new Customer_Order__c(
            Customer__c = customerId,
            Store__c = storeId,
            Delivery_Address__c = addressId,
            Order_Date__c = Date.today(),
            Status__c = 'Draft',
            Payment_Status__c = 'Pending',
            Subtotal__c = 100,
            Tax__c = 10,
            Delivery_Fee__c = 40,
            Discount__c = 0
        );
    }
}
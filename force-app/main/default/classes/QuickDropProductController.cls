public with sharing class QuickDropProductController {

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts() {
        return [
            SELECT Id,
                   Name,
                   SKU__c,
                   Brand__c,
                   Selling_Price__c,
                   MRP__c,
                   Tax__c,
                   Active__c,
                   Category__c,
                   Category__r.Name
            FROM Product__c
            WHERE Active__c = true
            ORDER BY Name
        ];
    }
}
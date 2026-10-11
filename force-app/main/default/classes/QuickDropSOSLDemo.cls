public with sharing class QuickDropSOSLDemo {

    public static void searchQuickDrop() {

        List<List<SObject>> results = [
            FIND 'QuickDrop'
            IN ALL FIELDS
            RETURNING
                Product__c(Id, Name),
                Store__c(Id, Name),
                Category__c(Id, Name)
        ];


        // Products
        List<Product__c> products =
            (List<Product__c>) results[0];

        // Stores
        List<Store__c> stores =
            (List<Store__c>) results[1];

        // Categories
        List<Category__c> categories =
            (List<Category__c>) results[2];


        System.debug(
            'Products found: ' +
            products.size()
        );

        System.debug(
            'Stores found: ' +
            stores.size()
        );

        System.debug(
            'Categories found: ' +
            categories.size()
        );


        for (Product__c product : products) {
            System.debug(
                'Product: ' + product.Name
            );
        }

        for (Store__c store : stores) {
            System.debug(
                'Store: ' + store.Name
            );
        }

        for (Category__c category : categories) {
            System.debug(
                'Category: ' + category.Name
            );
        }
    }
}
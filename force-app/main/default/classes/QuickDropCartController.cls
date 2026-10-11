public with sharing class QuickDropCartController {

    // =========================================================
    // GET CUSTOMERS
    // =========================================================

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


    // =========================================================
    // GET STORES
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<Store__c> getStores() {

        return [
            SELECT Id, Name
            FROM Store__c
            WHERE Active__c = true
            ORDER BY Name
            LIMIT 200
        ];
    }


    // =========================================================
    // GET PRODUCTS
    // =========================================================

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
                   Active__c
            FROM Product__c
            WHERE Active__c = true
            ORDER BY Name
            LIMIT 500
        ];
    }


    // =========================================================
    // GET ACTIVE CART
    // =========================================================

    @AuraEnabled
    public static List<Cart_Item__c> getCart(
        Id customerId,
        Id storeId
    ) {

        if (
            customerId == null ||
            storeId == null
        ) {
            return new List<Cart_Item__c>();
        }


        List<Cart__c> carts = [
            SELECT Id
            FROM Cart__c
            WHERE Customer_Quickdrop__c = :customerId
              AND Store__c = :storeId
              AND Status__c = 'Active'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];


        if (carts.isEmpty()) {
            return new List<Cart_Item__c>();
        }


        Id cartId = carts[0].Id;


        return [
            SELECT Id,
                   Cart__c,
                   QuickDrop_Product__c,
                   QuickDrop_Product__r.Name,
                   QuickDrop_Product__r.SKU__c,
                   QuickDrop_Product__r.Brand__c,
                   Quantity__c,
                   Unit_Price__c,
                   Discount__c,
                   Line_Total__c
            FROM Cart_Item__c
            WHERE Cart__c = :cartId
            ORDER BY CreatedDate ASC
        ];
    }


    // =========================================================
    // ADD PRODUCT TO CART
    // =========================================================

    @AuraEnabled
    public static void addToCart(
        Id customerId,
        Id storeId,
        Id productId,
        Integer quantity
    ) {

        if (customerId == null) {
            throw new AuraHandledException(
                'Customer is required.'
            );
        }

        if (storeId == null) {
            throw new AuraHandledException(
                'Store is required.'
            );
        }

        if (productId == null) {
            throw new AuraHandledException(
                'Product is required.'
            );
        }

        if (
            quantity == null ||
            quantity < 1
        ) {
            throw new AuraHandledException(
                'Quantity must be at least 1.'
            );
        }


        // -----------------------------------------------------
        // GET PRODUCT
        // -----------------------------------------------------

        List<Product__c> products = [
            SELECT Id,
                   Selling_Price__c,
                   Active__c
            FROM Product__c
            WHERE Id = :productId
            LIMIT 1
        ];


        if (products.isEmpty()) {
            throw new AuraHandledException(
                'Product was not found.'
            );
        }


        Product__c product = products[0];


        if (product.Active__c != true) {
            throw new AuraHandledException(
                'Selected product is inactive.'
            );
        }


        if (product.Selling_Price__c == null) {
            throw new AuraHandledException(
                'Product selling price is not configured.'
            );
        }


        // -----------------------------------------------------
        // FIND ACTIVE CART
        // -----------------------------------------------------

        List<Cart__c> carts = [
            SELECT Id
            FROM Cart__c
            WHERE Customer_Quickdrop__c = :customerId
              AND Store__c = :storeId
              AND Status__c = 'Active'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];


        Cart__c cart;


        if (carts.isEmpty()) {

            cart = new Cart__c();

            cart.Customer_Quickdrop__c =
                customerId;

            cart.Store__c =
                storeId;

            cart.Status__c =
                'Active';

            cart.Total_Amount__c =
                0;

            insert cart;

        } else {

            cart = carts[0];

        }


        // -----------------------------------------------------
        // CHECK EXISTING ITEM
        // -----------------------------------------------------

        List<Cart_Item__c> existingItems = [
            SELECT Id,
                   Quantity__c
            FROM Cart_Item__c
            WHERE Cart__c = :cart.Id
              AND QuickDrop_Product__c = :productId
            LIMIT 1
        ];


        if (!existingItems.isEmpty()) {

            Decimal oldQuantity =
                existingItems[0].Quantity__c == null
                    ? 0
                    : existingItems[0].Quantity__c;


            Cart_Item__c itemToUpdate =
                new Cart_Item__c(
                    Id = existingItems[0].Id,
                    Quantity__c =
                        oldQuantity + quantity
                );


            update itemToUpdate;

        } else {

            Cart_Item__c newItem =
                new Cart_Item__c();

            newItem.Cart__c =
                cart.Id;

            newItem.QuickDrop_Product__c =
                productId;

            newItem.Quantity__c =
                quantity;

            newItem.Unit_Price__c =
                product.Selling_Price__c;

            newItem.Discount__c =
                0;

            insert newItem;
        }


        recalculateCartTotal(
            cart.Id
        );
    }


    // =========================================================
    // ONE METHOD FOR:
    // INCREASE / DECREASE / REMOVE
    // =========================================================

    @AuraEnabled
    public static void changeCartItem(
        Id cartItemId,
        String action
    ) {

        if (cartItemId == null) {
            throw new AuraHandledException(
                'Cart Item ID is required.'
            );
        }


        if (String.isBlank(action)) {
            throw new AuraHandledException(
                'Cart action is required.'
            );
        }


        List<Cart_Item__c> items = [
            SELECT Id,
                   Cart__c,
                   Quantity__c
            FROM Cart_Item__c
            WHERE Id = :cartItemId
            LIMIT 1
        ];


        if (items.isEmpty()) {
            throw new AuraHandledException(
                'Cart item was not found.'
            );
        }


        Cart_Item__c currentItem =
            items[0];


        Id cartId =
            currentItem.Cart__c;


        Integer currentQuantity =
            currentItem.Quantity__c == null
                ? 0
                : Integer.valueOf(
                    currentItem.Quantity__c
                );


        // -----------------------------------------------------
        // INCREASE
        // -----------------------------------------------------

        if (action == 'INCREASE') {

            Cart_Item__c itemToUpdate =
                new Cart_Item__c(
                    Id = cartItemId,
                    Quantity__c =
                        currentQuantity + 1
                );


            update itemToUpdate;

        }


        // -----------------------------------------------------
        // DECREASE
        // -----------------------------------------------------

        else if (action == 'DECREASE') {

            if (currentQuantity <= 1) {

                delete new Cart_Item__c(
                    Id = cartItemId
                );

            } else {

                Cart_Item__c itemToUpdate =
                    new Cart_Item__c(
                        Id = cartItemId,
                        Quantity__c =
                            currentQuantity - 1
                    );


                update itemToUpdate;
            }

        }


        // -----------------------------------------------------
        // REMOVE
        // -----------------------------------------------------

        else if (action == 'REMOVE') {

            delete new Cart_Item__c(
                Id = cartItemId
            );

        }


        else {

            throw new AuraHandledException(
                'Invalid cart action: ' + action
            );
        }


        // -----------------------------------------------------
        // UPDATE CART TOTAL
        // -----------------------------------------------------

        if (cartId != null) {

            recalculateCartTotal(
                cartId
            );
        }
    }


    // =========================================================
    // RECALCULATE CART TOTAL
    // =========================================================

    private static void recalculateCartTotal(
        Id cartId
    ) {

        if (cartId == null) {
            return;
        }


        List<Cart_Item__c> items = [
            SELECT Line_Total__c
            FROM Cart_Item__c
            WHERE Cart__c = :cartId
        ];


        Decimal total = 0;


        for (Cart_Item__c item : items) {

            if (item.Line_Total__c != null) {

                total +=
                    item.Line_Total__c;
            }
        }


        Cart__c cartToUpdate =
            new Cart__c(
                Id = cartId,
                Total_Amount__c = total
            );


        update cartToUpdate;
    }

}
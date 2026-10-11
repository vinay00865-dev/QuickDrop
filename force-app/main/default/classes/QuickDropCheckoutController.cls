public with sharing class QuickDropCheckoutController {

    public class CheckoutResult {

        @AuraEnabled
        public Id orderId;

        @AuraEnabled
        public String orderNumber;

        @AuraEnabled
        public Decimal grandTotal;

        @AuraEnabled
        public String paymentStatus;

        @AuraEnabled
        public String orderStatus;
    }


    // =========================================================
    // GET CUSTOMER / STORE CONTEXT
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static QuickDropStoreContextController.StoreContext
        getCheckoutContext() {

        return QuickDropStoreContextController.getCurrentContext();
    }


    // =========================================================
    // GET ACTIVE CUSTOMER ADDRESSES
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<Customer_Address__c>
        getAddresses(Id customerId) {

        Id currentCustomerId = getCurrentCustomerId();

        if (customerId == null || customerId != currentCustomerId) {
            throw new AuraHandledException(
                'You are not authorized to access this customer account.'
            );
        }

        return [
            SELECT Id,
                   Name,
                   Customer__c,
                   Address_Label__c,
                   Address_Line__c,
                   City__c,
                   State__c,
                   Pincode__c,
                   Default_Address__c,
                   Active__c
            FROM Customer_Address__c
            WHERE Customer__c = :customerId
              AND Active__c = true
            ORDER BY Default_Address__c DESC, CreatedDate DESC
        ];
    }


    // =========================================================
    // GET ACTIVE CART ITEMS
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<Cart_Item__c>
        getCheckoutCart(
            Id customerId,
            Id storeId
        ) {

        Id currentCustomerId = getCurrentCustomerId();

        if (customerId == null || customerId != currentCustomerId) {
            throw new AuraHandledException(
                'You are not authorized to access this customer cart.'
            );
        }

        if (storeId == null) {
            throw new AuraHandledException(
                'Store is required for checkout.'
            );
        }

        List<Cart__c> carts = [
            SELECT Id,
                   Status__c
            FROM Cart__c
            WHERE Customer_Quickdrop__c = :customerId
              AND Store__c = :storeId
              AND Status__c = 'Active'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (carts.isEmpty()) {
            throw new AuraHandledException(
                'Your active cart could not be found.'
            );
        }

        Id cartId = carts[0].Id;

        return [
            SELECT Id,
                   Cart__c,
                   QuickDrop_Product__c,
                   QuickDrop_Product__r.Name,
                   QuickDrop_Product__r.Selling_Price__c,
                   Quantity__c,
                   Unit_Price__c,
                   Discount__c,
                   Line_Total__c
            FROM Cart_Item__c
            WHERE Cart__c = :cartId
            ORDER BY CreatedDate
        ];
    }


    // =========================================================
    // PLACE ORDER
    // =========================================================

    @AuraEnabled
    public static CheckoutResult placeOrder(
        Id customerId,
        Id storeId,
        Id addressId,
        String paymentMethod
    ) {

        Savepoint checkoutSavepoint = Database.setSavepoint();

        try {

            // -------------------------------------------------
            // BASIC VALIDATION
            // -------------------------------------------------

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

            if (addressId == null) {
                throw new AuraHandledException(
                    'Delivery address is required.'
                );
            }

            if (String.isBlank(paymentMethod)) {
                throw new AuraHandledException(
                    'Payment method is required.'
                );
            }


            // -------------------------------------------------
            // SECURITY CHECK
            // -------------------------------------------------

            Id currentCustomerId = getCurrentCustomerId();

            if (customerId != currentCustomerId) {
                throw new AuraHandledException(
                    'You cannot place an order for another customer.'
                );
            }


            // -------------------------------------------------
            // VALIDATE ADDRESS
            // -------------------------------------------------

            List<Customer_Address__c> addresses = [
                SELECT Id,
                       Customer__c,
                       Active__c
                FROM Customer_Address__c
                WHERE Id = :addressId
                  AND Customer__c = :customerId
                  AND Active__c = true
                LIMIT 1
            ];

            if (addresses.isEmpty()) {
                throw new AuraHandledException(
                    'The selected delivery address is invalid.'
                );
            }


            // -------------------------------------------------
            // GET ACTIVE CART
            // -------------------------------------------------

            List<Cart__c> carts = [
                SELECT Id,
                       Customer_Quickdrop__c,
                       Store__c,
                       Status__c
                FROM Cart__c
                WHERE Customer_Quickdrop__c = :customerId
                  AND Store__c = :storeId
                  AND Status__c = 'Active'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (carts.isEmpty()) {
                throw new AuraHandledException(
                    'This cart has already been checked out. '
                    + 'Please return to Home and create a new cart.'
                );
            }

            Cart__c cart = carts[0];


            // -------------------------------------------------
            // GET CART ITEMS
            // -------------------------------------------------

            List<Cart_Item__c> cartItems = [
                SELECT Id,
                       Cart__c,
                       QuickDrop_Product__c,
                       QuickDrop_Product__r.Name,
                       Quantity__c,
                       Unit_Price__c,
                       Discount__c,
                       Line_Total__c
                FROM Cart_Item__c
                WHERE Cart__c = :cart.Id
                ORDER BY CreatedDate
            ];

            if (cartItems.isEmpty()) {
                throw new AuraHandledException(
                    'Your cart is empty. Add products before checkout.'
                );
            }


            // -------------------------------------------------
            // CREATE CUSTOMER ORDER
            // -------------------------------------------------

            Decimal deliveryFee = 40;

            Customer_Order__c order = new Customer_Order__c();

            order.Customer__c = customerId;
            order.Store__c = storeId;
            order.Delivery_Address__c = addressId;

            order.Order_Date__c = Date.today();

            order.Status__c = 'Draft';
            order.Payment_Status__c = 'Pending';

            // The Order Total Calculation flow will
            // recalculate subtotal/tax after line items
            // are inserted.
            order.Subtotal__c = 0;
            order.Tax__c = 0;
            order.Delivery_Fee__c = deliveryFee;
            order.Discount__c = 0;

            // Approximately 30 minutes initially.
            // Delivery Assignment automation may update ETA.
            order.Estimated_Delivery_Time__c =
                System.now().addMinutes(30);

            insert order;


            // -------------------------------------------------
            // CREATE ORDER LINE ITEMS
            // -------------------------------------------------

            List<Order_Line_Item__c> orderLineItems =
                new List<Order_Line_Item__c>();

            for (Cart_Item__c cartItem : cartItems) {

                Order_Line_Item__c line =
                    new Order_Line_Item__c();

                line.Order__c = order.Id;

                line.QuickDrop_Product__c =
                    cartItem.QuickDrop_Product__c;

                line.Quantity__c =
                    cartItem.Quantity__c;

                line.Unit_Price__c =
                    cartItem.Unit_Price__c;

                line.Discount__c =
                    cartItem.Discount__c == null
                        ? 0
                        : cartItem.Discount__c;

                // QuickDrop Order Line Item Pricing flow
                // will calculate the correct tax.
                line.Tax__c = 0;

                orderLineItems.add(line);
            }

            insert orderLineItems;


            // -------------------------------------------------
            // RE-QUERY ORDER AFTER AUTOMATION
            // -------------------------------------------------

            Customer_Order__c calculatedOrder = [
                SELECT Id,
                       Name,
                       Status__c,
                       Payment_Status__c,
                       Grand_Total__c
                FROM Customer_Order__c
                WHERE Id = :order.Id
                LIMIT 1
            ];


            // -------------------------------------------------
            // CREATE PAYMENT
            // -------------------------------------------------

            Payment__c payment = new Payment__c();

            payment.Order__c = calculatedOrder.Id;
            payment.Payment_Method__c = paymentMethod;

            if (
    paymentMethod == 'UPI' ||
    paymentMethod == 'Card' ||
    paymentMethod == 'Wallet'
) {
    payment.Payment_Status__c = 'Success';
} else if (paymentMethod == 'Cash on Delivery') {
    payment.Payment_Status__c = 'Pending';
} else {
    throw new AuraHandledException(
        'Invalid payment method selected: ' + paymentMethod
    );
}

            payment.Amount__c =
                calculatedOrder.Grand_Total__c;

            payment.Transaction_Reference__c =
                'QD-' + String.valueOf(DateTime.now().getTime());

            payment.Payment_Date__c = Date.today();

            insert payment;


            // -------------------------------------------------
            // MARK CART AS CHECKED OUT
            // -------------------------------------------------

          Cart__c cartToUpdate = new Cart__c(
    Id = cart.Id,
    Status__c = 'Checked Out'
);

update cartToUpdate;


            // -------------------------------------------------
            // GET FINAL ORDER STATUS
            // Existing automation may have changed it:
            //
            // Payment Success
            //      ↓
            // Payment Status Sync
            //      ↓
            // Order Paid
            //      ↓
            // Order Confirmation
            //      ↓
            // Confirmed
            //      ↓
            // Delivery Assignment
            // -------------------------------------------------

            Customer_Order__c finalOrder = [
                SELECT Id,
                       Name,
                       Status__c,
                       Payment_Status__c,
                       Grand_Total__c
                FROM Customer_Order__c
                WHERE Id = :order.Id
                LIMIT 1
            ];


            // -------------------------------------------------
            // RETURN RESULT TO LWC
            // -------------------------------------------------

            CheckoutResult result =
                new CheckoutResult();

            result.orderId = finalOrder.Id;
            result.orderNumber = finalOrder.Name;
            result.grandTotal = finalOrder.Grand_Total__c;
            result.paymentStatus = finalOrder.Payment_Status__c;
            result.orderStatus = finalOrder.Status__c;

            return result;

        } catch (AuraHandledException e) {

            Database.rollback(checkoutSavepoint);

            throw e;

        } catch (Exception e) {

            Database.rollback(checkoutSavepoint);

            throw new AuraHandledException(
                'Something went wrong during checkout: '
                + e.getMessage()
            );
        }
    }


    // =========================================================
    // CURRENT CUSTOMER HELPER
    // =========================================================

    private static Id getCurrentCustomerId() {

        Id currentUserId = UserInfo.getUserId();

        List<Customer__c> customers = [
            SELECT Id
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

        return customers[0].Id;
    }
}
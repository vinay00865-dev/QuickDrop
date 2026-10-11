public with sharing class QuickDropOrderLineItemTriggerHandler {

    public static void validateQuantity(
        List<Order_Line_Item__c> orderLineItems
    ) {

        for (Order_Line_Item__c item : orderLineItems) {

            if (
                item.Quantity__c == null ||
                item.Quantity__c <= 0
            ) {

                item.addError(
                    'Order Line Item quantity must be greater than zero.'
                );
            }
        }
    }
}
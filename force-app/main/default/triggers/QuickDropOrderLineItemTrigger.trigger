
   trigger QuickDropOrderLineItemTrigger
    on Order_Line_Item__c (
        before insert,
        before update
    ) {

    QuickDropOrderLineItemTriggerHandler.validateQuantity(
        Trigger.new
    );
}

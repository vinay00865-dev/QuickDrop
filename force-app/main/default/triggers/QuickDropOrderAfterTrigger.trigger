trigger QuickDropOrderAfterTrigger
    on Customer_Order__c (after insert) {

    for (Customer_Order__c order : Trigger.new) {

        System.debug(
            'QuickDrop Order Created: ' +
            order.Name +
            ' | Id: ' +
            order.Id
        );
    }
}
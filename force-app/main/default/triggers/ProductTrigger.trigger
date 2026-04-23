/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Trigger for Product2 objects. Handles after insert events to automatically
 *              create PricebookEntry records in the standard pricebook for new products.
 */
trigger ProductTrigger on Product2 (after insert) {
    ProductHandler.addToStandardPricebook(Trigger.new);
}
/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Trigger for Opportunity objects. Handles after update events to trigger Account
 *              synchronization when opportunities are marked as 'Closed Won'.
 */
trigger OpportunityTrigger on Opportunity(after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}

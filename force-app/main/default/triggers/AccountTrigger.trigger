/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Trigger for Account objects. Handles before insert/update to mark accounts for sync
 *              and after insert/update to trigger batch processing for SAP synchronization.
 */
trigger AccountTrigger on Account(before insert, after insert, before update, after update) {
    if (Trigger.isBefore) {
        AccountHandler.markedByAccountTrigger(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter) {
        AccountHandler.performBatch();
    }
}

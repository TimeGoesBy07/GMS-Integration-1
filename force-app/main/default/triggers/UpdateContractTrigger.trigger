/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Trigger for Contract objects. Handles before insert events to synchronize
 *              Contract records with related Account data for consistency.
 */
trigger UpdateContractTrigger on Contract (before insert) {
    UpdateContractHandler.syncAccountToContract(Trigger.new);
}
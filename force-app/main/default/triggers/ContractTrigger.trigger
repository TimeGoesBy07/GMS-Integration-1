trigger ContractTrigger on Contract(after insert, after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        ContractHandler.markedByContractTrigger(Trigger.new, Trigger.oldMap);
        ContractHandler.performBatch();
    }
}

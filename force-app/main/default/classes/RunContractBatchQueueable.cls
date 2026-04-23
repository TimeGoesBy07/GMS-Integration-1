public class RunContractBatchQueueable implements Queueable {
    public void execute(QueueableContext context) {
        Database.executeBatch(new OrderSyncBatch(), 50);
    }
}
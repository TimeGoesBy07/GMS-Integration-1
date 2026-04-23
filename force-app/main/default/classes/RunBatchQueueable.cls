/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Queueable Apex class for executing AccountSyncBatch asynchronously.
 *              Used to enqueue batch jobs from trigger context or other asynchronous operations
 *              to avoid governor limit violations.
 */
public class RunBatchQueueable implements Queueable {
    public void execute(QueueableContext context) {
        Database.executeBatch(new AccountSyncBatch(), 50);
    }
}

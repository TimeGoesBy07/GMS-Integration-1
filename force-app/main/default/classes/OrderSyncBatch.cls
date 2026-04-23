public with sharing class OrderSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    Integer totalProcessed = 0;
    Integer totalSuccess = 0;
    Integer totalFailed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, AccountId, Account.OwnerId, Status, Sync_Status__c
                FROM Order
                WHERE Sync_Status__c = 'Pending'
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Order> scope) {
        totalProcessed += scope.size();
        Datetime nowTime = System.now();

        // Call integration
        UtilityClass.SyncResult result = SAPIntegrationService.syncOrders(scope);

        Set<Id> orderIds = new Map<Id, Order>(scope).keySet();

        List<OrderItem> items = [
            SELECT Id, Sync_Status__c, Sync_Message__c, Sync_Time__c
            FROM OrderItem
            WHERE OrderId IN :orderIds
        ];

        if (result.status == 'Success') {
            totalSuccess += scope.size();
            markSuccess(scope, result.message, nowTime);

            if (!items.isEmpty()) {
                markItemSuccess(items, result.message, nowTime);
            }
        } else {
            totalFailed += scope.size();
            markFailed(scope, result.message, String.join(result.errors, ', '), nowTime);

            if (!items.isEmpty()) {
                markItemFailed(items, result.message, String.join(result.errors, ', '), nowTime);
            }
        }

        // Logging (reuse your pattern)
        UtilityClass.insertLog(result, 'Order Sync');
        List<SObject> toUpdate = new List<SObject>();
        toUpdate.addAll(scope);

        if (!items.isEmpty()) {
            toUpdate.addAll(items);
        }

        // Prevent recursion
        ContractHandler.skipSyncStatusUpdate = true;
        update toUpdate;
        ContractHandler.skipSyncStatusUpdate = false;
    }

    public void finish(Database.BatchableContext bc) {
        if (totalProcessed == 0) {
            return;
        }

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];

        // Get email addresses of System Administrators
        List<User> users = [
            SELECT Email
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
        ];

        List<String> listEmails = new List<String>();
        // listEmails.add('tthieu2@gimasys.com');

        for (User u : users) {
            if (u.Email != null) {
                listEmails.add(u.Email);
            }
        }

        String body =
            'Order & Order Item Sync Batch Summary\n\n' +
            'Job Id: ' +
            job.Id +
            '\n' +
            'Status: ' +
            job.Status +
            '\n\n' +
            'Total Records Processed: ' +
            totalProcessed +
            '\n' +
            'Successful: ' +
            totalSuccess +
            '\n' +
            'Failed: ' +
            totalFailed +
            '\n' +
            'System Errors: ' +
            job.NumberOfErrors +
            '\n\n' +
            'Note: Check API_Log__c for full request/response details.';

        if (totalProcessed > 0) {
            Integer successRate = (totalSuccess * 100) / totalProcessed;
            body += '\nSuccess Rate: ' + successRate + '%';
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(listEmails);
        mail.setSubject('Order Sync Completed - ' + job.Status);
        mail.setPlainTextBody(body);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    private void markSuccess(List<Order> scope, String msg, Datetime nowTime) {
        String safeMsg = msg != null ? msg.substring(0, Math.min(255, msg.length())) : 'Success';

        for (Order o : scope) {
            o.Sync_Status__c = 'Success';
            o.Sync_Message__c = safeMsg;
            o.Sync_Time__c = nowTime;
            o.Sync_Error__c = 'None';
        }
    }

    private void markFailed(List<Order> scope, String msg, String errors, Datetime nowTime) {
        String safeMsg = msg != null ? msg.substring(0, Math.min(255, msg.length())) : 'Failed';

        for (Order o : scope) {
            o.Sync_Status__c = 'Failed';
            o.Sync_Message__c = safeMsg;
            o.Sync_Time__c = nowTime;
            o.Sync_Error__c = errors;
        }
    }

    private void markItemSuccess(List<OrderItem> items, String msg, Datetime nowTime) {
        String safeMsg = msg != null ? msg.substring(0, Math.min(255, msg.length())) : 'Success';

        for (OrderItem oi : items) {
            oi.Sync_Status__c = 'Success';
            oi.Sync_Message__c = safeMsg;
            oi.Sync_Time__c = nowTime;
        }
    }

    private void markItemFailed(List<OrderItem> items, String msg, String errors, Datetime nowTime) {
        String safeMsg = msg != null ? msg.substring(0, Math.min(255, msg.length())) : 'Failed';

        for (OrderItem oi : items) {
            oi.Sync_Status__c = 'Failed';
            oi.Sync_Message__c = safeMsg;
            oi.Sync_Time__c = nowTime;
        }
    }
}

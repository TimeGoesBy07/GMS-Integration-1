/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Batch Apex class for synchronizing Account records with SAP system.
 *              Processes accounts with 'Pending' sync status, performs HTTP callouts to SAP API,
 *              updates sync status based on response, and sends email notifications upon completion.
 */
public class AccountSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    Integer totalProcessed = 0;
    Integer totalSuccess = 0;
    Integer totalFailed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    Name,
                    Phone,
                    AccountNumber,
                    Name_1__c,
                    Salutation__c,
                    Grouping__c,
                    Search_Term_1__c,
                    Search_Term_2__c,
                    Owner.Name,
                    Owner.Manager.Name
                FROM Account
                WHERE Sync_Status__c = 'Pending'
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        totalProcessed += scope.size();
        Datetime nowTime = System.now();

        UtilityClass.SyncResult result = SAPIntegrationService.syncAccounts(scope);

        if (result.status == 'Success') {
            totalSuccess += scope.size();
            markSuccess(scope, result.message, nowTime);
        } else {
            totalFailed += scope.size();
            String errors = result.errors != null ? JSON.serialize(result.errors) : null;
            markFailed(scope, result.message, errors, nowTime);
        }

        // Insert API log
        UtilityClass.insertLog(result, 'Account Sync');

        // UPDATE RECORDS & BYPASS TRIGGER (Updating Sync_Status__c to Success/Failed would cause an infinite loop)
        AccountHandler.skipSyncStatusUpdate = true;
        Database.update(scope, false);
        AccountHandler.skipSyncStatusUpdate = false;
    }

    public void finish(Database.BatchableContext bc) {
        if (totalProcessed == 0) {
            return;
        }

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
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
        /* listEmails.add('tthieu2@gimasys.com'); */

        for (User u : users) {
            if (u.Email != null) {
                listEmails.add(u.Email);
            }
        }

        // BUILD EMAIL BODY
        String body =
            'Account Sync Batch Summary\n\n' +
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

        // SEND EMAIL
        try {
            // only send if there were records processed, otherwise it's just noise in the inbox
            if (totalProcessed == 0) {
                return;
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(listEmails);
            mail.setSubject('Account Sync Batch Completed - ' + job.Status);
            mail.setPlainTextBody(body);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug('Email sending failed: ' + e.getMessage());
        }
    }

    // STATUS HELPERS
    private void markSuccess(List<Account> scope, String msg, Datetime nowTime) {
        String safeMsg = msg != null ? msg.substring(0, Math.min(255, msg.length())) : 'Success';

        for (Account acc : scope) {
            acc.Sync_Status__c = 'Success';
            acc.Sync_Message__c = safeMsg;
            acc.Sync_time__c = nowTime;
            acc.Sync_Errors__c = 'None';
        }
    }

    private void markFailed(List<Account> scope, String msg, String errors, Datetime nowTime) {
        String safeMsg = msg != null ? msg.substring(0, Math.min(255, msg.length())) : 'Failed';

        for (Account acc : scope) {
            acc.Sync_Status__c = 'Failed';
            acc.Sync_Message__c = safeMsg;
            acc.Sync_time__c = nowTime;
            acc.Sync_Errors__c = errors;
        }
    }
}

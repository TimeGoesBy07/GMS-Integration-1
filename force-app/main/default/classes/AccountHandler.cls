/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Handler class for Account synchronization with SAP system. Manages sync status,
 *              batch processing, and provides Aura-enabled methods for manual sync operations.
 */
public with sharing class AccountHandler {
    public static Boolean skipSyncStatusUpdate = false;
    private static Boolean isQueued = false;

    public static void markedByAccountTrigger(List<Account> newList, Map<Id, Account> oldMap) {
        if (skipSyncStatusUpdate) {
            return;
        }

        for (Account acc : newList) {
            if (acc.AccountNumber != null) {
                acc.Sync_Status__c = 'Pending';
            }
        }
    }

    public static void markedByOppTrigger(Set<Id> accountIds) {
        List<Account> updates = new List<Account>();

        for (Id accId : accountIds) {
            updates.add(new Account(Id = accId, Sync_Status__c = 'Pending'));
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public static void performBatch() {
        if (!FeatureManagement.checkPermission('SAP_API_Access')) {
            return;
        }

        if (isQueued) {
            return;
        }

        isQueued = true;
        System.enqueueJob(new RunBatchQueueable());
    }

    @AuraEnabled(cacheable=true)
    public static Account getAccountSyncInfo(Id accountId) {
        return [
            SELECT Sync_Status__c, Sync_Message__c, Sync_Time__c, Sync_Errors__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static UtilityClass.SyncResult syncNow(Id accountId) {
        List<Account> accList = [
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
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (accList.isEmpty()) {
            throw new AuraHandledException('Account not found');
        }

        Account acc = accList[0];
        List<Account> scope = new List<Account>{ acc };

        UtilityClass.SyncResult result = SAPIntegrationService.syncAccounts(scope);

        Account updateAcc = new Account(
            Id = accountId,
            Sync_Status__c = result.status,
            Sync_Message__c = result.message,
            Sync_Time__c = System.now(),
            Sync_Errors__c = result.errors != null ? JSON.serialize(result.errors) : null
        );

        // prevent trigger from resetting to Pending
        AccountHandler.skipSyncStatusUpdate = true;
        update updateAcc;
        AccountHandler.skipSyncStatusUpdate = false;

        // Insert API log
        UtilityClass.insertLog(result, 'Account Sync');

        return result;
    }
}

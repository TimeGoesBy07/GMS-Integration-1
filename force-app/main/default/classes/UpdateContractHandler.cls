/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Trigger handler class for Contract objects. Synchronizes Contract records with
 *              related Account data by copying sales-related fields from Account to Contract.
 *              Ensures data consistency between Account and Contract records.
 */
public with sharing class UpdateContractHandler {
    public static void syncAccountToContract(List<Contract> contracts) {
        Set<Id> accountIds = new Set<Id>();

        for (Contract c : contracts) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id,
                    Sales_Manager__c,
                    Employee__c,
                    Sales_Organization__c,
                    Distribution_Channel__c,
                    Sales_Office__c,
                    Sales_Group__c
             FROM Account
             WHERE Id IN :accountIds]
        );

        for (Contract c : contracts) {
            Account acc = accountMap.get(c.AccountId);

            if (acc != null) {
                c.Sales_Manager__c = acc.Sales_Manager__c;
                c.Employee__c = acc.Employee__c;
                c.Sales_Organization__c = acc.Sales_Organization__c;
                c.Distribution_Channel__c = acc.Distribution_Channel__c;
                c.Sales_Office__c = acc.Sales_Office__c;
                c.Sales_Group__c = acc.Sales_Group__c;
            }
        }
    }
}
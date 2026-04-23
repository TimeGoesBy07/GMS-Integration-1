/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Trigger handler class for Opportunity objects. Monitors Opportunity stage changes
 *              and triggers Account synchronization when opportunities are marked as 'Closed Won'.
 *              Ensures related accounts are queued for SAP sync process.
 */
public class OpportunityHandler {
    public static void handleAfterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> accountIds = getAccountsToSync(newList, oldMap);

        if (!accountIds.isEmpty()) {
            AccountHandler.markedByOppTrigger(accountIds);
        }
    }

    private static Set<Id> getAccountsToSync(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> accountIds = new Set<Id>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            if (isClosedWonTransition(opp, oldOpp)) {
                accountIds.add(opp.AccountId);
            }
        }

        return accountIds;
    }

    private static Boolean isClosedWonTransition(Opportunity newOpp, Opportunity oldOpp) {
        return newOpp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won' && newOpp.AccountId != null;
    }
}

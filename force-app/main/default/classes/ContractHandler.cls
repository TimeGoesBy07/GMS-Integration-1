public with sharing class ContractHandler {
    public static Boolean skipSyncStatusUpdate = false;
    private static Boolean isQueued = false;

    public static void markedByContractTrigger(List<Contract> newList, Map<Id, Contract> oldMap) {
        if (skipSyncStatusUpdate)
            return;

        Set<Id> accIds = new Set<Id>();

        for (Contract con : newList) {
            Contract oldCon = oldMap != null ? oldMap.get(con.Id) : null;

            // 1. Became Active
            if (oldCon != null && con.Status == 'Activated' && oldCon.Status != 'Activated') {
                accIds.add(con.AccountId);
                continue;
            }

            // 2. Has SAP Id and updated
            if (oldCon != null && con.SAP_Contract_Id__c != null) {
                accIds.add(con.AccountId);
            }

            // 3. Insert active
            if (oldCon == null && con.Status == 'Activated') {
                accIds.add(con.AccountId);
            }
        }

        if (!accIds.isEmpty()) {
            markOrdersPending(accIds);
            System.debug('Marked orders and order items as Pending for account IDs: ' + accIds);
        }
    }

    private static void markOrdersPending(Set<Id> accIds) {
        // Get Orders
        List<Order> orders = [
            SELECT Id, Sync_Status__c
            FROM Order
            WHERE AccountId IN :accIds
        ];

        // Get OrderItems
        List<OrderItem> items = [
            SELECT Id, Sync_Status__c
            FROM OrderItem
            WHERE Order.AccountId IN :accIds
        ];

        // Mark Orders
        for (Order o : orders) {
            o.Sync_Status__c = 'Pending';
        }

        // Mark OrderItems
        for (OrderItem oi : items) {
            oi.Sync_Status__c = 'Pending';
        }

        // Prevent recursion if needed
        // ContractHandler.skipSyncStatusUpdate = true;
        if (!orders.isEmpty())
            update orders;

        if (!items.isEmpty())
            update items;
        // ContractHandler.skipSyncStatusUpdate = false;
    }

    public static void performBatch() {
        if (!FeatureManagement.checkPermission('SAP_API_Access')) {
            return;
        }

        if (isQueued) {
            return;
        }

        isQueued = true;
        System.enqueueJob(new RunContractBatchQueueable());
    }

    @AuraEnabled(cacheable=true)
    public static Order getOrderSyncInfo(Id orderId) {
        return [
            SELECT Sync_Status__c, Sync_Message__c, Sync_Time__c, Sync_Error__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static UtilityClass.SyncResult syncNow(Id orderId) {
        List<Order> ordersList = [
            SELECT Id, AccountId, Account.OwnerId
            FROM Order
            WHERE Id = :orderId
        ];

        if (ordersList.isEmpty()) {
            throw new AuraHandledException('Orders not found');
        }

        Order order = ordersList[0];
        List<Order> scope = new List<Order>{ order };

        UtilityClass.SyncResult result = SAPIntegrationService.syncOrders(scope);

        Order updatedOrder = new Order(
            Id = order.Id,
            Sync_Status__c = result.status,
            Sync_Message__c = result.message,
            Sync_Time__c = System.now(),
            Sync_Error__c = result.errors != null ? JSON.serialize(result.errors) : null
        );

        // Update order
        ContractHandler.skipSyncStatusUpdate = true;
        update updatedOrder;
        ContractHandler.skipSyncStatusUpdate = false;

        // Insert API log
        UtilityClass.insertLog(result, 'Order Sync');

        return result;
    }
}

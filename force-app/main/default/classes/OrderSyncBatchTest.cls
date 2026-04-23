@isTest
class OrderSyncBatchTest {
    @isTest
    static void testBatchSuccess() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Order ord = TestDataFactory.createOrderData(acc);

        Contract con = [
            SELECT Id
            FROM Contract
            WHERE AccountId = :acc.Id
        ];

        con.Sales_Group__c = 'Canada';
        update con;

        Test.setMock(HttpCalloutMock.class, new MockHTTPResponseGenerator.SuccessMock());

        Test.startTest();
        Database.executeBatch(new OrderSyncBatch(), 1);
        Test.stopTest();

        Order updated = [
            SELECT Sync_Status__c, Sync_Message__c
            FROM Order
            WHERE Id = :ord.Id
        ];

        System.assertEquals('Success', updated.Sync_Status__c);

        List<OrderItem> items = [
            SELECT Sync_Status__c
            FROM OrderItem
            WHERE OrderId = :ord.Id
        ];

        System.assertEquals('Success', items[0].Sync_Status__c);
    }

    @isTest
    static void testGetOrderSyncInfo() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Order ord = TestDataFactory.createOrderData(acc);

        Order result = ContractHandler.getOrderSyncInfo(ord.Id);

        System.assertEquals(ord.Id, result.Id);
    }

    @isTest
    static void testSyncNow() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Order ord = TestDataFactory.createOrderData(acc);

        Test.setMock(HttpCalloutMock.class, new MockHTTPResponseGenerator.SuccessMock());

        Test.startTest();
        UtilityClass.SyncResult res = ContractHandler.syncNow(ord.Id);
        Test.stopTest();

        Order updated = [
            SELECT Sync_Status__c, Sync_Message__c
            FROM Order
            WHERE Id = :ord.Id
        ];

        System.assertEquals('Success', updated.Sync_Status__c);
        System.assertEquals('Success', res.status);
    }

    // -------------------------------
    // TEST FAILURE
    // -------------------------------
    @isTest
    static void testBatchFailure() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Order ord = TestDataFactory.createOrderData(acc);

        Test.setMock(HttpCalloutMock.class, new MockHTTPResponseGenerator.MockHttpFail());

        Test.startTest();
        Database.executeBatch(new OrderSyncBatch(), 1);
        Test.stopTest();

        Order updated = [
            SELECT Sync_Status__c, Sync_Error__c
            FROM Order
            WHERE Id = :ord.Id
        ];

        System.assertEquals('Failed', updated.Sync_Status__c);
        System.assertNotEquals(null, updated.Sync_Error__c);

        List<OrderItem> items = [
            SELECT Sync_Status__c
            FROM OrderItem
            WHERE OrderId = :ord.Id
        ];

        System.assertEquals('Failed', items[0].Sync_Status__c);
    }
}

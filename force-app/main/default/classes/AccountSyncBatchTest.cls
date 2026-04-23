/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Test class for AccountSyncBatch and related functionality. Covers success scenarios,
 *              failure scenarios, trigger-based sync, manual sync operations, and product handler
 *              functionality. Uses mock HTTP responses for callout testing.
 */
@isTest
class AccountSyncBatchTest {
    // TEST DATA SETUP
    private static List<Account> createAccounts(Integer count) {
        List<Account> accs = new List<Account>();

        for (Integer i = 0; i < count; i++) {
            Account acc = TestDataFactory.createAccount();
            acc.Name = 'Test Account ' + i;
            acc.AccountNumber = 'ACC-' + i;
            accs.add(acc);
        }

        insert accs;
        return accs;
    }

    // TEST: Success Scenario

    @isTest
    static void testBatchSuccess() {
        // Create test data
        List<Account> accs = createAccounts(1);

        // Set mock
        Test.setMock(HttpCalloutMock.class, new MockHTTPResponseGenerator.SuccessMock());

        Test.startTest();
        Database.executeBatch(new AccountSyncBatch(), 1);

        Test.stopTest();

        // Verify result
        List<Account> updated = [
            SELECT Sync_Status__c, Sync_Message__c, Sync_Time__c
            FROM Account
            WHERE Id IN :accs
        ];

        for (Account a : updated) {
            System.assertEquals('Success', a.Sync_Status__c, 'Expected Sync_Status__c to be Success');
            System.assertEquals('Success', a.Sync_Message__c, 'Expected Sync_Message__c to be Success');
            System.assertNotEquals(null, a.Sync_Time__c, 'Expected Sync_Time__c to not be null');
        }

        List<API_Log__c> logs = [
            SELECT Id, Status__c, Status_Code__c
            FROM API_Log__c
        ];

        System.assert(logs.size() > 0, 'Logs should be created');
        System.assertEquals('Success', logs[0].Status__c, 'Expected log status to be Success');
        System.assertEquals(200, logs[0].Status_Code__c, 'Expected log status code to be 200');
    }

    @IsTest
    static void testAddToStandardPricebook() {
        // =========================
        // ARRANGE
        // =========================

        Id stdPbId = Test.getStandardPricebookId();

        // IMPORTANT: ensure it's active (safe update)
        Pricebook2 pb = new Pricebook2(Id = stdPbId, IsActive = true);
        update pb;

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Type_Of_Production__c = 'TNG SX, gia công ngoài, mua ngoài',
            Packing__c = '45 kg',
            Certificate__c = 'An toàn, sạch (hàng bình thường) - 0',
            Item_Category_Group__c = 'NORM: Hàng có quản lý tồn kho',
            Tax_Classification__c = 'Không kê khai thuế',
            Division__c = 'Cross Division',
            Size__c = 'CẮT CHUNK KHÔNG SIZE',
            Product_Description_VI__c = 'Sản phẩm thử nghiệm'
        );

        Test.startTest();
        insert prod; // triggers ProductHandler
        Test.stopTest();

        // =========================
        // ASSERT
        // =========================

        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive
            FROM PricebookEntry
            WHERE Product2Id = :prod.Id
        ];

        System.assertEquals(1, entries.size(), 'Expected 1 pricebook entry');
        System.assertEquals(stdPbId, entries[0].Pricebook2Id, 'Expected standard pricebook ID');
        System.assertEquals(prod.Id, entries[0].Product2Id, 'Expected product ID');
    }

    @IsTest
    static void testClosedWonTriggersAccountSync() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Contract con = new Contract(
            Account__c = acc.Id,
            AccountId = acc.Id,
            Delivery_Block__c = 'Chưa đặt cọc/ Chưa cho phép SX',
            Customer_Reference__c = 'REF-001',
            Status = 'Draft',
            StartDate = Date.today()
        );

        insert con;

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Type_Of_Production__c = 'TNG SX, gia công ngoài, mua ngoài',
            Packing__c = '45 kg',
            Certificate__c = 'An toàn, sạch (hàng bình thường) - 0',
            Item_Category_Group__c = 'NORM: Hàng có quản lý tồn kho',
            Tax_Classification__c = 'Không kê khai thuế',
            Division__c = 'Cross Division',
            Size__c = 'CẮT CHUNK KHÔNG SIZE',
            Product_Description_VI__c = 'Sản phẩm thử nghiệm'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId = acc.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert ord;

        OrderItem oi = new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100);
        insert oi;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // UPDATE → CLOSED WON
        Test.startTest();

        opp.StageName = 'Closed Won';
        update opp;

        Test.stopTest();

        Account updatedAcc = [
            SELECT Sync_Message__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertNotEquals(
            null,
            updatedAcc.Sync_Message__c,
            'Sync_Message__c should always be populated after Closed Won trigger'
        );

        System.assert(updatedAcc.Sync_Message__c.length() > 0, 'Sync_Message__c should not be empty');
    }

    @IsTest
    static void testManualSync() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MockHTTPResponseGenerator.SuccessMock());

        Test.startTest();
        UtilityClass.SyncResult result = AccountHandler.syncNow(acc.Id);
        Test.stopTest();

        System.assertEquals('Success', result.status, 'Expected status to be Success');
        System.assertEquals(200, result.statusCode, 'Expected status code to be 200');
        System.assertNotEquals(null, result.requestBody, 'Expected request body to not be null');

        Account updatedAcc = [
            SELECT Sync_Status__c, Sync_Message__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'Success',
            updatedAcc.Sync_Status__c,
            'Expected Sync_Status__c to be Success after manual sync'
        );
        System.assertEquals(
            'Success',
            updatedAcc.Sync_Message__c,
            'Expected Sync_Message__c to be Success after manual sync'
        );
    }

    // ███████████████████████████████
    // TEST: Exception Scenario
    // ███████████████████████████████

    @isTest
    static void testBatchFailureResponse() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MockHTTPResponseGenerator.MockHttpFail());

        Test.startTest();
        Database.executeBatch(new AccountSyncBatch(), 1);
        Test.stopTest();

        Account updatedAcc = [
            SELECT Sync_Status__c, Sync_Message__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'Failed',
            updatedAcc.Sync_Status__c,
            'Expected Sync_Status__c to be Failed for non-200 response'
        );

        System.assertEquals(
            'Invalid request payload',
            updatedAcc.Sync_Message__c,
            'Expected Sync_Message__c to store API error message'
        );
    }

    @isTest
    static void testBatchFailureException() {
        Account acc = TestDataFactory.createAccount();
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MockHTTPResponseGenerator.MockHttpExceptionResponse());

        Test.startTest();
        Database.executeBatch(new AccountSyncBatch(), 1);
        Test.stopTest();

        Account updatedAcc = [
            SELECT Sync_Status__c, Sync_Message__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'Failed',
            updatedAcc.Sync_Status__c,
            'Expected Sync_Status__c to be Failed when exception occurs'
        );

        System.assert(
            updatedAcc.Sync_Message__c.contains('Connection timeout'),
            'Expected Sync_Message__c to contain exception message'
        );
    }
}

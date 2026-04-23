/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Test data factory class for creating test Account records with predefined values.
 *              Provides standardized test data creation methods for unit tests, ensuring consistent
 *              test data across all test classes.
 */
public class TestDataFactory {
    public static Account createAccount() {
        return new Account(
            Name = 'Test Account',
            AccountNumber = '12345',
            Sync_Status__c = 'Pending',
            Name_1__c = 'Test Name 1',
            Business_Email__c = 'test@company.com',
            Distribution_Channel__c = '14',
            Sales_Office__c = 'Châu Á',
            Account_Currency__c = 'USD',
            Customer_Tax_Classification__c = 'Không chịu thuế',
            Reconcile_Account__c = '1311000100',
            Email__c = 'test@company.com',
            Sales_Organization__c = 'TNG',
            OwnerId = UserInfo.getUserId()
        );
    }

    public static List<Account> createAccounts(Integer count) {
        List<Account> accs = new List<Account>();

        for (Integer i = 0; i < count; i++) {
            Account acc = createAccount();
            acc.Name = 'Test Account ' + i;
            acc.AccountNumber = 'ACC-' + i;
            accs.add(acc);
        }

        insert accs;
        return accs;
    }

    public static Order createOrderData(Account acc) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Contract con = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            Delivery_Block__c = 'Chưa đặt cọc/ Chưa cho phép SX',
            Customer_Reference__c = 'REF-001',
            Opportunity__c = opp.Id
        );
        insert con;

        con.Status = 'Activated';
        update con;

        // Standard Pricebook
        Id pbId = Test.getStandardPricebookId();

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
            Pricebook2Id = pbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            Pricebook2Id = pbId,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Sync_Status__c = 'Pending'
        );
        insert ord;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oi;

        return ord;
    }
}

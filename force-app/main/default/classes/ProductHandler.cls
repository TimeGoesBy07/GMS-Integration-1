/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Trigger handler class for Product2 objects. Automatically creates PricebookEntry
 *              records in the standard pricebook when new products are created. Ensures products
 *              are available for use in orders and opportunities.
 */
public with sharing class ProductHandler {
    public static void addToStandardPricebook(List<Product2> products) {
        List<Pricebook2> pbs = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = TRUE
            LIMIT 1
        ];

        if (pbs.isEmpty()) {
            return;
        }

        Id standardPricebookId = pbs[0].Id;

        List<PricebookEntry> entries = new List<PricebookEntry>();

        for (Product2 p : products) {
            entries.add(
                new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = p.Id,
                    UnitPrice = 0,
                    IsActive = true
                )
            );
        }

        if (!entries.isEmpty()) {
            insert entries;
        }
    }
}

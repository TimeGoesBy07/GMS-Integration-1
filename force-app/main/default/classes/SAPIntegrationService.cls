/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Service class for SAP system integration. Handles HTTP callouts to SAP API endpoints,
 *              builds request payloads with account, contract, and order item data, processes responses,
 *              and returns standardized sync results for batch processing.
 */
public with sharing class SAPIntegrationService {
    // Sync accounts
    public static UtilityClass.SyncResult syncAccounts(List<Account> scope) {
        List<UtilityClass.ObjectWrapper> requestList = UtilityClass.buildAccountRequest(scope);

        return UtilityClass.sendRequest(
            requestList,
            'callout:SAP_API/integrate/services/apexrest/api/v1/sap-sync/account'
        );
    }

    // Sync orders
    public static UtilityClass.SyncResult syncOrders(List<Order> scope) {
        List<UtilityClass.ObjectWrapper> requestList = UtilityClass.buildOrderRequest(scope);

        return UtilityClass.sendRequest(requestList, 'callout:SAP_API/integrate/services/apexrest/api/v1/sap-sync/so');
    }
}

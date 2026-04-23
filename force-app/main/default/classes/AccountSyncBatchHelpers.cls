/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Helper class for Account synchronization batch processing. Provides data structures
 *              and utility methods for building SAP API requests, retrieving related contracts and
 *              order items, and formatting sync results.
 */
public with sharing class AccountSyncBatchHelpers {
    public class SyncResult {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String responseBody;
        @AuraEnabled
        public Integer statusCode;
        @AuraEnabled
        public String requestBody;
        @AuraEnabled
        public List<String> errors;
    }

    public class AccountWrapper {
        public String vw;
        public String vhc_contract;
        public String sold_to;
        public String so_no;
        public String ship_to;
        public String sf_id;
        public String sales_org;
        public String sales_office;
        public String sales_group;
        public String reject_reason;
        public String place_port;
        public String payer;
        public String pay_term;
        public String pay_method;
        public String order_reason;
        public String op_id;
        public List<OrderItemWrapper> items;
        public String inco;
        public String if_flag;
        public String er;
        public String doc_date;
        public String dest_port;
        public String del_date;
        public String del_block;
        public String dc;
        public String cus_ref;
        @JsonName('currency')
        public String currencyIsoCode;
        public String contract;
        public String bill_to;
    }

    public class OrderItemWrapper {
        public String so_line;
        public String sf_id;
        public String sales_unit;
        public Decimal sales_qty;
        public String REQ_TYPE;
        public String plant;
        public Decimal order_qty;
        public Decimal net_price;
        public String mat_prc_grp;
        public String mat;
        public String item_cate;
        public String ex_id_line;
    }

    public static Map<Id, Contract> getLatestContracts(Set<Id> accIds) {
        Map<Id, Contract> mapCon = new Map<Id, Contract>();

        List<Contract> conList = [
            SELECT Id, AccountId, ContractNumber, Customer_Reference__c
            FROM Contract
            WHERE AccountId IN :accIds
            ORDER BY CreatedDate DESC
        ];

        for (Contract con : conList) {
            if (!mapCon.containsKey(con.AccountId)) {
                mapCon.put(con.AccountId, con);
            }
        }

        return mapCon;
    }

    public static Map<Id, List<OrderItem>> getOrderItems(Set<Id> accIds) {
        Map<Id, List<OrderItem>> mapItems = new Map<Id, List<OrderItem>>();

        List<OrderItem> oiList = [
            SELECT Id, Order.AccountId, Quantity, UnitPrice, PricebookEntry.Product2.ProductCode
            FROM OrderItem
            WHERE Order.AccountId IN :accIds
        ];

        for (OrderItem oi : oiList) {
            if (!mapItems.containsKey(oi.Order.AccountId)) {
                mapItems.put(oi.Order.AccountId, new List<OrderItem>());
            }
            mapItems.get(oi.Order.AccountId).add(oi);
        }

        return mapItems;
    }

    public static List<Object> buildRequest(
        List<Account> scope,
        Map<Id, Contract> contractMap,
        Map<Id, List<OrderItem>> itemMap
    ) {
        List<Object> requestList = new List<Object>();

        for (Account acc : scope) {
            Contract con = contractMap.get(acc.Id);

            requestList.add(
                new Map<String, Object>{
                    'vw' => acc.Owner.Name,
                    'sf_id' => acc.Id,
                    'cus_ref' => con != null ? con.Customer_Reference__c : null,
                    'contract' => con != null ? con.ContractNumber : null,
                    'cus_no' => acc.AccountNumber,
                    'cus_name234' => acc.Name,
                    'cus_name1' => acc.Name_1__c,
                    'items' => buildItems(itemMap.get(acc.Id))
                }
            );
        }

        return requestList;
    }

    public static List<Object> buildItems(List<OrderItem> oiList) {
        List<Object> items = new List<Object>();

        if (oiList == null) {
            return items;
        }

        for (OrderItem oi : oiList) {
            items.add(
                new Map<String, Object>{
                    'sf_id' => oi.Id,
                    'sales_qty' => oi.Quantity,
                    'net_price' => String.valueOf(oi.UnitPrice),
                    'mat' => oi.PricebookEntry.Product2.ProductCode
                }
            );
        }

        return items;
    }

    public static void insertLog(SyncResult result){
        List<API_Log__c> logs = new List<API_Log__c>();

        logs.add(
            new API_Log__c(
                Request__c = result.requestBody,
                Response__c = result.responseBody,
                Status_Code__c = result.statusCode,
                Status__c = result.status,
                Url__c = 'SAP Account Sync',
                Method__c = 'POST'
            )
        );

        insert logs;
    }
}

public with sharing class UtilityClass {
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

    public class ObjectWrapper {
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

    public static Map<Id, List<OrderItem>> getOrderItemsByOrder(Set<Id> orderIds) {
        Map<Id, List<OrderItem>> mapItems = new Map<Id, List<OrderItem>>();

        List<OrderItem> oiList = [
            SELECT
                Id,
                OrderId,
                Order.AccountId,
                Sales_Document_Item_SAP__c,
                Sales_Unit__c,
                OrderedQuantity__c,
                Plant__c,
                Order_Quantity_Based_Unit__c,
                UnproratedNetPrice__c,
                Material_Price_Group__c,
                Item_Category__c,
                Item_Line_ID__c,
                PricebookEntry.Product2.ProductCode
            FROM OrderItem
            WHERE OrderId IN :orderIds
        ];

        for (OrderItem oi : oiList) {
            if (!mapItems.containsKey(oi.OrderId)) {
                mapItems.put(oi.OrderId, new List<OrderItem>());
            }

            mapItems.get(oi.OrderId).add(oi);
        }

        return mapItems;
    }

    public static Map<Id, List<OrderItem>> getOrderItemsByAccount(Set<Id> accIds) {
        Map<Id, List<OrderItem>> mapItems = new Map<Id, List<OrderItem>>();

        List<OrderItem> oiList = [
            SELECT
                Id,
                OrderId,
                Order.AccountId,
                Sales_Document_Item_SAP__c,
                Sales_Unit__c,
                OrderedQuantity__c,
                Plant__c,
                Order_Quantity_Based_Unit__c,
                UnproratedNetPrice__c,
                Material_Price_Group__c,
                Item_Category__c,
                Item_Line_ID__c,
                PricebookEntry.Product2.ProductCode
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

    public static List<ObjectWrapper> buildAccountRequest(List<Account> accounts) {
        Set<Id> accIds = new Set<Id>();

        for (Account acc : accounts) {
            accIds.add(acc.Id);
        }

        Map<Id, Contract> contractMap = getContracts(accIds);
        Map<Id, List<OrderItem>> itemsByAccount = getOrderItemsByAccount(accIds);

        List<ObjectWrapper> requestList = new List<ObjectWrapper>();

        for (Account acc : accounts) {
            Contract c = contractMap.get(acc.Id);

            if (c == null) {
                continue;
            }

            List<OrderItem> items = itemsByAccount.get(acc.Id);

            if (items == null || items.isEmpty()) {
                continue;
            }

            ObjectWrapper req = new ObjectWrapper();

            req.vw = acc.OwnerId;
            req.er = acc.OwnerId;
            req.sf_id = acc.Id;
            fillFromContract(req, c);
            req.items = buildItems(items);
            requestList.add(req);
        }

        return requestList;
    }

    public static List<ObjectWrapper> buildOrderRequest(List<Order> orders) {
        Set<Id> accIds = new Set<Id>();

        for (Order o : orders) {
            accIds.add(o.AccountId);
        }

        Map<Id, Contract> contractMap = getContracts(accIds);
        Set<Id> orderIds = new Set<Id>();

        for (Order o : orders) {
            orderIds.add(o.Id);
        }

        Map<Id, List<OrderItem>> itemsMap = getOrderItemsByOrder(orderIds);

        List<ObjectWrapper> requestList = new List<ObjectWrapper>();

        for (Order o : orders) {
            Contract c = contractMap.get(o.AccountId);

            if (c == null) {
                continue;
            }

            ObjectWrapper req = new ObjectWrapper();

            req.vw = o.Account.OwnerId;
            req.er = o.Account.OwnerId;
            req.sf_id = o.Id;
            fillFromContract(req, c);
            req.items = buildItems(itemsMap.get(o.Id));
            requestList.add(req);
        }

        return requestList;
    }

    private static void fillFromContract(ObjectWrapper req, Contract c) {
        req.vhc_contract = c.VHC_Number__c;
        req.sold_to = c.Ship_to_Party__r.AccountNumber;
        req.ship_to = c.Ship_to_Party__r.AccountNumber;
        req.payer = c.Payer__r.AccountNumber;
        req.bill_to = c.Bill_to_Party__r.AccountNumber;
        req.so_no = c.SO_Number__c;
        req.sales_org = c.Sales_Organization__c;
        req.sales_office = c.Sales_Office__c;
        req.sales_group = c.Sales_Group__c;
        req.reject_reason = c.Reason_for_Rejection__c;
        req.order_reason = c.Order_reason__c;
        req.place_port = c.Port_of_Departure__c;
        req.dest_port = c.Port_of_Booking__c;
        req.pay_term = c.Payments_Terms__c;
        req.pay_method = c.Payment_Method__c;
        req.inco = c.Incoterms__c;
        req.dc = c.Distribution_Channel__c;
        req.cus_ref = c.Customer_Reference__c;
        req.currencyIsoCode = c.CurrencyIsoCode__c;
        req.contract = c.ContractNumber;
        req.op_id = c.Opportunity__c;
        req.doc_date = formatDate(c.Document_Date__c);
        req.del_date = formatDate(c.Requested_Delivery_Date__c);
        req.del_block = c.Delivery_Block__c;
        req.if_flag = '0';
    }

    private static List<OrderItemWrapper> buildItems(List<OrderItem> items) {
        List<OrderItemWrapper> itemsPayload = new List<OrderItemWrapper>();

        if (items == null)
            return itemsPayload;

        for (OrderItem oi : items) {
            OrderItemWrapper item = new OrderItemWrapper();

            item.so_line = String.valueOf(oi.Sales_Document_Item_SAP__c);
            item.sf_id = oi.Id;
            item.sales_unit = oi.Sales_Unit__c;
            item.sales_qty = oi.OrderedQuantity__c;
            item.REQ_TYPE = 'BB6';
            item.plant = oi.Plant__c;
            item.order_qty = oi.Order_Quantity_Based_Unit__c;
            item.net_price = oi.UnproratedNetPrice__c;
            item.mat_prc_grp = oi.Material_Price_Group__c;
            item.mat = (oi.PricebookEntry != null &&
                oi.PricebookEntry.Product2 != null)
                ? oi.PricebookEntry.Product2.ProductCode
                : null;

            item.item_cate = oi.Item_Category__c;
            item.ex_id_line = oi.Item_Line_ID__c;

            itemsPayload.add(item);
        }

        return itemsPayload;
    }

    private static String formatDate(Date d) {
        if (d == null)
            return null;

        Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        return dt.format('yyyyMMdd');
    }

    public static Map<Id, Contract> getContracts(Set<Id> accIds) {
        Map<Id, Contract> mapCon = new Map<Id, Contract>();

        for (Contract c : [
            SELECT
                Id,
                AccountId,
                ContractNumber,
                Customer_Reference__c,
                VHC_Number__c,
                SO_Number__c,
                Sales_Organization__c,
                Sales_Office__c,
                Sales_Group__c,
                Reason_for_Rejection__c,
                Order_reason__c,
                Payments_Terms__c,
                Payment_Method__c,
                Incoterms__c,
                Distribution_Channel__c,
                Delivery_Block__c,
                Document_Date__c,
                Requested_Delivery_Date__c,
                CurrencyIsoCode__c,
                Opportunity__c,
                Ship_to_Party__r.AccountNumber,
                Payer__r.AccountNumber,
                Bill_to_Party__r.AccountNumber,
                Port_of_Departure__c,
                Port_of_Booking__c
            FROM Contract
            WHERE AccountId IN :accIds AND Status IN ('Activated', 'Active')
            ORDER BY CreatedDate DESC
        ]) {
            if (!mapCon.containsKey(c.AccountId)) {
                mapCon.put(c.AccountId, c);
            }
        }

        return mapCon;
    }

    public static void insertLog(SyncResult result, String context) {
        List<API_Log__c> logs = new List<API_Log__c>();

        logs.add(
            new API_Log__c(
                Request__c = result.requestBody,
                Response__c = result.responseBody,
                Status_Code__c = result.statusCode,
                Status__c = result.status,
                Url__c = context,
                Method__c = 'POST'
            )
        );

        insert logs;
    }

    public static UtilityClass.SyncResult sendRequest(List<UtilityClass.ObjectWrapper> requestList, String endpoint) {
        UtilityClass.SyncResult result = new UtilityClass.SyncResult();

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{ 'Request' => requestList }));

            Http http = new Http();
            HttpResponse res = http.send(req);

            result.requestBody = req.getBody();
            result.responseBody = res.getBody();
            result.statusCode = res.getStatusCode();

            ApiResponse apiRes = (ApiResponse) JSON.deserialize(res.getBody(), ApiResponse.class);

            if (apiRes.meta.success) {
                result.status = 'Success';
                result.message = apiRes.meta.message;
                result.errors = new List<String>{ 'None' };
            } else {
                result.status = 'Failed';
                result.message = apiRes.meta.message;
                result.errors = apiRes.meta.errors;
            }
        } catch (Exception e) {
            result.status = 'Failed';
            result.message = e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
        }

        return result;
    }
}

import { LightningElement, api, track } from "lwc";
import syncNow from "@salesforce/apex/ContractHandler.syncNow";
import getOrderSyncInfo from "@salesforce/apex/ContractHandler.getOrderSyncInfo";

export default class ContractOrderSync extends LightningElement {
    @api recordId; // ContractId

    @track lastSyncTime;
    @track statusMessage;
    @track message = '-';

    @track isSuccess = false;
    @track isFailed = false;
    @track isLoading = false;
    @track errorMessages = [];

    get hasErrors() {
        if (!Array.isArray(this.errorMessages)) return false;

        return this.errorMessages.some(
            (e) => e && e.toLowerCase() !== 'none'
        );
    }

    connectedCallback() {
        this.loadContract();
    }

    normalizeError(error) {
        if (!error) return "Unknown error";

        if (error.body?.message) return error.body.message;
        if (error.message) return error.message;

        return JSON.stringify(error);
    }

    loadContract() {
        this.isLoading = true;

        getOrderSyncInfo({ orderId: this.recordId })
            .then((con) => {
                this.updateUI(con);
            })
            .catch((error) => {
                this.statusMessage = "Failed to load contract data";
                this.message = this.normalizeError(error);
                this.isFailed = true;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSync() {
        this.isLoading = true;
        this.statusMessage = "Syncing Orders...";
        this.isSuccess = false;
        this.isFailed = false;
        this.errorMessages = [];

        syncNow({ orderId: this.recordId })
            .then((res) => {
                this.updateFromResult(res);
            })
            .catch((error) => {
                this.statusMessage = "Error during Order sync";
                this.message = this.normalizeError(error);
                this.isFailed = true;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    updateUI(con) {
        this.message = con?.Sync_Message__c || '-';
        this.lastSyncTime = con?.Sync_Time__c;

        try {
            this.errorMessages = con?.Sync_Errors__c
                ? JSON.parse(con.Sync_Errors__c)
                : [];
        } catch (e) {
            console.error("Failed to parse errors", e);
            this.errorMessages = [];
        }

        switch (con?.Sync_Status__c) {
            case "Success":
                this.statusMessage = "Order Sync Successful!";
                this.isSuccess = true;
                break;

            case "Failed":
                this.statusMessage = "Order Sync Failed!";
                this.isFailed = true;
                break;

            case "Pending":
                this.statusMessage = "Order sync in progress...";
                break;

            default:
                this.statusMessage = "Not synced yet";
        }
    }

    updateFromResult(res) {
        this.lastSyncTime = new Date().toISOString();

        if (res?.status === "Success") {
            this.statusMessage = "Order Sync Successful!";
            this.message = res?.message;
            this.errorMessages = [];
            this.isSuccess = true;
            this.isFailed = false;
        } else {
            this.statusMessage = "Order Sync Failed!";
            this.message = res?.message;
            this.errorMessages = Array.isArray(res?.errors) ? res.errors : [];
            this.isFailed = true;
            this.isSuccess = false;
        }
    }
}
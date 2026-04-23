/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Lightning Web Component for manual Account synchronization with SAP system.
 *              Provides UI to trigger sync, display sync status, show last sync time, and handle
 *              error messages. Integrates with AccountHandler Apex methods for sync operations.
 */
import { LightningElement, api, track } from "lwc";
import syncNow from "@salesforce/apex/AccountHandler.syncNow";
import getAccountSyncInfo from "@salesforce/apex/AccountHandler.getAccountSyncInfo";

export default class AccountSync extends LightningElement {
    @api recordId;

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
        this.loadAccount();
    }

    // Helper to normalize error messages
    normalizeError(error) {
        if (!error) return "Unknown error";

        // Apex error
        if (error.body?.message) {
            return error.body.message;
        }

        // JS error
        if (error.message) {
            return error.message;
        }

        return JSON.stringify(error);
    }

    loadAccount() {
        this.isLoading = true;

        getAccountSyncInfo({ accountId: this.recordId })
            .then((acc) => {
                this.updateUI(acc);
            })
            .catch((error) => {
                this.statusMessage = "Failed to load data";
                this.message = this.normalizeError(error);
                this.isFailed = true;
                this.isSuccess = false;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSync() {
        this.isLoading = true;
        this.statusMessage = "Syncing...";
        this.isSuccess = false;
        this.isFailed = false;
        this.errorMessages = [];

        syncNow({ accountId: this.recordId })
            .then((res) => {
                this.updateFromResult(res);
            })
            .catch((error) => {
                this.statusMessage = "Error during sync";
                this.message = this.normalizeError(error);
                this.isFailed = true;
                this.isSuccess = false;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    updateUI(acc) {
        this.message = acc?.Sync_Message__c || '-';
        this.lastSyncTime = acc?.Sync_Time__c;

        try {
            this.errorMessages = acc?.Sync_Errors__c ? JSON.parse(acc.Sync_Errors__c) : [];
        } catch (e) {
            console.error("Failed to parse sync errors:", e);
            this.errorMessages = [];
        }

        switch (acc?.Sync_Status__c) {
            case "Success":
                this.statusMessage = "Synchronization Successful!";
                this.isSuccess = true;
                this.isFailed = false;
                break;

            case "Failed":
                this.statusMessage = "Synchronization Failed!";
                this.isSuccess = false;
                this.isFailed = true;
                break;

            case "Pending":
                this.statusMessage = "Sync in progress...";
                this.isSuccess = false;
                this.isFailed = false;
                break;

            default:
                this.statusMessage = "Not synced yet";
                this.isSuccess = false;
                this.isFailed = false;
        }
    }

    updateFromResult(res) {
        this.lastSyncTime = new Date().toISOString();

        if (res?.status === "Success") {
            this.statusMessage = "Synchronization Successful!";
            this.message = res?.message;
            this.errorMessages = [];
            this.isSuccess = true;
            this.isFailed = false;
        } else {
            this.statusMessage = "Synchronization Failed!";
            this.message = res?.message;

            // multiple errors
            this.errorMessages = Array.isArray(res?.errors) ? res.errors : [];
            this.isSuccess = false;
            this.isFailed = true;
        }
    }
}

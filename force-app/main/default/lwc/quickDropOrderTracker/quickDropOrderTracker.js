import { LightningElement, track } from 'lwc';
import getCurrentCustomerOrders
    from '@salesforce/apex/QuickDropOrderTrackerController.getCurrentCustomerOrders';

export default class QuickDropOrderTracker extends LightningElement {
    @track orders = [];

    isLoading = true;
    error;

    connectedCallback() {
        this.loadOrders();
    }

    async loadOrders() {
        this.isLoading = true;
        this.error = undefined;

        try {
            const result = await getCurrentCustomerOrders();
            this.orders = Array.isArray(result) ? result : [];
        } catch (error) {
            this.orders = [];
            this.error = this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    get hasOrders() {
        return Array.isArray(this.orders) && this.orders.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.error && !this.hasOrders;
    }

    get formattedOrders() {
        return this.orders.map(order => ({
            ...order,
            formattedDate: this.formatDate(order.Order_Date__c),
            formattedTotal: this.formatCurrency(order.Grand_Total__c),
            statusClass: this.getStatusClass(order.Status__c),
            paymentClass: this.getPaymentClass(order.Payment_Status__c)
        }));
    }

    formatDate(value) {
        if (!value) {
            return '';
        }

        try {
            return new Intl.DateTimeFormat('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            }).format(new Date(value));
        } catch (error) {
            return value;
        }
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            maximumFractionDigits: 2
        }).format(Number(value || 0));
    }

    getStatusClass(status) {
        const normalized = (status || '')
            .toLowerCase()
            .replace(/\s+/g, '-');

        return `status-badge status-${normalized}`;
    }

    getPaymentClass(status) {
        const normalized = (status || '')
            .toLowerCase()
            .replace(/\s+/g, '-');

        return `payment-badge payment-${normalized}`;
    }

    handleOrderClick(event) {
        const orderId = event.currentTarget.dataset.orderId;

        if (!orderId) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('orderselect', {
                detail: {
                    orderId
                },
                bubbles: true,
                composed: true
            })
        );
    }

    async handleRefresh() {
        await this.loadOrders();
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unable to load your orders.';
    }
}
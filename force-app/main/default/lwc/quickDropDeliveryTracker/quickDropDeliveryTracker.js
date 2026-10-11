import { LightningElement, api } from 'lwc';

import getDelivery
    from '@salesforce/apex/QuickDropDeliveryTrackerController.getDelivery';

export default class QuickDropDeliveryTracker extends LightningElement {

    delivery;

    isLoading = false;
    error;

    lastUpdated;

    _orderId;
    refreshTimer;

    isComponentConnected = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {
        this.isComponentConnected = true;

        if (this._orderId) {
            this.loadDelivery();
        }
    }


    disconnectedCallback() {
        this.isComponentConnected = false;
        this.stopAutoRefresh();
    }


    // =========================================================
    // PUBLIC ORDER ID
    // =========================================================

    @api
    get orderId() {
        return this._orderId;
    }

    set orderId(value) {
        this._orderId = value;

        this.stopAutoRefresh();

        if (this._orderId && this.isComponentConnected) {
            this.loadDelivery();
        }
    }


    // =========================================================
    // LOAD DELIVERY
    // =========================================================

    async loadDelivery() {

        if (!this._orderId) {
            return;
        }

        try {

            this.delivery = await getDelivery({
                orderId: this._orderId
            });

            this.error = undefined;
            this.lastUpdated = new Date();

        } catch (error) {

            this.delivery = undefined;
            this.error = this.getErrorMessage(error);

        } finally {

            this.isLoading = false;

            if (this.isComponentConnected && this._orderId) {
                this.scheduleAutoRefresh();
            }
        }
    }


    // =========================================================
    // AUTO REFRESH
    // =========================================================

    scheduleAutoRefresh() {

        this.stopAutoRefresh();

        this.refreshTimer = setTimeout(() => {
            this.loadDelivery();
        }, 15000);
    }


    stopAutoRefresh() {

        if (this.refreshTimer) {
            clearTimeout(this.refreshTimer);
            this.refreshTimer = undefined;
        }
    }


    // =========================================================
    // MANUAL REFRESH
    // =========================================================

    async handleRefresh() {

        this.stopAutoRefresh();

        this.isLoading = true;

        await this.loadDelivery();
    }


    // =========================================================
    // LAST UPDATED
    // =========================================================

    get formattedLastUpdated() {

        if (!this.lastUpdated) {
            return 'Waiting for update...';
        }

        return new Intl.DateTimeFormat('en-IN', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        }).format(this.lastUpdated);
    }


    // =========================================================
    // STATE
    // =========================================================

    get hasDelivery() {
        return !!this.delivery;
    }


    get currentStatusIndex() {

        const status = this.delivery?.Status__c;

        const statuses = [
            'Assigned',
            'Picking Up',
            'Out for Delivery',
            'Delivered'
        ];

        return statuses.indexOf(status);
    }


    // =========================================================
    // TIMELINE
    // =========================================================

    get timelineSteps() {

        const steps = [
            {
                label: 'Assigned',
                icon: '📦',
                time: this.delivery?.Assigned_Time__c
            },
            {
                label: 'Picking Up',
                icon: '🏪',
                time: this.delivery?.Pickup_Time__c
            },
            {
                label: 'Out for Delivery',
                icon: '🛵',
                time: this.delivery?.Out_for_Delivery_Time__c
            },
            {
                label: 'Delivered',
                icon: '✅',
                time: this.delivery?.Delivered_Time__c
            }
        ];

        return steps.map((step, index) => {

            let state = 'pending';

            if (index < this.currentStatusIndex) {
                state = 'completed';
            } else if (index === this.currentStatusIndex) {
                state = 'current';
            }

            return {
                ...step,
                cssClass: `timeline-step ${state}`,
                formattedTime: this.formatDateTime(step.time)
            };
        });
    }


    // =========================================================
    // DELIVERY DETAILS
    // =========================================================

    get orderNumber() {
        return this.delivery?.Order__r?.Name || '';
    }


    get deliveryNumber() {
        return this.delivery?.Name || '';
    }


    get currentStatus() {
        return this.delivery?.Status__c || '';
    }


    get agentName() {

        return (
            this.delivery?.Delivery_Agent__r?.Agent_Name__c ||
            this.delivery?.Delivery_Agent__r?.Name ||
            'Not assigned'
        );
    }


    get storeName() {

        return (
            this.delivery?.Pickup_Store__r?.Name ||
            'QuickDrop Store'
        );
    }


    get formattedEta() {

        return this.formatDateTime(
            this.delivery?.ETA__c
        );
    }


    get currentLocation() {

        const latitude =
            this.delivery?.Current_Latitude__c;

        const longitude =
            this.delivery?.Current_Longitude__c;

        if (
            latitude === null ||
            latitude === undefined ||
            longitude === null ||
            longitude === undefined
        ) {
            return 'Location unavailable';
        }

        return `${latitude}, ${longitude}`;
    }


    // =========================================================
    // DATE FORMATTER
    // =========================================================

    formatDateTime(value) {

        if (!value) {
            return '';
        }

        try {

            return new Intl.DateTimeFormat('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }).format(new Date(value));

        } catch (error) {

            return value;
        }
    }


    // =========================================================
    // ERROR HANDLER
    // =========================================================

    getErrorMessage(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unable to load delivery information.';
    }
}
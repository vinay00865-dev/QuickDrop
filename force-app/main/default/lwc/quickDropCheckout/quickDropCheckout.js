import { LightningElement, track } from 'lwc';

import getCheckoutContext
    from '@salesforce/apex/QuickDropCheckoutController.getCheckoutContext';

import getAddresses
    from '@salesforce/apex/QuickDropCheckoutController.getAddresses';

import getCheckoutCart
    from '@salesforce/apex/QuickDropCheckoutController.getCheckoutCart';

import placeOrder
    from '@salesforce/apex/QuickDropCheckoutController.placeOrder';

export default class QuickDropCheckout extends LightningElement {

    // =========================================================
    // DATA
    // =========================================================

    @track context;
    @track addresses = [];
    @track checkoutItems = [];
    @track orderResult;


    // =========================================================
    // STATE
    // =========================================================

    isLoading = true;
    isPlacingOrder = false;
    isOrderPlaced = false;

    error;

    selectedAddressId;
    paymentMethod = 'COD';


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {
        this.loadCheckout();
    }


    // =========================================================
    // LOAD CHECKOUT
    // =========================================================

    async loadCheckout() {
        this.isLoading = true;
        this.error = undefined;

        try {
            const contextResult = await getCheckoutContext();

            this.context = contextResult;

            if (!this.context?.customerId) {
                throw new Error(
                    'Unable to identify your QuickDrop customer account.'
                );
            }

            await this.loadAddresses();
            await this.loadCart();

        } catch (error) {
            this.error = this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }


    // =========================================================
    // LOAD ADDRESSES
    // =========================================================

    async loadAddresses() {

        const result = await getAddresses({
            customerId: this.context.customerId
        });

        this.addresses = Array.isArray(result)
            ? result
            : [];

        if (this.addresses.length > 0) {

            const defaultAddress = this.addresses.find(
                address => address.Default_Address__c === true
            );

            this.selectedAddressId =
                defaultAddress?.Id ||
                this.addresses[0].Id;
        }
    }


    // =========================================================
    // LOAD CART
    // =========================================================

    async loadCart() {

        const result = await getCheckoutCart({
            customerId: this.context.customerId,
            storeId: this.context.storeId
        });

        this.checkoutItems = Array.isArray(result)
            ? result
            : [];

        if (this.checkoutItems.length === 0) {
            this.error =
                'Your cart is empty. Please add products before checkout.';
        }
    }


    // =========================================================
    // ADDRESS OPTIONS
    // =========================================================

    get addressOptions() {

        return this.addresses.map(address => {

            const parts = [
                address.Address_Line__c,
                address.City__c,
                address.State__c,
                address.Pincode__c
            ].filter(value => value !== null && value !== undefined && value !== '');

            return {
                label: `${address.Address_Label__c || 'Address'} — ${parts.join(', ')}`,
                value: address.Id
            };
        });
    }


    // =========================================================
    // PAYMENT OPTIONS
    // =========================================================

    get paymentOptions() {
    return [
        {
            label: 'UPI',
            value: 'UPI'
        },
        {
            label: 'Card',
            value: 'Card'
        },
        {
            label: 'Wallet',
            value: 'Wallet'
        },
        {
            label: 'Cash on Delivery',
            value: 'Cash on Delivery'
        }
    ];
}


    // =========================================================
    // SELECTED ADDRESS
    // =========================================================

    get selectedAddress() {

        if (!this.selectedAddressId) {
            return undefined;
        }

        return this.addresses.find(
            address => address.Id === this.selectedAddressId
        );
    }


    get selectedAddressLabel() {

        return this.selectedAddress?.Address_Label__c || '';
    }


    get selectedAddressLine() {

        return this.selectedAddress?.Address_Line__c || '';
    }


    get selectedAddressCity() {

        return this.selectedAddress?.City__c || '';
    }


    get selectedAddressState() {

        return this.selectedAddress?.State__c || '';
    }


    get selectedAddressPincode() {

        return this.selectedAddress?.Pincode__c || '';
    }


    // =========================================================
    // TOTALS
    // =========================================================

    get subtotal() {

        return this.checkoutItems.reduce(
            (total, item) => {
                return total + Number(item.Line_Total__c || 0);
            },
            0
        );
    }


    get tax() {

        return this.checkoutItems.reduce(
            (total, item) => {

                const quantity =
                    Number(item.Quantity__c || 0);

                const unitPrice =
                    Number(item.Unit_Price__c || 0);

                const tax =
                    Number(item.Tax__c || 0);

                return total + (
                    quantity *
                    unitPrice *
                    tax /
                    100
                );
            },
            0
        );
    }


    get deliveryFee() {

        return 40;
    }


    get discount() {

        return this.checkoutItems.reduce(
            (total, item) => {
                return total + Number(item.Discount__c || 0);
            },
            0
        );
    }


    get grandTotal() {

        return (
            this.subtotal +
            this.tax +
            this.deliveryFee -
            this.discount
        );
    }


    // =========================================================
    // CHECKOUT STATE
    // =========================================================

    get hasCheckout() {

        return (
            !this.isOrderPlaced &&
            !!this.context &&
            !this.error
        );
    }


    get hasItems() {

        return (
            Array.isArray(this.checkoutItems) &&
            this.checkoutItems.length > 0
        );
    }


    // =========================================================
    // ADDRESS CHANGE
    // =========================================================

    handleAddressChange(event) {

        this.selectedAddressId =
            event.detail.value;
    }


    // =========================================================
    // PAYMENT CHANGE
    // =========================================================

    handlePaymentChange(event) {

        this.paymentMethod =
            event.detail.value;
    }


    // =========================================================
    // PLACE ORDER
    // =========================================================

    async handlePlaceOrder() {

        // Prevent duplicate clicks
        if (this.isPlacingOrder || this.isOrderPlaced) {
            return;
        }


        // Validate customer context
        if (
            !this.context?.customerId ||
            !this.context?.storeId
        ) {
            this.error =
                'Your QuickDrop account context could not be loaded.';
            return;
        }


        // Validate address
        if (!this.selectedAddressId) {
            this.error =
                'Please select a delivery address.';
            return;
        }


        // Validate payment
        if (!this.paymentMethod) {
            this.error =
                'Please select a payment method.';
            return;
        }


        // Validate cart
        if (!this.hasItems) {
            this.error =
                'Your cart is empty. Please add products before checkout.';
            return;
        }


        this.isPlacingOrder = true;
        this.error = undefined;


        try {

            const result = await placeOrder({
                customerId: this.context.customerId,
                storeId: this.context.storeId,
                addressId: this.selectedAddressId,
                paymentMethod: this.paymentMethod
            });


            // Save returned order result
            this.orderResult = result;


            // Show success screen
            this.isOrderPlaced = true;


            // Clear local checkout items
            this.checkoutItems = [];


        } catch (error) {

            this.error =
                this.getErrorMessage(error);

        } finally {

            this.isPlacingOrder = false;
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

        return 'Something went wrong during checkout.';
    }
}
import { LightningElement } from 'lwc';

import getCurrentContext
    from '@salesforce/apex/QuickDropStoreContextController.getCurrentContext';

import addToCart
    from '@salesforce/apex/QuickDropCartController.addToCart';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class QuickDropStoreHome extends LightningElement {

    // =========================================================
    // NAVIGATION
    // =========================================================

    currentView = 'home';

    selectedOrderId;


    // =========================================================
    // CUSTOMER CONTEXT
    // =========================================================

    customerContext;
    contextError;
    isContextLoading = true;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {
        this.loadCustomerContext();
    }


    // =========================================================
    // CUSTOMER CONTEXT
    // =========================================================

    async loadCustomerContext() {

        this.isContextLoading = true;
        this.contextError = undefined;

        try {

            this.customerContext =
                await getCurrentContext();

        } catch (error) {

            this.customerContext = undefined;
            this.contextError =
                this.getErrorMessage(error);

        } finally {

            this.isContextLoading = false;
        }
    }


    // =========================================================
    // VIEW GETTERS
    // =========================================================

    get isHome() {
        return this.currentView === 'home';
    }

    get isCart() {
        return this.currentView === 'cart';
    }

    get isCheckout() {
        return this.currentView === 'checkout';
    }

    get isOrders() {
        return this.currentView === 'orders';
    }

    get isTracking() {
        return this.currentView === 'tracking';
    }


    // =========================================================
    // NAVIGATION CLASSES
    // =========================================================

    get homeClass() {
        return this.isHome
            ? 'nav-item active'
            : 'nav-item';
    }

    get cartClass() {
        return this.isCart
            ? 'nav-item active'
            : 'nav-item';
    }

    get checkoutClass() {
        return this.isCheckout
            ? 'nav-item active'
            : 'nav-item';
    }

    get ordersClass() {
        return this.isOrders
            ? 'nav-item active'
            : 'nav-item';
    }


    // =========================================================
    // CART VIEW
    // =========================================================

    get cartViewClass() {
        return this.isCart
            ? 'store-view visible'
            : 'store-view hidden';
    }


    // =========================================================
    // CUSTOMER CONTEXT GETTERS
    // =========================================================

    get hasContext() {
        return !!this.customerContext;
    }

    get customerId() {
        return this.customerContext?.customerId;
    }

    get customerName() {
        return this.customerContext?.customerName;
    }

    get addressId() {
        return this.customerContext?.addressId;
    }

    get addressLabel() {
        return this.customerContext?.addressLabel;
    }

    get addressLine() {
        return this.customerContext?.addressLine;
    }

    get city() {
        return this.customerContext?.city;
    }

    get state() {
        return this.customerContext?.state;
    }

    get pincode() {
        return this.customerContext?.pincode;
    }

    get zoneName() {
        return this.customerContext?.zoneName;
    }

    get storeId() {
        return this.customerContext?.storeId;
    }

    get storeName() {
        return this.customerContext?.storeName;
    }


    // =========================================================
    // FULL ADDRESS
    // =========================================================

    get fullAddress() {

        return [
            this.addressLine,
            this.city,
            this.state,
            this.pincode
        ]
        .filter(value => value)
        .join(', ');
    }


    // F=========================================================
    // NAVIGATION
    // =========================================================

    handleNavigation(event) {

        const view =
            event.currentTarget.dataset.view;

        if (!view) {
            return;
        }

        this.currentView = view;

        // Clear selected order when leaving tracking
        if (view !== 'tracking') {
            this.selectedOrderId = undefined;
        }
    }


    // =========================================================
    // PRODUCT ADD
    // =========================================================

    async handleProductAdd(event) {
    const productId = event?.detail?.productId;
    const productName = event?.detail?.productName || 'Product';

    if (!productId) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to Add Product',
                message: 'The product ID was not provided.',
                variant: 'error'
            })
        );
        return;
    }

    if (!this.customerId || !this.storeId) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Store Not Ready',
                message: 'Customer or store context is missing. Please refresh the page.',
                variant: 'warning'
            })
        );
        return;
    }

    try {
        await addToCart({
            customerId: this.customerId,
            storeId: this.storeId,
            productId: productId,
            quantity: 1
        });

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Added to Cart',
                message: `${productName} was added to your cart.`,
                variant: 'success'
            })
        );
    } catch (error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Add to Cart Failed',
                message:
                    error?.body?.message ||
                    error?.message ||
                    'An unexpected error occurred.',
                variant: 'error'
            })
        );
    }
}


    // =========================================================
    // PROCEED TO CHECKOUT
    // =========================================================

    handleProceedToCheckout() {

        this.currentView = 'checkout';
    }


    // =========================================================
    // ORDER SELECT
    // =========================================================

    handleOrderSelect(event) {

        const orderId =
            event.detail.orderId;

        if (!orderId) {
            return;
        }

        this.selectedOrderId =
            orderId;

        // Open dedicated tracking screen
        this.currentView = 'tracking';
    }


    // =========================================================
    // BACK TO MY ORDERS
    // =========================================================

    handleBackToOrders() {

        this.selectedOrderId = undefined;
        this.currentView = 'orders';
    }


    // =========================================================
    // ERROR MESSAGE
    // =========================================================

    getErrorMessage(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unable to load your QuickDrop account.';
    }
}
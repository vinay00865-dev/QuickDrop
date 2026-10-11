import {
    LightningElement,
    track,
    api
} from 'lwc';

import getCustomers
    from '@salesforce/apex/QuickDropCartController.getCustomers';

import getStores
    from '@salesforce/apex/QuickDropCartController.getStores';

import getProducts
    from '@salesforce/apex/QuickDropCartController.getProducts';

import getCart
    from '@salesforce/apex/QuickDropCartController.getCart';

import addToCart
    from '@salesforce/apex/QuickDropCartController.addToCart';

import changeCartItem
    from '@salesforce/apex/QuickDropCartController.changeCartItem';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';


export default class QuickDropCart extends LightningElement {

    // =====================================================
    // DATA
    // =====================================================

    @track customers = [];
    @track stores = [];
    @track products = [];
    @track cartItems = [];


    // =====================================================
    // STOREFRONT CONTEXT
    // =====================================================

    _customerId;
    _storeId;


    @api
    get customerId() {
        return this._customerId;
    }

    set customerId(value) {
        this._customerId = value;
        this.tryLoadCart();
    }


    @api
    get storeId() {
        return this._storeId;
    }

    set storeId(value) {
        this._storeId = value;
        this.tryLoadCart();
    }


    // =====================================================
    // OTHER VALUES
    // =====================================================

    selectedProductId;
    quantity = 1;

    isLoading = false;
    error;


    // =====================================================
    // LIFECYCLE
    // =====================================================

    connectedCallback() {
        this.loadCustomers();
        this.loadStores();
        this.loadProducts();
    }


    // =====================================================
    // LOAD CUSTOMERS
    // =====================================================

    async loadCustomers() {

        try {

            const result = await getCustomers();

            this.customers =
                Array.isArray(result) ? result : [];

        } catch (error) {

            this.handleError(error);

        }

    }


    // =====================================================
    // LOAD STORES
    // =====================================================

    async loadStores() {

        try {

            const result = await getStores();

            this.stores =
                Array.isArray(result) ? result : [];

        } catch (error) {

            this.handleError(error);

        }

    }


    // =====================================================
    // LOAD PRODUCTS
    // =====================================================

    async loadProducts() {

        try {

            const result = await getProducts();

            this.products =
                Array.isArray(result) ? result : [];

        } catch (error) {

            this.handleError(error);

        }

    }


    // =====================================================
    // LOAD CART
    // =====================================================

    async loadCart() {

        if (
            !this._customerId ||
            !this._storeId
        ) {

            this.cartItems = [];
            return;
        }


        try {

            const result = await getCart({
                customerId: this._customerId,
                storeId: this._storeId
            });


            this.cartItems =
                Array.isArray(result) ? result : [];

        } catch (error) {

            this.cartItems = [];

            this.handleError(error);

        }

    }


    // =====================================================
    // TRY LOAD CART
    // =====================================================

    async tryLoadCart() {

        if (
            !this._customerId ||
            !this._storeId
        ) {
            return;
        }

        await this.loadCart();

    }


    // =====================================================
    // CUSTOMER CHANGE
    // =====================================================

    handleCustomerChange(event) {

        this._customerId =
            event.detail.value;

        this.loadCart();

    }


    // =====================================================
    // STORE CHANGE
    // =====================================================

    handleStoreChange(event) {

        this._storeId =
            event.detail.value;

        this.loadCart();

    }


    // =====================================================
    // PRODUCT CHANGE
    // =====================================================

    handleProductChange(event) {

        this.selectedProductId =
            event.detail.value;

    }


    // =====================================================
    // QUANTITY INPUT
    // =====================================================

    handleQuantityChange(event) {

        const value =
            Number(event.detail.value);

        this.quantity =
            value > 0 ? value : 1;

    }


    // =====================================================
    // ADD TO CART
    // =====================================================

    async handleAddToCart() {

        await this.addProductToCart(
            this.selectedProductId,
            this._customerId,
            this._storeId,
            this.quantity
        );

    }


    // =====================================================
    // PUBLIC ADD PRODUCT TO CART
    // =====================================================

    @api
    async addProductToCart(
        productId,
        customerId,
        storeId,
        quantity = 1
    ) {

        const finalCustomerId =
            customerId || this._customerId;

        const finalStoreId =
            storeId || this._storeId;


        if (!finalCustomerId) {

            this.showToast(
                'Select Customer',
                'Please select a customer.',
                'warning'
            );

            return false;
        }


        if (!finalStoreId) {

            this.showToast(
                'Select Store',
                'Please select a store.',
                'warning'
            );

            return false;
        }


        if (!productId) {

            this.showToast(
                'Product Required',
                'Please select a product.',
                'warning'
            );

            return false;
        }


        this._customerId =
            finalCustomerId;

        this._storeId =
            finalStoreId;


        this.isLoading = true;


        try {

            await addToCart({
                customerId: finalCustomerId,
                storeId: finalStoreId,
                productId: productId,
                quantity: Number(quantity) || 1
            });


            await this.loadCart();


            this.showToast(
                'Added to Cart',
                'Product added successfully.',
                'success'
            );


            return true;

        } catch (error) {

            this.handleError(error);

            return false;

        } finally {

            this.isLoading = false;

        }

    }


    // =====================================================
    // INCREASE
    // =====================================================

    async handleIncrease(event) {

        const cartItemId =
            event.currentTarget.dataset.itemId;


        if (!cartItemId) {

            this.showToast(
                'Error',
                'Cart item ID is missing.',
                'error'
            );

            return;
        }


        const item =
            this.cartItems.find(
                currentItem =>
                    currentItem.Id === cartItemId
            );


        if (!item) {

            this.showToast(
                'Error',
                'Cart item was not found.',
                'error'
            );

            return;
        }


        const currentQuantity =
            Number(item.Quantity__c || 0);


        const newQuantity =
            currentQuantity + 1;


        await this.changeItem(
            cartItemId,
            'INCREASE',
            newQuantity
        );

    }


    // =====================================================
    // DECREASE
    // =====================================================

    async handleDecrease(event) {

        const cartItemId =
            event.currentTarget.dataset.itemId;


        if (!cartItemId) {

            this.showToast(
                'Error',
                'Cart item ID is missing.',
                'error'
            );

            return;
        }


        const item =
            this.cartItems.find(
                currentItem =>
                    currentItem.Id === cartItemId
            );


        if (!item) {

            this.showToast(
                'Error',
                'Cart item was not found.',
                'error'
            );

            return;
        }


        const currentQuantity =
            Number(item.Quantity__c || 0);


        const newQuantity =
            currentQuantity - 1;


        if (newQuantity < 1) {

            await this.changeItem(
                cartItemId,
                'REMOVE',
                0
            );

            return;
        }


        await this.changeItem(
            cartItemId,
            'DECREASE',
            newQuantity
        );

    }


    // =====================================================
    // REMOVE
    // =====================================================

    async handleRemove(event) {

        const cartItemId =
            event.currentTarget.dataset.itemId;


        if (!cartItemId) {

            this.showToast(
                'Error',
                'Cart item ID is missing.',
                'error'
            );

            return;
        }


        await this.changeItem(
            cartItemId,
            'REMOVE',
            0
        );

    }


    // =====================================================
    // CHANGE CART ITEM
    // =====================================================

    async changeItem(
        cartItemId,
        action,
        newQuantity
    ) {

        if (!cartItemId) {
            return;
        }


        this.isLoading = true;


        try {

            // ---------------------------------------------
            // UPDATE SERVER
            // ---------------------------------------------

            await changeCartItem({
                cartItemId: cartItemId,
                action: action
            });


            // ---------------------------------------------
            // UPDATE UI IMMEDIATELY
            // ---------------------------------------------

            if (action === 'REMOVE') {

                this.cartItems =
                    this.cartItems.filter(
                        item =>
                            item.Id !== cartItemId
                    );

            } else {

                this.cartItems =
                    this.cartItems.map(
                        item => {

                            if (
                                item.Id !== cartItemId
                            ) {

                                return item;
                            }


                            const unitPrice =
                                Number(
                                    item.Unit_Price__c || 0
                                );


                            const discount =
                                Number(
                                    item.Discount__c || 0
                                );


                            const lineTotal =
                                (
                                    unitPrice *
                                    newQuantity
                                ) - discount;


                            return {
                                ...item,

                                Quantity__c:
                                    newQuantity,

                                Line_Total__c:
                                    lineTotal
                            };

                        }
                    );

            }

        } catch (error) {

            this.handleError(error);

        } finally {

            this.isLoading = false;

        }

    }


    // =====================================================
    // CART COUNT
    // =====================================================

    get cartCount() {

        if (!Array.isArray(this.cartItems)) {
            return 0;
        }


        return this.cartItems.reduce(
            (total, item) =>
                total +
                Number(item.Quantity__c || 0),
            0
        );

    }


    // =====================================================
    // CART TOTAL
    // =====================================================

    get cartTotal() {

        if (!Array.isArray(this.cartItems)) {
            return 0;
        }


        return this.cartItems.reduce(
            (total, item) =>
                total +
                Number(item.Line_Total__c || 0),
            0
        );

    }


    // =====================================================
    // HAS ITEMS
    // =====================================================

    get hasCartItems() {

        return (
            Array.isArray(this.cartItems) &&
            this.cartItems.length > 0
        );

    }


    // =====================================================
    // EMPTY CART
    // =====================================================

    get isCartEmpty() {

        return !this.hasCartItems;

    }


    // =====================================================
    // PROCEED TO CHECKOUT
    // =====================================================

    handleProceedToCheckout() {

        this.dispatchEvent(
            new CustomEvent(
                'proceedcheckout',
                {
                    bubbles: true,
                    composed: true
                }
            )
        );

    }


    // =====================================================
    // ERROR HANDLING
    // =====================================================

    handleError(error) {

        const message =
            this.getErrorMessage(error);


        this.error =
            message;


        this.showToast(
            'Error',
            message,
            'error'
        );

    }


    // =====================================================
    // GET ERROR MESSAGE
    // =====================================================

    getErrorMessage(error) {

        if (
            error &&
            error.body &&
            error.body.message
        ) {

            return error.body.message;
        }


        if (
            error &&
            error.message
        ) {

            return error.message;
        }


        return 'Something went wrong.';

    }


    // =====================================================
    // TOAST
    // =====================================================

    showToast(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );

    }

}
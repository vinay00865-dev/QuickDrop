import { LightningElement, wire } from 'lwc';

import getProducts
    from '@salesforce/apex/QuickDropProductController.getProducts';

export default class QuickDropProductCatalog extends LightningElement {

    products = [];
    searchTerm = '';
    selectedCategory = 'All';
    error;
    loading = true;

    @wire(getProducts)
    wiredProducts({ data, error }) {

        this.loading = false;

        if (data) {

            this.products = data.map(product => ({
                ...product,
                categoryName:
                    product.Category__r?.Name || 'Other'
            }));

            this.error = undefined;

        } else if (error) {

            this.error = error;
            this.products = [];
        }
    }

    get categoryOptions() {

        const categories = [
            ...new Set(
                this.products.map(
                    product => product.categoryName
                )
            )
        ];

        return [
            {
                label: 'All Categories',
                value: 'All'
            },
            ...categories.map(category => ({
                label: category,
                value: category
            }))
        ];
    }

    get filteredProducts() {

        let result = [...this.products];

        if (this.searchTerm) {

            const search =
                this.searchTerm.toLowerCase();

            result = result.filter(product => {

                const name =
                    product.Name?.toLowerCase() || '';

                const brand =
                    product.Brand__c?.toLowerCase() || '';

                const sku =
                    product.SKU__c?.toLowerCase() || '';

                return (
                    name.includes(search) ||
                    brand.includes(search) ||
                    sku.includes(search)
                );
            });
        }

        if (this.selectedCategory !== 'All') {

            result = result.filter(
                product =>
                    product.categoryName ===
                    this.selectedCategory
            );
        }

        return result;
    }

    get productCount() {
        return this.filteredProducts.length;
    }

    get hasProducts() {
        return this.filteredProducts.length > 0;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
    }

    handleAddToCart(event) {

        const productId =
            event.currentTarget.dataset.id;

        const product =
            this.products.find(
                item => item.Id === productId
            );

        this.dispatchEvent(
            new CustomEvent('productadd', {
                detail: {
                    productId: productId,
                    productName: product?.Name
                }
            })
        );
    }
}
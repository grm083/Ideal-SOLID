/**
 * @description Inline Detail Card Component
 * Displays record details in an inline card format
 * REPLACES problematic hover cards with stable inline display
 *
 * Used for displaying Location, Asset, Contact details in case management
 *
 * @property {String} title - Card title
 * @property {String} iconName - Lightning icon name
 * @property {Array} fields - Array of field objects to display
 * @property {String} variant - Card variant (base|narrow)
 * @property {Boolean} isVisible - Whether card is visible
 * @property {Boolean} showCloseButton - Whether to show close button
 * @property {Boolean} hasFooter - Whether card has footer content
 */
import { LightningElement, api } from 'lwc';

export default class InlineDetailCard extends LightningElement {
    /**
     * @description Card title
     */
    @api title = '';

    /**
     * @description Lightning icon name (e.g., 'standard:account')
     */
    @api iconName = '';

    /**
     * @description Array of field objects
     * Each field should have: { id, label, value, type }
     * Optional: { isLink, linkUrl, isBold, isHighlight }
     */
    @api fields = [];

    /**
     * @description Card variant
     * Options: base (default), narrow
     */
    @api variant = 'base';

    /**
     * @description Whether card is visible
     */
    @api isVisible = true;

    /**
     * @description Whether to show close button
     */
    @api showCloseButton = false;

    /**
     * @description Whether card has footer content
     */
    @api hasFooter = false;

    /**
     * @description Computed CSS class for card
     */
    get cardClass() {
        let classes = 'slds-card';
        if (this.variant === 'narrow') {
            classes += ' slds-card_narrow';
        }
        return classes;
    }

    /**
     * @description Computed property - whether fields exist
     */
    get hasFields() {
        return this.fields && this.fields.length > 0;
    }

    /**
     * @description Handle close button click
     */
    handleClose() {
        this.isVisible = false;

        // Dispatch event to parent
        this.dispatchEvent(new CustomEvent('close'));
    }

    /**
     * @description Handle field click (for links)
     * @param {Event} event - Click event
     */
    handleFieldClick(event) {
        event.preventDefault();

        const fieldId = event.currentTarget.dataset.id;
        const field = this.fields.find(f => f.id === fieldId);

        if (field && field.isLink) {
            // Dispatch event to parent for custom handling
            this.dispatchEvent(new CustomEvent('fieldclick', {
                detail: {
                    fieldId: fieldId,
                    fieldLabel: field.label,
                    fieldValue: field.value
                }
            }));

            // Navigate if linkUrl is provided
            if (field.linkUrl) {
                // Use Navigation Service if available, otherwise window.location
                if (field.linkUrl.startsWith('/')) {
                    window.location.href = field.linkUrl;
                } else {
                    window.open(field.linkUrl, '_blank');
                }
            }
        }
    }

    /**
     * @description Public API to show the card
     */
    @api
    show() {
        this.isVisible = true;
    }

    /**
     * @description Public API to hide the card
     */
    @api
    hide() {
        this.isVisible = false;
    }

    /**
     * @description Public API to toggle card visibility
     */
    @api
    toggle() {
        this.isVisible = !this.isVisible;
    }

    /**
     * @description Public API to update fields
     * @param {Array} newFields - New fields array
     */
    @api
    updateFields(newFields) {
        this.fields = this.processFields(newFields);
    }

    /**
     * @description Process fields to add computed properties
     * @param {Array} rawFields - Raw field objects
     * @returns {Array} Processed field objects
     */
    processFields(rawFields) {
        if (!rawFields || rawFields.length === 0) {
            return [];
        }

        return rawFields.map((field, index) => {
            // Ensure ID exists
            const id = field.id || `field-${index}`;

            // Format value based on type
            let displayValue = field.value;
            if (field.type === 'currency' && field.value) {
                displayValue = this.formatCurrency(field.value);
            } else if (field.type === 'date' && field.value) {
                displayValue = this.formatDate(field.value);
            } else if (field.type === 'datetime' && field.value) {
                displayValue = this.formatDateTime(field.value);
            } else if (field.type === 'boolean') {
                displayValue = field.value ? 'Yes' : 'No';
            } else if (!field.value || field.value === '') {
                displayValue = '--';
            }

            // Build value CSS class
            let valueClass = 'slds-truncate';
            if (field.isBold) {
                valueClass += ' slds-text-body_strong';
            }
            if (field.isHighlight) {
                valueClass += ' slds-text-color_success';
            }

            return {
                ...field,
                id,
                displayValue,
                valueClass,
                isLink: field.isLink || false,
                linkUrl: field.linkUrl || ''
            };
        });
    }

    /**
     * @description Format currency value
     * @param {Number} value - Currency value
     * @returns {String} Formatted currency
     */
    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(value);
    }

    /**
     * @description Format date value
     * @param {String} value - Date string
     * @returns {String} Formatted date
     */
    formatDate(value) {
        try {
            const date = new Date(value);
            return new Intl.DateTimeFormat('en-US').format(date);
        } catch (e) {
            return value;
        }
    }

    /**
     * @description Format datetime value
     * @param {String} value - DateTime string
     * @returns {String} Formatted datetime
     */
    formatDateTime(value) {
        try {
            const date = new Date(value);
            return new Intl.DateTimeFormat('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: 'numeric',
                minute: '2-digit'
            }).format(date);
        } catch (e) {
            return value;
        }
    }

    /**
     * @description Lifecycle hook - process fields on connection
     */
    connectedCallback() {
        if (this.fields && this.fields.length > 0) {
            this.fields = this.processFields(this.fields);
        }
    }

    /**
     * @description Lifecycle hook - watch for field changes
     */
    renderedCallback() {
        // Auto-process fields if they haven't been processed yet
        if (this.fields && this.fields.length > 0) {
            const firstField = this.fields[0];
            if (!firstField.displayValue && !firstField.valueClass) {
                this.fields = this.processFields(this.fields);
            }
        }
    }
}

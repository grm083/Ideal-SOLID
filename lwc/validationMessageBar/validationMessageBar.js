/**
 * @description Validation Message Bar Component
 * Displays validation messages, errors, warnings, and info messages
 * Used throughout the case management wizard for user feedback
 *
 * @property {Array} messages - Array of message objects
 * @property {String} variant - Message variant (error|warning|info|success)
 * @property {Boolean} dismissible - Whether messages can be dismissed
 */
import { LightningElement, api } from 'lwc';

export default class ValidationMessageBar extends LightningElement {
    /**
     * @description Array of message objects
     * Each message should have: { id, type, heading, message, icon }
     */
    @api messages = [];

    /**
     * @description Default variant for all messages
     * Options: error, warning, info, success
     */
    @api variant = 'error';

    /**
     * @description Whether messages can be dismissed
     */
    @api dismissible = false;

    /**
     * @description Internal message tracking with unique IDs
     */
    _internalMessages = [];

    /**
     * @description Computed property to check if there are messages
     */
    get hasMessages() {
        return this._internalMessages && this._internalMessages.length > 0;
    }

    /**
     * @description Computed CSS class for message container
     */
    get messageClass() {
        const baseClass = 'slds-notify slds-notify_alert slds-m-bottom_x-small';
        switch (this.variant.toLowerCase()) {
            case 'error':
                return `${baseClass} slds-alert_error`;
            case 'warning':
                return `${baseClass} slds-alert_warning`;
            case 'success':
                return `${baseClass} slds-theme_success`;
            case 'info':
            default:
                return `${baseClass} slds-theme_info`;
        }
    }

    /**
     * @description Computed CSS class for icon container
     */
    get iconClass() {
        return 'slds-icon_container slds-m-right_x-small';
    }

    /**
     * @description Lifecycle hook - process messages when they change
     */
    connectedCallback() {
        this.processMessages();
    }

    /**
     * @description Lifecycle hook - watch for message property changes
     */
    renderedCallback() {
        if (this.messages && this.messages.length !== this._internalMessages.length) {
            this.processMessages();
        }
    }

    /**
     * @description Process incoming messages and add defaults
     */
    processMessages() {
        if (!this.messages || this.messages.length === 0) {
            this._internalMessages = [];
            return;
        }

        this._internalMessages = this.messages.map((msg, index) => {
            return {
                id: msg.id || `msg-${index}-${Date.now()}`,
                type: msg.type || this.variant,
                heading: msg.heading || this.getDefaultHeading(msg.type || this.variant),
                message: msg.message || '',
                icon: msg.icon || this.getDefaultIcon(msg.type || this.variant)
            };
        });
    }

    /**
     * @description Get default heading based on message type
     * @param {String} type - Message type
     * @returns {String} Default heading
     */
    getDefaultHeading(type) {
        switch (type?.toLowerCase()) {
            case 'error':
                return 'Error';
            case 'warning':
                return 'Warning';
            case 'success':
                return 'Success';
            case 'info':
            default:
                return 'Information';
        }
    }

    /**
     * @description Get default icon based on message type
     * @param {String} type - Message type
     * @returns {String} Icon name
     */
    getDefaultIcon(type) {
        switch (type?.toLowerCase()) {
            case 'error':
                return 'utility:error';
            case 'warning':
                return 'utility:warning';
            case 'success':
                return 'utility:success';
            case 'info':
            default:
                return 'utility:info';
        }
    }

    /**
     * @description Handle close button click
     * @param {Event} event - Click event
     */
    handleClose(event) {
        const messageId = event.currentTarget.dataset.id;

        // Remove message from internal array
        this._internalMessages = this._internalMessages.filter(msg => msg.id !== messageId);

        // Dispatch event to parent to remove from messages array
        this.dispatchEvent(new CustomEvent('closemessage', {
            detail: { messageId }
        }));
    }

    /**
     * @description Public API to add a message
     * @param {Object} message - Message object
     */
    @api
    addMessage(message) {
        const newMessages = [...this.messages, message];
        this.messages = newMessages;
        this.processMessages();
    }

    /**
     * @description Public API to clear all messages
     */
    @api
    clearMessages() {
        this.messages = [];
        this._internalMessages = [];
    }

    /**
     * @description Public API to remove a specific message
     * @param {String} messageId - ID of message to remove
     */
    @api
    removeMessage(messageId) {
        this.messages = this.messages.filter(msg => msg.id !== messageId);
        this._internalMessages = this._internalMessages.filter(msg => msg.id !== messageId);
    }
}

import { LightningElement, api, track } from 'lwc';
import getCaseHighlightData from '@salesforce/apex/CaseHighlightStripController.getCaseHighlightData';

/**
 * Case Highlight Strip Component
 *
 * Horizontal strip layout displaying key case fields with color coding:
 * - Green background = Complete & valid
 * - Orange background = Needs attention
 * - Red background = Missing required field
 * - Blue background = Informational
 *
 * Features:
 * - Click any field to edit (dispatches fieldedit event)
 * - NO HOVER CARDS - All details shown inline
 * - Real-time field status updates
 * - Color-coded visual indicators
 *
 * Replaces: CustomCaseHighlightPanel (Aura + LWC)
 *
 * @author George Martin
 * @date 2025-11-18
 */
export default class CaseHighlightStrip extends LightningElement {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Case ID (required)
     */
    @api caseId;

    // ========================================
    // Private Properties
    // ========================================

    @track highlightData = {};
    @track isLoading = false;
    @track error = null;

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        if (this.caseId) {
            this.loadHighlightData();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Location field CSS class with status color
     */
    get locationFieldClass() {
        return this.getFieldClass(this.highlightData.locationStatus);
    }

    /**
     * Contact field CSS class with status color
     */
    get contactFieldClass() {
        return this.getFieldClass(this.highlightData.contactStatus);
    }

    /**
     * Asset field CSS class with status color
     */
    get assetFieldClass() {
        return this.getFieldClass(this.highlightData.assetStatus);
    }

    /**
     * Case type field CSS class with status color
     */
    get caseTypeFieldClass() {
        return this.getFieldClass(this.highlightData.caseTypeStatus);
    }

    /**
     * Service date field CSS class with status color
     */
    get serviceDateFieldClass() {
        return this.getFieldClass(this.highlightData.serviceDateStatus);
    }

    /**
     * Customer info field CSS class with status color
     */
    get customerInfoFieldClass() {
        return this.getFieldClass(this.highlightData.customerInfoStatus);
    }

    /**
     * Formatted service date
     */
    get formattedServiceDate() {
        if (!this.highlightData.serviceDate) return '--';

        try {
            const date = new Date(this.highlightData.serviceDate);
            return date.toLocaleDateString();
        } catch (error) {
            return '--';
        }
    }

    /**
     * Customer info summary (PO/Profile/PSI)
     */
    get customerInfoSummary() {
        const parts = [];

        if (this.highlightData.purchaseOrderNumber && this.highlightData.purchaseOrderNumber !== '--') {
            parts.push('PO: ' + this.highlightData.purchaseOrderNumber);
        }

        if (this.highlightData.profileNumber && this.highlightData.profileNumber !== '--') {
            parts.push('Profile: ' + this.highlightData.profileNumber);
        }

        if (this.highlightData.psi != null) {
            parts.push('PSI: ' + this.highlightData.psi);
        }

        return parts.length > 0 ? parts.join(', ') : '--';
    }

    // ========================================
    // Event Handlers
    // ========================================

    /**
     * Handle field click for editing
     */
    handleFieldClick(event) {
        const fieldName = event.currentTarget.dataset.field;

        if (!fieldName) return;

        // Dispatch event to parent for field editing
        this.dispatchEvent(new CustomEvent('fieldedit', {
            detail: {
                field: fieldName,
                caseId: this.caseId
            }
        }));
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load case highlight data
     */
    loadHighlightData() {
        if (!this.caseId) return;

        this.isLoading = true;

        getCaseHighlightData({ caseId: this.caseId })
            .then(result => {
                this.highlightData = result;
            })
            .catch(error => {
                console.error('Failed to load highlight data:', error);
                this.error = error;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ========================================
    // Private Methods - Utilities
    // ========================================

    /**
     * Get field CSS class based on status
     */
    getFieldClass(status) {
        const baseClass = 'highlight-field';

        if (status === 'complete') {
            return baseClass + ' highlight-field_complete';
        } else if (status === 'warning') {
            return baseClass + ' highlight-field_warning';
        } else if (status === 'missing') {
            return baseClass + ' highlight-field_missing';
        } else {
            return baseClass + ' highlight-field_info';
        }
    }

    // ========================================
    // Public API Methods
    // ========================================

    /**
     * Refresh highlight data
     */
    @api
    refreshHighlight() {
        this.loadHighlightData();
    }

    /**
     * Get highlight data
     */
    @api
    getHighlightData() {
        return this.highlightData;
    }
}

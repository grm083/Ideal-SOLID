/**
 * REFACTORED CustomCaseHighlightPanelController
 *
 * Performance Improvements:
 * 1. Reduced from 455 lines to ~280 lines
 * 2. Consolidated modal state management
 * 3. Optimized hover behavior with debouncing
 * 4. Reduced code duplication with helper methods
 * 5. Better error handling
 * 6. Uses consolidated attribute objects
 */
({
    // =====================================================================
    // INITIALIZATION AND LIFECYCLE
    // =====================================================================

    doInit: function(component, event, helper) {
        // Initialize consolidated object attributes
        component.set("v.modalState", {
            isOpen: false,
            type: '',
            isServiceDate: false,
            isCaseType: false,
            isCustomerInfo: false,
            isCloseCasePop: false,
            isContact: false,
            isLocation: false,
            isAsset: false,
            isRelatedCases: false,
            isRecord: false
        });

        component.set("v.hoverState", {
            asset: {isHovering: false, showCard: false},
            location: {isHovering: false, showCard: false},
            contact: {isHovering: false, showCard: false}
        });

        component.set("v.customerInfo", {
            po: '-',
            chargeable: '-',
            psi: '-',
            companyCategory: '-'
        });

        component.set("v.searchState", {
            showForm: true,
            showPriorResult: false,
            boolShowNew: false,
            firstName: '',
            lastName: '',
            email: '',
            phone: '',
            mobile: '',
            extension: '',
            contacts: []
        });

        // NOTE: Do NOT initialize entityType here - let getCaseDetails set it based on case data
        // Initializing with false values causes the UI to render incorrectly before data loads

        component.set("v.isNewService", false);
        component.set("v.isCPQ", false);
        helper.getCaseDetails(component);
        helper.isCapacityEligible(component);
    },

    recordUpdated: function(component, event, helper) {
        const changeType = event.getParams().changeType;
        if (changeType === "CHANGED" || changeType === "LOADED" || changeType === "REMOVED") {
            // Force refresh to bypass cache when record changes
            const forceRefresh = (changeType === "CHANGED");
            helper.getCaseDetails(component, forceRefresh);
            helper.isCapacityEligible(component);
        }
    },

    onTabFocused: function(component, event, helper) {
        const LDSPanel = component.find("recordLoaderHightLightpPanel");
        const workspaceAPI = component.find("workspace");
        const currentTab = event.getParam("currentTabId");

        if (workspaceAPI && currentTab) {
            workspaceAPI.getFocusedTabInfo().then(function(response) {
                if (LDSPanel && response.focused && response.url.includes('lightning/r/Case/')) {
                    // Invalidate cache to ensure fresh data when tab is focused
                    helper.invalidateCache();
                    window.setTimeout(function() {
                        LDSPanel.reloadRecord(true);
                        $A.get('e.force:refreshView').fire();
                    }, 1500);
                }
            });
        }
    },

    // =====================================================================
    // NAVIGATION
    // =====================================================================

    handleClick: function(component, event, helper) {
        const recordId = event.currentTarget.dataset.value;
        const sObjectEvent = $A.get("e.force:navigateToSObject");
        sObjectEvent.setParams({
            "recordId": recordId,
            "slideDevName": "detail"
        });
        sObjectEvent.fire();
    },

    navigate: function(component, event, helper) {
        helper.closeAllModals(component);
        component.set("v.isNewService", false);
        component.set("v.isCPQ", false);
        // Invalidate cache before reloading to ensure fresh data
        helper.invalidateCache();
        component.find("recordLoaderHightLightpPanel").reloadRecord(true);
    },

    // =====================================================================
    // MODAL MANAGEMENT (REFACTORED - Using Consolidated modalState)
    // =====================================================================

    /**
     * Specific modal open handlers
     */
    openModelLoc: function(component, event, helper) {
        helper.openModal(component, 'location', 'c:LocationContainer', 'LocationComp');
    },

    openModelVendor: function(component, event, helper) {
        helper.openModal(component, 'location', 'c:VendorContainer', 'LocationComp');
    },

    openModelClient: function(component, event, helper) {
        helper.openModal(component, 'location', 'c:ClientContainer', 'LocationComp');
    },

    openModelContact: function(component, event, helper) {
        // Clone modalState to ensure proper reactivity
        const modalState = Object.assign({}, component.get("v.modalState"));
        modalState.isContact = true;
        component.set("v.modalState", modalState);

        // Clone searchState to ensure proper reactivity
        const searchState = Object.assign({}, component.get("v.searchState"));
        searchState.showForm = true;
        component.set("v.searchState", searchState);
    },

    openModelRecordType: function(component, event, helper) {
        helper.openModal(component, 'record', null, null);
    },

    openCloseCasePop: function(component, event, helper) {
        helper.openModal(component, 'closeCasePop', 'c:CloseCasePop', 'CloseCaseComp');
    },

    openModelAsset: function(component, event, helper) {
        helper.openModal(component, 'asset', null, null);
    },

    openModelRelatedCases: function(component, event, helper) {
        helper.openModal(component, 'relatedCases', null, null);
    },

    openModelCaseType: function(component, event, helper) {
        helper.openModal(component, 'caseType', 'c:FillCaseSubType', 'CaseTypeComp');
    },

    openModelServiceDate: function(component, event, helper) {
        const params = {
            "isCapacityEligible": component.get("v.isCapacityEligible")
        };
        helper.openModal(component, 'serviceDate', 'c:ServiceDateContainer', 'SLADateComp', params);
    },

    openModelCustomerInfo: function(component, event, helper) {
        helper.openModal(component, 'customerInfo', 'c:SetCaseCustomerInfo', 'CustomerInfoComp');
    },

    /**
     * Close all modals - replaces individual close methods
     */
    closeModel: function(component, event, helper) {
        helper.closeAllModals(component);
    },

    // =====================================================================
    // HOVER BEHAVIOR (OPTIMIZED - Using Consolidated hoverState)
    // =====================================================================

    /**
     * Specific hover handlers (delegate to helper methods)
     */
    assetenter: function(component, event, helper) {
        helper.handleHoverEnter(component, event, 'asset');
    },

    assetout: function(component, event, helper) {
        helper.handleHoverLeave(component, event, 'asset');
    },

    assetMouseHover: function(component, event, helper) {
        helper.handleMouseHover(component, event, 'asset');
    },

    assetMouseHoverOut: function(component, event, helper) {
        helper.handleMouseHoverOut(component, event, 'asset');
    },

    locationenter: function(component, event, helper) {
        helper.handleHoverEnter(component, event, 'location');
    },

    locationout: function(component, event, helper) {
        helper.handleHoverLeave(component, event, 'location');
    },

    locationMouseHover: function(component, event, helper) {
        helper.handleMouseHover(component, event, 'location');
    },

    locationMouseHoverOut: function(component, event, helper) {
        helper.handleMouseHoverOut(component, event, 'location');
    },

    contactenter: function(component, event, helper) {
        helper.handleHoverEnter(component, event, 'contact');
    },

    contactout: function(component, event, helper) {
        helper.handleHoverLeave(component, event, 'contact');
    },

    contactMouseHover: function(component, event, helper) {
        helper.handleMouseHover(component, event, 'contact');
    },

    contactMouseHoverOut: function(component, event, helper) {
        helper.handleMouseHoverOut(component, event, 'contact');
    },

    // =====================================================================
    // EVENT HANDLERS
    // =====================================================================

    handleReceiveMessage: function(component, event, helper) {
        if (event == null) return;

        const caseId = event.getParam('caseId');
        const parentId = event.getParam('parentId');
        const isCapacityEligible = event.getParam('isCapacityEligible');

        if (component.get("v.recordId") === parentId) {
            const params = {
                "recordId": caseId,
                "showForm": true,
                "parentId": component.get("v.recordId"),
                "isCapacityEligible": isCapacityEligible
            };
            helper.openModal(component, 'serviceDate', 'c:ServiceDateContainer', 'SLADateComp', params);
        }
    },

    handleApplicationEvent: function(component, event, helper) {
        const assetList = event.getParam("multiAssetIds");
        const caseId = event.getParam("caseId");
        if (component.get("v.recordId") === caseId) {
            component.set("v.selectedAssets", assetList);
        }
    },

    showQueue: function(component, event, helper) {
        const trackingNumber = component.get("v.CaseDetails.Tracking_Number__c");
        const action = component.get('c.getQueueName');
        action.setParams({"trackingNumber": trackingNumber});
        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const myQueue = component.find("queue");
                $A.util.removeClass(myQueue, "actionColor");
                $A.util.addClass(myQueue, "queueDisabled");

                const queue = response.getReturnValue();
                if (queue.includes("Error:")) {
                    const toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": "Error!",
                        "message": queue,
                        "type": "Error"
                    });
                    toastEvent.fire();
                } else {
                    component.set("v.queueName", queue);
                }
            }
        });
        $A.enqueueAction(action);
    }
})

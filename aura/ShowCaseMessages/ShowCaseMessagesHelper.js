/**
 * ShowCaseMessages Helper - Refactored
 *
 * SOLID Principles Applied:
 * 1. Single Responsibility - Each method has one clear purpose
 * 2. Open/Closed - Extensible without modifying existing code
 * 3. Interface Segregation - Clean method signatures
 * 4. Dependency Inversion - Decoupled logic
 *
 * Refactoring Improvements:
 * - Consolidated state objects (displayState, modalState, buttonState, stateFlags)
 * - Extracted business logic into focused methods
 * - Improved code organization and readability
 * - Better error handling and logging
 * - Enhanced maintainability and testability
 */
({
    // ========================================================================
    // UTILITY METHODS FOR STATE MANAGEMENT
    // ========================================================================

    /**
     * Update button state - centralizes button state updates
     */
    _updateButtonState: function(component, updates) {
        const buttonState = component.get('v.buttonState');
        Object.assign(buttonState, updates);
        component.set('v.buttonState', buttonState);
    },

    /**
     * Update display state - centralizes display state updates
     */
    _updateDisplayState: function(component, updates) {
        const displayState = component.get('v.displayState');
        Object.assign(displayState, updates);
        component.set('v.displayState', displayState);
    },

    /**
     * Update state flags - centralizes state flag updates
     */
    _updateStateFlags: function(component, updates) {
        const stateFlags = component.get('v.stateFlags');
        Object.assign(stateFlags, updates);
        component.set('v.stateFlags', stateFlags);
    },

    /**
     * Update modal state - centralizes modal state updates
     */
    _updateModalState: function(component, updates) {
        const modalState = component.get('v.modalState');
        Object.assign(modalState, updates);
        component.set('v.modalState', modalState);
    },

    // ========================================================================
    // MESSAGE PROCESSING METHODS
    // ========================================================================

    /**
     * Process wrapper messages and update component state
     */
    _processWrapperMessages: function(component, wrapper) {
        // Handle NTE messages
        if (wrapper.caseInfo && wrapper.caseInfo.includes('NTE Approval Needed')) {
            this._updateDisplayState(component, { showMsgNTE: true });
        }

        // Handle Create New Service message (SDT-42650)
        if (wrapper.caseInfo && wrapper.caseInfo.includes('Create a New Service Open Top request')) {
            component.set('v.CaseMsg', wrapper.caseInfo);
            component.set('v.viewCaseRed', true);
        }

        // Handle required info
        if (wrapper.reqInfo && wrapper.reqInfo.includes('PSI is Required.Provide valid PSI or Bypass reason')) {
            this._updateStateFlags(component, { psiReq: false });
        }

        // Handle multi-case visibility
        this._updateStateFlags(component, {
            isMultiCheckedVisible: !wrapper.disableMultiCase
        });

        // Handle assign case button
        this._updateButtonState(component, {
            isShowAssignCase: wrapper.CaseStatus === 'Open'
        });

        // Handle multiple case label
        this._updateDisplayState(component, {
            showMultipleCaseLabel: wrapper.CaseSubType !== 'Empty and Do NOT Return'
        });
    },

    /**
     * Handle required information messages
     */
    _handleRequiredInfo: function(component, wrapper) {
        if (wrapper.reqInfo && wrapper.reqInfo !== "undefined" && wrapper.reqInfo !== null && wrapper.reqInfo !== "") {
            component.set('v.reqInfo', wrapper.reqInfo);
            this._updateDisplayState(component, {
                reqInfoMsg: true,
                displaySummary: false
            });
            this._updateButtonState(component, { caseServiceDateBtn: true });
        } else {
            this._updateDisplayState(component, { reqInfoMsg: false });
        }
    },

    /**
     * Handle approval information messages
     */
    _handleApprovalInfo: function(component, wrapper) {
        if (wrapper.approvalInfo && wrapper.approvalInfo !== "undefined" && wrapper.approvalInfo !== null && wrapper.approvalInfo !== "") {
            component.set('v.approvalInfo', wrapper.approvalInfo);

            if (wrapper.occurrenceLimit && wrapper.occurrenceLimit !== "undefined" && wrapper.occurrenceLimit !== null && wrapper.occurrenceLimit !== "" && wrapper.occurrenceLimit !== 0) {
                component.set('v.occurrenceLimit', wrapper.occurrenceLimit);
                this._updateDisplayState(component, { displayOccurrence: true });
            }

            this._updateDisplayState(component, { approvalInfoMsg: true });
        } else if (wrapper.enableapprovalInfo) {
            component.set('v.approvalInfo', 'Case will be auto Approved');
            this._updateDisplayState(component, { approvalInfoMsg: true });
        } else {
            this._updateDisplayState(component, { approvalInfoMsg: false });
        }
    },

    // ========================================================================
    // QUOTE AND CPQ LOGIC
    // ========================================================================

    /**
     * Handle quote visibility and CPQ eligibility
     */
    _handleQuoteLogic: function(component, wrapper) {
        const displayState = component.get('v.displayState');
        const caseRecordTypeList = wrapper.caseRecordTypeList || [];

        // Check if add quote should be visible based on backend logic
        if (wrapper.addQuoteVisibility) {
            this._updateButtonState(component, {
                isAddQuote: true,
                disableAddQuote: false
            });

            // CPQ validation for New cases with Assets
            if (wrapper.CaseStatus === 'New' && wrapper.caseData && wrapper.caseData.AssetId) {
                this._launchCPQValidation(component);
            }
        } else {
            this._updateButtonState(component, { isAddQuote: false });
        }

        // Handle progress case visibility based on backend logic
        if (wrapper.progressCaseVisibility) {
            this._updateButtonState(component, { isShowProgressCase: true });
        } else {
            this._updateButtonState(component, { isShowProgressCase: false });
        }
    },

    /**
     * Launch CPQ validation flow
     */
    _launchCPQValidation: function(component) {
        const getValidationFlow = component.get('c.launchCPQQuoteValidation');
        getValidationFlow.setParams({ 'CaseId': component.get('v.recordId') });

        getValidationFlow.setCallback(this, function(response) {
            if (response.getState() === 'SUCCESS') {
                const returnVal = response.getReturnValue();
                if (returnVal) {
                    const caseMessage = "Your case is eligible to be worked in CPQ!  Please use the 'Add Quote' button to configure the customer's requested change.";
                    component.set('v.CaseMsg', caseMessage);
                } else {
                    const caseMessage = "Your case is not eligible to be worked in CPQ.  Please utilize tasking functionality to engage the setup teams.";
                    this._updateButtonState(component, { disableAddQuote: true });
                    component.set('v.CaseMsg', caseMessage);
                }
            }
        });
        $A.enqueueAction(getValidationFlow);
    },

    /**
     * Handle opportunity (quote) logic
     */
    _handleOpportunityLogic: function(component, wrapper) {
        // Check if opportunity exists (SDT-41473, SDT-41538, SDT-41540)
        if (wrapper.isOpportunityCreated && wrapper.IsHaulAwayService) {
            this._updateButtonState(component, { isOpportunityAdded: true });
        }

        // Additional opportunity checks for other record types
        if (wrapper.Is_UserHaveCPQLicence === true &&
            wrapper.Is_UpdateAssetActiveUser === true &&
            wrapper.assetId && wrapper.assetId !== '' &&
            wrapper.CPQProduct && wrapper.CPQProduct !== '') {

            if (wrapper.CaseType && wrapper.CaseSubType &&
                wrapper.caseData && wrapper.caseData.ContactId &&
                wrapper.caseInfo && wrapper.caseInfo !== '' &&
                wrapper.caseInfo !== 'undefined' && wrapper.caseInfo !== null) {

                if (wrapper.isOpportunityCreated) {
                    this._updateButtonState(component, { isOpportunityAdded: true });
                }
            }
        }

        // Handle Modify Existing Service Case with opportunity
        if (wrapper.CaseType !== 'Cancellation' &&
            wrapper.CaseType !== 'Change Vendor' &&
            wrapper.caseRecordType === 'Modify Existing Service Case' &&
            wrapper.Is_UserHaveCPQLicence === true &&
            wrapper.Is_UpdateAssetActiveUser === true &&
            wrapper.assetId && wrapper.assetId !== '') {

            if (wrapper.CaseType && wrapper.caseData && wrapper.caseData.ContactId) {
                if (wrapper.isOpportunityCreated) {
                    this._updateButtonState(component, { isOpportunityAdded: true });
                } else if (wrapper.CaseStatus !== 'Closed') {
                    // Handle quote visibility based on addQuoteVisibility flag (SDT-31503)
                    if (wrapper.addQuoteVisibility) {
                        this._updateDisplayState(component, { actionReqRed: false });
                        component.set('v.CaseMsg', '');
                    } else {
                        this._updateDisplayState(component, { actionReqRed: true });
                        component.set('v.CaseMsg', wrapper.caseInfo);
                    }

                    // Handle progress case visibility (SDT-32426)
                    if (wrapper.progressCaseVisibility) {
                        this._updateDisplayState(component, { displayMsg: true });
                    } else {
                        this._updateDisplayState(component, { displayMsg: false });
                    }
                }
            }
        } else if (wrapper.caseRecordType === 'Modify Existing Service Case' &&
                   (wrapper.CaseType === 'Cancellation' || wrapper.CaseType === 'Change Vendor')) {
            // Handle Cancellation and Change Vendor cases
            this._updateDisplayState(component, { displayMsg: true });
            this._updateButtonState(component, { isAddCaseAsset: true });

            if (wrapper.assetId && wrapper.assetId !== '' &&
                wrapper.caseData && wrapper.caseData.ContactId &&
                wrapper.isManualCaseAsset) {

                if (wrapper.CaseStatus === "New") {
                    this._updateDisplayState(component, { displaySummary: true });
                    this._updateButtonState(component, { isAddCaseAsset: false });

                    // Handle Change Vendor with CPQ (SDT-32822)
                    if (wrapper.CaseType === 'Change Vendor' && wrapper.Is_UserHaveCPQLicence === true) {
                        if (wrapper.addQuoteVisibility) {
                            this._updateDisplayState(component, { actionReqRed: false });
                            component.set('v.CaseMsg', '');
                        } else {
                            this._updateDisplayState(component, { actionReqRed: true });
                            component.set('v.CaseMsg', wrapper.caseInfo);
                        }
                    }
                } else {
                    this._updateDisplayState(component, { displaySummary: false });
                    this._updateButtonState(component, { isAddCaseAsset: false });
                }
            }
        }
    },

    /**
     * Handle New Service case logic
     */
    _handleNewServiceCase: function(component, wrapper) {
        if (wrapper.CaseType !== "New Service") {
            return;
        }

        this._updateButtonState(component, { isOpportunityAdded: false });

        if (wrapper.Is_UserHaveCPQLicence === true) {
            if (wrapper.Is_UserHaveCPQLicence === true &&
                wrapper.CaseReason && wrapper.CaseReason !== '' &&
                wrapper.caseData && wrapper.caseData.ContactId) {

                if (wrapper.isOpportunityCreated) {
                    this._updateButtonState(component, { isOpportunityAdded: true });
                }
            }

            this._updateDisplayState(component, {
                displayMsg: false,
                actionReqRed: false,
                displaySummary: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
            component.set('v.CaseMsg', wrapper.caseInfo || '');

            // Show required info message
            this._handleRequiredInfo(component, wrapper);
        } else {
            // No CPQ license
            this._updateDisplayState(component, {
                displayMsg: false,
                actionReqRed: false,
                displaySummary: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
            component.set('v.CaseMsg', wrapper.caseInfo || '');
        }
    },

    // ========================================================================
    // CASE TYPE SPECIFIC LOGIC
    // ========================================================================

    /**
     * Handle Non-Pickup case logic
     */
    _handleNonPickupCase: function(component, wrapper, sMsg) {
        const errNoCaseAsset = 'No Asset Details have been added to the Case, To continue, create a new case to have components added.';
        const errAssetPst = "The asset has ended for this service date. Please select the service date in the past to continue with the case";

        // Check if this is a non-pickup case type
        if (wrapper.CaseType === "Pickup" || wrapper.CaseType === "New Service") {
            return;
        }

        // Case 1: Case info exists and case is not ready
        if (sMsg && sMsg !== "undefined" && sMsg !== null && sMsg !== "" &&
            sMsg !== errAssetPst &&
            (wrapper.CaseStatus === "New" && !sMsg.includes("Ready") && wrapper.isCaseInfoReady ||
             wrapper.CaseStatus === "Open" && !sMsg.includes("Progress Case"))) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: true,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
            component.set('v.CaseMsg', sMsg);

            // Check if work order creation is allowed without asset
            if (wrapper.WorkOrderCreation && !wrapper.isAssetMandatory &&
                wrapper.caseData && wrapper.caseData.ContactId !== null) {
                this._updateDisplayState(component, { actionReqRed: false });
            }
        }
        // Case 2: No case asset error
        else if (wrapper.CaseStatus === "New" && sMsg &&
                 (sMsg === errNoCaseAsset || sMsg === errAssetPst) &&
                 wrapper.WorkOrderCreation && !wrapper.isManualCaseAsset) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: true,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            component.set('v.CaseMsg', sMsg);

            if (sMsg === errNoCaseAsset) {
                this._updateButtonState(component, { isAddCaseAsset: true });
            } else {
                this._updateButtonState(component, { isAddCaseAsset: false });
            }

            // Asset past end date error (SDT-13757)
            if (sMsg === errAssetPst) {
                this._updateButtonState(component, {
                    isShowProgressCase: true,
                    isAddCaseAsset: false
                });
            } else {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        }
        // Case 3: No case asset error without work order creation
        else if (wrapper.CaseStatus === "New" && sMsg &&
                 sMsg === errNoCaseAsset && !wrapper.WorkOrderCreation) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: true,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
            component.set('v.CaseMsg', sMsg);
        }
        // Case 4: Case is ready without manual case asset
        else if (wrapper.CaseStatus === "New" && sMsg &&
                 ((sMsg.includes("Ready") || !wrapper.isCaseInfoReady) &&
                  wrapper.WorkOrderCreation && !wrapper.isManualCaseAsset)) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });

            // Handle Service Request Case messaging (SDT-31503, moved here as part of SDT-32766)
            if (wrapper.caseRecordType === 'Service Request Case' &&
                wrapper.addQuoteVisibility &&
                wrapper.Is_UserHaveCPQLicence === true) {
                this._updateDisplayState(component, { actionReqRed: true });
                component.set('v.CaseMsg', wrapper.caseInfo);
            } else {
                component.set('v.CaseMsg', ' Read the Authorization Notes ');
            }

            // Duplicate check for single asset case
            const caseRecord = component.get("v.caseRecord");
            const singleAssetDupCheck = component.get('v.stateFlags.singleAssetDupCheck');

            if (caseRecord && caseRecord.Location__c && caseRecord.AssetId &&
                caseRecord.Service_Date__c && caseRecord.Case_Type__c !== 'Pickup' &&
                caseRecord.Case_Sub_Type__c && !caseRecord.Ignore_Duplicate__c &&
                !caseRecord.Is_Clone__c && !singleAssetDupCheck) {
                this.duplicateCheckInvocation(component, false);
            }

            if (caseRecord && caseRecord.AssetId && sMsg !== errAssetPst) {
                this._updateButtonState(component, { isAddCaseAsset: true });
            }
        }
        // Case 5: Case is ready with manual case asset
        else if (wrapper.CaseStatus === "New" && sMsg &&
                 (sMsg.includes("Ready") || !wrapper.isCaseInfoReady) &&
                 wrapper.WorkOrderCreation && wrapper.isManualCaseAsset) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: true,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });

            // Handle Service Request Case messaging (SDT-31503)
            if (wrapper.caseRecordType === 'Service Request Case' &&
                wrapper.addQuoteVisibility &&
                wrapper.Is_UserHaveCPQLicence === true) {
                this._updateDisplayState(component, { actionReqRed: true });
                component.set('v.CaseMsg', wrapper.caseInfo);
            } else {
                component.set('v.CaseMsg', ' Read the Authorization Notes ');
            }
        }
        // Case 6: Case is ready without work order creation
        else if (wrapper.CaseStatus === "New" && sMsg &&
                 (sMsg.includes("Ready") || !wrapper.isCaseInfoReady) &&
                 !wrapper.WorkOrderCreation) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
            component.set('v.CaseMsg', '');
        }
        // Case 7: Open case with work order created message
        else if (wrapper.CaseStatus === "Open" && sMsg &&
                 sMsg.includes("* Workorder has been Created\n")) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, {
                isShowProgressCase: true,
                isAddCaseAsset: false
            });
            component.set('v.CaseMsg', sMsg);
        }
        // Case 8: Open case without work order creation
        else if (wrapper.CaseStatus === "Open" && !wrapper.WorkOrderCreation) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
        }
        // Case 9: Open case with work order creation, no manual asset
        else if (wrapper.CaseStatus === "Open" && wrapper.WorkOrderCreation &&
                 !wrapper.isManualCaseAsset) {

            const caseRecord = component.get("v.caseRecord");

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });

            if (caseRecord && caseRecord.AssetId && sMsg !== errAssetPst) {
                this._updateButtonState(component, { isAddCaseAsset: true });
            }

            if (sMsg && sMsg === 'Select the appropriate asset header to Progress Case') {
                component.set('v.CaseMsg', sMsg);
                this._updateDisplayState(component, { actionReqRed: true });
            } else {
                component.set('v.CaseMsg', ' Read the Authorization Notes ');
            }
        }
        // Case 10: Open case with work order creation and manual asset
        else if (wrapper.CaseStatus === "Open" && wrapper.WorkOrderCreation &&
                 wrapper.isManualCaseAsset) {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: true,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
            component.set('v.CaseMsg', ' Read the Authorization Notes ');

            if (wrapper.caseData && wrapper.caseData.Case_Sub_Status__c &&
                wrapper.caseData.Case_Sub_Status__c !== "undefined" &&
                wrapper.caseData.Case_Sub_Status__c !== null &&
                wrapper.caseData.Case_Sub_Status__c !== "") {
                this._updateDisplayState(component, { displaySummary: false });
            }
        }
        // Case 11: Closed case
        else if (wrapper.CaseStatus === "Closed") {

            this._updateDisplayState(component, {
                displayMsg: true,
                actionReqRed: false,
                displaySummary: false,
                showMultipleCaseLabel: false,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, { isAddCaseAsset: false });
            component.set('v.CaseMsg', sMsg || '');
        }
    },

    /**
     * Handle Pickup case logic
     */
    _handlePickupCase: function(component, wrapper, sMsg) {
        if (wrapper.CaseType !== "Pickup") {
            return;
        }

        const assetCode = ["Utility", "UTL", "CAM"];
        const caseRecord = component.get("v.caseRecord");
        const stateFlags = component.get('v.stateFlags');

        // Case is Ready
        if (sMsg && sMsg !== "undefined" && sMsg !== null && sMsg !== "" && sMsg.includes("Ready")) {

            // Check if this is a multi-asset case
            if (caseRecord && caseRecord.Is_Multiple_Asset__c &&
                !caseRecord.Show_Multiple_Asset_Cases__c &&
                !caseRecord.isMultiCalendarChecked__c) {

                component.set('v.CaseMsg', "Complete the intake of related cases(if any) from the parent case");
                this._updateDisplayState(component, {
                    displaySummary: false,
                    displayMsg: true,
                    showOnRelatedMultiAssetCase: true
                });
            } else {
                component.set('v.CaseMsg', '');
                this._updateDisplayState(component, {
                    displaySummary: true,
                    displayMsg: true,
                    actionReqRed: false,
                    showMultipleCaseLabel: true
                });

                // Set button label based on capacity eligibility
                if (!stateFlags.isCapacityEligible) {
                    component.find("disablebuttonid").set("v.label", 'View Case Summary');
                }

                // Duplicate check for single asset
                if (caseRecord && caseRecord.Location__c && caseRecord.AssetId &&
                    caseRecord.Service_Date__c && caseRecord.Case_Type__c === 'Pickup' &&
                    caseRecord.Case_Sub_Type__c && !caseRecord.Ignore_Duplicate__c &&
                    !caseRecord.Is_Clone__c && !stateFlags.singleAssetDupCheck) {

                    this._updateStateFlags(component, { singleAssetDupCheck: true });
                    this.duplicateCheckInvocation(component, false);
                }
            }

            this._updateButtonState(component, {
                subTypeBtn: false,
                caseServiceDateBtn: true,
                isShowPOPSI: true
            });

            // Handle specific asset types and sub-types
            if (assetCode.indexOf(wrapper.assetSCode) > -1) {
                this._updateDisplayState(component, { showMultipleCaseLabel: false });
            } else if (wrapper.CaseSubType === "Bale(s)") {
                component.set('v.CaseMsg', '');
                this._updateDisplayState(component, {
                    displayMultipleAssetCases: false,
                    showMultipleCaseLabel: false,
                    displaySummary: false
                });
                this._updateButtonState(component, { caseServiceDateBtn: false });
            }
        }
        // Complete intake of related cases message
        else if (sMsg && sMsg.includes("Complete the intake of related cases(if any) from the parent case")) {

            if (caseRecord && caseRecord.Status === 'New') {
                this._updateDisplayState(component, {
                    displayMsg: true,
                    actionReqRed: false
                });

                this._updateButtonState(component, {
                    subTypeBtn: false,
                    caseServiceDateBtn: false,
                    isShowPOPSI: false
                });

                component.set('v.CaseMsg', sMsg);

                if (wrapper.reqInfo === "" && caseRecord.Location__c && caseRecord.AssetId &&
                    caseRecord.Service_Date__c && caseRecord.Case_Sub_Type__c) {
                    this._updateDisplayState(component, {
                        showMultipleCaseLabel: true,
                        showOnRelatedMultiAssetCase: true
                    });
                }
            }
        }
        // Workorder initiated or created
        else if (sMsg && (sMsg.includes("Workorder has been initiated. Please complete any open tasks if created.") ||
                         sMsg.includes("* Workorder has been Created\n"))) {

            component.set('v.CaseMsg', sMsg);
            this._updateDisplayState(component, {
                displaySummary: false,
                displayMsg: true
            });

            this._updateButtonState(component, {
                subTypeBtn: false,
                caseServiceDateBtn: false,
                isShowPOPSI: false
            });

            if (sMsg === '* Workorder has been Created\n') {
                this._updateDisplayState(component, { actionReqRed: false });
                this.getOpenTask(component, null);
            } else if (sMsg !== '* Workorder has been created. Please check Related Cases tab to complete intake' &&
                      sMsg !== '* Workorder has been Created\n') {
                this._updateDisplayState(component, { actionReqRed: true });
            }

            if (assetCode.indexOf(wrapper.assetSCode) > -1) {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        }
        // Check Related Cases tab messages
        else if (sMsg && (sMsg.includes("* Workorder has been created. Please check Related Cases tab to complete intake") ||
                         sMsg.includes("* Workorder has been initiated. Please check Related Cases tab to complete intake") ||
                         sMsg.includes("Complete the intake of related cases(if any) from the above list"))) {

            component.set('v.CaseMsg', sMsg);
            this._updateDisplayState(component, {
                displaySummary: false,
                displayMsg: true,
                displayMultipleAssetCases: false
            });

            this._updateButtonState(component, {
                subTypeBtn: false,
                caseServiceDateBtn: false,
                isShowPOPSI: false
            });

            if (sMsg !== '* Workorder has been created. Please check Related Cases tab to complete intake' &&
                sMsg !== '* Workorder has been Created\n') {
                this._updateDisplayState(component, { actionReqRed: true });
                component.set('v.ShowRelatedCases', true);
            }

            if (assetCode.indexOf(wrapper.assetSCode) > -1) {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        }
        // Create multiple cases message
        else if (sMsg && sMsg.includes("Create multiple cases for selected assets")) {

            component.set('v.CaseMsg', sMsg);
            this._updateDisplayState(component, {
                displayMsg: true,
                displaySummary: false,
                displayMultipleAssetCases: true,
                actionReqRed: true
            });

            this._updateButtonState(component, {
                subTypeBtn: false,
                caseServiceDateBtn: true
            });

            if (assetCode.indexOf(wrapper.assetSCode) > -1) {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        }
        // Select Case Subtype message
        else if (sMsg && sMsg.includes("Select Case Subtype to Progress Case ")) {

            component.set('v.CaseMsg', sMsg);
            this._updateDisplayState(component, {
                displayMsg: true,
                displaySummary: false,
                actionReqRed: true
            });

            this._updateButtonState(component, {
                subTypeBtn: true,
                caseServiceDateBtn: false
            });

            component.set('v.ShowRelatedCases', true);

            if (assetCode.indexOf(wrapper.assetSCode) > -1) {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        }
        // Progress Case message
        else if (sMsg && sMsg === "Progress Case") {

            this._updateDisplayState(component, {
                displayMsg: true,
                displayMultipleAssetCases: false,
                displaySummary: false
            });

            this._updateButtonState(component, {
                caseServiceDateBtn: false,
                isShowProgressCase: true,
                isShowPOPSI: false
            });

            this._updateDisplayState(component, { showMultipleCaseLabel: false });
        }
        // Other messages
        else if (sMsg && sMsg !== "undefined" && sMsg !== null && sMsg !== "") {

            component.set('v.CaseMsg', sMsg);
            this._updateDisplayState(component, {
                displayMsg: true,
                displaySummary: false
            });

            this._updateButtonState(component, { subTypeBtn: false });

            if (sMsg.includes('Provide SLA Service Date/Time to Progress Case ') ||
                sMsg.includes('The Asset details have already passed the end date')) {
                this._updateButtonState(component, { caseServiceDateBtn: true });
            } else {
                this._updateButtonState(component, { caseServiceDateBtn: false });
            }

            if (sMsg !== '* Workorder has been created. Please check Related Cases tab to complete intake' &&
                sMsg !== '* Workorder has been Created\n') {
                this._updateDisplayState(component, { actionReqRed: true });
                component.set('v.ShowRelatedCases', true);
            }

            if (assetCode.indexOf(wrapper.assetSCode) > -1) {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        }
        // No message
        else {
            this._updateDisplayState(component, {
                displayMsg: false,
                displaySummary: false
            });

            this._updateButtonState(component, {
                subTypeBtn: false,
                caseServiceDateBtn: true,
                isShowPOPSI: true
            });

            if (assetCode.indexOf(wrapper.assetSCode) > -1) {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        }

        // Handle required info for pickup cases
        const assetCodeForReqInfo = ["Utility", "UTL", "CAM"];
        if (wrapper.reqInfo && wrapper.reqInfo !== "undefined" && wrapper.reqInfo !== null && wrapper.reqInfo !== "" &&
            (wrapper.caseInfo === '' || wrapper.caseInfo === 'Ready' || wrapper.caseInfo === 'Multi Asset')) {

            component.set('v.reqInfo', wrapper.reqInfo);
            this._updateDisplayState(component, {
                reqInfoMsg: true,
                displaySummary: false
            });

            this._updateButtonState(component, { caseServiceDateBtn: true });

            if (assetCodeForReqInfo.indexOf(wrapper.assetSCode) > -1) {
                this._updateButtonState(component, { isShowProgressCase: false });
            }
        } else {
            this._updateDisplayState(component, { reqInfoMsg: false });
        }

        // Handle approval info
        this._handleApprovalInfo(component, wrapper);
    },

    // ========================================================================
    // MAIN getCaseMsg METHOD
    // ========================================================================

    /**
     * Main method to get case messages and update UI state
     */
    getCaseMsg: function(component, selfFlag, helper) {
        const cId = component.get("v.recordId");
        const action = component.get('c.getCaseMessages');

        action.setParams({ "caseId": cId });

        action.setCallback(this, function(response) {
            const state = response.getState();

            if (state === "SUCCESS") {
                const wrapper = response.getReturnValue();

                if (!wrapper) {
                    console.warn('No wrapper data returned from getCaseMessages');
                    return;
                }

                // DEBUG: Log wrapper to see what's being returned
                console.log('getCaseMessages wrapper:', JSON.stringify(wrapper, null, 2));
                console.log('addQuoteVisibility:', wrapper.addQuoteVisibility);
                console.log('progressCaseVisibility:', wrapper.progressCaseVisibility);
                console.log('caseInfo:', wrapper.caseInfo);
                console.log('CaseStatus:', wrapper.CaseStatus);
                console.log('CaseType:', wrapper.CaseType);

                // Set multi-asset selections
                component.set("v.multiAssetSelections", wrapper.multiAssetSelections);

                // Handle related case list
                if (wrapper.relatedCaseList && wrapper.relatedCaseList.length > 1 && !selfFlag) {
                    let relatedIdList = '';
                    wrapper.relatedCaseList.forEach(function(res) {
                        relatedIdList += res.Id + '|';
                    });

                    const relatedCaseEvt = $A.get("e.c:RelatedCaseListener");
                    relatedCaseEvt.setParams({
                        "triggeringCase": component.get("v.recordId"),
                        "relatedCases": relatedIdList
                    });
                    relatedCaseEvt.fire();
                }

                // Get case info message
                let sMsg = null;
                if (wrapper.caseInfo && wrapper.caseInfo !== "undefined" && wrapper.caseInfo !== null && wrapper.caseInfo !== "") {
                    sMsg = wrapper.caseInfo;
                }

                // Process wrapper messages
                this._processWrapperMessages(component, wrapper);

                // Handle quote logic
                this._handleQuoteLogic(component, wrapper);

                // Handle opportunity logic
                this._handleOpportunityLogic(component, wrapper);

                // Handle New Service cases
                this._handleNewServiceCase(component, wrapper);

                // Handle case type specific logic
                this._handleNonPickupCase(component, wrapper, sMsg);
                this._handlePickupCase(component, wrapper, sMsg);

                // DEBUG: Log final state
                console.log('Final buttonState:', component.get('v.buttonState'));
                console.log('Final displayState:', component.get('v.displayState'));
                console.log('Final CaseMsg:', component.get('v.CaseMsg'));

            } else {
                console.error('Error getting case messages:', response.getError());
            }
        });

        $A.enqueueAction(action);
    },

    // ========================================================================
    // CASE SUMMARY AND DETAILS
    // ========================================================================

    getCaseSummary: function(component, helper, btnValue) {
        const cId = component.get("v.recordId");
        const referenceNo = component.get("v.multiAssetCaseReferenceNo");
        const action = component.get('c.getCaseSummary');

        action.setParams({
            "caseId": cId,
            "referenceNo": referenceNo,
            "parentId": component.get("v.caseRecord").ParentId
        });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const data = response.getReturnValue();

                // Validate that we have case summary data
                if (!data || data.length === 0) {
                    console.warn('getCaseSummary: No case summary data returned');
                    // Close the modal since there's no data to display
                    this._updateModalState(component, { viewCaseSummary: false });

                    // Show a warning toast to the user
                    const toastEvent = $A.get("e.force:showToast");
                    if (toastEvent) {
                        toastEvent.setParams({
                            "title": "No Case Summary Available",
                            "message": "No cases found to display in the summary.",
                            "type": "warning"
                        });
                        toastEvent.fire();
                    }
                    return;
                }

                component.set('v.caseSummary', data);

                // Use setTimeout to ensure modal is rendered before accessing its elements
                window.setTimeout(
                    $A.getCallback(function() {
                        helper.populateCheckboxField(component);

                        // Enable work order button after modal is rendered
                        const workOrderButton = component.find("workOrderButton");
                        if (workOrderButton) {
                            workOrderButton.set("v.disabled", false);
                        }
                    }), 100
                );
            } else {
                console.error('Error getting case summary:', response.getError());
                // Close the modal on error
                this._updateModalState(component, { viewCaseSummary: false });

                // Show an error toast
                const toastEvent = $A.get("e.force:showToast");
                if (toastEvent) {
                    toastEvent.setParams({
                        "title": "Error",
                        "message": "Failed to load case summary. Please try again.",
                        "type": "error"
                    });
                    toastEvent.fire();
                }
            }
        });

        $A.enqueueAction(action);
    },

    getQAOverride: function(component, helper) {
        const caseId = component.get("v.recordId");
        const action = component.get('c.getCaseDetails');

        action.setParams({ "caseRecId": caseId });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const data = response.getReturnValue();
                component.set('v.caseRec', data);
            } else {
                console.error('Error getting case details:', response.getError());
            }
        });

        $A.enqueueAction(action);
    },

    getOpenTask: function(component, event) {
        const selectedCase = component.get("v.recordId");
        const action = component.get('c.getCopyCaseOpenTask');

        action.setParams({ "caseId": selectedCase });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const data = response.getReturnValue();
                if (data) {
                    component.set('v.CaseMsg', " Workorder has been created. Please check Related Cases tab to complete intake. ");
                } else {
                    component.set('v.CaseMsg', " Workorder has been Created.");
                }
            } else {
                console.error('Error getting open task:', response.getError());
            }
        });

        $A.enqueueAction(action);
    },

    // ========================================================================
    // WORK ORDER OPERATIONS
    // ========================================================================

    addWODetails: function(component, helper) {
        const selectedCaseList = component.get("v.selectedCases");
        const caseObjFields = component.get("v.CaseObj");
        const stateFlags = component.get('v.stateFlags');
        caseObjFields.Is_ByPassWO__c = stateFlags.isByPassWO; // SDT-18424

        const action = component.get('c.addWorkOrderDetails');

        action.setParams({
            "caseWoFields": caseObjFields,
            "caseIdList": selectedCaseList
        });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const data = response.getReturnValue();
                this._updateModalState(component, { WOInstructions: false });
                component.set("v.CaseObj", { 'sobjectType': 'Case' });

                if (data === 'Success') {
                    $A.get('e.force:refreshView').fire();
                }
            } else {
                console.error('Error adding WO details:', response.getError());
            }
        });

        $A.enqueueAction(action);
    },

    initiateWo: function(component, helper) {
        this._updateModalState(component, { viewCaseSummary: false });
        this._updateStateFlags(component, { loaded: true });

        const selectedCaseList = component.get("v.selectedCases");
        const selectedCase = component.get("v.recordId");
        const action = component.get('c.initiateWorkOrder');

        action.setParams({
            "caseId": selectedCase,
            "caseIdList": selectedCaseList
        });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const data = response.getReturnValue();
                if (data === 'Success') {
                    component.find("recordLoader").reloadRecord(true);

                    const label = component.find("disablebuttonid").get("v.label");
                    const workOrderButton = component.find("workOrderButton");
                    const initiatebtn = workOrderButton ? workOrderButton.get("v.disabled") : null;

                    this._updateModalState(component, { viewCaseSummary: false });
                    this._updateStateFlags(component, { loaded: false });

                    window.setTimeout(function() {
                        helper.refreshFocusedTab(component);
                        if (label === "View Multi Asset Case Summary" && !initiatebtn) {
                            const payload = { caseId: component.get("v.recordId") };
                            component.find("lmschannel").publish(payload);
                        }
                    }, 3000);
                }
            } else {
                console.error('Error initiating work order:', response.getError());
                this._updateStateFlags(component, { loaded: false });
            }
        });

        $A.enqueueAction(action);
    },

    updatedRelatedCases: function(component, helper) {
        this._updateStateFlags(component, { loaded: true });

        const cId = component.get("v.recordId");
        const action = component.get('c.updateRelatedCases');
        const multiAssetSelections = component.get("v.multiAssetSelections");

        action.setParams({
            "caseId": cId,
            "multiAssetSelections": multiAssetSelections
        });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const data = response.getReturnValue();
                this._updateDisplayState(component, { displayMultipleAssetCases: false });
                component.find("recordLoader").reloadRecord(true);
                this._updateStateFlags(component, { loaded: false });
                helper.getCaseMsg(component, false, helper);
            } else {
                console.error('Error updating related cases:', response.getError());
                this._updateStateFlags(component, { loaded: false });
            }
        });

        $A.enqueueAction(action);
    },

    // ========================================================================
    // UI HELPER METHODS
    // ========================================================================

    refreshFocusedTab: function(component) {
        const workspaceAPI = component.find("workspace");
        workspaceAPI.getFocusedTabInfo().then(function(response) {
            const focusedTabId = response.tabId;
            workspaceAPI.refreshTab({
                tabId: focusedTabId,
                includeAllSubtabs: true
            });
        })
        .catch(function(error) {
            console.error('Error refreshing focused tab:', error);
        });
    },

    navigateToCaseDetail: function(component, event, helper) {
        const sObjectEvent = $A.get("e.force:navigateToSObject");
        sObjectEvent.setParams({
            "recordId": event.currentTarget.dataset.id,
            "slideDevName": "detail"
        });
        sObjectEvent.fire();
    },

    populateCheckboxField: function(component) {
        let array = component.find("multiSelect");
        let selectedCase = [];
        let woUpdatesButton = component.find("woUpdates");

        // Guard: If caseSummary is empty or checkboxes don't exist, exit early
        let caseList = component.get("v.caseSummary");
        if (!caseList || caseList.length === 0) {
            console.warn('populateCheckboxField: No case summary data available');
            component.set('v.selectedCases', selectedCase);
            return;
        }

        // Guard: If multiSelect checkboxes don't exist, exit early
        if (!array) {
            console.warn('populateCheckboxField: multiSelect checkboxes not found in component');
            // Still populate selectedCase from caseList
            caseList.forEach(function(res) {
                selectedCase.push(res.Id);
            });
            component.set('v.selectedCases', selectedCase);
            return;
        }

        // Process checkboxes
        if (Array.isArray(array) && array.length > 1) {
            if (woUpdatesButton) {
                woUpdatesButton.set("v.disabled", true);
            }
            array.forEach(function(res) {
                res.set("v.value", true);
            });
        } else if (array) {
            array.set("v.value", true);
        }

        // Build selected case list
        if (caseList) {
            caseList.forEach(function(res) {
                selectedCase.push(res.Id);
            });
        }

        component.set('v.selectedCases', selectedCase);

        // Update woUpdates button state if it exists
        if (woUpdatesButton) {
            if (selectedCase.length === 1) {
                woUpdatesButton.set("v.disabled", false);
            } else {
                woUpdatesButton.set("v.disabled", true);
            }
        }
    },

    enableWorkorderButton: function(component) {
        let checkboxes = component.find("multiSelect");
        let chkflag = false;
        let count = 0;

        // Guard: If checkboxes don't exist, exit early
        if (!checkboxes) {
            console.warn('enableWorkorderButton: multiSelect checkboxes not found');
            return;
        }

        if (checkboxes.length !== undefined) {
            for (let i = 0; i < checkboxes.length; i++) {
                if (checkboxes[i].get("v.value") === true) {
                    chkflag = true;
                    count++;
                }
            }
        } else {
            checkboxes = [component.find("multiSelect")];
            if (checkboxes[0] && checkboxes[0].get("v.value") === true) {
                chkflag = true;
                count++;
            }
        }

        // Safely update button states
        const workOrderButton = component.find("workOrderButton");
        const workOrderButtonInst = component.find("workOrderButtonInst");
        const woUpdatesButton = component.find("woUpdates");

        if (workOrderButton) {
            workOrderButton.set("v.disabled", !chkflag);
        }
        if (workOrderButtonInst) {
            workOrderButtonInst.set("v.disabled", !chkflag);
        }

        if (woUpdatesButton) {
            if (count === 1) {
                woUpdatesButton.set("v.disabled", false);
            } else {
                woUpdatesButton.set("v.disabled", true);
            }
        }
    },

    // ========================================================================
    // DUPLICATE CHECK AND EMAIL TEMPLATE
    // ========================================================================

    duplicateCheckInvocation: function(component, flag) {
        const modalState = component.get('v.modalState');
        if (!modalState.duplicateModal) {
            const self = this; // Store reference to helper for use in callback
            $A.createComponent(
                "c:DuplicateCheckOnCase",
                {
                    "currentCaseID": component.get("v.recordId"),
                    "isMultiAssetCase": flag
                },
                function(msgBox) {
                    if (component.isValid()) {
                        const targetCmp = component.find('duplicateCheck');
                        const body = targetCmp.get("v.body");
                        body.push(msgBox);
                        targetCmp.set("v.body", body);

                        // Update modal state using stored reference
                        const modalState = component.get('v.modalState');
                        modalState.duplicateModal = true;
                        component.set('v.modalState', modalState);
                    }
                }
            );
        }
    },

    AdditionalEmailTemplate: function(component, helper) {
        const selectedCaseId = component.get("v.selectedCases");
        const caseRec = component.get("v.CaseObj");
        const action = component.get('c.saveAdditionalTemplate');

        action.setParams({
            "emailTempDesc": caseRec.EmailTemplateAdditionalComments__c,
            "caseId": component.get("v.selectedCases")
        });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const data = response.getReturnValue();
                this._updateModalState(component, { caseEmailTemp: false });

                if (data === 'Success') {
                    $A.get('e.force:refreshView').fire();
                }
            } else {
                console.error('Error saving email template:', response.getError());
            }
        });

        $A.enqueueAction(action);
    },

    isTemplateVisible: function(component) {
        const caseId = component.get("v.recordId");
        const action = component.get('c.IsTemplateVisible');

        action.setParams({ "caseRecId": caseId });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const isEligible = response.getReturnValue();
                this._updateStateFlags(component, { isTempVisible: isEligible });
            } else {
                console.error('Error checking template visibility:', response.getError());
            }
        });

        $A.enqueueAction(action);
    },

    isCapacityEligible: function(component) {
        const caseId = component.get("v.recordId");
        const action = component.get('c.IsWMCapacityPlannerVisible');

        action.setParams({ "caseRecId": caseId });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const isEligible = response.getReturnValue();
                this._updateStateFlags(component, { isCapacityEligible: isEligible });
            } else {
                console.error('Error checking capacity eligibility:', response.getError());
            }
        });

        $A.enqueueAction(action);
    },

    getCaseMsg_new_trail: function(component) {
        const action = component.get('c.getCaseMessages_new');
        action.setParams({ "caseId": component.get("v.recordId") });

        action.setCallback(this, function(response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const wrapper = response.getReturnValue();
                if (wrapper) {
                    // Future implementation
                }
            } else {
                console.error('Error getting new case messages:', response.getError());
            }
        });

        $A.enqueueAction(action);
    }
})

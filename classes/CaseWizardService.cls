/**
 * @author Waste Management
 * @date 2025
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Case Wizard Service - handles validation and case creation for the
 *              wizard-based case management UI. Validates each phase of the wizard
 *              and orchestrates case creation from wizard data.
 *
 * WIZARD PHASES:
 * - Phase 1: CALLER - Location/Vendor/Client + Contact selection
 * - Phase 2: INTENT - Asset + Case Type/Sub-Type/Reason configuration
 * - Phase 3: DETAILS - Customer Info (PO/Profile/PSI) + Service Date + Business Rules
 * - Phase 4: REVIEW - Summary and final submission
 *
 * USAGE:
 * - Called by caseManagerContainer LWC (wizard parent)
 * - Integrates with CaseBusinessRuleService for validation
 * - Uses CaseDMLService for case creation
 */
public without sharing class CaseWizardService {

    /**
     * @description Wrapper class for phase validation results
     */
    public class PhaseValidationResult {
        @AuraEnabled public Boolean isValid { get; set; }
        @AuraEnabled public List<String> messages { get; set; }
        @AuraEnabled public Map<String, String> fieldErrors { get; set; }
        @AuraEnabled public String nextPhase { get; set; }

        public PhaseValidationResult() {
            this.isValid = true;
            this.messages = new List<String>();
            this.fieldErrors = new Map<String, String>();
        }
    }

    /**
     * @description Wrapper class for case creation result
     */
    public class CaseCreationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public List<String> messages { get; set; }
        @AuraEnabled public String errorDetails { get; set; }

        public CaseCreationResult() {
            this.success = false;
            this.messages = new List<String>();
        }
    }

    /**
     * @description Wizard data wrapper containing all form field values
     */
    public class WizardData {
        // Phase 1: Caller Identification
        @AuraEnabled public String entityType { get; set; } // 'Location', 'Vendor', 'Client'
        @AuraEnabled public String locationId { get; set; }
        @AuraEnabled public String vendorId { get; set; }
        @AuraEnabled public String clientId { get; set; }
        @AuraEnabled public String contactId { get; set; }

        // Phase 2: Intent Configuration
        @AuraEnabled public String assetId { get; set; }
        @AuraEnabled public String recordTypeId { get; set; }
        @AuraEnabled public String caseType { get; set; }
        @AuraEnabled public String caseSubType { get; set; }
        @AuraEnabled public String caseReason { get; set; }

        // Phase 3: Details
        @AuraEnabled public String purchaseOrderNumber { get; set; }
        @AuraEnabled public Boolean overridePOCreateTask { get; set; }
        @AuraEnabled public String profileNumber { get; set; }
        @AuraEnabled public Boolean overrideProfileNumberTask { get; set; }
        @AuraEnabled public String psi { get; set; }
        @AuraEnabled public String psiOverrideReason { get; set; }
        @AuraEnabled public String psiComments { get; set; }
        @AuraEnabled public String serviceDate { get; set; }
        @AuraEnabled public String slaServiceDateTime { get; set; }

        // Phase 4: Work Order (Optional)
        @AuraEnabled public String siteContact { get; set; }
        @AuraEnabled public String siteContactPhone { get; set; }
        @AuraEnabled public String workOrderInstructions { get; set; }
        @AuraEnabled public Boolean byPassWorkOrder { get; set; }

        // Additional fields
        @AuraEnabled public String origin { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String priority { get; set; }
    }

    /**
     * @description Validates a wizard phase with provided data
     * @param phase The phase to validate ('CALLER', 'INTENT', 'DETAILS', 'REVIEW')
     * @param wizardDataJson JSON string of WizardData
     * @return PhaseValidationResult with validation results
     */
    @AuraEnabled
    public static PhaseValidationResult validatePhase(String phase, String wizardDataJson) {
        PhaseValidationResult result = new PhaseValidationResult();

        try {
            // Deserialize wizard data
            WizardData data = (WizardData) JSON.deserialize(wizardDataJson, WizardData.class);

            // Validate based on phase
            switch on phase.toUpperCase() {
                when 'CALLER' {
                    validateCallerPhase(data, result);
                    if (result.isValid) {
                        result.nextPhase = 'INTENT';
                    }
                }
                when 'INTENT' {
                    validateIntentPhase(data, result);
                    if (result.isValid) {
                        result.nextPhase = 'DETAILS';
                    }
                }
                when 'DETAILS' {
                    validateDetailsPhase(data, result);
                    if (result.isValid) {
                        result.nextPhase = 'REVIEW';
                    }
                }
                when 'REVIEW' {
                    validateReviewPhase(data, result);
                    if (result.isValid) {
                        result.nextPhase = 'COMPLETE';
                    }
                }
                when else {
                    result.isValid = false;
                    result.messages.add('Invalid phase: ' + phase);
                }
            }

        } catch (Exception ex) {
            result.isValid = false;
            result.messages.add('Validation error: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'CaseWizardService', LoggingLevel.ERROR);
        }

        return result;
    }

    /**
     * @description Validates Phase 1: Caller Identification
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateCallerPhase(WizardData data, PhaseValidationResult result) {
        // Validate entity selection
        if (String.isBlank(data.entityType)) {
            result.isValid = false;
            result.messages.add('Please select an entity type (Location, Vendor, or Client)');
            result.fieldErrors.put('entityType', 'Entity type is required');
        }

        // Validate that the appropriate entity ID is populated
        Boolean hasEntity = false;
        if (data.entityType == 'Location' && String.isNotBlank(data.locationId)) {
            hasEntity = true;
        } else if (data.entityType == 'Vendor' && String.isNotBlank(data.vendorId)) {
            hasEntity = true;
        } else if (data.entityType == 'Client' && String.isNotBlank(data.clientId)) {
            hasEntity = true;
        }

        if (!hasEntity) {
            result.isValid = false;
            result.messages.add('Please select a ' + data.entityType);
            result.fieldErrors.put('entity', data.entityType + ' selection is required');
        }

        // Validate contact selection
        if (String.isBlank(data.contactId)) {
            result.isValid = false;
            result.messages.add(Constant_Util.SELECT_CONTACT);
            result.fieldErrors.put('contactId', 'Contact is required');
        }

        // If valid, check that contact belongs to selected entity
        if (hasEntity && String.isNotBlank(data.contactId)) {
            validateContactBelongsToEntity(data, result);
        }
    }

    /**
     * @description Validates that contact belongs to selected entity
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateContactBelongsToEntity(WizardData data, PhaseValidationResult result) {
        try {
            Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id = :data.contactId LIMIT 1];

            String entityId = null;
            if (data.entityType == 'Location') {
                entityId = data.locationId;
            } else if (data.entityType == 'Vendor') {
                entityId = data.vendorId;
            } else if (data.entityType == 'Client') {
                entityId = data.clientId;
            }

            if (contact.AccountId != entityId) {
                result.isValid = false;
                result.messages.add('Selected contact does not belong to the selected ' + data.entityType);
                result.fieldErrors.put('contactId', 'Contact mismatch');
            }
        } catch (Exception ex) {
            result.isValid = false;
            result.messages.add('Error validating contact: ' + ex.getMessage());
        }
    }

    /**
     * @description Validates Phase 2: Intent Configuration
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateIntentPhase(WizardData data, PhaseValidationResult result) {
        // Validate record type
        if (String.isBlank(data.recordTypeId)) {
            result.isValid = false;
            result.messages.add('Please select a record type');
            result.fieldErrors.put('recordTypeId', 'Record type is required');
        }

        // Validate case type
        if (String.isBlank(data.caseType)) {
            result.isValid = false;
            result.messages.add('Please select a case type');
            result.fieldErrors.put('caseType', 'Case type is required');
        }

        // Validate case sub-type
        if (String.isBlank(data.caseSubType)) {
            result.isValid = false;
            result.messages.add(Constant_Util.SELECT_CASESUBTYPE);
            result.fieldErrors.put('caseSubType', 'Case sub-type is required');
        }

        // Asset is optional for some case types (e.g., New Service)
        // Validate based on case type
        if (data.caseType != 'New Service') {
            if (String.isBlank(data.assetId)) {
                result.isValid = false;
                result.messages.add(Constant_Util.SELECT_ASSET);
                result.fieldErrors.put('assetId', 'Asset is required for this case type');
            }
        }

        // Check for restricted record type + case type combinations
        if (String.isNotBlank(data.recordTypeId) && String.isNotBlank(data.caseType)) {
            validateRecordTypeCaseTypeCombination(data, result);
        }
    }

    /**
     * @description Validates record type and case type combination
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateRecordTypeCaseTypeCombination(WizardData data, PhaseValidationResult result) {
        // Query metadata for restricted combinations
        // This would integrate with existing changeRecordTypeController logic
        // Simplified for now
        try {
            // Get record type name
            RecordType rt = [SELECT Name FROM RecordType WHERE Id = :data.recordTypeId LIMIT 1];

            // Example: Standard Case record type cannot have Pickup case type
            if (rt.Name == 'Standard Case' && data.caseType == 'Pickup') {
                result.isValid = false;
                result.messages.add('Pickup case type is not allowed for Standard Case record type');
                result.fieldErrors.put('caseType', 'Invalid combination');
            }
        } catch (Exception ex) {
            // Log but don't fail validation
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'CaseWizardService', LoggingLevel.ERROR);
        }
    }

    /**
     * @description Validates Phase 3: Details
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateDetailsPhase(WizardData data, PhaseValidationResult result) {
        // Build a temporary case object for business rule validation
        Case tempCase = buildTempCaseForValidation(data);

        // Validate service date
        if (String.isBlank(data.serviceDate) || String.isBlank(data.slaServiceDateTime)) {
            result.isValid = false;
            result.messages.add(Constant_Util.SELECT_CASESLADATE);
            result.fieldErrors.put('serviceDate', 'Service date is required');
        }

        // Validate business rules (using existing service)
        // Note: We'd need to insert the temp case first or use a validation-only method
        validateBusinessRuleRequirements(tempCase, data, result);

        // Validate required information based on business rules
        validateRequiredInformation(tempCase, data, result);
    }

    /**
     * @description Builds a temporary case object for validation
     * @param data Wizard data
     * @return Temporary Case object
     */
    private static Case buildTempCaseForValidation(WizardData data) {
        Case tempCase = new Case();
        tempCase.RecordTypeId = data.recordTypeId;
        tempCase.Case_Type__c = data.caseType;
        tempCase.Case_Sub_Type__c = data.caseSubType;
        tempCase.Case_Reason__c = data.caseReason;
        tempCase.ContactId = data.contactId;
        tempCase.AssetId = data.assetId;

        if (data.entityType == 'Location') {
            tempCase.Location__c = data.locationId;
        } else if (data.entityType == 'Vendor') {
            tempCase.Supplier__c = data.vendorId;
        } else if (data.entityType == 'Client') {
            tempCase.Client__c = data.clientId;
        }

        tempCase.PurchaseOrder_Number__c = data.purchaseOrderNumber;
        tempCase.Override_PO_Create_Task__c = data.overridePOCreateTask;
        tempCase.Profile_Number__c = data.profileNumber;
        tempCase.Override_Profile_Number_Task__c = data.overrideProfileNumberTask;
        tempCase.PSI__c = data.psi;
        tempCase.PSI_Override_Reason__c = data.psiOverrideReason;
        tempCase.PSI_Comments__c = data.psiComments;

        if (String.isNotBlank(data.serviceDate)) {
            tempCase.Service_Date__c = Date.valueOf(data.serviceDate);
        }
        if (String.isNotBlank(data.slaServiceDateTime)) {
            tempCase.SLA_Service_DateTime__c = DateTime.valueOf(data.slaServiceDateTime);
        }

        tempCase.Status = Constant_Util.STATUS_New;

        return tempCase;
    }

    /**
     * @description Validates business rule requirements
     * @param tempCase Temporary case for validation
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateBusinessRuleRequirements(Case tempCase, WizardData data, PhaseValidationResult result) {
        // Note: This is a simplified validation
        // Full implementation would integrate with CaseBusinessRuleService
        // after the case is inserted or use a validation-only approach

        // For now, we'll do basic checks
        if (String.isNotBlank(tempCase.Case_Type__c) &&
            String.isNotBlank(tempCase.Case_Sub_Type__c)) {

            // Check if work order is needed
            Boolean woNeeded = !CaseBusinessRuleService.shouldBypassWorkOrderCreation(tempCase);

            if (woNeeded && String.isBlank(tempCase.AssetId)) {
                result.isValid = false;
                result.messages.add(Constant_Util.SELECT_ASSET);
                result.fieldErrors.put('assetId', 'Asset is required for work order creation');
            }
        }
    }

    /**
     * @description Validates required information (PO, Profile, PSI)
     * @param tempCase Temporary case for validation
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateRequiredInformation(Case tempCase, WizardData data, PhaseValidationResult result) {
        // Check PO requirement
        Boolean poRequired = CaseBusinessRuleService.isPurchaseOrderRequired(tempCase);
        if (poRequired &&
            String.isBlank(data.purchaseOrderNumber) &&
            !data.overridePOCreateTask) {
            result.isValid = false;
            result.messages.add(Constant_Util.PO_MSG);
            result.fieldErrors.put('purchaseOrderNumber', 'PO Number is required');
        }

        // Check Profile Number requirement
        Boolean profileRequired = CaseBusinessRuleService.isProfileNumberRequired(tempCase);
        if (profileRequired &&
            String.isBlank(data.profileNumber) &&
            !data.overrideProfileNumberTask) {
            result.isValid = false;
            result.messages.add(Constant_Util.PROFILE_MSG);
            result.fieldErrors.put('profileNumber', 'Profile Number is required');
        }

        // Check PSI requirement
        Boolean psiRequired = CaseBusinessRuleService.isPSIRequired(tempCase);
        if (psiRequired) {
            if (String.isBlank(data.psi)) {
                if (String.isBlank(data.psiOverrideReason)) {
                    result.isValid = false;
                    result.messages.add(Constant_Util.PSI_REQUIRED);
                    result.fieldErrors.put('psi', 'PSI is required');
                } else if (data.psiOverrideReason == Constant_Util.OTHER_API &&
                           String.isBlank(data.psiComments)) {
                    result.isValid = false;
                    result.messages.add(Constant_Util.PSI_COMMENTS);
                    result.fieldErrors.put('psiComments', 'PSI Comments are required');
                }
            }
        }
    }

    /**
     * @description Validates Phase 4: Review (final validation before submission)
     * @param data Wizard data
     * @param result Validation result to populate
     */
    private static void validateReviewPhase(WizardData data, PhaseValidationResult result) {
        // Re-validate all phases to ensure nothing was missed
        validateCallerPhase(data, result);
        if (!result.isValid) return;

        validateIntentPhase(data, result);
        if (!result.isValid) return;

        validateDetailsPhase(data, result);
        if (!result.isValid) return;

        // Additional final validations
        Case tempCase = buildTempCaseForValidation(data);

        // Validate work order readiness (if applicable)
        Map<String, Object> woValidation =
            CaseBusinessRuleService.validateCaseReadyForWorkOrder(tempCase.Id);

        if (woValidation != null) {
            Boolean isValid = (Boolean) woValidation.get('isValid');
            if (!isValid) {
                List<String> messages = (List<String>) woValidation.get('messages');
                result.isValid = false;
                result.messages.addAll(messages);
            }
        }
    }

    /**
     * @description Creates a case from wizard data
     * @param wizardDataJson JSON string of WizardData
     * @return CaseCreationResult with creation results
     */
    @AuraEnabled
    public static CaseCreationResult createCaseFromWizard(String wizardDataJson) {
        CaseCreationResult result = new CaseCreationResult();

        try {
            // Deserialize wizard data
            WizardData data = (WizardData) JSON.deserialize(wizardDataJson, WizardData.class);

            // Final validation
            PhaseValidationResult validation = validatePhase('REVIEW', wizardDataJson);
            if (!validation.isValid) {
                result.success = false;
                result.messages.addAll(validation.messages);
                result.errorDetails = 'Validation failed: ' + String.join(validation.messages, '; ');
                return result;
            }

            // Build case from wizard data
            Case newCase = buildCaseFromWizardData(data);

            // Use existing service layer for insertion
            CaseDMLService.insertCases(new List<Case>{ newCase });

            // Business rules will be evaluated via trigger -> CaseBusinessRuleService

            result.success = true;
            result.caseId = newCase.Id;
            result.caseNumber = newCase.CaseNumber;
            result.messages.add('Case created successfully');

        } catch (DmlException dmlEx) {
            result.success = false;
            result.errorDetails = dmlEx.getDmlMessage(0);
            result.messages.add('Case creation failed: ' + dmlEx.getDmlMessage(0));
            UTIL_LoggingService.logHandledException(dmlEx, UserInfo.getOrganizationId(),
                'CaseWizardService', LoggingLevel.ERROR);
        } catch (Exception ex) {
            result.success = false;
            result.errorDetails = ex.getMessage();
            result.messages.add('Case creation failed: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'CaseWizardService', LoggingLevel.ERROR);
        }

        return result;
    }

    /**
     * @description Builds a Case object from wizard data
     * @param data Wizard data
     * @return Case object ready for insertion
     */
    private static Case buildCaseFromWizardData(WizardData data) {
        Case newCase = new Case();

        // Record Type
        newCase.RecordTypeId = data.recordTypeId;

        // Case Types
        newCase.Case_Type__c = data.caseType;
        newCase.Case_Sub_Type__c = data.caseSubType;
        newCase.Case_Reason__c = data.caseReason;

        // Entities
        if (data.entityType == 'Location') {
            newCase.Location__c = data.locationId;
        } else if (data.entityType == 'Vendor') {
            newCase.Supplier__c = data.vendorId;
        } else if (data.entityType == 'Client') {
            newCase.Client__c = data.clientId;
        }

        // Contact and Asset
        newCase.ContactId = data.contactId;
        newCase.AssetId = data.assetId;

        // Service Dates
        if (String.isNotBlank(data.serviceDate)) {
            newCase.Service_Date__c = Date.valueOf(data.serviceDate);
        }
        if (String.isNotBlank(data.slaServiceDateTime)) {
            newCase.SLA_Service_DateTime__c = DateTime.valueOf(data.slaServiceDateTime);
        }

        // Customer Information
        newCase.PurchaseOrder_Number__c = data.purchaseOrderNumber;
        newCase.Override_PO_Create_Task__c = data.overridePOCreateTask;
        newCase.Profile_Number__c = data.profileNumber;
        newCase.Override_Profile_Number_Task__c = data.overrideProfileNumberTask;
        newCase.PSI__c = data.psi;
        newCase.PSI_Override_Reason__c = data.psiOverrideReason;
        newCase.PSI_Comments__c = data.psiComments;

        // Work Order Details
        newCase.Site_Contact__c = data.siteContact;
        newCase.Site_Contact_Phone__c = data.siteContactPhone;
        newCase.User_Input_Work_Order_Instructions__c = data.workOrderInstructions;
        newCase.Is_ByPassWO__c = data.byPassWorkOrder;

        // Additional fields
        newCase.Origin = String.isNotBlank(data.origin) ? data.origin : 'Web';
        newCase.Subject = data.subject;
        newCase.Description = data.description;
        newCase.Priority = String.isNotBlank(data.priority) ? data.priority : 'Medium';
        newCase.Status = Constant_Util.STATUS_New;

        return newCase;
    }

    /**
     * @description Updates an existing case from wizard data (for edit mode)
     * @param caseId Existing case ID
     * @param wizardDataJson JSON string of WizardData
     * @return CaseCreationResult with update results
     */
    @AuraEnabled
    public static CaseCreationResult updateCaseFromWizard(String caseId, String wizardDataJson) {
        CaseCreationResult result = new CaseCreationResult();

        try {
            // Deserialize wizard data
            WizardData data = (WizardData) JSON.deserialize(wizardDataJson, WizardData.class);

            // Build case from wizard data
            Case updatedCase = buildCaseFromWizardData(data);
            updatedCase.Id = caseId;

            // Use existing service layer for update
            CaseDMLService.updateCases(new List<Case>{ updatedCase });

            result.success = true;
            result.caseId = updatedCase.Id;
            result.messages.add('Case updated successfully');

        } catch (Exception ex) {
            result.success = false;
            result.errorDetails = ex.getMessage();
            result.messages.add('Case update failed: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'CaseWizardService', LoggingLevel.ERROR);
        }

        return result;
    }
}

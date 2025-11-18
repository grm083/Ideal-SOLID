/**
 * @description ActionMessagesPanelController - Apex controller for actionMessagesPanel LWC
 *
 * Provides action messages and button visibility logic for case action panel.
 * Replaces ShowCaseMessages/GetCaseInformation logic with modern LWC-optimized approach.
 *
 * Key Responsibilities:
 * - Provide case action messages and status
 * - Determine button visibility (Progress Case, Add Quote, Initiate WO, etc.)
 * - Integrate with business rule services for validation
 * - Support action button operations
 *
 * Design Principles:
 * - Single Responsibility: Only handles action panel UI data
 * - Service Layer Integration: 100% reuse of CaseBusinessRuleService
 * - Cacheable: Uses @AuraEnabled(cacheable=true) for wire services
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 * @group Controllers
 */
public with sharing class ActionMessagesPanelController {

    // ========================================================================
    // DATA RETRIEVAL METHODS
    // ========================================================================

    /**
     * @description Gets comprehensive action panel data
     * @param caseId The case ID
     * @return ActionPanelData wrapper with messages and button visibility
     */
    @AuraEnabled(cacheable=true)
    public static ActionPanelData getActionPanelData(String caseId) {
        ActionPanelData result = new ActionPanelData();

        try {
            if (String.isBlank(caseId)) {
                return result;
            }

            // Get case data
            Case caseRecord = CaseContextGetter.getCaseByIdExtended(Id.valueOf(caseId));

            if (caseRecord == null) {
                return result;
            }

            // Populate basic info
            result.caseId = caseRecord.Id;
            result.status = caseRecord.Status;
            result.caseType = caseRecord.Case_Type__c;

            // Get action messages
            result.actionMessage = getActionMessage(caseRecord);
            result.messageVariant = getMessageVariant(caseRecord);
            result.messageIcon = getMessageIcon(result.messageVariant);

            // Get button visibility
            determineButtonVisibility(result, caseRecord);

            // Get related case count
            result.relatedCaseCount = getRelatedCaseCount(caseRecord);

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to load action panel data: ' + ex.getMessage());
        }

        return result;
    }

    /**
     * @description Gets button visibility flags only (lighter weight)
     * @param caseId The case ID
     * @return ButtonVisibilityData with all button visibility flags
     */
    @AuraEnabled(cacheable=true)
    public static ButtonVisibilityData getButtonVisibility(String caseId) {
        ButtonVisibilityData result = new ButtonVisibilityData();

        try {
            if (String.isBlank(caseId)) {
                return result;
            }

            Case caseRecord = CaseContextGetter.getCaseByIdExtended(Id.valueOf(caseId));

            if (caseRecord == null) {
                return result;
            }

            // Determine all button visibility flags
            result.showProgressCase = CaseBusinessRuleService.shouldShowProgressCaseButton(caseId);
            result.showAddQuote = CaseBusinessRuleService.shouldShowAddQuoteButton(caseId);
            result.showInitiateWorkOrder = shouldShowInitiateWorkOrderButton(caseRecord);
            result.showViewCaseSummary = shouldShowViewCaseSummaryButton(caseRecord);
            result.showAddCaseAssets = shouldShowAddCaseAssetsButton(caseRecord);
            result.showPendingInfoTask = shouldShowPendingInfoTaskButton(caseRecord);
            result.showMultiDates = shouldShowMultiDatesButton(caseRecord);

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                LoggingLevel.ERROR
            );
        }

        return result;
    }

    // ========================================================================
    // MESSAGE GENERATION METHODS
    // ========================================================================

    /**
     * @description Gets action message for case
     * @param caseRecord The case record
     * @return Action message string
     */
    private static String getActionMessage(Case caseRecord) {
        // Check if case is ready
        Map<String, Object> validationResult = CaseBusinessRuleService.validateCaseReadyForWorkOrder(caseRecord.Id);
        Boolean isValid = (Boolean) validationResult.get('isValid');
        List<String> messages = (List<String>) validationResult.get('messages');

        if (!isValid && messages != null && !messages.isEmpty()) {
            return String.join(messages, ' ');
        }

        // Check status
        if (caseRecord.Status == Constant_Util.STATUS_New || caseRecord.Status == Constant_Util.PENDING) {
            return 'Case is ready to progress. Click "Progress Case" to continue.';
        }

        if (caseRecord.Status == Constant_Util.OPEN) {
            return 'Case is open and in progress.';
        }

        if (caseRecord.Status == 'Closed') {
            return 'Case is closed.';
        }

        return 'Review case details and take appropriate action.';
    }

    /**
     * @description Gets message variant (info, warning, error, success)
     * @param caseRecord The case record
     * @return Message variant string
     */
    private static String getMessageVariant(Case caseRecord) {
        Map<String, Object> validationResult = CaseBusinessRuleService.validateCaseReadyForWorkOrder(caseRecord.Id);
        Boolean isValid = (Boolean) validationResult.get('isValid');

        if (!isValid) {
            return 'error';
        }

        if (caseRecord.Status == Constant_Util.STATUS_New || caseRecord.Status == Constant_Util.PENDING) {
            return 'info';
        }

        if (caseRecord.Status == Constant_Util.OPEN) {
            return 'success';
        }

        if (caseRecord.Status == 'Closed') {
            return 'info';
        }

        return 'info';
    }

    /**
     * @description Gets icon name for message variant
     * @param variant Message variant
     * @return Lightning icon name
     */
    private static String getMessageIcon(String variant) {
        if (variant == 'error') {
            return 'utility:error';
        } else if (variant == 'warning') {
            return 'utility:warning';
        } else if (variant == 'success') {
            return 'utility:success';
        } else {
            return 'utility:info';
        }
    }

    // ========================================================================
    // BUTTON VISIBILITY METHODS
    // ========================================================================

    /**
     * @description Determines all button visibility flags
     * @param result The ActionPanelData to populate
     * @param caseRecord The case record
     */
    private static void determineButtonVisibility(ActionPanelData result, Case caseRecord) {
        result.showProgressCase = CaseBusinessRuleService.shouldShowProgressCaseButton(caseRecord.Id);
        result.showAddQuote = CaseBusinessRuleService.shouldShowAddQuoteButton(caseRecord.Id);
        result.showInitiateWorkOrder = shouldShowInitiateWorkOrderButton(caseRecord);
        result.showViewCaseSummary = shouldShowViewCaseSummaryButton(caseRecord);
        result.showAddCaseAssets = shouldShowAddCaseAssetsButton(caseRecord);
        result.showPendingInfoTask = shouldShowPendingInfoTaskButton(caseRecord);
        result.showMultiDates = shouldShowMultiDatesButton(caseRecord);
    }

    /**
     * @description Check if Initiate Work Order button should be shown
     * @param caseRecord The case record
     * @return Whether to show button
     */
    private static Boolean shouldShowInitiateWorkOrderButton(Case caseRecord) {
        // Don't show if closed
        if (caseRecord.Status == 'Closed') {
            return false;
        }

        // Show if case is ready and doesn't have bypass flag
        if (caseRecord.Is_ByPassWO__c == true) {
            return false;
        }

        // Check if WO is needed
        Boolean woNeeded = !CaseBusinessRuleService.shouldBypassWorkOrderCreation(caseRecord);

        // Check if case is ready
        Map<String, Object> validationResult = CaseBusinessRuleService.validateCaseReadyForWorkOrder(caseRecord.Id);
        Boolean isValid = (Boolean) validationResult.get('isValid');

        return woNeeded && isValid;
    }

    /**
     * @description Check if View Case Summary button should be shown
     * @param caseRecord The case record
     * @return Whether to show button
     */
    private static Boolean shouldShowViewCaseSummaryButton(Case caseRecord) {
        // Show if there are related cases or multi-asset
        return String.isNotBlank(caseRecord.Reference_Number__c);
    }

    /**
     * @description Check if Add Case Assets button should be shown
     * @param caseRecord The case record
     * @return Whether to show button
     */
    private static Boolean shouldShowAddCaseAssetsButton(Case caseRecord) {
        // Don't show if closed
        if (caseRecord.Status == 'Closed') {
            return false;
        }

        // Show for new or pending cases
        return caseRecord.Status == Constant_Util.STATUS_New ||
               caseRecord.Status == Constant_Util.PENDING;
    }

    /**
     * @description Check if Create Pending Info Task button should be shown
     * @param caseRecord The case record
     * @return Whether to show button
     */
    private static Boolean shouldShowPendingInfoTaskButton(Case caseRecord) {
        // Don't show if closed
        if (caseRecord.Status == 'Closed') {
            return false;
        }

        // Show for open or new cases
        return caseRecord.Status == Constant_Util.OPEN ||
               caseRecord.Status == Constant_Util.STATUS_New;
    }

    /**
     * @description Check if Multi Dates button should be shown
     * @param caseRecord The case record
     * @return Whether to show button
     */
    private static Boolean shouldShowMultiDatesButton(Case caseRecord) {
        // Show if multi-calendar or multi-date is applicable
        return caseRecord.Is_MultiCalendar_Checked__c == true ||
               caseRecord.Create_AM_and_PM_Pickups__c == true;
    }

    /**
     * @description Gets count of related cases
     * @param caseRecord The case record
     * @return Count of related cases
     */
    private static Integer getRelatedCaseCount(Case caseRecord) {
        if (String.isBlank(caseRecord.Reference_Number__c)) {
            return 0;
        }

        try {
            return [
                SELECT COUNT()
                FROM Case
                WHERE Reference_Number__c = :caseRecord.Reference_Number__c
                AND Id != :caseRecord.Id
            ];
        } catch (Exception ex) {
            return 0;
        }
    }

    // ========================================================================
    // WRAPPER CLASSES
    // ========================================================================

    /**
     * @description Comprehensive action panel data wrapper
     */
    public class ActionPanelData {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String caseType { get; set; }

        // Message information
        @AuraEnabled public String actionMessage { get; set; }
        @AuraEnabled public String messageVariant { get; set; }
        @AuraEnabled public String messageIcon { get; set; }

        // Button visibility flags
        @AuraEnabled public Boolean showProgressCase { get; set; }
        @AuraEnabled public Boolean showAddQuote { get; set; }
        @AuraEnabled public Boolean showInitiateWorkOrder { get; set; }
        @AuraEnabled public Boolean showViewCaseSummary { get; set; }
        @AuraEnabled public Boolean showAddCaseAssets { get; set; }
        @AuraEnabled public Boolean showPendingInfoTask { get; set; }
        @AuraEnabled public Boolean showMultiDates { get; set; }

        // Related data
        @AuraEnabled public Integer relatedCaseCount { get; set; }

        public ActionPanelData() {
            this.actionMessage = '';
            this.messageVariant = 'info';
            this.messageIcon = 'utility:info';
            this.showProgressCase = false;
            this.showAddQuote = false;
            this.showInitiateWorkOrder = false;
            this.showViewCaseSummary = false;
            this.showAddCaseAssets = false;
            this.showPendingInfoTask = false;
            this.showMultiDates = false;
            this.relatedCaseCount = 0;
        }
    }

    /**
     * @description Button visibility data wrapper
     */
    public class ButtonVisibilityData {
        @AuraEnabled public Boolean showProgressCase { get; set; }
        @AuraEnabled public Boolean showAddQuote { get; set; }
        @AuraEnabled public Boolean showInitiateWorkOrder { get; set; }
        @AuraEnabled public Boolean showViewCaseSummary { get; set; }
        @AuraEnabled public Boolean showAddCaseAssets { get; set; }
        @AuraEnabled public Boolean showPendingInfoTask { get; set; }
        @AuraEnabled public Boolean showMultiDates { get; set; }

        public ButtonVisibilityData() {
            this.showProgressCase = false;
            this.showAddQuote = false;
            this.showInitiateWorkOrder = false;
            this.showViewCaseSummary = false;
            this.showAddCaseAssets = false;
            this.showPendingInfoTask = false;
            this.showMultiDates = false;
        }
    }
}

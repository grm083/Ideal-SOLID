/**
 * @description CaseHighlightStripController - Apex controller for caseHighlightStrip LWC
 *
 * Provides comprehensive case highlight data for inline display in horizontal strip layout.
 * Replaces CustomCaseHighlightPanelCntrl with modern LWC-optimized approach.
 *
 * Key Responsibilities:
 * - Provide case field data for highlight strip display
 * - Determine field status/color coding (complete, warning, missing)
 * - Support click-to-edit functionality
 * - Real-time field validation status
 *
 * Design Principles:
 * - Single Responsibility: Only handles highlight strip UI data
 * - Service Layer Integration: 100% reuse of existing services
 * - Cacheable: Uses @AuraEnabled(cacheable=true) for wire services
 *
 * @author George Martin
 * @date 2025-11-18
 * @group Controllers
 */
public with sharing class CaseHighlightStripController {

    // ========================================================================
    // DATA RETRIEVAL METHODS
    // ========================================================================

    /**
     * @description Gets comprehensive case highlight data for strip display
     * @param caseId The case ID
     * @return CaseHighlightData wrapper with all highlight strip fields
     */
    @AuraEnabled(cacheable=true)
    public static CaseHighlightData getCaseHighlightData(String caseId) {
        CaseHighlightData result = new CaseHighlightData();

        try {
            if (String.isBlank(caseId)) {
                return result;
            }

            // Query case with all highlight panel fields
            Case caseRecord = CaseContextGetter.getCaseWithHighlightPanelFields(Id.valueOf(caseId));

            if (caseRecord == null) {
                return result;
            }

            // Populate basic case info
            result.caseId = caseRecord.Id;
            result.caseNumber = caseRecord.CaseNumber;
            result.referenceNumber = caseRecord.Reference_Number__c;
            result.status = caseRecord.Status;
            result.subStatus = caseRecord.Case_Sub_Status__c;

            // Entity information
            result.locationId = caseRecord.Location__c;
            result.locationName = caseRecord.Location__r != null ? caseRecord.Location__r.Name : '--';
            result.vendorId = caseRecord.Vendor__c;
            result.vendorName = caseRecord.Vendor__r != null ? caseRecord.Vendor__r.Name : '--';
            result.clientId = caseRecord.Client__c;
            result.clientName = caseRecord.Client__r != null ? caseRecord.Client__r.Name : '--';

            // Contact information
            result.contactId = caseRecord.ContactId;
            result.contactName = caseRecord.Contact != null ? caseRecord.Contact.Name : '--';

            // Asset information
            result.assetId = caseRecord.AssetId;
            result.assetName = caseRecord.Asset != null ? caseRecord.Asset.Name : '--';
            result.material = caseRecord.Asset_Material__c;

            // Case Type information
            result.recordTypeId = caseRecord.RecordTypeId;
            result.recordTypeName = caseRecord.Case_Record_Type__c;
            result.caseType = caseRecord.Case_Type__c;
            result.caseSubType = caseRecord.Case_Sub_Type__c;
            result.caseReason = caseRecord.Case_Reason__c;

            // Customer info
            result.purchaseOrderNumber = caseRecord.PurchaseOrder_Number__c;
            result.profileNumber = caseRecord.Profile_Number__c;
            result.psi = caseRecord.PSI__c;
            result.companyCategory = caseRecord.Company_Category__c;

            // Service date information
            result.serviceDate = caseRecord.Service_Date__c;
            result.slaServiceDateTime = caseRecord.SLA_Service_Date_Time__c;

            // Work order and queue information
            result.workOrderNumber = caseRecord.WorkOrder__r != null ? caseRecord.WorkOrder__r.WorkOrderNumber : '--';
            result.trackingNumber = caseRecord.Tracking_Number__c;
            result.queueName = getQueueName(caseRecord.Tracking_Number__c);

            // Determine field statuses (for color coding)
            determineFieldStatuses(result, caseRecord);

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to load case highlight data: ' + ex.getMessage());
        }

        return result;
    }

    /**
     * @description Gets summary info for highlight strip (lighter weight than full data)
     * @param caseId The case ID
     * @return CaseHighlightSummary with essential fields only
     */
    @AuraEnabled(cacheable=true)
    public static CaseHighlightSummary getCaseHighlightSummary(String caseId) {
        CaseHighlightSummary result = new CaseHighlightSummary();

        try {
            if (String.isBlank(caseId)) {
                return result;
            }

            Case caseRecord = CaseContextGetter.getCaseById(Id.valueOf(caseId));

            if (caseRecord == null) {
                return result;
            }

            result.caseNumber = caseRecord.CaseNumber;
            result.status = caseRecord.Status;
            result.caseType = caseRecord.Case_Type__c;
            result.referenceNumber = caseRecord.Reference_Number__c;
            result.hasRequiredInfo = String.isNotBlank(caseRecord.PurchaseOrder_Number__c) ||
                                     String.isNotBlank(caseRecord.Profile_Number__c);

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
    // FIELD STATUS DETERMINATION METHODS
    // ========================================================================

    /**
     * @description Determines status for each field (complete, warning, missing)
     * @param result The CaseHighlightData to populate statuses for
     * @param caseRecord The Case record
     */
    private static void determineFieldStatuses(CaseHighlightData result, Case caseRecord) {
        // Location status
        result.locationStatus = String.isNotBlank(result.locationName) && result.locationName != '--' ?
            'complete' : 'missing';

        // Contact status
        result.contactStatus = String.isNotBlank(result.contactName) && result.contactName != '--' ?
            'complete' : 'missing';

        // Asset status
        result.assetStatus = String.isNotBlank(result.assetName) && result.assetName != '--' ?
            'complete' : 'warning';

        // Case Type status
        result.caseTypeStatus = String.isNotBlank(result.caseType) ? 'complete' : 'missing';

        // Service Date status
        result.serviceDateStatus = result.serviceDate != null ? 'complete' : 'warning';

        // PO/Profile/PSI status (check business rules)
        Boolean poRequired = CaseBusinessRuleService.isPurchaseOrderRequired(caseRecord);
        Boolean profileRequired = CaseBusinessRuleService.isProfileNumberRequired(caseRecord);
        Boolean psiRequired = CaseBusinessRuleService.isPSIRequired(caseRecord);

        if (poRequired && String.isBlank(result.purchaseOrderNumber)) {
            result.customerInfoStatus = 'missing';
        } else if (profileRequired && String.isBlank(result.profileNumber)) {
            result.customerInfoStatus = 'missing';
        } else if (psiRequired && result.psi == null) {
            result.customerInfoStatus = 'missing';
        } else if (String.isNotBlank(result.purchaseOrderNumber) ||
                   String.isNotBlank(result.profileNumber) ||
                   result.psi != null) {
            result.customerInfoStatus = 'complete';
        } else {
            result.customerInfoStatus = 'info';
        }

        // Overall case readiness
        result.caseReadiness = determineCaseReadiness(result);
    }

    /**
     * @description Determines overall case readiness based on field statuses
     * @param result The CaseHighlightData
     * @return Readiness status: 'ready', 'warning', or 'missing'
     */
    private static String determineCaseReadiness(CaseHighlightData result) {
        if (result.locationStatus == 'missing' ||
            result.contactStatus == 'missing' ||
            result.caseTypeStatus == 'missing' ||
            result.customerInfoStatus == 'missing') {
            return 'missing';
        }

        if (result.assetStatus == 'warning' ||
            result.serviceDateStatus == 'warning') {
            return 'warning';
        }

        return 'ready';
    }

    /**
     * @description Gets queue name from tracking number
     * @param trackingNumber Tracking number
     * @return Queue name string
     */
    private static String getQueueName(String trackingNumber) {
        if (String.isBlank(trackingNumber)) {
            return '--';
        }

        // Reuse existing logic from CustomCaseHighlightPanelCntrl
        try {
            return CustomCaseHighlightPanelCntrl.getQueueName(trackingNumber);
        } catch (Exception ex) {
            return '--';
        }
    }

    // ========================================================================
    // WRAPPER CLASSES
    // ========================================================================

    /**
     * @description Comprehensive case highlight data wrapper
     */
    public class CaseHighlightData {
        // Case identification
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String referenceNumber { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String subStatus { get; set; }

        // Entity information
        @AuraEnabled public Id locationId { get; set; }
        @AuraEnabled public String locationName { get; set; }
        @AuraEnabled public Id vendorId { get; set; }
        @AuraEnabled public String vendorName { get; set; }
        @AuraEnabled public Id clientId { get; set; }
        @AuraEnabled public String clientName { get; set; }

        // Contact information
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String contactName { get; set; }

        // Asset information
        @AuraEnabled public Id assetId { get; set; }
        @AuraEnabled public String assetName { get; set; }
        @AuraEnabled public String material { get; set; }

        // Case type information
        @AuraEnabled public Id recordTypeId { get; set; }
        @AuraEnabled public String recordTypeName { get; set; }
        @AuraEnabled public String caseType { get; set; }
        @AuraEnabled public String caseSubType { get; set; }
        @AuraEnabled public String caseReason { get; set; }

        // Customer information
        @AuraEnabled public String purchaseOrderNumber { get; set; }
        @AuraEnabled public String profileNumber { get; set; }
        @AuraEnabled public Decimal psi { get; set; }
        @AuraEnabled public String companyCategory { get; set; }

        // Service date information
        @AuraEnabled public Date serviceDate { get; set; }
        @AuraEnabled public DateTime slaServiceDateTime { get; set; }

        // Work order and queue
        @AuraEnabled public String workOrderNumber { get; set; }
        @AuraEnabled public String trackingNumber { get; set; }
        @AuraEnabled public String queueName { get; set; }

        // Field statuses (for color coding)
        @AuraEnabled public String locationStatus { get; set; }
        @AuraEnabled public String contactStatus { get; set; }
        @AuraEnabled public String assetStatus { get; set; }
        @AuraEnabled public String caseTypeStatus { get; set; }
        @AuraEnabled public String serviceDateStatus { get; set; }
        @AuraEnabled public String customerInfoStatus { get; set; }
        @AuraEnabled public String caseReadiness { get; set; }

        public CaseHighlightData() {
            this.caseNumber = '--';
            this.referenceNumber = '--';
            this.status = '--';
            this.subStatus = '--';
            this.locationName = '--';
            this.vendorName = '--';
            this.clientName = '--';
            this.contactName = '--';
            this.assetName = '--';
            this.material = '--';
            this.recordTypeName = '--';
            this.caseType = '--';
            this.caseSubType = '--';
            this.caseReason = '--';
            this.purchaseOrderNumber = '--';
            this.profileNumber = '--';
            this.companyCategory = '--';
            this.workOrderNumber = '--';
            this.trackingNumber = '--';
            this.queueName = '--';
            this.locationStatus = 'info';
            this.contactStatus = 'info';
            this.assetStatus = 'info';
            this.caseTypeStatus = 'info';
            this.serviceDateStatus = 'info';
            this.customerInfoStatus = 'info';
            this.caseReadiness = 'info';
        }
    }

    /**
     * @description Lightweight case highlight summary wrapper
     */
    public class CaseHighlightSummary {
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String caseType { get; set; }
        @AuraEnabled public String referenceNumber { get; set; }
        @AuraEnabled public Boolean hasRequiredInfo { get; set; }

        public CaseHighlightSummary() {
            this.caseNumber = '--';
            this.status = '--';
            this.caseType = '--';
            this.referenceNumber = '--';
            this.hasRequiredInfo = false;
        }
    }
}

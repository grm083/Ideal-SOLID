/**
 * @description QuoteProcurementIntegrationService - External integration layer
 *
 * This service handles integrations with external systems including SLA calculations,
 * Asset Availability API, and special handling flags.
 *
 * Key Responsibilities:
 * - SLA override comment management
 * - Asset Availability API integration
 * - Alternate product updates
 * - Special handling flags
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Integration
 */
public with sharing class QuoteProcurementIntegrationService {

    // ========================================================================
    // PUBLIC API - SLA OPERATIONS
    // ========================================================================

    /**
     * @description Add comment for SLA override from Intake
     * Refactored from: addCommentForSLAOverrideFromIntake() in QuoteProcurementController
     * @param caseId The Case ID
     */
    @AuraEnabled
    public static void addCommentForSLAOverrideFromIntake(String caseId) {
        addCommentForSLAOverride(caseId, null, null);
    }

    /**
     * @description Add comment for SLA override from MIF Flow
     * Refactored from: addCommentForSLAOverrideFromMIF() in QuoteProcurementController
     * @param input List of input wrappers
     */
    @InvocableMethod(label='Add Comment for SLA Override'
                    description='This action is for creating sla override comment')
    public static void addCommentForSLAOverrideFromMIF(List<InputWrapperForMIFFlow> input) {
        if (input != null && !input.isEmpty()) {
            addCommentForSLAOverride(input[0].caseId, input[0].slaComment, input[0].slaReason);
        }
    }

    /**
     * @description Add comment for SLA override
     * Refactored from: addCommentForSLAOverride() in QuoteProcurementController
     * @param caseId The Case ID
     * @param slaComment SLA override comment
     * @param slaReason SLA override reason
     */
    @AuraEnabled
    public static void addCommentForSLAOverride(String caseId, String slaComment, String slaReason) {
        try {
            String commentBody;
            String trackingNumber;
            String caseNumber;

            // Get comment template
            Map<String, Comment_Log_Detail__mdt> commentLogTemplateData =
                new Map<String, Comment_Log_Detail__mdt>();

            for (Comment_Log_Detail__mdt c : Comment_Log_Detail__mdt.getAll().values()) {
                commentLogTemplateData.put(c.DeveloperName, c);
            }

            Comment_Log_Detail__mdt slaOverrideCommentTemplate =
                commentLogTemplateData.get('SLA_Override');

            Id recordTypeId = Schema.getGlobalDescribe()
                .get('Comment__c')
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('Acorn_Ticket_Comment')
                .getRecordTypeId();

            // When called from MIF flow
            if (String.isNotEmpty(slaComment) && String.isNotEmpty(slaReason)) {
                commentBody = slaOverrideCommentTemplate.Comment__c.replaceAll('<Reason__x>', slaReason);
                commentBody = commentBody.replaceAll('<Comment__c>', slaComment);

                List<Case> csList = [
                    SELECT Id, CaseNumber, Tracking_Number__c
                    FROM Case
                    WHERE Id = :caseId
                    LIMIT 1
                ];

                if (!csList.isEmpty()) {
                    caseNumber = csList[0].CaseNumber;
                    trackingNumber = csList[0].Tracking_Number__c;
                }
            } else {
                // Query quoteline for comment details
                List<SBQQ__QuoteLine__c> qlList = [
                    SELECT Id, SLA_Override_Reason__c, SLA_Override_Comment__c,
                           SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c,
                           SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.CaseNumber,
                           SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Tracking_Number__c
                    FROM SBQQ__QuoteLine__c
                    WHERE SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c = :caseId
                          AND SBQQ__Requiredby__c = null
                          AND SLA_Override_Reason__c != null
                    LIMIT 1
                ];

                if (!qlList.isEmpty()) {
                    String overrideReason = qlList[0].SLA_Override_Reason__c;
                    String overrideComment = qlList[0].SLA_Override_Comment__c;
                    commentBody = slaOverrideCommentTemplate.Comment__c.replaceAll(
                        '<Reason__x>',
                        overrideReason
                    );
                    commentBody = commentBody.replaceAll('<Comment__c>', overrideComment);

                    caseNumber = qlList[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.CaseNumber;
                    if (String.isNotEmpty(qlList[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Tracking_Number__c)) {
                        trackingNumber = qlList[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Tracking_Number__c;
                    }
                }
            }

            // Create comment record
            if (String.isNotBlank(commentBody)) {
                Comment__c comment = new Comment__c();
                comment.RecordTypeId = recordTypeId;
                comment.Comment__c = commentBody;
                comment.is_Log__c = true;
                comment.Workflow_TeamUser__c = System.UserInfo.getName();
                comment.Communication_Log_Type_Name__c = 'Internal';
                comment.Case__c = caseId;
                comment.Type__c = Constant_Util.OBJECT_CASE;
                comment.Case_Number__c = caseNumber;
                comment.Acorn_Tracking_Number__c = trackingNumber;

                insert comment;
            }

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledExceptionWithClass(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CONFIRM_CONFIGURATION_ACTION,
                System.LoggingLevel.Error,
                UTIL_ErrorConstants.QUOTEPROCUREMNTCONTROLLER_CLASSNAME,
                'addCommentForSLAOverride',
                null
            );
        }
    }

    // ========================================================================
    // PUBLIC API - ASSET AVAILABILITY
    // ========================================================================

    /**
     * @description Get Asset Availability response for a QuoteLine
     * Refactored from: getAvailabilityResponse() in QuoteProcurementController
     * @param quoteLineId The QuoteLine ID
     * @return AAV_Asset_Availability__c Availability response
     */
    @AuraEnabled
    public static AAV_Asset_Availability__c getAvailabilityResponse(String quoteLineId) {
        return AAV_APIIntegration.getAvailabilityResponse(quoteLineId);
    }

    // ========================================================================
    // PUBLIC API - ALTERNATE PRODUCT
    // ========================================================================

    /**
     * @description Update alternate product for QuoteLine
     * Refactored from: updateAlternateProduct() in QuoteProcurementController
     * @param productWrapper Product wrapper with new equipment size
     * @return Boolean True if successful
     */
    @AuraEnabled
    public static Boolean updateAlternateProduct(Object productWrapper) {
        try {
            // Convert productWrapper to map to access parentId
            Map<String, Object> wrapperMap = (Map<String, Object>)JSON.deserializeUntyped(
                JSON.serialize(productWrapper)
            );

            Id parentId = (Id)wrapperMap.get('parentId');
            String equipmentSize = (String)wrapperMap.get('equipmentSize');

            if (parentId != null) {
                List<SBQQ__QuoteLine__c> qlList =
                    QuoteProcurementContextGetter.getQuoteLinesByParentId(parentId);

                for (SBQQ__QuoteLine__c ql : qlList) {
                    ql.Equipment_Size__c = equipmentSize;
                    ql.SLA_Override_Reason__c = '';
                    ql.SLA_Override_Comment__c = '';
                    ql.SBQQ__StartDate__c = null;
                    ql.AAV_Delivery_Override_Reason__c = '';
                    ql.AAV_Delivery_Override_Comment__c = '';
                }

                QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();
                QuoteProcurementDMLService.DMLResult result = dmlService.updateQuoteLines(qlList);

                return result.isSuccess;
            }
        } catch (Exception e) {
            System.debug('updateAlternateProduct Error->' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }

        return false;
    }

    // ========================================================================
    // INNER CLASSES
    // ========================================================================

    /**
     * @description Input wrapper for MIF Flow invocable method
     */
    public class InputWrapperForMIFFlow {
        @InvocableVariable(label='Case Id')
        public String caseId;

        @InvocableVariable(label='Sla Comment')
        public String slaComment;

        @InvocableVariable(label='Sla Reason')
        public String slaReason;
    }
}

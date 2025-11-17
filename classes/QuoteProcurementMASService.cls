/**
 * @description QuoteProcurementMASService - MAS (Management Automation System) operations layer
 *
 * This service handles all MAS-related operations including MAS detail retrieval,
 * validation, and updates for QuoteLines. It consolidates MAS library/company code
 * management and VCR code handling.
 *
 * Key Responsibilities:
 * - MAS detail retrieval by facility code and business unit
 * - MAS field updates for QuoteLine bundles
 * - Bypass price review determination
 * - VCR code validation
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - MAS Operations
 */
public with sharing class QuoteProcurementMASService {

    // ========================================================================
    // PUBLIC API - MAS DETAIL RETRIEVAL
    // ========================================================================

    /**
     * @description Get MAS details for a QuoteLine
     * Refactored from: returnUniqueMASDetails() in QuoteProcurementController
     * @param quoteLineId The QuoteLine ID
     * @return List<AggregateResult> MAS details
     */
    @AuraEnabled
    public static List<AggregateResult> getMASDetailsForQuoteLine(Id quoteLineId) {
        SBQQ__QuoteLine__c parentLine = QuoteProcurementContextGetter.getQuoteLineMASDetails(quoteLineId);

        if (parentLine == null) {
            return new List<AggregateResult>();
        }

        Boolean newServiceCase = (parentLine.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name ==
                                 Constant_Util.New_Service_Case);
        String lineOfBusiness = getLineOfBusiness(parentLine.SBQQ__Product__r.Family);
        String facilityCode = parentLine.Vendor__r.FacilityCode__c;
        String businessUnit = parentLine.Vendor__r.Vendor_Business_Unit__c;

        List<AggregateResult> masDetails = new List<AggregateResult>();

        // Try facility code first
        if (String.isNotBlank(facilityCode)) {
            masDetails = QuoteProcurementContextGetter.getMASDetailsByFacility(
                facilityCode,
                lineOfBusiness,
                newServiceCase
            );
        }

        // Fallback to business unit
        if (masDetails.isEmpty() && String.isNotBlank(businessUnit)) {
            masDetails = QuoteProcurementContextGetter.getMASDetailsByBusinessUnit(
                businessUnit,
                lineOfBusiness
            );
        }

        return masDetails;
    }

    /**
     * @description Get MAS wrapper for a QuoteLine
     * Refactored from: getMasDetails() in QuoteProcurementController
     * @param quoteLineId The QuoteLine ID
     * @return MASWrapper MAS details wrapper
     */
    @AuraEnabled
    public static MASWrapper getMASWrapper(Id quoteLineId) {
        MASWrapper masWrapper = new MASWrapper();
        SBQQ__QuoteLine__c parentLine = QuoteProcurementContextGetter.getQuoteLineMASDetails(quoteLineId);

        if (parentLine != null) {
            masWrapper.MASLibrary = parentLine.MASLibrary__c;
            masWrapper.MASCompany = parentLine.MASCompany__c;
            masWrapper.MASAccount = parentLine.MASAccount__c;
            masWrapper.MASUniqueId = parentLine.MASCustomerUniqueId__c;
            masWrapper.MASServiceLine = parentLine.MASServiceLine__c;
            masWrapper.MASBox = parentLine.MASBox__c;
            masWrapper.MASComment = parentLine.SetupComment__c;
            masWrapper.MASBypassPrice = parentLine.BypassPriceReview__c;
            masWrapper.MASDoNotCreate = parentLine.DoNotCreateMASTicket__c;
            masWrapper.DoNotCreateTaskGridTickets = parentLine.DoNotCreateTaskGridTickets__c;
            masWrapper.VCRCode = parentLine.VCRCode__c;

            // Show checkbox for non-new service cases
            if (parentLine.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name !=
                Constant_Util.New_Service_Case) {
                masWrapper.IsDoNotCreateTaskGridTicketVisible = true;
            }

            masWrapper.MASCommentSize = Schema.SObjectType.SBQQ__QuoteLine__c.fields.SetupComment__c.getLength();
        }

        return masWrapper;
    }

    // ========================================================================
    // PUBLIC API - MAS UPDATES
    // ========================================================================

    /**
     * @description Update MAS details for a QuoteLine bundle
     * Refactored from: writeMASDetails() in QuoteProcurementController
     * @param parentQuoteLineId The parent QuoteLine ID
     * @param masData MAS data wrapper
     * @return MASResponseWrapper Response with success/error info
     */
    @AuraEnabled
    public static MASResponseWrapper updateMASDetails(Id parentQuoteLineId, MASWrapper masData) {
        MASResponseWrapper response = new MASResponseWrapper();

        try {
            List<SBQQ__QuoteLine__c> quoteLines = [
                SELECT Id, MASLibrary__c, MASCompany__c, MASAccount__c, MASCustomerUniqueId__c,
                       MASServiceLine__c, MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c,
                       SetupComment__c, DoNotCreateMASTicket__c, DoNotCreateTaskGridTickets__c,
                       VCRCode__c
                FROM SBQQ__QuoteLine__c
                WHERE Id = :parentQuoteLineId
                      OR SBQQ__RequiredBy__c = :parentQuoteLineId
                      OR SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :parentQuoteLineId
            ];

            for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
                if (String.isNotBlank(masData.MASLibrary)) {
                    quoteLine.MASLibrary__c = masData.MASLibrary;
                }
                if (String.isNotBlank(masData.MASCompany)) {
                    quoteLine.MASCompany__c = masData.MASCompany;
                }
                if (masData.MASAccount != null) {
                    quoteLine.MASAccount__c = masData.MASAccount;
                }
                if (masData.MASUniqueId != null) {
                    quoteLine.MASCustomerUniqueId__c = masData.MASUniqueId;
                }
                if (masData.MASServiceLine != null) {
                    quoteLine.MASServiceLine__c = masData.MASServiceLine;
                }
                if (String.isNotBlank(masData.MASBox)) {
                    quoteLine.MASBox__c = masData.MASBox;
                }
                if (String.isNotBlank(masData.MASComment)) {
                    quoteLine.SetupComment__c = masData.MASComment;
                }
                quoteLine.BypassPriceReview__c = masData.MASBypassPrice;
                quoteLine.DoNotCreateMASTicket__c = masData.MASDoNotCreate;
                quoteLine.DoNotCreateTaskGridTickets__c = masData.DoNotCreateTaskGridTickets;
                if (String.isNotBlank(masData.VCRCode)) {
                    quoteLine.VCRCode__c = masData.VCRCode;
                }
            }

            // Use DML Service for field-level security check
            QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();
            QuoteProcurementDMLService.DMLResult result = dmlService.updateQuoteLines(quoteLines);

            response.IsSuccess = result.isSuccess;
            response.ErrorMessage = result.isSuccess ? '' : result.message;

        } catch (Exception ex) {
            response.IsSuccess = false;
            response.ErrorMessage = ex.getMessage();
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
        }

        return response;
    }

    // ========================================================================
    // PUBLIC API - BYPASS PRICE REVIEW
    // ========================================================================

    /**
     * @description Determine if price review should be bypassed
     * Delegates to BusinessRuleService
     * @param quoteLineId The QuoteLine ID
     * @param masLibrary The MAS Library code
     * @return Boolean True if bypass enabled
     */
    @AuraEnabled
    public static Boolean shouldBypassPriceReview(Id quoteLineId, String masLibrary) {
        return QuoteProcurementBusinessRuleService.shouldBypassPriceReview(quoteLineId, masLibrary);
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================

    /**
     * @description Get MAS line of business from product family
     * @param productFamily The product family
     * @return String Line of business code
     */
    private static String getLineOfBusiness(String productFamily) {
        if (productFamily == Constant_Util.ROLLOFF) {
            return 'O';
        } else if (productFamily == Constant_Util.COMMERCIAL) {
            return 'C';
        }
        return null;
    }

    // ========================================================================
    // INNER CLASSES
    // ========================================================================

    /**
     * @description Wrapper for MAS details
     */
    public class MASWrapper {
        @AuraEnabled public String MASLibrary {get; set;}
        @AuraEnabled public String MASCompany {get; set;}
        @AuraEnabled public Decimal MASAccount {get; set;}
        @AuraEnabled public Decimal MASUniqueId {get; set;}
        @AuraEnabled public Decimal MASServiceLine {get; set;}
        @AuraEnabled public String MASBox {get; set;}
        @AuraEnabled public String MASComment {get; set;}
        @AuraEnabled public Boolean MASBypassPrice {get; set;}
        @AuraEnabled public Boolean MASDoNotCreate {get; set;}
        @AuraEnabled public Boolean DoNotCreateTaskGridTickets {get; set;}
        @AuraEnabled public Boolean IsDoNotCreateTaskGridTicketVisible {get; set;}
        @AuraEnabled public String VCRCode {get; set;}
        @AuraEnabled public Integer MASCommentSize {get; set;}
    }

    /**
     * @description Wrapper for MAS update response
     */
    public class MASResponseWrapper {
        @AuraEnabled public Boolean IsSuccess {get; set;}
        @AuraEnabled public String ErrorMessage {get; set;}
    }
}

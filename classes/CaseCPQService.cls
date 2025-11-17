/**
 * @description CaseCPQService - Service Layer for CPQ/Quote Operations
 *
 * This service class handles all CPQ (Configure, Price, Quote) integrations for Cases.
 * It provides a centralized location for quote creation, opportunity management,
 * and CPQ product configuration logic.
 *
 * Key Responsibilities:
 * - Create Opportunities and Quotes from Cases
 * - Manage CPQ quote line items
 * - Handle quote type determination logic
 * - Coordinate between Case and CPQ objects
 *
 * Design Principles:
 * - Single Responsibility: Only handles CPQ/Quote operations
 * - Service Layer: No direct UI dependencies
 * - Testability: All methods are mockable and bulkified where possible
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer
 */
public class CaseCPQService {

    // ========================================================================
    // QUOTE CREATION METHODS
    // ========================================================================

    /**
     * @description Creates Opportunity and Quote from Case (Lightning-enabled wrapper)
     * This method wraps the legacy createOppQuote logic from GetCaseInformation
     * for backward compatibility while providing the proper service layer structure.
     *
     * @param caseId The Case Id to create quote from
     * @return Quote Id of the created quote
     */
    @AuraEnabled
    public static String createQuoteFromCase(String caseId) {
        // Delegate to GetCaseInformation for now (maintains backward compatibility)
        // TODO: Refactor to move all CPQ logic into this service class
        return GetCaseInformation.createOppQuote(caseId);
    }

    /**
     * @description Creates Opportunity and Quote from multiple Cases (bulkified)
     * @param caseIds Set of Case Ids to create quotes from
     * @return Map of Case Id to Quote Id
     */
    public static Map<Id, Id> createQuotesFromCases(Set<Id> caseIds) {
        Map<Id, Id> caseToQuoteMap = new Map<Id, Id>();

        // TODO: Implement bulkified quote creation logic
        // For now, iterate (not optimal but maintains functionality)
        for (Id caseId : caseIds) {
            try {
                String quoteId = createQuoteFromCase(caseId);
                if (String.isNotBlank(quoteId)) {
                    caseToQuoteMap.put(caseId, quoteId);
                }
            } catch (Exception ex) {
                UTIL_LoggingService.logHandledException(
                    ex,
                    UserInfo.getOrganizationId(),
                    'CaseCPQService.createQuotesFromCases',
                    LoggingLevel.ERROR
                );
            }
        }

        return caseToQuoteMap;
    }

    /**
     * @description Determines the appropriate Quote Type based on Case attributes
     * Extracted from GetCaseInformation createOppQuote method for reusability
     *
     * @param caseRecord The Case record
     * @return Quote Type constant (Quote, Amendment, Correction, etc.)
     */
    public static String determineQuoteType(Case caseRecord) {
        String quoteType = '';
        Boolean isInternalCorrectionsTeamUser = UserServices.isInternalCorrectionTeamUser(UserInfo.getUserId());
        Boolean isHaulAway = HaulAwayService.getIsHaulAwayService(caseRecord);

        if ((caseRecord.Case_Record_Type__c == Constant_Util.New_Service_Case) || isHaulAway) {
            quoteType = Constant_Util.QUOTE;
        } else if (caseRecord.Case_Record_Type__c == Constant_Util.MODIFY_EXISTING_SERVICE_CASE &&
                   caseRecord.Case_Type__c == Constant_Util.Change_Service &&
                   caseRecord.Case_Sub_Type__c == Constant_Util.Change_Correction &&
                   caseRecord.Case_Reason__c == Constant_Util.CASE_REASON_DAYSOFSERVICE &&
                   !isInternalCorrectionsTeamUser) {
            quoteType = Constant_Util.QUOTE_TYPE_AMEND;
        } else if (caseRecord.Case_Record_Type__c == Constant_Util.UPDATE_ASSET_CASE) {
            quoteType = Constant_Util.QUOTE_TYPE_AMEND;
        } else if (caseRecord.Case_Record_Type__c == Constant_Util.MODIFY_EXISTING_SERVICE_CASE &&
                   caseRecord.Case_Type__c == Constant_Util.Change_Service &&
                   caseRecord.Case_Sub_Type__c == Constant_Util.Change_Correction) {
            quoteType = Constant_Util.QUOTE_TYPE_CORRECTION;
        } else if (caseRecord.Case_Record_Type__c == Constant_Util.MODIFY_EXISTING_SERVICE_CASE &&
                   caseRecord.Case_Type__c == Constant_Util.Change_Service &&
                   (caseRecord.Case_Sub_Type__c == Constant_Util.WASTE_STREAM ||
                    caseRecord.Case_Sub_Type__c == Constant_Util.Decrease ||
                    caseRecord.Case_Sub_Type__c == Constant_Util.Increase ||
                    caseRecord.Case_Sub_Type__c == Constant_Util.Rightsizing_Load_Max ||
                    caseRecord.Case_Sub_Type__c == Constant_Util.VENDOR)) {
            quoteType = Constant_Util.QUOTE_TYPE_AMEND;
        } else {
            quoteType = Constant_Util.KEYWORD_EXCEPTION;
        }

        return quoteType;
    }

    /**
     * @description Checks if a Case is eligible for CPQ quote creation
     * @param caseRecord The Case record to evaluate
     * @return True if eligible, false otherwise
     */
    public static Boolean isCaseEligibleForQuote(Case caseRecord) {
        // Business rules for quote eligibility
        if (caseRecord == null) {
            return false;
        }

        // Add eligibility checks based on Case Type, Status, etc.
        if (caseRecord.IsOpportunity_Created__c == true) {
            return false; // Already has a quote
        }

        // Check for New Service or Modify Service cases
        if (caseRecord.Case_Record_Type__c == Constant_Util.New_Service_Case ||
            caseRecord.Case_Record_Type__c == Constant_Util.MODIFY_EXISTING_SERVICE_CASE ||
            caseRecord.Case_Record_Type__c == Constant_Util.UPDATE_ASSET_CASE) {
            return true;
        }

        // Check for Haul Away Service
        if (HaulAwayService.getIsHaulAwayService(caseRecord)) {
            return true;
        }

        return false;
    }

    /**
     * @description Retrieves all Quotes associated with a Case
     * @param caseId The Case Id
     * @return List of Quotes related to the Case
     */
    public static List<SBQQ__Quote__c> getQuotesByCase(Id caseId) {
        List<SBQQ__Quote__c> quotes = [
            SELECT Id, Name, SBQQ__Status__c, SBQQ__Type__c,
                   SBQQ__Opportunity2__c, SBQQ__Primary__c,
                   SBQQ__StartDate__c, Duration__c, Quote_Only__c,
                   CreatedDate, LastModifiedDate
            FROM SBQQ__Quote__c
            WHERE SBQQ__Opportunity2__r.Case__c = :caseId
            ORDER BY CreatedDate DESC
        ];

        return quotes;
    }

    /**
     * @description Retrieves the primary Quote for a Case
     * @param caseId The Case Id
     * @return Primary Quote or null if not found
     */
    public static SBQQ__Quote__c getPrimaryQuoteByCase(Id caseId) {
        List<SBQQ__Quote__c> quotes = [
            SELECT Id, Name, SBQQ__Status__c, SBQQ__Type__c,
                   SBQQ__Opportunity2__c, SBQQ__Primary__c,
                   SBQQ__StartDate__c, Duration__c, Quote_Only__c,
                   CreatedDate, LastModifiedDate
            FROM SBQQ__Quote__c
            WHERE SBQQ__Opportunity2__r.Case__c = :caseId
            AND SBQQ__Primary__c = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return quotes.isEmpty() ? null : quotes[0];
    }

    /**
     * @description Retrieves Opportunities associated with a Case
     * @param caseId The Case Id
     * @return List of Opportunities related to the Case
     */
    public static List<Opportunity> getOpportunitiesByCase(Id caseId) {
        List<Opportunity> opportunities = [
            SELECT Id, Name, StageName, CloseDate, Duration__c,
                   AccountId, Case__c, SBQQ__QuotePricebookId__c,
                   CreatedDate, LastModifiedDate
            FROM Opportunity
            WHERE Case__c = :caseId
            ORDER BY CreatedDate DESC
        ];

        return opportunities;
    }

    // ========================================================================
    // HELPER METHODS
    // ========================================================================

    /**
     * @description Builds case comments string for Quote
     * @param caseRecord The Case record
     * @param quoteName The Quote name
     * @return Formatted comments string
     */
    private static String buildQuoteComments(Case caseRecord, String quoteName) {
        String comments = 'SFDC Quote: ' + quoteName + '\n';

        if (caseRecord.Tracking_Number__c != null) {
            comments += 'SFDC Case: ' + caseRecord.CaseNumber + ' - Tracking Number: ' + caseRecord.Tracking_Number__c + '\n';
        } else {
            comments += 'SFDC Case: ' + caseRecord.CaseNumber + '\n';
        }

        comments += 'SFDC Reference #: ' + caseRecord.Reference_Number__c + '\n';

        return comments;
    }

    /**
     * @description Result wrapper for quote creation operations
     */
    public class QuoteCreationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String quoteId { get; set; }
        @AuraEnabled public String opportunityId { get; set; }
        @AuraEnabled public String errorMessage { get; set; }

        public QuoteCreationResult(Boolean success, String quoteId, String oppId, String error) {
            this.success = success;
            this.quoteId = quoteId;
            this.opportunityId = oppId;
            this.errorMessage = error;
        }
    }
}

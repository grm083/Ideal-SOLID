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
     * @description Creates Opportunity and Quote from Case
     * REFACTORED (Phase 5C): Moved from GetCaseInformation.createOppQuote()
     * This method contains the full CPQ quote creation logic that was previously
     * scattered in GetCaseInformation.
     *
     * @param caseId The Case Id to create quote from
     * @return Quote Id of the created quote
     * @throws Exception if quote creation fails
     */
    @AuraEnabled
    public static String createQuoteFromCase(String caseId) {
        Opportunity opp = new Opportunity();
        String quoteStatus;

        // Query Case with all required fields
        Case c = [
            SELECT Id, Status, AssetId, Asset.Duration__c, Location__c, ContactId,
                   CaseNumber, Service_Date__c, Case_Sub_Type__c, Case_Reason__c,
                   Reference_Number__c, Tracking_Number__c, Integrate_with_Acorn__c,
                   Case_Type__c, Case_Record_Type__c, Quote_Only__c,
                   Is_Haul_Away_Service__c, Haul_Away_information__c, Haul_Away_Vendor__c
            FROM Case
            WHERE Id = :caseId
        ];

        // Query Location details
        Account loc = [
            SELECT Id, Primary_Segment__c, ShippingStreet, ShippingCity,
                   ShippingState, ShippingPostalCode
            FROM Account
            WHERE Id = :c.Location__c
        ];

        // Check if this is Haul Away service
        Boolean isHaulAway = HaulAwayService.getIsHaulAwayService(c);

        // Build Opportunity
        opp.Name = c.CaseNumber;
        opp.AccountId = loc.Id;
        opp.StageName = Constant_Util.PRODUCT_CONFIGURATION;
        opp.CloseDate = Date.today() + 4;
        opp.SBQQ__QuotePricebookId__c = [
            SELECT Id
            FROM PriceBook2
            WHERE Name = 'Standard Price Book'
            LIMIT 1
        ].Id;
        opp.Case__c = c.Id;

        // Set Duration based on service type
        if (isHaulAway) {
            opp.Duration__c = 'Temporary';
        } else if (!String.isEmpty(c.Case_Type__c) && c.Case_Type__c == Constant_Util.NEW_SERVICE) {
            opp.Duration__c = c.Case_Sub_Type__c;
        } else {
            opp.Duration__c = c.Asset.Duration__c != null ? c.Asset.Duration__c : c.Case_Sub_Type__c;
        }

        // Insert Opportunity
        try {
            if (opp != null) {
                insert opp;
            }
        } catch (DmlException e) {
            System.debug('Error creating Opportunity: ' + e.getMessage());
            throw e;
        }

        // Build Quote
        SBQQ__Quote__c q = new SBQQ__Quote__c();
        q.SBQQ__Opportunity2__c = opp.Id;
        q.SBQQ__Account__c = loc.Id;
        q.SBQQ__Primary__c = true;
        q.SBQQ__StartDate__c = c.Service_Date__c;
        q.SBQQ__ShippingStreet__c = loc.ShippingStreet;
        q.SBQQ__ShippingCity__c = loc.ShippingCity;
        q.SBQQ__ShippingState__c = loc.ShippingState;
        q.SBQQ__ShippingPostalCode__c = loc.ShippingPostalCode;
        q.SBQQ__PrimaryContact__c = c.ContactId;
        q.Duration__c = opp.Duration__c;
        q.Quote_Only__c = c.Quote_Only__c;

        // Determine Quote Type
        String quoteTypeConst = determineQuoteType(c);

        // Get Quote Type picklist values
        Schema.DescribeFieldResult quoteTypeDesc = SBQQ__Quote__c.SBQQ__Type__c.getDescribe();
        List<Schema.PicklistEntry> quoteTypes = quoteTypeDesc.getPicklistValues();

        Map<String, String> typePLMap = new Map<String, String>();
        for (Schema.PicklistEntry plEntry : quoteTypes) {
            if (plEntry.isActive()) {
                typePLMap.put(plEntry.getValue(), plEntry.getLabel());
            }
        }

        if (typePLMap.containsKey(quoteTypeConst)) {
            q.SBQQ__Type__c = typePLMap.get(quoteTypeConst);
        }

        // Insert Quote
        try {
            if (q != null) {
                insert q;
            }

            // Query back the Quote to get Name
            SBQQ__Quote__c quote = [
                SELECT Id, Name
                FROM SBQQ__Quote__c
                WHERE Id = :q.Id
            ];

            // Build case comments
            String sComments = buildQuoteComments(c, quote.Name);
            q.Case_Comments__c = sComments;

            // Update Quote with comments
            if (q != null) {
                update q;
            }

            // Update Case
            c.IsOpportunity_Created__c = true;
            c.Integrate_with_Acorn__c = false;
            c.Status = Constant_Util.OPEN;
            c.Master_Intake_Complete__c = true;

            // Haul Away specific fields
            if (isHaulAway) {
                c.Material_Grade__c = 'No Grade';
                c.Material_Type__c = Constant_Util.BULK_MATERIAL_PRODUCTCODE;
                c.Equipment_Type_Code__c = 'UNK';
                c.Equipment_Size_Code__c = 'UNK';
                c.Service_Occurrence_Type_Code__c = 'OC';
            }

            // Update Case
            if (c != null) {
                update c;

                // Haul Away quote line creation
                if (isHaulAway) {
                    Map<String, SObject> returnMap = new Map<String, SObject>();
                    returnMap.put(String.valueOf(c.Id), (SObject) c);
                    returnMap.put(String.valueOf(q.Id), (SObject) q);
                    QuoteLineCreationHandler.execute(returnMap);
                }
            }

        } catch (Exception e) {
            System.debug('Error creating Quote: ' + e.getMessage());
            throw e;
        }

        return q.Id;
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

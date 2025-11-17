/**
 * @description QuoteProcurementDMLService - Data persistence layer for Quote Procurement operations
 *
 * This service centralizes all DML operations (insert, update, delete, upsert) for QuoteLines,
 * Quotes, Quote Orders, and related objects. It provides consistent error handling, logging,
 * and support for partial success scenarios.
 *
 * Key Responsibilities:
 * - All DML operations for procurement-related objects
 * - Consistent error handling and logging
 * - Support for partial success with Database.SaveResult
 * - Field-level security enforcement
 * - Governor limit-aware bulk operations
 *
 * Architecture:
 * - Singleton pattern for consistent configuration
 * - DMLResult wrapper for standardized responses
 * - Integration with UTIL_LoggingService
 * - Support for both all-or-nothing and partial success modes
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Data Persistence
 */
public inherited sharing class QuoteProcurementDMLService {

    // ========================================================================
    // SINGLETON PATTERN
    // ========================================================================

    private static QuoteProcurementDMLService instance;
    private Database.DMLOptions dmlOpts;

    /**
     * @description Private constructor for singleton
     */
    private QuoteProcurementDMLService() {
        // Initialize DML options
        dmlOpts = new Database.DMLOptions();
        dmlOpts.optAllOrNone = false; // Allow partial success
    }

    /**
     * @description Get singleton instance
     * @return QuoteProcurementDMLService The singleton instance
     */
    public static QuoteProcurementDMLService getInstance() {
        if (instance == null) {
            instance = new QuoteProcurementDMLService();
        }
        return instance;
    }

    // ========================================================================
    // PUBLIC API - QUOTELINE DML OPERATIONS
    // ========================================================================

    /**
     * @description Insert QuoteLines with error handling
     * @param quoteLines List of QuoteLines to insert
     * @return DMLResult Result of the operation
     */
    public DMLResult insertQuoteLines(List<SBQQ__QuoteLine__c> quoteLines) {
        if (quoteLines == null || quoteLines.isEmpty()) {
            return new DMLResult(true, 'No records to insert', 0, 0);
        }

        try {
            Database.SaveResult[] saveResults = Database.insert(quoteLines, dmlOpts);
            return processSaveResults(saveResults, quoteLines, 'INSERT QuoteLine');
        } catch (Exception ex) {
            return handleException(ex, 'insertQuoteLines', quoteLines.size());
        }
    }

    /**
     * @description Update QuoteLines with error handling
     * @param quoteLines List of QuoteLines to update
     * @return DMLResult Result of the operation
     */
    public DMLResult updateQuoteLines(List<SBQQ__QuoteLine__c> quoteLines) {
        if (quoteLines == null || quoteLines.isEmpty()) {
            return new DMLResult(true, 'No records to update', 0, 0);
        }

        try {
            // Check field-level security
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                quoteLines
            );

            if (decision.getRemovedFields().size() > 0) {
                return new DMLResult(false,
                    'You do not have access to update all required fields',
                    0, quoteLines.size());
            }

            Database.SaveResult[] saveResults = Database.update(decision.getRecords(), dmlOpts);
            return processSaveResults(saveResults, decision.getRecords(), 'UPDATE QuoteLine');
        } catch (Exception ex) {
            return handleException(ex, 'updateQuoteLines', quoteLines.size());
        }
    }

    /**
     * @description Delete QuoteLines with error handling
     * @param quoteLines List of QuoteLines to delete
     * @return DMLResult Result of the operation
     */
    public DMLResult deleteQuoteLines(List<SBQQ__QuoteLine__c> quoteLines) {
        if (quoteLines == null || quoteLines.isEmpty()) {
            return new DMLResult(true, 'No records to delete', 0, 0);
        }

        try {
            Database.DeleteResult[] deleteResults = Database.delete(quoteLines, false);
            return processDeleteResults(deleteResults, quoteLines, 'DELETE QuoteLine');
        } catch (Exception ex) {
            return handleException(ex, 'deleteQuoteLines', quoteLines.size());
        }
    }

    /**
     * @description Upsert QuoteLines with error handling
     * @param quoteLines List of QuoteLines to upsert
     * @return DMLResult Result of the operation
     */
    public DMLResult upsertQuoteLines(List<SBQQ__QuoteLine__c> quoteLines) {
        if (quoteLines == null || quoteLines.isEmpty()) {
            return new DMLResult(true, 'No records to upsert', 0, 0);
        }

        try {
            Database.UpsertResult[] upsertResults = Database.upsert(quoteLines, false);
            return processUpsertResults(upsertResults, quoteLines, 'UPSERT QuoteLine');
        } catch (Exception ex) {
            return handleException(ex, 'upsertQuoteLines', quoteLines.size());
        }
    }

    // ========================================================================
    // PUBLIC API - QUOTE DML OPERATIONS
    // ========================================================================

    /**
     * @description Update Quotes with error handling
     * @param quotes List of Quotes to update
     * @return DMLResult Result of the operation
     */
    public DMLResult updateQuotes(List<SBQQ__Quote__c> quotes) {
        if (quotes == null || quotes.isEmpty()) {
            return new DMLResult(true, 'No records to update', 0, 0);
        }

        try {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                quotes
            );

            if (decision.getRemovedFields().size() > 0) {
                return new DMLResult(false,
                    'You do not have access to update all required fields',
                    0, quotes.size());
            }

            Database.SaveResult[] saveResults = Database.update(decision.getRecords(), dmlOpts);
            return processSaveResults(saveResults, decision.getRecords(), 'UPDATE Quote');
        } catch (Exception ex) {
            return handleException(ex, 'updateQuotes', quotes.size());
        }
    }

    // ========================================================================
    // PUBLIC API - QUOTE ORDER DML OPERATIONS
    // ========================================================================

    /**
     * @description Insert Quote Orders with error handling
     * @param quoteOrders List of Quote Orders to insert
     * @return DMLResult Result of the operation
     */
    public DMLResult insertQuoteOrders(List<Quote_Order__c> quoteOrders) {
        if (quoteOrders == null || quoteOrders.isEmpty()) {
            return new DMLResult(true, 'No records to insert', 0, 0);
        }

        try {
            Database.SaveResult[] saveResults = Database.insert(quoteOrders, dmlOpts);
            return processSaveResults(saveResults, quoteOrders, 'INSERT Quote_Order');
        } catch (Exception ex) {
            return handleException(ex, 'insertQuoteOrders', quoteOrders.size());
        }
    }

    /**
     * @description Delete Quote Orders with error handling
     * Refactored from: deleteQuoteOrders() in QuoteProcurementController
     * @param quoteOrders List of Quote Orders to delete
     * @return DMLResult Result of the operation
     */
    public DMLResult deleteQuoteOrders(List<Quote_Order__c> quoteOrders) {
        if (quoteOrders == null || quoteOrders.isEmpty()) {
            return new DMLResult(true, 'No records to delete', 0, 0);
        }

        try {
            Database.DeleteResult[] deleteResults = Database.delete(quoteOrders, false);
            return processDeleteResults(deleteResults, quoteOrders, 'DELETE Quote_Order');
        } catch (Exception ex) {
            return handleException(ex, 'deleteQuoteOrders', quoteOrders.size());
        }
    }

    // ========================================================================
    // PUBLIC API - ACCOUNT POSITION DML OPERATIONS
    // ========================================================================

    /**
     * @description Insert Account Positions with error handling
     * @param positions List of Account Positions to insert
     * @return DMLResult Result of the operation
     */
    public DMLResult insertAccountPositions(List<Account_Position__c> positions) {
        if (positions == null || positions.isEmpty()) {
            return new DMLResult(true, 'No records to insert', 0, 0);
        }

        try {
            Database.SaveResult[] saveResults = Database.insert(positions, dmlOpts);
            return processSaveResults(saveResults, positions, 'INSERT Account_Position');
        } catch (Exception ex) {
            return handleException(ex, 'insertAccountPositions', positions.size());
        }
    }

    // ========================================================================
    // PUBLIC API - BULK UPDATE OPERATIONS
    // ========================================================================

    /**
     * @description Update vendor details for a QuoteLine bundle
     * Refactored from: updateVendorDetails() in QuoteProcurementController
     * @param parentQuoteLineId The parent QuoteLine ID
     * @param vendorId The Vendor Account ID
     * @param sCode The s-code value
     * @return DMLResult Result of the operation
     */
    public DMLResult updateVendorDetails(Id parentQuoteLineId, Id vendorId, String sCode) {
        try {
            List<SBQQ__QuoteLine__c> quoteLines = QuoteProcurementContextGetter.getQuoteLinesByParentId(parentQuoteLineId);

            for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
                quoteLine.Vendor__c = vendorId;
                quoteLine.sCode__c = sCode;
            }

            return updateQuoteLines(quoteLines);
        } catch (Exception ex) {
            return handleException(ex, 'updateVendorDetails', 1);
        }
    }

    /**
     * @description Update company categories for a QuoteLine bundle
     * Refactored from: updateCompanyCategories() in QuoteProcurementController
     * @param parentQuoteLineId The parent QuoteLine ID
     * @param companyCategory The company category code
     * @return DMLResult Result of the operation
     */
    public DMLResult updateCompanyCategories(Id parentQuoteLineId, String companyCategory) {
        try {
            List<SBQQ__QuoteLine__c> quoteLines = QuoteProcurementContextGetter.getQuoteLinesByParentId(parentQuoteLineId);

            for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
                quoteLine.CompanyCategoryCode__c = companyCategory;
            }

            return updateQuoteLines(quoteLines);
        } catch (Exception ex) {
            return handleException(ex, 'updateCompanyCategories', 1);
        }
    }

    /**
     * @description Update financial details for a QuoteLine bundle
     * Refactored from: updateFinancialDetail() in QuoteProcurementController
     * @param parentQuoteLineId The parent QuoteLine ID
     * @param isQuoteOnly Whether quote is quote-only
     * @param companyCategory Company category code
     * @param companyCategoryName Company category name
     * @param generalLedgerNo GL account number
     * @param customerCostCenter Customer cost center
     * @return DMLResult Result of the operation
     */
    public DMLResult updateFinancialDetails(Id parentQuoteLineId, Boolean isQuoteOnly,
                                           String companyCategory, String companyCategoryName,
                                           String generalLedgerNo, String customerCostCenter) {
        try {
            List<SBQQ__QuoteLine__c> quoteLines = [SELECT Id, SBQQ__Quote__c,
                                                          CompanyCategoryCode__c,
                                                          CompanyCategoryName__c,
                                                          ClientGLAccount__c,
                                                          ClientCostCenter__c
                                                    FROM SBQQ__QuoteLine__c
                                                    WHERE SBQQ__RequiredBy__c = :parentQuoteLineId];

            List<SObject> recordsToUpdate = new List<SObject>();

            // Update child QuoteLines
            for (SBQQ__QuoteLine__c ql : quoteLines) {
                if (String.isNotBlank(companyCategoryName) && String.isNotBlank(companyCategory)) {
                    ql.CompanyCategoryCode__c = companyCategory;
                    ql.CompanyCategoryName__c = companyCategoryName;
                }
                ql.ClientGLAccount__c = generalLedgerNo;
                ql.ClientCostCenter__c = customerCostCenter;
                recordsToUpdate.add(ql);
            }

            // Update parent QuoteLine
            SBQQ__QuoteLine__c parentQL = new SBQQ__QuoteLine__c(Id = parentQuoteLineId);
            if (String.isNotBlank(companyCategoryName) && String.isNotBlank(companyCategory)) {
                parentQL.CompanyCategoryCode__c = companyCategory;
                parentQL.CompanyCategoryName__c = companyCategoryName;
            }
            parentQL.ClientGLAccount__c = generalLedgerNo;
            parentQL.ClientCostCenter__c = customerCostCenter;
            recordsToUpdate.add(parentQL);

            // Update Quote
            if (!quoteLines.isEmpty()) {
                SBQQ__Quote__c quote = new SBQQ__Quote__c(
                    Id = quoteLines[0].SBQQ__Quote__c,
                    Quote_Only__c = isQuoteOnly
                );
                recordsToUpdate.add(quote);
            }

            Database.SaveResult[] saveResults = Database.update(recordsToUpdate, false);
            return processSaveResults(saveResults, recordsToUpdate, 'UPDATE Financial Details');
        } catch (Exception ex) {
            return handleException(ex, 'updateFinancialDetails', 1);
        }
    }

    /**
     * @description Update position on QuoteLines
     * Refactored from: updateALPOnQuoteLine() in QuoteProcurementController
     * @param parentQuoteLineId The parent QuoteLine ID
     * @param positionId The Account Position ID
     * @param setupComments Setup comments
     * @param isOffsite Whether position is offsite
     * @return DMLResult Result of the operation
     */
    public DMLResult updatePositionOnQuoteLines(Id parentQuoteLineId, Id positionId,
                                               String setupComments, Boolean isOffsite) {
        try {
            List<SBQQ__QuoteLine__c> quoteLines = QuoteProcurementContextGetter.getQuoteLinesForPosition(parentQuoteLineId);
            List<SBQQ__QuoteLine__c> upsertList = new List<SBQQ__QuoteLine__c>();

            for (SBQQ__QuoteLine__c qLine : quoteLines) {
                SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c();
                ql.Id = qLine.Id;
                ql.Location_Position_Name__c = positionId;
                ql.LocationPositionName__c = setupComments;

                if (isOffsite) {
                    ql.SetupComment__c = setupComments;
                }

                upsertList.add(ql);
            }

            return updateQuoteLines(upsertList);
        } catch (Exception ex) {
            return handleException(ex, 'updatePositionOnQuoteLines', 1);
        }
    }

    // ========================================================================
    // PRIVATE HELPER METHODS - RESULT PROCESSING
    // ========================================================================

    /**
     * @description Process Database.SaveResult[] and create DMLResult
     * @param saveResults Array of SaveResults
     * @param records List of records processed
     * @param operation Description of operation
     * @return DMLResult Processed result
     */
    private DMLResult processSaveResults(Database.SaveResult[] saveResults,
                                        List<SObject> records,
                                        String operation) {
        Integer successCount = 0;
        Integer failureCount = 0;
        List<DMLError> errors = new List<DMLError>();

        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult sr = saveResults[i];
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                for (Database.Error err : sr.getErrors()) {
                    DMLError dmlError = new DMLError(
                        records[i].Id,
                        records[i].getSObjectType().getDescribe().getName(),
                        err.getStatusCode().name(),
                        err.getMessage(),
                        err.getFields()
                    );
                    errors.add(dmlError);

                    // Log error
                    logDMLError(operation, dmlError);
                }
            }
        }

        Boolean isSuccess = (failureCount == 0);
        String message = isSuccess ?
            operation + ' completed successfully' :
            operation + ' completed with ' + failureCount + ' error(s)';

        DMLResult result = new DMLResult(isSuccess, message, successCount, failureCount);
        result.errors = errors;

        return result;
    }

    /**
     * @description Process Database.DeleteResult[] and create DMLResult
     * @param deleteResults Array of DeleteResults
     * @param records List of records processed
     * @param operation Description of operation
     * @return DMLResult Processed result
     */
    private DMLResult processDeleteResults(Database.DeleteResult[] deleteResults,
                                          List<SObject> records,
                                          String operation) {
        Integer successCount = 0;
        Integer failureCount = 0;
        List<DMLError> errors = new List<DMLError>();

        for (Integer i = 0; i < deleteResults.size(); i++) {
            Database.DeleteResult dr = deleteResults[i];
            if (dr.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                for (Database.Error err : dr.getErrors()) {
                    DMLError dmlError = new DMLError(
                        records[i].Id,
                        records[i].getSObjectType().getDescribe().getName(),
                        err.getStatusCode().name(),
                        err.getMessage(),
                        err.getFields()
                    );
                    errors.add(dmlError);

                    // Log error
                    logDMLError(operation, dmlError);
                }
            }
        }

        Boolean isSuccess = (failureCount == 0);
        String message = isSuccess ?
            operation + ' completed successfully' :
            operation + ' completed with ' + failureCount + ' error(s)';

        DMLResult result = new DMLResult(isSuccess, message, successCount, failureCount);
        result.errors = errors;

        return result;
    }

    /**
     * @description Process Database.UpsertResult[] and create DMLResult
     * @param upsertResults Array of UpsertResults
     * @param records List of records processed
     * @param operation Description of operation
     * @return DMLResult Processed result
     */
    private DMLResult processUpsertResults(Database.UpsertResult[] upsertResults,
                                          List<SObject> records,
                                          String operation) {
        Integer successCount = 0;
        Integer failureCount = 0;
        List<DMLError> errors = new List<DMLError>();

        for (Integer i = 0; i < upsertResults.size(); i++) {
            Database.UpsertResult ur = upsertResults[i];
            if (ur.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                for (Database.Error err : ur.getErrors()) {
                    DMLError dmlError = new DMLError(
                        records[i].Id,
                        records[i].getSObjectType().getDescribe().getName(),
                        err.getStatusCode().name(),
                        err.getMessage(),
                        err.getFields()
                    );
                    errors.add(dmlError);

                    // Log error
                    logDMLError(operation, dmlError);
                }
            }
        }

        Boolean isSuccess = (failureCount == 0);
        String message = isSuccess ?
            operation + ' completed successfully' :
            operation + ' completed with ' + failureCount + ' error(s)';

        DMLResult result = new DMLResult(isSuccess, message, successCount, failureCount);
        result.errors = errors;

        return result;
    }

    /**
     * @description Handle exceptions and create DMLResult
     * @param ex The exception
     * @param methodName The method where exception occurred
     * @param recordCount Number of records affected
     * @return DMLResult Error result
     */
    private DMLResult handleException(Exception ex, String methodName, Integer recordCount) {
        // Log exception
        UTIL_LoggingService.logHandledException(
            ex,
            UserInfo.getOrganizationId(),
            UTIL_ErrorConstants.ERROR_APPLICATION,
            LoggingLevel.ERROR
        );

        DMLError dmlError = new DMLError(
            null,
            'Unknown',
            ex.getTypeName(),
            ex.getMessage(),
            new List<String>()
        );

        DMLResult result = new DMLResult(false, ex.getMessage(), 0, recordCount);
        result.errors = new List<DMLError>{dmlError};

        return result;
    }

    /**
     * @description Log DML error using logging service
     * @param operation The operation being performed
     * @param error The DML error
     */
    private void logDMLError(String operation, DMLError error) {
        String errorMessage = operation + ' failed for ' + error.objectType +
                             ' (ID: ' + error.recordId + '): ' + error.message;

        System.debug(LoggingLevel.ERROR, errorMessage);

        // Could integrate with UTIL_LoggingService for persistent logging if needed
    }

    // ========================================================================
    // INNER CLASSES
    // ========================================================================

    /**
     * @description Wrapper class for DML operation results
     */
    public class DMLResult {
        @AuraEnabled public Boolean isSuccess {get; set;}
        @AuraEnabled public String message {get; set;}
        @AuraEnabled public Integer successCount {get; set;}
        @AuraEnabled public Integer failureCount {get; set;}
        @AuraEnabled public List<DMLError> errors {get; set;}

        public DMLResult(Boolean isSuccess, String message, Integer successCount, Integer failureCount) {
            this.isSuccess = isSuccess;
            this.message = message;
            this.successCount = successCount;
            this.failureCount = failureCount;
            this.errors = new List<DMLError>();
        }
    }

    /**
     * @description Wrapper class for individual DML errors
     */
    public class DMLError {
        @AuraEnabled public Id recordId {get; set;}
        @AuraEnabled public String objectType {get; set;}
        @AuraEnabled public String statusCode {get; set;}
        @AuraEnabled public String message {get; set;}
        @AuraEnabled public List<String> fields {get; set;}

        public DMLError(Id recordId, String objectType, String statusCode,
                       String message, List<String> fields) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.statusCode = statusCode;
            this.message = message;
            this.fields = fields;
        }
    }
}

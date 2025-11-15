/**
* @description Service class for all Case DML operations
* Follows Single Responsibility Principle - only handles data persistence
* Isolates all Case DML into a single, dedicated class for improved transaction management,
* easier debugging, improved security, and reduced code redundancy
* @author Refactoring Team
* @date 2024
*/
public inherited sharing class CaseDMLService {
    
    private static CaseDMLService instance;
    
    // DML Options configuration
    private Database.DMLOptions dmlOpts;
    
    /**
    * @description Get singleton instance
    * @return CaseDMLService instance
    */
    public static CaseDMLService getInstance() {
        if (instance == null) {
            instance = new CaseDMLService();
        }
        return instance;
    }
    
    /**
    * @description Private constructor for singleton pattern
    */
    private CaseDMLService() {
        this.dmlOpts = new Database.DMLOptions();
        this.dmlOpts.optAllOrNone = false; // Allow partial success
    }
    
    /**
    * @description Constructor for dependency injection (testing)
    * @param contextGetter ContextGetter instance for testing
    */
    @TestVisible
    private CaseDMLService(Database.DMLOptions options) {
        this.dmlOpts = options != null ? options : new Database.DMLOptions();
        if (this.dmlOpts.optAllOrNone == null) {
            this.dmlOpts.optAllOrNone = false;
        }
    }
    
    // ========== INSERT OPERATIONS ==========
    
    /**
    * @description Insert single case with error handling
    * @param caseRecord Case to insert
    * @return DMLResult with success/error information
    */
    public DMLResult insertCase(Case caseRecord) {
        return insertCases(new List<Case>{caseRecord});
    }
    
    /**
    * @description Insert multiple cases with error handling
    * @param cases List of cases to insert
    * @return DMLResult with success/error information
    */
    public DMLResult insertCases(List<Case> cases) {
        DMLResult result = new DMLResult();
        
        if (cases == null || cases.isEmpty()) {
            result.hasErrors = true;
            result.errors.add(new DMLError('No cases provided for insert', null));
            return result;
        }
        
        try {
            Database.SaveResult[] saveResults = Database.insert(cases, dmlOpts);
            result = processSaveResults(saveResults, cases);
            
            // Log errors if any
            if (!result.errors.isEmpty()) {
                UTIL_LoggingService.logDmlResults(
                    saveResults, null, cases, '', 
                    'CaseDMLService', 'insertCases', 
                    'DML Operation', LoggingLevel.ERROR
                );
            }
            
        } catch (Exception ex) {
            result.hasErrors = true;
            result.errors.add(new DMLError(ex.getMessage(), null));
            UTIL_LoggingService.logHandledException(
                ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
        
        return result;
    }
    
    // ========== UPDATE OPERATIONS ==========
    
    /**
    * @description Update single case with error handling
    * @param caseRecord Case to update
    * @return DMLResult with success/error information
    */
    public DMLResult updateCase(Case caseRecord) {
        return updateCases(new List<Case>{caseRecord});
    }
    
    /**
    * @description Update multiple cases with error handling
    * @param cases List of cases to update
    * @return DMLResult with success/error information
    */
    public DMLResult updateCases(List<Case> cases) {
        DMLResult result = new DMLResult();
        
        if (cases == null || cases.isEmpty()) {
            result.hasErrors = true;
            result.errors.add(new DMLError('No cases provided for update', null));
            return result;
        }
        
        try {
            Database.SaveResult[] saveResults = Database.update(cases, dmlOpts);
            result = processSaveResults(saveResults, cases);
            
            // Log errors if any
            if (!result.errors.isEmpty()) {
                UTIL_LoggingService.logDmlResults(
                    saveResults, null, cases, '', 
                    'CaseDMLService', 'updateCases', 
                    'DML Operation', LoggingLevel.ERROR
                );
            }
            
        } catch (Exception ex) {
            result.hasErrors = true;
            result.errors.add(new DMLError(ex.getMessage(), null));
            UTIL_LoggingService.logHandledException(
                ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
        
        return result;
    }
    
    // ========== UPSERT OPERATIONS ==========
    
    /**
    * @description Upsert single case with error handling
    * @param caseRecord Case to upsert
    * @return DMLResult with success/error information
    */
    public DMLResult upsertCase(Case caseRecord) {
        return upsertCases(new List<Case>{caseRecord});
    }
    
    /**
    * @description Upsert multiple cases with error handling
    * @param cases List of cases to upsert
    * @return DMLResult with success/error information
    */
    public DMLResult upsertCases(List<Case> cases) {
        DMLResult result = new DMLResult();
        
        if (cases == null || cases.isEmpty()) {
            result.hasErrors = true;
            result.errors.add(new DMLError('No cases provided for upsert', null));
            return result;
        }
        
        try {
            Database.UpsertResult[] upsertResults = Database.upsert(cases, dmlOpts.optAllOrNone);
            result = processUpsertResults(upsertResults, cases);
            
            // Log errors if any
            if (!result.errors.isEmpty()) {
                UTIL_LoggingService.logDmlResults(
                    null, null, cases, '', 
                    'CaseDMLService', 'upsertCases', 
                    'DML Operation', LoggingLevel.ERROR
                );
            }
            
        } catch (Exception ex) {
            result.hasErrors = true;
            result.errors.add(new DMLError(ex.getMessage(), null));
            UTIL_LoggingService.logHandledException(
                ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
        
        return result;
    }
    
    // ========== DELETE OPERATIONS ==========
    
    /**
    * @description Delete single case with error handling
    * @param caseRecord Case to delete
    * @return DMLResult with success/error information
    */
    public DMLResult deleteCase(Case caseRecord) {
        return deleteCases(new List<Case>{caseRecord});
    }
    
    /**
    * @description Delete multiple cases with error handling
    * @param cases List of cases to delete
    * @return DMLResult with success/error information
    */
    public DMLResult deleteCases(List<Case> cases) {
        DMLResult result = new DMLResult();
        
        if (cases == null || cases.isEmpty()) {
            result.hasErrors = true;
            result.errors.add(new DMLError('No cases provided for delete', null));
            return result;
        }
        
        try {
            Database.DeleteResult[] deleteResults = Database.delete(cases, dmlOpts.optAllOrNone);
            result = processDeleteResults(deleteResults, cases);
            
            // Log errors if any
            if (!result.errors.isEmpty()) {
                UTIL_LoggingService.logDmlResults(
                    null, deleteResults, cases, '', 
                    'CaseDMLService', 'deleteCases', 
                    'DML Operation', LoggingLevel.ERROR
                );
            }
            
        } catch (Exception ex) {
            result.hasErrors = true;
            result.errors.add(new DMLError(ex.getMessage(), null));
            UTIL_LoggingService.logHandledException(
                ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
        
        return result;
    }
    
    // ========== HELPER METHODS ==========
    
    /**
    * @description Process SaveResult array and build DMLResult
    * @param saveResults Array of SaveResult from insert/update
    * @param cases Original list of cases
    * @return DMLResult with processed information
    */
    private DMLResult processSaveResults(Database.SaveResult[] saveResults, List<Case> cases) {
        DMLResult result = new DMLResult();
        
        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult sr = saveResults[i];
            
            if (sr.isSuccess()) {
                result.successIds.add(sr.getId());
            } else {
                result.hasErrors = true;
                for (Database.Error err : sr.getErrors()) {
                    DMLError dmlError = new DMLError(
                        err.getMessage(),
                        cases[i].Id
                    );
                    dmlError.statusCode = String.valueOf(err.getStatusCode());
                    dmlError.fields = err.getFields();
                    result.errors.add(dmlError);
                }
            }
        }
        
        return result;
    }
    
    /**
    * @description Process UpsertResult array and build DMLResult
    * @param upsertResults Array of UpsertResult from upsert
    * @param cases Original list of cases
    * @return DMLResult with processed information
    */
    private DMLResult processUpsertResults(Database.UpsertResult[] upsertResults, List<Case> cases) {
        DMLResult result = new DMLResult();
        
        for (Integer i = 0; i < upsertResults.size(); i++) {
            Database.UpsertResult ur = upsertResults[i];
            
            if (ur.isSuccess()) {
                result.successIds.add(ur.getId());
            } else {
                result.hasErrors = true;
                for (Database.Error err : ur.getErrors()) {
                    DMLError dmlError = new DMLError(
                        err.getMessage(),
                        cases[i].Id
                    );
                    dmlError.statusCode = String.valueOf(err.getStatusCode());
                    dmlError.fields = err.getFields();
                    result.errors.add(dmlError);
                }
            }
        }
        
        return result;
    }
    
    /**
    * @description Process DeleteResult array and build DMLResult
    * @param deleteResults Array of DeleteResult from delete
    * @param cases Original list of cases
    * @return DMLResult with processed information
    */
    private DMLResult processDeleteResults(Database.DeleteResult[] deleteResults, List<Case> cases) {
        DMLResult result = new DMLResult();
        
        for (Integer i = 0; i < deleteResults.size(); i++) {
            Database.DeleteResult dr = deleteResults[i];
            
            if (dr.isSuccess()) {
                result.successIds.add(dr.getId());
            } else {
                result.hasErrors = true;
                for (Database.Error err : dr.getErrors()) {
                    DMLError dmlError = new DMLError(
                        err.getMessage(),
                        cases[i].Id
                    );
                    dmlError.statusCode = String.valueOf(err.getStatusCode());
                    dmlError.fields = err.getFields();
                    result.errors.add(dmlError);
                }
            }
        }
        
        return result;
    }
    
    // ===== RELATED DML OPERATIONS ======
    
    /**
    * @description Creates related records (e.g., Case Comments, initial logs) after Case insertion.
    * Uses the DML options (e.g., optAllOrNone=false) configured on this service instance.
    * @param newCases List of newly inserted Cases (Trigger.new)
    * @return DMLResult Wrapper containing success/failure information.
    */
    public DMLResult createRelatedRecords(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) {
            return new DMLResult();
        }
        
        // List to hold Case Comments to be inserted
        List<CaseComment> commentsToInsert = new List<CaseComment>();
        // List to hold other related records (e.g., Approval_Log__c)
        List<Approval_Log__c> logsToInsert = new List<Approval_Log__c>();
        
        // --- Logic for Creating Related Records ---
        
        for (Case caseRecord : newCases) {
            // ASSUMPTION 1: Create a system-generated Internal Case Comment on creation
            CaseComment newComment = new CaseComment(
                ParentId = caseRecord.Id,
                CommentBody = 'Case created successfully. System attributes initialized by CaseAttributeService.',
                IsPublished = false // Internal comment
            );
            commentsToInsert.add(newComment);
            
            // Placeholder for other initialization (e.g., a required Approval Log)
            /*
            logsToInsert.add(new Approval_Log__c(
            Case__c = caseRecord.Id,
            Status__c = 'Pending Review',
            System_Generated__c = true
            ));
            */
        }
        
        // --- DML Operations ---
        DMLResult combinedResult = new DMLResult();
        
        try {
            if (!commentsToInsert.isEmpty()) {
                Database.SaveResult[] commentResults = Database.insert(commentsToInsert, this.dmlOpts);
                for (Database.SaveResult sr : commentResults) {
                    if (!sr.isSuccess()) {
                        combinedResult.hasErrors = true;
                        // Log the error for the relevant Case ID
                        for(Database.Error err : sr.getErrors()) {
                            combinedResult.errors.add(
                                new DMLError('Case Comment DML Failed: ' + err.getMessage(), sr.getId())
                            );
                        }
                    }
                }
            }
            
            // DML for Approval Logs (Placeholder DML operation)
            if (!logsToInsert.isEmpty()) {
                // Database.insert(logsToInsert, this.dmlOpts);
                // Handle results and add to combinedResult as needed
            }
            
        } catch(Exception ex) {
            // Catch-all for unexpected DML errors, though partial success should handle most
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    'CaseDMLService.createRelatedRecords', LoggingLevel.ERROR);
        }
        
        return combinedResult;
    }
    
    /**
    * @description Updates or creates related records after Case updates based on field changes.
    * @param newCases List of updated Cases (Trigger.new)
    * @param oldMap Map of old Case versions (Trigger.oldMap)
    * @return void (This method focuses on side-effects and internal DML)
    */
    public void updateRelatedRecords(List<Case> newCases, Map<Id, Case> oldMap) {
        if (newCases == null || newCases.isEmpty() || oldMap == null) {
            return;
        }
        
        Set<Id> workOrderIdsToUpdate = new Set<Id>();
        List<CaseComment> commentsToInsert = new List<CaseComment>();
        
        // --- Identify Records to Update/Create ---
        for (Case newCase : newCases) {
            Case oldCase = oldMap.get(newCase.Id);
            
            if (oldCase == null) continue;
            
            // 1. Logic for Propagating Field Changes to Child Records
            // ASSUMPTION 2: Propagate Tracking_Number__c to a custom Work_Order__c object
            if (newCase.Tracking_Number__c != oldCase.Tracking_Number__c && 
                newCase.Work_Order__c != null) {
                    workOrderIdsToUpdate.add(newCase.Work_Order__c);
                }
            
            // 2. Logic for Creating Related Records based on Status Change
            // ASSUMPTION 3: Create a system comment when Status changes to 'Escalated'
            if (newCase.Status == 'Escalated' && oldCase.Status != 'Escalated') {
                commentsToInsert.add(new CaseComment(
                    ParentId = newCase.Id,
                    CommentBody = 'Case status automatically changed to Escalated. Review required.',
                    IsPublished = false // Internal comment
                ));
            }
        }
        
        // --- DML Operations ---
        try {
            // DML for Case Comments
            if (!commentsToInsert.isEmpty()) {
                // Using DML options to allow partial success
                Database.insert(commentsToInsert, this.dmlOpts); 
            }
            
            // DML for Work Order Updates
            if (!workOrderIdsToUpdate.isEmpty()) {
                // Query related Work Orders efficiently
                List<WorkOrder> workOrdersToUpdate = WorkOrderContextGetter.getWorkOrdersByIds(workOrderIdsToUpdate).values();
                
                for (WorkOrder wo : workOrdersToUpdate) {
                    // Find the corresponding Case to get the new Tracking Number
                    // Since this is a service class, we assume a mechanism to map back (e.g., custom relationship field)
                    Case caseWithNewTrackingNumber = [SELECT Tracking_Number__c FROM Case WHERE Work_Order__c = :wo.Id LIMIT 1];
                    wo.CaseId = caseWithNewTrackingNumber.Id;
                }
                
                if (!workOrdersToUpdate.isEmpty()) {
                    // Using DML options to allow partial success
                    Database.update(workOrdersToUpdate, this.dmlOpts); 
                }
            }
            
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    'CaseDMLService.updateRelatedRecords', LoggingLevel.ERROR);
        }
    }
    
    
    // ========== INNER CLASSES ==========
    
    /**
* @description Wrapper class for DML operation results
*/
    public class DMLResult {
        public Boolean hasErrors { get; set; }
        public List<Id> successIds { get; set; }
        public List<DMLError> errors { get; set; }
        
        public DMLResult() {
            this.hasErrors = false;
            this.successIds = new List<Id>();
            this.errors = new List<DMLError>();
        }
        
        /**
* @description Check if the DML operation was successful (no errors occurred)
* Used in refactored code to determine SUCCESS/FAILURE status strings
* @return true if operation succeeded (no errors), false otherwise
*/
        public Boolean isSuccess() {
            return !hasErrors && errors.isEmpty();
        }
        
        /**
* @description Check if all operations were successful
* @return true if all successful, false otherwise
*/
        public Boolean isAllSuccess() {
            return !hasErrors && errors.isEmpty();
        }
        
        /**
* @description Get count of successful operations
* @return Number of successful operations
*/
        public Integer getSuccessCount() {
            return successIds.size();
        }
        
        /**
        * @description Get count of failed operations
        * @return Number of failed operations
        */
        public Integer getErrorCount() {
            return errors.size();
        }
    }
    
    /**
    * @description Wrapper class for individual DML errors
    */
    public class DMLError {
        public String message { get; set; }
        public Id recordId { get; set; }
        public String statusCode { get; set; }
        public List<String> fields { get; set; }
        
        public DMLError(String message, Id recordId) {
            this.message = message;
            this.recordId = recordId;
            this.fields = new List<String>();
        }
    }
}
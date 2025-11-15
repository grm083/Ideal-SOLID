/**
 * @description CaseContextGetter - Data Access Layer for Case Records
 * 
 * This service class acts as the single source of truth for all Case-related queries.
 * It provides optimized, cached data retrieval methods and eliminates redundant SOQL queries
 * throughout the application.
 * 
 * Key Responsibilities:
 * - Execute all Case-related SOQL queries
 * - Cache frequently accessed data to improve performance
 * - Provide consistent field selections across the application
 * - Reduce overall SOQL query count through intelligent data fetching
 * 
 * Design Principles:
 * - Single Responsibility: Only handles data retrieval, no business logic
 * - Performance: Implements caching and bulkification
 * - Consistency: Ensures all queries use the same field sets
 * - Testability: All methods are easily mockable
 * 
 * @author Waste Management
 * @date 2025
 * @group Service Layer
 */
public with sharing class CaseContextGetter {
    
    // ========================================================================
    // CACHE STRUCTURES
    // ========================================================================
    
    /**
     * @description Cache for Case records to avoid redundant queries
     */
    private static Map<Id, Case> caseCache = new Map<Id, Case>();
    
    /**
     * @description Cache for Asset records to avoid redundant queries
     */
    private static Map<Id, Asset> assetCache = new Map<Id, Asset>();
    
    /**
     * @description Cache for Account (Location) records to avoid redundant queries
     */
    private static Map<Id, Account> accountCache = new Map<Id, Account>();
    
    /**
     * @description Cache for BusinessHours mapped by timezone
     */
    private static Map<String, Id> businessHoursCache = new Map<String, Id>();
    
    /**
     * @description Flag to track if caches have been initialized
     */
    private static Boolean cachesInitialized = false;
    
    // ========================================================================
    // FIELD SETS - Consistent field selection across application
    // ========================================================================
    
    /**
     * @description Standard fields to query for Case records
     */
    private static final String CASE_STANDARD_FIELDS = 
        'Id, CaseNumber, Status, Case_Sub_Status__c, RecordTypeId, RecordType.Name, ' +
        'AccountId, Client__c, Client__r.Name, Client__r.Customer_Code__c, Client__r.Primary_Segment__c, ' +
        'Client__r.ParentId, Client__r.Vendor_ID__c, ' +
        'Location__c, Location__r.Name, Location__r.Location_Code__c, Location__r.Location_Type__c, ' +
        'Location__r.tz__Timezone__c, Location__r.tz__Timezone_SFDC__c, Location__r.Brand__c, ' +
        'Location__r.Geography__c, Location__r.Division__c, ' +
        'ContactId, Contact.Name, Contact.Email, Contact.Phone, Contact.MobilePhone, ' +
        'Contact.Preferred_Method__c, Contact.Email_Validated__c, Contact_Title__c, ' +
        'AssetId, Asset.Name, Asset.Acorn_SID__c, ' +
        'Case_Type__c, Case_Sub_Type__c, Case_Reason__c, ' +
        'Service_Date__c, SLA_Service_Date_Time__c, SlaStartDate, ' +
        'Reference_Number__c, ParentId, ' +
        'PurchaseOrder_Number__c, Profile_Number__c, PSI__c, Company_Category__c, Chargeable__c, ' +
        'Origin, CreatedDate, CreatedById, LastModifiedDate, OwnerId, ' +
        'Tracking_Number__c, Work_Order__c, Is_Multiple_Asset__c, ' +
        'Supplier__c, Supplier__r.Name';
    
    /**
     * @description Extended fields for detailed Case queries
     */
    private static final String CASE_EXTENDED_FIELDS = 
        CASE_STANDARD_FIELDS + ', ' +
        'Override_PO_Create_Task__c, Override_Profile_Number_Task__c, Override_Company_Category_Create_Task__c, ' +
        'PSI_Override_Reason__c, PSI_Comments__c, ' +
        'User_Input_Work_Order_Instructions__c, Site_Contact__c, Site_Contact_Phone__c, ' +
        'Show_Multiple_Asset_Cases__c, isMultiCalendarChecked__c, ' +
        'Is_Clone__c, Create_AM_and_PM_Pickups__c, Is_Multivendor__c, ' +
        'Last_Agent_ID__c, Last_Agent_Id_ForTaskAssignment__c, ' +
        'Business_RuleId__c, Required_Information__c, ' +
        'Case_Information__c, Description, Subject, ' +
        'CPQ_New_Service__c, IsOpportunity_Created__c, Case_Record_Type__c';
    
    /**
     * @description Standard fields to query for Asset records
     */
    private static final String ASSET_STANDARD_FIELDS = 
        'Id, Name, Acorn_SID__c, ' +
        'Product2Id, Product2.Name, Product2.ProductCode, Product2.ProductTypeSelected__c, ' +
        'Product2.Family, Product2.Equipment_Type__c, ProductFamily, ' +
        'Duration__c, Occurrence_Type__c, Material_Type__c, Schedule__c, ' +
        'Sensitivity_Code__c, Has_Extra_Pickup__c, Is_Active__c, Is_Core_Service__c, ' +
        'Start_Date__c, End_Date__c, End_Date_Based_on_Project_code__c, ' +
        'Service_Header_Id__c, Service_Type__c, ' +
        'ParentId, RootAssetId, ' +
        'Project_Code__c, Project_Code__r.ProjectCode_Id__c, Project_Code__r.Active__c, ' +
        'Quantity__c, Category__c, Container_Position__c, Equipment_Owner__c, ' +
        'Supplier__c, Supplier__r.Name, Vendor_ID__c, ' +
        'CPQ_Product__c, Active__c';
    
    /**
     * @description Standard fields to query for Account (Location) records
     */
    private static final String ACCOUNT_STANDARD_FIELDS = 
        'Id, Name, AccountNumber, Customer_Code__c, ' +
        'Location_Code__c, Location_Type__c, ' +
        'Brand__c, Geography__c, Division__c, ' +
        'tz__Timezone__c, tz__Timezone_SFDC__c, tz__Local_Time_Short__c, ' +
        'ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry, ' +
        'Phone, Primary_Segment__c, Secondary_Segment__c, ' +
        'ParentId, Vendor_ID__c, Status__c';
    
    // ========================================================================
    // CASE QUERY METHODS
    // ========================================================================
    
    /**
     * @description Retrieves a single Case record by Id with standard fields
     * @param caseId The Case record Id
     * @return Case record with standard fields populated
     */
    public static Case getCaseById(Id caseId) {
        if (caseCache.containsKey(caseId)) {
            return caseCache.get(caseId);
        }
        
        String query = 'SELECT ' + CASE_STANDARD_FIELDS + ' FROM Case WHERE Id = :caseId LIMIT 1';
        List<Case> cases = Database.query(query);
        
        if (!cases.isEmpty()) {
            caseCache.put(caseId, cases[0]);
            return cases[0];
        }
        
        return null;
    }
    
    /**
     * @description Retrieves a single Case record by Id with extended fields
     * @param caseId The Case record Id
     * @return Case record with all fields populated
     */
    public static Case getCaseByIdExtended(Id caseId) {
        String query = 'SELECT ' + CASE_EXTENDED_FIELDS + ' FROM Case WHERE Id = :caseId LIMIT 1';
        List<Case> cases = Database.query(query);
        
        if (!cases.isEmpty()) {
            caseCache.put(caseId, cases[0]);
            return cases[0];
        }
        
        return null;
    }
    
    /**
     * @description Retrieves multiple Case records by Ids with standard fields
     * @param caseIds Set of Case record Ids
     * @return Map of Case Ids to Case records
     */
    public static Map<Id, Case> getCasesByIds(Set<Id> caseIds) {
        Map<Id, Case> results = new Map<Id, Case>();
        Set<Id> idsToQuery = new Set<Id>();
        
        // Check cache first
        for (Id caseId : caseIds) {
            if (caseCache.containsKey(caseId)) {
                results.put(caseId, caseCache.get(caseId));
            } else {
                idsToQuery.add(caseId);
            }
        }
        
        // Query for uncached records
        if (!idsToQuery.isEmpty()) {
            String query = 'SELECT ' + CASE_STANDARD_FIELDS + ' FROM Case WHERE Id IN :idsToQuery';
            List<Case> cases = Database.query(query);
            
            for (Case c : cases) {
                caseCache.put(c.Id, c);
                results.put(c.Id, c);
            }
        }
        
        return results;
    }
    
    /**
     * @description Retrieves Cases by Reference Number
     * @param referenceNumber The reference number to search for
     * @return List of Case records matching the reference number
     */
    public static List<Case> getCasesByReferenceNumber(String referenceNumber) {
        String query = 'SELECT ' + CASE_EXTENDED_FIELDS + 
                      ' FROM Case WHERE Reference_Number__c = :referenceNumber ' +
                      'ORDER BY CreatedDate ASC';
        return Database.query(query);
    }
    
    /**
     * @description Retrieves Cases by Parent Id
     * @param parentId The parent Case Id
     * @return List of child Case records
     */
    public static List<Case> getCasesByParentId(Id parentId) {
        String query = 'SELECT ' + CASE_EXTENDED_FIELDS + 
                      ' FROM Case WHERE ParentId = :parentId ' +
                      'ORDER BY CreatedDate ASC';
        return Database.query(query);
    }
    
    /**
     * @description Retrieves Cases with open Tasks
     * @param caseIds Set of Case Ids
     * @return Map of Case Id to List of open Tasks
     */
    public static Map<Id, List<Task>> getOpenTasksByCaseIds(Set<Id> caseIds) {
        Map<Id, List<Task>> caseTaskMap = new Map<Id, List<Task>>();
        
        List<Task> openTasks = [
            SELECT Id, WhatId, Subject, Status, Process__c, Priority, 
                   ActivityDate, Due_Date_Time__c, RecordType.DeveloperName
            FROM Task 
            WHERE WhatId IN :caseIds 
            AND Status = :Constant_Util.OPEN
            ORDER BY CreatedDate DESC
        ];
        
        for (Task t : openTasks) {
            if (!caseTaskMap.containsKey(t.WhatId)) {
                caseTaskMap.put(t.WhatId, new List<Task>());
            }
            caseTaskMap.get(t.WhatId).add(t);
        }
        
        return caseTaskMap;
    }
    
    /**
     * @description Retrieves Case Assets for given Case Ids
     * @param caseIds Set of Case Ids
     * @return Map of Case Id to List of Case Assets
     */
    public static Map<Id, List<SBS_Case_Asset__c>> getCaseAssetsByCaseIds(Set<Id> caseIds) {
        Map<Id, List<SBS_Case_Asset__c>> caseAssetMap = new Map<Id, List<SBS_Case_Asset__c>>();
        
        List<SBS_Case_Asset__c> caseAssets = [
            SELECT Id, CaseId__c, AssetId__c, Asset_Header__c, IsManual__c,
                   Asset_Header__r.Name, Asset_Header__r.Occurrence_Type__c,
                   AssetId__r.Occurrence_Type__c, AssetId__r.Service_Type__c,
                   AssetId__r.Start_Date__c, AssetId__r.End_Date__c,
                   CaseId__r.Service_Date__c
            FROM SBS_Case_Asset__c 
            WHERE CaseId__c IN :caseIds
            ORDER BY CreatedDate ASC
        ];
        
        for (SBS_Case_Asset__c ca : caseAssets) {
            if (!caseAssetMap.containsKey(ca.CaseId__c)) {
                caseAssetMap.put(ca.CaseId__c, new List<SBS_Case_Asset__c>());
            }
            caseAssetMap.get(ca.CaseId__c).add(ca);
        }
        
        return caseAssetMap;
    }
    
    /**
     * @description Retrieves Comments for given Case Ids
     * @param caseIds Set of Case Ids
     * @return Map of Case Id to List of Comments
     */
    public static Map<Id, List<Comment__c>> getCommentsByCaseIds(Set<Id> caseIds) {
        Map<Id, List<Comment__c>> caseCommentMap = new Map<Id, List<Comment__c>>();
        
        List<Comment__c> comments = [
            SELECT Id, Case__c, Case_Number__c, Comment__c, 
                   Acorn_Tracking_Number__c, Communication_Log_Type_Name__c,
                   Workflow_Action__c, Workflow_TeamUser__c, Acorn_SUser_ID__c,
                   Type__c, RecordTypeId, CreatedDate
            FROM Comment__c 
            WHERE Case__c IN :caseIds
            ORDER BY CreatedDate DESC
        ];
        
        for (Comment__c comment : comments) {
            if (!caseCommentMap.containsKey(comment.Case__c)) {
                caseCommentMap.put(comment.Case__c, new List<Comment__c>());
            }
            caseCommentMap.get(comment.Case__c).add(comment);
        }
        
        return caseCommentMap;
    }
    
    /**
     * @description Retrieves EmailMessages for given Case Ids
     * @param caseIds Set of Case Ids
     * @return Map of Case Id to List of EmailMessages
     */
    public static Map<Id, List<EmailMessage>> getEmailMessagesByCaseIds(Set<Id> caseIds) {
        Map<Id, List<EmailMessage>> caseEmailMap = new Map<Id, List<EmailMessage>>();
        
        List<EmailMessage> emails = [
            SELECT Id, ParentId, Subject, FromAddress, ToAddress,
                   HtmlBody, TextBody, CreatedDate
            FROM EmailMessage 
            WHERE ParentId IN :caseIds
            ORDER BY CreatedDate DESC
        ];
        
        for (EmailMessage email : emails) {
            if (!caseEmailMap.containsKey(email.ParentId)) {
                caseEmailMap.put(email.ParentId, new List<EmailMessage>());
            }
            caseEmailMap.get(email.ParentId).add(email);
        }
        
        return caseEmailMap;
    }
    
    // ========================================================================
    // ASSET QUERY METHODS
    // ========================================================================
    
    /**
     * @description Retrieves Asset records by Ids
     * @param assetIds Set of Asset Ids
     * @return Map of Asset Ids to Asset records
     */
    public static Map<Id, Asset> getAssetsByIds(Set<Id> assetIds) {
        Map<Id, Asset> results = new Map<Id, Asset>();
        Set<Id> idsToQuery = new Set<Id>();
        
        // Check cache first
        for (Id assetId : assetIds) {
            if (assetCache.containsKey(assetId)) {
                results.put(assetId, assetCache.get(assetId));
            } else {
                idsToQuery.add(assetId);
            }
        }
        
        // Query for uncached records
        if (!idsToQuery.isEmpty()) {
            String query = 'SELECT ' + ASSET_STANDARD_FIELDS + ' FROM Asset WHERE Id IN :idsToQuery';
            List<Asset> assets = Database.query(query);
            
            for (Asset a : assets) {
                assetCache.put(a.Id, a);
                results.put(a.Id, a);
            }
        }
        
        return results;
    }
    
    /**
     * @description Retrieves Asset with Service Header check
     * @param assetIds Set of Asset Ids
     * @param includeServiceHeader Whether to include service header related assets
     * @return Map of Asset Ids to Asset records
     */
    public static Map<Id, Asset> getAssetsWithServiceHeader(Set<Id> assetIds, Boolean includeServiceHeader) {
        String query = 'SELECT ' + ASSET_STANDARD_FIELDS + ' FROM Asset WHERE ';
        
        if (includeServiceHeader) {
            query += 'Service_Header_Id__c IN :assetIds AND Is_Active__c = true';
        } else {
            query += 'Id IN :assetIds';
        }
        
        query += ' LIMIT 49999';
        
        List<Asset> assets = Database.query(query);
        Map<Id, Asset> results = new Map<Id, Asset>();
        
        for (Asset a : assets) {
            assetCache.put(a.Id, a);
            if (includeServiceHeader) {
                results.put(a.Service_Header_Id__c, a);
            } else {
                results.put(a.Id, a);
            }
        }
        
        return results;
    }
    
    /**
     * @description Retrieves child Assets for given parent Asset Ids
     * @param parentAssetIds Set of parent Asset Ids
     * @return Map of parent Asset Id to List of child Assets
     */
    public static Map<Id, List<Asset>> getChildAssetsByParentIds(Set<Id> parentAssetIds) {
        Map<Id, List<Asset>> parentChildMap = new Map<Id, List<Asset>>();
        
        String query = 'SELECT ' + ASSET_STANDARD_FIELDS + 
                      ' FROM Asset WHERE ParentId IN :parentAssetIds AND Is_Active__c = true';
        List<Asset> childAssets = Database.query(query);
        
        for (Asset childAsset : childAssets) {
            if (!parentChildMap.containsKey(childAsset.ParentId)) {
                parentChildMap.put(childAsset.ParentId, new List<Asset>());
            }
            parentChildMap.get(childAsset.ParentId).add(childAsset);
        }
        
        return parentChildMap;
    }
    
    // ========================================================================
    // ACCOUNT (LOCATION) QUERY METHODS
    // ========================================================================
    
    /**
     * @description Retrieves Account (Location) records by Ids
     * @param accountIds Set of Account Ids
     * @return Map of Account Ids to Account records
     */
    public static Map<Id, Account> getAccountsByIds(Set<Id> accountIds) {
        Map<Id, Account> results = new Map<Id, Account>();
        Set<Id> idsToQuery = new Set<Id>();
        
        // Check cache first
        for (Id accountId : accountIds) {
            if (accountCache.containsKey(accountId)) {
                results.put(accountId, accountCache.get(accountId));
            } else {
                idsToQuery.add(accountId);
            }
        }
        
        // Query for uncached records
        if (!idsToQuery.isEmpty()) {
            String query = 'SELECT ' + ACCOUNT_STANDARD_FIELDS + ' FROM Account WHERE Id IN :idsToQuery';
            List<Account> accounts = Database.query(query);
            
            for (Account a : accounts) {
                accountCache.put(a.Id, a);
                results.put(a.Id, a);
            }
        }
        
        return results;
    }
    
    /**
     * @description Retrieves Account by specific criteria for standard cases
     * @return Account record for standard case timezone
     */
    public static Map<Id, Account> getLocationForStandardCase() {
        String query = 'SELECT ' + ACCOUNT_STANDARD_FIELDS + 
                      ' FROM Account WHERE tz__Timezone_SFDC__c = \'America/New_York\' ' +
                      'AND RecordType.Name = \'Location\' AND Status__c = \'Active\' LIMIT 1';
        List<Account> accounts = Database.query(query);
        
        Map<Id, Account> result = new Map<Id, Account>();
        if (!accounts.isEmpty()) {
            result.put(accounts[0].Id, accounts[0]);
        }
        
        return result;
    }
    
    // ========================================================================
    // BUSINESS HOURS QUERY METHODS
    // ========================================================================
    
    /**
     * @description Retrieves Business Hours by timezone
     * @return Map of timezone to BusinessHours Id
     */
    public static Map<String, Id> getBusinessHoursByTimezone() {
        if (!businessHoursCache.isEmpty()) {
            return businessHoursCache;
        }
        
        List<BusinessHours> businessHours = [
            SELECT Id, TimeZoneSidKey 
            FROM BusinessHours 
            LIMIT 39999
        ];
        
        for (BusinessHours bh : businessHours) {
            businessHoursCache.put(bh.TimeZoneSidKey, bh.Id);
        }
        
        return businessHoursCache;
    }
    
    /**
     * @description Gets BusinessHours Id for a specific timezone
     * @param timezone The timezone string
     * @return BusinessHours Id or null if not found
     */
    public static Id getBusinessHoursIdForTimezone(String timezone) {
        if (businessHoursCache.isEmpty()) {
            getBusinessHoursByTimezone();
        }
        
        return businessHoursCache.get(timezone);
    }
    
    // ========================================================================
    // WORK ORDER QUERY METHODS
    // ========================================================================
    
    /**
     * @description Retrieves WorkOrders by Case Ids
     * @param caseIds Set of Case Ids
     * @return List of WorkOrder records
     */
    public static List<WorkOrder> getWorkOrdersByCaseIds(Set<Id> caseIds) {
        return [
            SELECT Id, CaseId, WorkOrderNumber, Status, StatusCategory,
                   Service_Date__c, Case_Subtype__c, AssetId, Customer_Location__c,
                   Is_Bypass__c, WO_Accepted_Rejected_Comments__c,
                   Acorn_WorkOrder_Number__c
            FROM WorkOrder 
            WHERE CaseId IN :caseIds
            ORDER BY CreatedDate DESC
        ];
    }
    
    /**
     * @description Counts WorkOrders matching specific criteria for occurrence limit validation
     * @param assetIds Set of Asset Ids
     * @param locationIds Set of Location Ids
     * @param caseSubtype Case subtype to filter on
     * @param startDate Start date for date range
     * @param endDate End date for date range
     * @return Map of composite key to count of work orders
     */
    public static Map<String, Integer> getWorkOrderCounts(
        Set<Id> assetIds, 
        Set<Id> locationIds,
        String caseSubtype,
        Date startDate,
        Date endDate
    ) {
        Map<String, Integer> workOrderCounts = new Map<String, Integer>();
        Set<String> workOrderStatus = new Set<String>{
            Constant_Util.INPROGRESS, 
            Constant_Util.STATUS_NEW, 
            Constant_Util.COMPLETED, 
            Constant_Util.CLOSED
        };
        
        List<AggregateResult> results = [
            SELECT COUNT(Id) num, AssetId, Customer_Location__c, Case.Case_Sub_Type__c
            FROM WorkOrder
            WHERE AssetId IN :assetIds
            AND Customer_Location__c IN :locationIds
            AND StatusCategory IN :workOrderStatus
            AND Case_Subtype__c = :caseSubtype
            AND Is_Bypass__c = false
            AND Service_Date__c >= :startDate
            AND Service_Date__c <= :endDate
            GROUP BY AssetId, Customer_Location__c, Case.Case_Sub_Type__c
        ];
        
        for (AggregateResult ar : results) {
            String key = String.valueOf(ar.get('AssetId')) + 
                        String.valueOf(ar.get('Customer_Location__c')) + 
                        String.valueOf(ar.get('Case_Sub_Type__c'));
            workOrderCounts.put(key, (Integer)ar.get('num'));
        }
        
        return workOrderCounts;
    }
    
    // ========================================================================
    // APPROVAL LOG QUERY METHODS
    // ========================================================================
    
    /**
     * @description Retrieves Approval Logs for given Case Ids
     * @param caseIds Set of Case Ids
     * @return List of Approval Log records
     */
    public static List<Approval_Log__c> getApprovalLogsByCaseIds(Set<Id> caseIds) {
        return [
            SELECT Id, CaseId__c, Required_Approver__c, Required_Approver_Contact__c,
                   Required_Approver_Contact__r.Account_Title__r.Name,
                   Approver_Type__c, BusinessRuleId__c,
                   BusinessRuleId__r.Is_Auto_Email__c,
                   BusinessRuleId__r.Multiple_Mandatory_Approvers__c,
                   Required_Approver_Title__c,
                   Required_Approver_Contact__r.Preferred_Method__c,
                   Phone__c, Email__c,
                   Required_Approver_Contact__r.Email,
                   Required_Approver_Contact__r.Phone,
                   Required_Approver_Contact__r.MobilePhone,
                   Is_Required__c, ServiceApprovers__c,
                   CaseId__r.Is_Multiple_Asset__c, Status__c
            FROM Approval_Log__c
            WHERE CaseId__c IN :caseIds
            AND Status__c = :Constant_Util.APPROVAL_REQUESTED
            ORDER BY CaseId__r.CaseNumber ASC
            LIMIT 49999
        ];
    }
    
    // ========================================================================
    // UTILITY METHODS
    // ========================================================================
    
    /**
     * @description Clears all caches - useful for testing or transaction boundaries
     */
    public static void clearCaches() {
        caseCache.clear();
        assetCache.clear();
        accountCache.clear();
        businessHoursCache.clear();
        cachesInitialized = false;
    }
    
    /**
     * @description Checks if a Case Id is already cached
     * @param caseId The Case Id to check
     * @return true if cached, false otherwise
     */
    public static Boolean isCaseCached(Id caseId) {
        return caseCache.containsKey(caseId);
    }
    
    /**
     * @description Gets the current size of the case cache
     * @return Number of cached Case records
     */
    public static Integer getCaseCacheSize() {
        return caseCache.size();
    }
    
    /**
     * @description Retrieves Group Id by Developer Name (for queue lookups)
     * @param developerName The Developer Name of the Group/Queue
     * @return Group Id or null if not found
     */
    public static Id getGroupIdByDeveloperName(String developerName) {
        List<Group> groups = [
            SELECT Id 
            FROM Group 
            WHERE DeveloperName = :developerName 
            LIMIT 1
        ];
        
        return groups.isEmpty() ? null : groups[0].Id;
    }
    
    /**
     * @description Retrieves record type Id by object and record type name
     * @param objectName The sObject API name
     * @param recordTypeName The record type name
     * @return Record Type Id or null if not found
     */
    public static Id getRecordTypeId(String objectName, String recordTypeName) {
        Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
        return describeResult.getRecordTypeInfosByName().get(recordTypeName)?.getRecordTypeId();
    }
    
    public static Map<Id, WorkOrder> getWorkOrderByCaseId(Set<Id> idSet) {
        
        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<WorkOrder> woList = (List<WorkOrder>) UniversalQueryUtility.universalQuery('WorkOrder', idSet, 'CaseId');
        Map<Id, WorkOrder> workOrderCache = new Map<Id, WorkOrder>();
        workOrderCache.putAll(woList);
        
        return workOrderCache;
    }
}
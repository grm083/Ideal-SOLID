/**
 * @author Waste Management
 * @date 2025
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Value object that encapsulates all data needed for case trigger processing.
 *              This replaces the static Maps/Sets pattern used in CaseTriggerHelper and CaseTriggerHandler.
 *
 * DESIGN PATTERNS:
 * - Value Object Pattern: Immutable data container
 * - Builder Pattern: Fluent API for construction
 * - Dependency Injection: Passed as parameter instead of global state
 *
 * BENEFITS:
 * - Thread-safe (no static state pollution)
 * - Testable (can create test contexts with mock data)
 * - Clear dependencies (explicit parameter passing)
 * - Eliminates temporal coupling (no order-dependent static map population)
 *
 * USAGE:
 * CaseTriggerContext context = CaseTriggerContext.buildFromCases(casesToProcess);
 * CaseServiceFacade facade = new CaseServiceFacade();
 * facade.processBeforeInsert(casesToProcess, context);
 */
public class CaseTriggerContext {

    // ========================================================================
    // INSTANCE VARIABLES (Encapsulated data)
    // ========================================================================

    @TestVisible private Map<Id, Asset> assetsByContainerId;
    @TestVisible private Map<Id, Account> locationsByAccountId;
    @TestVisible private Map<Id, Contact> contactsById;
    @TestVisible private Map<String, Id> businessHoursIdByTimezone;
    @TestVisible private Map<String, Integer> workOrderCountByCaseTrackingNumber;
    @TestVisible private Map<Id, Asset> assetsById;
    @TestVisible private Map<Id, Case> parentCasesById;

    // Record Type IDs (cached for performance)
    @TestVisible private Id integrationRecordTypeId;
    @TestVisible private Id pickupRecordTypeId;
    @TestVisible private Id newServiceRecordTypeId;

    // Queue IDs (cached for performance)
    @TestVisible private Id corporateServiceQueueId;

    // ========================================================================
    // CONSTRUCTOR (Private - use Builder)
    // ========================================================================

    @TestVisible
    private CaseTriggerContext() {
        this.assetsByContainerId = new Map<Id, Asset>();
        this.locationsByAccountId = new Map<Id, Account>();
        this.contactsById = new Map<Id, Contact>();
        this.businessHoursIdByTimezone = new Map<String, Id>();
        this.workOrderCountByCaseTrackingNumber = new Map<String, Integer>();
        this.assetsById = new Map<Id, Asset>();
        this.parentCasesById = new Map<Id, Case>();
    }

    // ========================================================================
    // BUILDER METHODS (Factory pattern)
    // ========================================================================

    /**
     * @description Builds context from a list of cases, querying all necessary related data
     * @param casesToProcess Cases that need processing
     * @return CaseTriggerContext Fully populated context
     */
    public static CaseTriggerContext buildFromCases(List<Case> casesToProcess) {
        CaseTriggerContext context = new CaseTriggerContext();

        // Collect IDs from cases
        Set<Id> assetIds = new Set<Id>();
        Set<Id> containerIds = new Set<Id>();
        Set<Id> locationIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> parentCaseIds = new Set<Id>();

        for (Case c : casesToProcess) {
            if (String.isNotBlank(c.AssetId)) {
                assetIds.add(c.AssetId);
            }
            if (String.isNotBlank(c.Container__c)) {
                containerIds.add(c.Container__c);
            }
            if (String.isNotBlank(c.Location__c)) {
                locationIds.add(c.Location__c);
            }
            if (String.isNotBlank(c.ContactId)) {
                contactIds.add(c.ContactId);
            }
            if (String.isNotBlank(c.ParentId)) {
                parentCaseIds.add(c.ParentId);
            }
        }

        // Query all related data in bulk
        context.queryAssets(assetIds, containerIds);
        context.queryLocations(locationIds);
        context.queryContacts(contactIds);
        context.queryParentCases(parentCaseIds);
        context.queryBusinessHours();

        // Cache record type and queue IDs
        context.cacheRecordTypeIds();
        context.cacheQueueIds();

        return context;
    }

    /**
     * @description Creates empty context for testing
     * @return CaseTriggerContext Empty context
     */
    @TestVisible
    public static CaseTriggerContext createEmptyContext() {
        return new CaseTriggerContext();
    }

    // ========================================================================
    // QUERY METHODS (Private - called by builder)
    // ========================================================================

    private void queryAssets(Set<Id> assetIds, Set<Id> containerIds) {
        if (assetIds.isEmpty() && containerIds.isEmpty()) {
            return;
        }

        try {
            // Query assets by direct ID
            if (!assetIds.isEmpty()) {
                for (Asset a : [
                    SELECT Id, Name, AccountId, Container__c, Service__c,
                           Haul_Frequency__c, Product2Id, Route__c
                    FROM Asset
                    WHERE Id IN :assetIds
                ]) {
                    assetsById.put(a.Id, a);

                    // Also map by container if applicable
                    if (String.isNotBlank(a.Container__c)) {
                        assetsByContainerId.put(a.Container__c, a);
                    }
                }
            }

            // Query assets by container ID
            if (!containerIds.isEmpty()) {
                for (Asset a : [
                    SELECT Id, Name, AccountId, Container__c, Service__c,
                           Haul_Frequency__c, Product2Id, Route__c
                    FROM Asset
                    WHERE Container__c IN :containerIds
                    AND Id NOT IN :assetIds // Avoid duplicates
                ]) {
                    assetsByContainerId.put(a.Container__c, a);
                    assetsById.put(a.Id, a);
                }
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    private void queryLocations(Set<Id> locationIds) {
        if (locationIds.isEmpty()) {
            return;
        }

        try {
            for (Account acc : [
                SELECT Id, Name, BillingCity, BillingState, BillingPostalCode,
                       BillingStreet, TimeZone__c, Business_Hours_Id__c, ParentId,
                       Service_Division__c, Division__c
                FROM Account
                WHERE Id IN :locationIds
            ]) {
                locationsByAccountId.put(acc.Id, acc);
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    private void queryContacts(Set<Id> contactIds) {
        if (contactIds.isEmpty()) {
            return;
        }

        try {
            for (Contact con : [
                SELECT Id, Name, Email, Phone, AccountId
                FROM Contact
                WHERE Id IN :contactIds
            ]) {
                contactsById.put(con.Id, con);
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    private void queryParentCases(Set<Id> parentCaseIds) {
        if (parentCaseIds.isEmpty()) {
            return;
        }

        try {
            for (Case parentCase : [
                SELECT Id, CaseNumber, Status, RecordTypeId, Location__c, AssetId
                FROM Case
                WHERE Id IN :parentCaseIds
            ]) {
                parentCasesById.put(parentCase.Id, parentCase);
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    private void queryBusinessHours() {
        try {
            for (BusinessHours bh : [SELECT Id, TimeZoneSidKey FROM BusinessHours]) {
                businessHoursIdByTimezone.put(bh.TimeZoneSidKey, bh.Id);
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    private void cacheRecordTypeIds() {
        Map<String, Id> recordTypeMap = new Map<String, Id>();

        try {
            for (RecordType rt : [
                SELECT Id, DeveloperName
                FROM RecordType
                WHERE SObjectType = 'Case'
                AND DeveloperName IN (
                    :Constant_Util.Integration_Case,
                    :Constant_Util.PICKUP,
                    :Constant_Util.New_Service_Case
                )
            ]) {
                recordTypeMap.put(rt.DeveloperName, rt.Id);
            }

            this.integrationRecordTypeId = recordTypeMap.get(Constant_Util.Integration_Case);
            this.pickupRecordTypeId = recordTypeMap.get(Constant_Util.PICKUP);
            this.newServiceRecordTypeId = recordTypeMap.get(Constant_Util.New_Service_Case);
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    private void cacheQueueIds() {
        try {
            Group corporateServiceQueue = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName = 'Corporate_Service'
                LIMIT 1
            ];
            this.corporateServiceQueueId = corporateServiceQueue.Id;
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    // ========================================================================
    // GETTER METHODS (Public API)
    // ========================================================================

    public Asset getAssetByContainerId(Id containerId) {
        return assetsByContainerId.get(containerId);
    }

    public Asset getAssetById(Id assetId) {
        return assetsById.get(assetId);
    }

    public Account getLocation(Id accountId) {
        return locationsByAccountId.get(accountId);
    }

    public Contact getContact(Id contactId) {
        return contactsById.get(contactId);
    }

    public Case getParentCase(Id parentCaseId) {
        return parentCasesById.get(parentCaseId);
    }

    public Id getBusinessHoursId(String timezone) {
        return businessHoursIdByTimezone.get(timezone);
    }

    public Id getIntegrationRecordTypeId() {
        return integrationRecordTypeId;
    }

    public Id getPickupRecordTypeId() {
        return pickupRecordTypeId;
    }

    public Id getNewServiceRecordTypeId() {
        return newServiceRecordTypeId;
    }

    public Id getCorporateServiceQueueId() {
        return corporateServiceQueueId;
    }

    public Integer getWorkOrderCount(String trackingNumber) {
        return workOrderCountByCaseTrackingNumber.get(trackingNumber);
    }

    public Map<Id, Asset> getAllAssets() {
        return new Map<Id, Asset>(assetsById);
    }

    public Map<Id, Account> getAllLocations() {
        return new Map<Id, Account>(locationsByAccountId);
    }

    // ========================================================================
    // SETTER METHODS (For test data injection)
    // ========================================================================

    @TestVisible
    public void setAssetByContainerId(Id containerId, Asset asset) {
        assetsByContainerId.put(containerId, asset);
        assetsById.put(asset.Id, asset);
    }

    @TestVisible
    public void setLocation(Id accountId, Account location) {
        locationsByAccountId.put(accountId, location);
    }

    @TestVisible
    public void setContact(Id contactId, Contact con) {
        contactsById.put(contactId, con);
    }

    @TestVisible
    public void setWorkOrderCount(String trackingNumber, Integer count) {
        workOrderCountByCaseTrackingNumber.put(trackingNumber, count);
    }

    @TestVisible
    public void setBusinessHoursId(String timezone, Id businessHoursId) {
        businessHoursIdByTimezone.put(timezone, businessHoursId);
    }

    @TestVisible
    public void setRecordTypeIds(Id integrationRt, Id pickupRt, Id newServiceRt) {
        this.integrationRecordTypeId = integrationRt;
        this.pickupRecordTypeId = pickupRt;
        this.newServiceRecordTypeId = newServiceRt;
    }

    @TestVisible
    public void setCorporateServiceQueueId(Id queueId) {
        this.corporateServiceQueueId = queueId;
    }
}

/**
 * @author Waste Management
 * @date 2025
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Entity Selector Controller - Unified controller for searching and selecting
 *              Locations, Vendors, and Clients (all Account records with different types)
 *
 * REPLACES:
 * - LocationContainerController (Aura)
 * - VendorContainerController (Aura)
 * - ClientContainerController (Aura)
 *
 * ENTITY TYPES:
 * - Location: Account records with RecordType = 'Location'
 * - Vendor: Account records with RecordType = 'Vendor'
 * - Client: Account records with RecordType = 'Client' OR ParentId = null
 *
 * USAGE:
 * - Called by entitySelector LWC component
 * - Supports multi-field search
 * - Returns formatted results for display
 */
public with sharing class EntitySelectorController {

    /**
     * @description Search wrapper class for results
     */
    public class EntitySearchResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String accountNumber { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String fullAddress { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String recordTypeName { get; set; }
        @AuraEnabled public String division { get; set; }
        @AuraEnabled public String geography { get; set; }
        @AuraEnabled public String locationType { get; set; }
        @AuraEnabled public String brand { get; set; }
        @AuraEnabled public String segment { get; set; }
        @AuraEnabled public String parentAccountId { get; set; }
        @AuraEnabled public String parentAccountName { get; set; }
    }

    /**
     * @description Search for entities (Locations/Vendors/Clients)
     * @param entityType The type of entity to search for ('Location', 'Vendor', 'Client')
     * @param searchCriteria Map of search field names to values
     * @return List of EntitySearchResult objects
     */
    @AuraEnabled(cacheable=true)
    public static List<EntitySearchResult> searchEntities(String entityType, Map<String, String> searchCriteria) {
        List<EntitySearchResult> results = new List<EntitySearchResult>();

        try {
            // Build WHERE clause based on entity type and search criteria
            String whereClause = buildWhereClause(entityType, searchCriteria);

            // Build and execute query
            String query = buildSearchQuery(whereClause);
            List<Account> accounts = Database.query(query);

            // Convert to result wrapper
            for (Account acc : accounts) {
                results.add(mapAccountToResult(acc));
            }

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'EntitySelectorController', LoggingLevel.ERROR);
            throw new AuraHandledException('Error searching entities: ' + ex.getMessage());
        }

        return results;
    }

    /**
     * @description Get entity details by ID
     * @param entityId The ID of the entity (Account)
     * @return EntitySearchResult with full details
     */
    @AuraEnabled(cacheable=true)
    public static EntitySearchResult getEntityById(String entityId) {
        try {
            String query = buildSearchQuery('Id = :entityId');
            List<Account> accounts = Database.query(query);

            if (accounts.isEmpty()) {
                throw new AuraHandledException('Entity not found');
            }

            return mapAccountToResult(accounts[0]);

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'EntitySelectorController', LoggingLevel.ERROR);
            throw new AuraHandledException('Error retrieving entity: ' + ex.getMessage());
        }
    }

    /**
     * @description Get recent entities (for quick selection)
     * @param entityType The type of entity ('Location', 'Vendor', 'Client')
     * @param limitCount Number of records to return
     * @return List of EntitySearchResult objects
     */
    @AuraEnabled(cacheable=true)
    public static List<EntitySearchResult> getRecentEntities(String entityType, Integer limitCount) {
        List<EntitySearchResult> results = new List<EntitySearchResult>();

        try {
            String whereClause = buildEntityTypeFilter(entityType);
            String query = buildSearchQuery(whereClause) + ' ORDER BY LastViewedDate DESC NULLS LAST LIMIT :limitCount';

            List<Account> accounts = Database.query(query);

            for (Account acc : accounts) {
                results.add(mapAccountToResult(acc));
            }

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'EntitySelectorController', LoggingLevel.ERROR);
            throw new AuraHandledException('Error retrieving recent entities: ' + ex.getMessage());
        }

        return results;
    }

    /**
     * @description Build search query with all necessary fields
     * @param whereClause The WHERE clause to append
     * @return Complete SOQL query string
     */
    private static String buildSearchQuery(String whereClause) {
        String query = 'SELECT Id, Name, AccountNumber, ' +
                      'BillingStreet, BillingCity, BillingState, BillingPostalCode, ' +
                      'Phone, RecordType.Name, ' +
                      'Division__c, Geography__c, Location_Type__c, Brand__c, ' +
                      'Primary_Segment__c, ParentId, Parent.Name ' +
                      'FROM Account';

        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }

        query += ' LIMIT 100'; // Safety limit

        return query;
    }

    /**
     * @description Build WHERE clause based on entity type and search criteria
     * @param entityType The type of entity
     * @param searchCriteria Map of search criteria
     * @return WHERE clause string
     */
    private static String buildWhereClause(String entityType, Map<String, String> searchCriteria) {
        List<String> conditions = new List<String>();

        // Add entity type filter
        String entityTypeFilter = buildEntityTypeFilter(entityType);
        if (String.isNotBlank(entityTypeFilter)) {
            conditions.add(entityTypeFilter);
        }

        // Add search criteria
        if (searchCriteria != null && !searchCriteria.isEmpty()) {
            for (String fieldName : searchCriteria.keySet()) {
                String value = searchCriteria.get(fieldName);
                if (String.isNotBlank(value)) {
                    String condition = buildFieldCondition(fieldName, value);
                    if (String.isNotBlank(condition)) {
                        conditions.add(condition);
                    }
                }
            }
        }

        return String.join(conditions, ' AND ');
    }

    /**
     * @description Build entity type filter
     * @param entityType The type of entity
     * @return Filter condition string
     */
    private static String buildEntityTypeFilter(String entityType) {
        if (entityType == 'Location') {
            return 'RecordType.Name = \'Location\'';
        } else if (entityType == 'Vendor') {
            return 'RecordType.Name = \'Vendor\'';
        } else if (entityType == 'Client') {
            // Clients are parent accounts (no parent) or specific record type
            return '(ParentId = null OR RecordType.Name = \'Client\')';
        }
        return '';
    }

    /**
     * @description Build field condition for WHERE clause
     * @param fieldName The field name
     * @param value The search value
     * @return Condition string
     */
    private static String buildFieldCondition(String fieldName, String value) {
        // Escape single quotes in value
        String escapedValue = String.escapeSingleQuotes(value);

        switch on fieldName {
            when 'name' {
                return 'Name LIKE \'%' + escapedValue + '%\'';
            }
            when 'accountNumber' {
                return 'AccountNumber LIKE \'%' + escapedValue + '%\'';
            }
            when 'street' {
                return 'BillingStreet LIKE \'%' + escapedValue + '%\'';
            }
            when 'city' {
                return 'BillingCity LIKE \'%' + escapedValue + '%\'';
            }
            when 'state' {
                return 'BillingState LIKE \'%' + escapedValue + '%\'';
            }
            when 'postalCode' {
                return 'BillingPostalCode LIKE \'%' + escapedValue + '%\'';
            }
            when 'phone' {
                return 'Phone LIKE \'%' + escapedValue + '%\'';
            }
            when 'division' {
                return 'Division__c LIKE \'%' + escapedValue + '%\'';
            }
            when 'geography' {
                return 'Geography__c LIKE \'%' + escapedValue + '%\'';
            }
            when else {
                return '';
            }
        }
    }

    /**
     * @description Map Account to EntitySearchResult
     * @param acc Account record
     * @return EntitySearchResult object
     */
    private static EntitySearchResult mapAccountToResult(Account acc) {
        EntitySearchResult result = new EntitySearchResult();

        result.id = acc.Id;
        result.name = acc.Name;
        result.accountNumber = acc.AccountNumber;
        result.street = acc.BillingStreet;
        result.city = acc.BillingCity;
        result.state = acc.BillingState;
        result.postalCode = acc.BillingPostalCode;
        result.phone = acc.Phone;
        result.recordTypeName = acc.RecordType?.Name;
        result.division = acc.Division__c;
        result.geography = acc.Geography__c;
        result.locationType = acc.Location_Type__c;
        result.brand = acc.Brand__c;
        result.segment = acc.Primary_Segment__c;
        result.parentAccountId = acc.ParentId;
        result.parentAccountName = acc.Parent?.Name;

        // Build full address
        List<String> addressParts = new List<String>();
        if (String.isNotBlank(acc.BillingStreet)) addressParts.add(acc.BillingStreet);
        if (String.isNotBlank(acc.BillingCity)) addressParts.add(acc.BillingCity);
        if (String.isNotBlank(acc.BillingState)) addressParts.add(acc.BillingState);
        if (String.isNotBlank(acc.BillingPostalCode)) addressParts.add(acc.BillingPostalCode);
        result.fullAddress = String.join(addressParts, ', ');

        return result;
    }

    /**
     * @description Validate entity selection (ensure it's active, correct type, etc.)
     * @param entityId The ID of the entity
     * @param entityType Expected entity type
     * @return Map with validation result
     */
    @AuraEnabled
    public static Map<String, Object> validateEntitySelection(String entityId, String entityType) {
        Map<String, Object> result = new Map<String, Object>{
            'isValid' => true,
            'message' => ''
        };

        try {
            Account entity = [
                SELECT Id, RecordType.Name, ParentId, IsActive__c
                FROM Account
                WHERE Id = :entityId
                LIMIT 1
            ];

            // Check if active (if field exists)
            if (entity.IsActive__c != null && !entity.IsActive__c) {
                result.put('isValid', false);
                result.put('message', 'This ' + entityType + ' is inactive');
                return result;
            }

            // Check record type matches
            if (entityType == 'Location' && entity.RecordType?.Name != 'Location') {
                result.put('isValid', false);
                result.put('message', 'Selected account is not a Location');
            } else if (entityType == 'Vendor' && entity.RecordType?.Name != 'Vendor') {
                result.put('isValid', false);
                result.put('message', 'Selected account is not a Vendor');
            } else if (entityType == 'Client' && entity.ParentId != null && entity.RecordType?.Name != 'Client') {
                result.put('isValid', false);
                result.put('message', 'Selected account is not a Client');
            }

        } catch (Exception ex) {
            result.put('isValid', false);
            result.put('message', 'Error validating entity: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                'EntitySelectorController', LoggingLevel.ERROR);
        }

        return result;
    }
}

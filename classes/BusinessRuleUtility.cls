public class BusinessRuleUtility {
    //**Overview** A utility class that aides in preparing the data to identify appropriate business rules given a transaction.  It
    //aspires to serve as a central governing body in determining the appropriate fields, the appropriate priorities, and the 
    //most to least-specific rules needed to process a customer transaction.
    //**Problem Statement** Business Rules (approvals, notifications and required information) are difficult to work with and are 
    //decentralized, with code existing on both Case (BusinessRuleHelper) and Quote (QuoteApproval) Interfaces
    //**Author** George R Martin III - gmarti18@wm.com
    //**Date** February 20, 2025
    //**Refactored** Optimized for performance and bulkification - November 2025
    
    // Adding a flag for stopping trigger for specific scenarios with BR 
    public static boolean skipTaskTriggerBR = true;
    
    //Constants used throughout the process to reduce variability
    static final String QUERY_INTRO = 'SELECT Id, RecordType.Name';
    //Constant for the type of "in scope" business rules
    static final List<String> BR_TYPES = new List<String>{'Approval', 'Required Information', 'Business Notification'};
    //Constant for the Service Approver portion of the BR Query
    static final String SERVICE_APPROVER_QUERY_STRING = ', (SELECT Id, Name, RecordType.Name, Approver__c, User__c, User__r.Name, Title__c, Account_Title__c, ' +
        'Approver_Contact__c, Approver_Contact__r.Name, Approver_Email__c, ServiceApprover__c,Service_Approver__c.Business_Rule__c,Email__c, Account_Department__c, Requester_Only__c, ' +
        'Approver_Contact__r.Account_Title__r.Name, Service_Type__c, NTE_Amount__c, Origin__c, Fuzzy_Search__c, Approver_Type__c, Account_Team_Member__c,Title__r.Name FROM Approver_Entities__r WHERE Active__c = TRUE) ';
    
    // Static caches for metadata (significantly improves performance)
    private static List<Business_Rule_Field_Mapping__mdt> cachedFieldMappings;
    private static List<priorityFieldSets> cachedPriorityFieldSets;
    
    /**
     * BULKIFIED ENTRY POINT - Use this method for trigger contexts
     * Processes multiple records efficiently with a single set of queries
     * 
     * @param targetRecordIds Set of Case or Quote IDs to process
     * @return Map of record ID to Map of business rule types to business rule records
     */
    @AuraEnabled
    public static Map<Id, Map<String, List<Business_Rule__c>>> getPriorityBusinessRulesBulk(List<Id> targetRecordIds) {
        Map<Id, Map<String, List<Business_Rule__c>>> resultMap = new Map<Id, Map<String, List<Business_Rule__c>>>();
        
        if (targetRecordIds == null || targetRecordIds.isEmpty()) {
            return resultMap;
        }
        
        // Reduce overhead by calling metadata query once for all records
        List<Business_Rule_Field_Mapping__mdt> mappedFields = getFieldMappings();
        
        // Group IDs by object type
        Map<String, Set<Id>> idsByType = new Map<String, Set<Id>>();
        for (Id recordId : targetRecordIds) {
            String sObjectType = String.valueOf(recordId.getSObjectType());
            if (!idsByType.containsKey(sObjectType)) {
                idsByType.put(sObjectType, new Set<Id>());
            }
            idsByType.get(sObjectType).add(recordId);
        }
        
        // Process each object type in bulk
        for (String sObjectType : idsByType.keySet()) {
            Map<Id, List<priorityFields>> priorityFieldsByRecordId;
            
            switch on sObjectType {
                when 'Case' {
                    priorityFieldsByRecordId = getCaseValuesBulk(idsByType.get(sObjectType), mappedFields);
                }
                when 'SBQQ__Quote__c' {
                    priorityFieldsByRecordId = getQuoteValuesBulk(idsByType.get(sObjectType), mappedFields);
                }
                when else {
                    continue;
                }
            }
            
            if (priorityFieldsByRecordId.isEmpty()) {
                continue;
            }
            
            // Query business rules once for all records of this type
            Map<Id, List<Business_Rule__c>> businessRulesByRecordId = getBusinessRulesBulk(
                priorityFieldsByRecordId, 
                mappedFields
            );
            
            // Prioritize for each record
            for (Id recordId : priorityFieldsByRecordId.keySet()) {
                if (businessRulesByRecordId.containsKey(recordId) && !businessRulesByRecordId.get(recordId).isEmpty()) {
                    Map<String, List<Business_Rule__c>> parsedRules = parseBusinessRules(
                        businessRulesByRecordId.get(recordId)
                    );
                    
                    if (!parsedRules.isEmpty()) {
                        Map<String, List<Business_Rule__c>> prioritizedRules = prioritizeBusinessRules(
                            priorityFieldsByRecordId.get(recordId),
                            parsedRules
                        );
                        resultMap.put(recordId, prioritizedRules);
                    }
                }
            }
        }
        
        return resultMap;
    }
    
    /**
     * SINGLE RECORD ENTRY POINT - Backwards compatible with existing code
     * For new code, prefer getPriorityBusinessRulesBulk for better performance
     * 
     * @param targetRecord Single Case or Quote ID
     * @return Map of business rule type to list of business rule records
     */
    @AuraEnabled
    public static Map<String, List<Business_Rule__c>> getPriorityBusinessRule(Id targetRecord) {
        if (targetRecord == null) {
            return new Map<String, List<Business_Rule__c>>();
        }
        
        // Use the bulk method for single records (more efficient due to caching)
        List<Id> recordIds = new List<Id>{targetRecord};
        Map<Id, Map<String, List<Business_Rule__c>>> bulkResults = getPriorityBusinessRulesBulk(recordIds);
        
        return bulkResults.containsKey(targetRecord) 
            ? bulkResults.get(targetRecord) 
            : new Map<String, List<Business_Rule__c>>();
    }
    
    /**
     * BULKIFIED - Query all business rules for multiple records in one query
     * This is the key performance improvement over the original implementation
     */
    public static Map<Id, List<Business_Rule__c>> getBusinessRulesBulk(
        Map<Id, List<priorityFields>> priorityFieldsByRecordId,
        List<Business_Rule_Field_Mapping__mdt> mappedFields
    ) {
        Map<Id, List<Business_Rule__c>> businessRulesByRecordId = new Map<Id, List<Business_Rule__c>>();
        
        // Collect all unique accounts and date ranges
        Set<String> allAccounts = new Set<String>();
        Date minDate = null;
        Date maxDate = null;
        
        // Also collect all unique values for other fields that might need exact matching
        Map<String, Set<String>> fieldValuesMap = new Map<String, Set<String>>();
        
        for (List<priorityFields> priorityFields : priorityFieldsByRecordId.values()) {
            for (priorityFields pf : priorityFields) {
                if (pf.objectValue == null) continue;
                
                if (pf.commonName == 'Account Name') {
                    allAccounts.add(pf.objectValue);
                } else if (pf.commonName == 'Effective Date') {
                    Date d = Date.valueOf(pf.objectValue);
                    if (minDate == null || d < minDate) minDate = d;
                    if (maxDate == null || d > maxDate) maxDate = d;
                } else if (pf.businessRuleField != null) {
                    // Collect other field values for potential filtering
                    if (!fieldValuesMap.containsKey(pf.businessRuleField)) {
                        fieldValuesMap.put(pf.businessRuleField, new Set<String>());
                    }
                    fieldValuesMap.get(pf.businessRuleField).add(pf.objectValue);
                }
            }
        }
        
        if (allAccounts.isEmpty()) {
            return businessRulesByRecordId;
        }
        
        // Build query string
        String queryString = QUERY_INTRO;
        Set<String> targetFields = new Set<String>();
        
        for (Business_Rule_Field_Mapping__mdt field : mappedFields) {
            if (String.isNotBlank(field.Business_Rule__c)) {
                targetFields.add(field.Business_Rule__c);
            }
        }
        
        for (String s : targetFields) {
            queryString += ', ' + s;
        }
        
        queryString += SERVICE_APPROVER_QUERY_STRING;
        queryString += ' FROM Business_Rule__c WHERE Active__c = true AND Account__c IN :allAccounts';
        
        // Add date filters if dates exist
        if (minDate != null && maxDate != null) {
            queryString += ' AND Effective_Date__c <= :maxDate';
            queryString += ' AND (End_Date__c >= :minDate OR End_Date__c = null)';
        }
        
        system.debug('Bulk Query String: ' + queryString);
        
        // Query all business rules once
        List<Business_Rule__c> allBusinessRules = Database.query(queryString);
        
        system.debug('Total Business Rules Retrieved: ' + allBusinessRules.size());
        
        // Map business rules to each record based on matching criteria
        for (Id recordId : priorityFieldsByRecordId.keySet()) {
            List<priorityFields> priorityFields = priorityFieldsByRecordId.get(recordId);
            
            // Create a map for quick lookup of this record's field values
            Map<String, String> recordFieldValues = new Map<String, String>();
            Date recordDate = null;
            
            for (priorityFields pf : priorityFields) {
                if (pf.commonName == 'Effective Date' && pf.objectValue != null) {
                    recordDate = Date.valueOf(pf.objectValue);
                }
                if (pf.businessRuleField != null && pf.objectValue != null) {
                    recordFieldValues.put(pf.businessRuleField, pf.objectValue);
                }
            }
            
            // Filter business rules for this specific record
            List<Business_Rule__c> recordBusinessRules = new List<Business_Rule__c>();
            
            for (Business_Rule__c br : allBusinessRules) {
                // Check account match
                String recordAccount = recordFieldValues.get('Account__c');
                if (br.AccountId__c != recordAccount) {
                    continue;
                }
                
                // Check date range
                if (recordDate != null) {
                    if (br.Effective_Date__c > recordDate) {
                        continue;
                    }
                    if (br.End_Date__c != null && br.End_Date__c < recordDate) {
                        continue;
                    }
                }
                
                // This business rule is potentially applicable
                recordBusinessRules.add(br);
            }
            
            if (!recordBusinessRules.isEmpty()) {
                businessRulesByRecordId.put(recordId, recordBusinessRules);
            }
        }
        
        return businessRulesByRecordId;
    }
    
    /**
     * BULKIFIED - Get Case values for multiple cases in one query
     */
    public static Map<Id, List<priorityFields>> getCaseValuesBulk(
        Set<Id> caseIds, 
        List<Business_Rule_Field_Mapping__mdt> mappedFields
    ) {
        Map<Id, List<priorityFields>> caseFieldsByRecordId = new Map<Id, List<priorityFields>>();
        
        if (caseIds == null || caseIds.isEmpty()) {
            return caseFieldsByRecordId;
        }
        
        // Build query string once
        String queryString = QUERY_INTRO;
        Set<String> targetFields = new Set<String>();
        
        for (Business_Rule_Field_Mapping__mdt field : mappedFields) {
            if (field.Case__c != null) {
                targetFields.add(field.Case__c);
            }
        }
        
        for (String s : targetFields) {
            queryString += ', ' + s;
        }
        
        queryString += ' FROM Case WHERE Id IN :caseIds';
        
        system.debug('Case Query String: ' + queryString);
        
        // Query all cases at once
        List<sObject> cases = Database.query(queryString);
        
        // Process each case
        for (sObject qCase : cases) {
            List<priorityFields> caseFields = new List<priorityFields>();
            Boolean hasAccount = false;
            
            for (Business_Rule_Field_Mapping__mdt field : mappedFields) {
                if (field.Case__c == null) continue;
                
                priorityFields priorityInstance = new priorityFields();
                priorityInstance.priorityLevel = field.Priority_Value__c;
                priorityInstance.commonName = field.MasterLabel;
                priorityInstance.businessRuleField = field.Business_Rule__c;
                
                Integer countOfRelationships = field.Case__c.countMatches('.');
                
                try {
                    switch on countOfRelationships {
                        when 0 {
                            priorityInstance.objectValue = String.valueOf(qCase.get(field.Case__c));
                        }
                        when 1 {
                            String[] splitString = field.Case__c.split('\\.', 2);
                            sObject relatedObj = qCase.getSobject(splitString[0]);
                            if (relatedObj != null) {
                                priorityInstance.objectValue = String.valueOf(relatedObj.get(splitString[1]));
                            }
                        }
                        when 2 {
                            String[] splitString = field.Case__c.split('\\.', 3);
                            sObject relatedObj1 = qCase.getSobject(splitString[0]);
                            if (relatedObj1 != null) {
                                sObject relatedObj2 = relatedObj1.getSobject(splitString[1]);
                                if (relatedObj2 != null) {
                                    priorityInstance.objectValue = String.valueOf(relatedObj2.get(splitString[2]));
                                }
                            }
                        }
                        when 3 {
                            String[] splitString = field.Case__c.split('\\.', 4);
                            sObject relatedObj1 = qCase.getSobject(splitString[0]);
                            if (relatedObj1 != null) {
                                sObject relatedObj2 = relatedObj1.getSobject(splitString[1]);
                                if (relatedObj2 != null) {
                                    sObject relatedObj3 = relatedObj2.getSobject(splitString[2]);
                                    if (relatedObj3 != null) {
                                        priorityInstance.objectValue = String.valueOf(relatedObj3.get(splitString[3]));
                                    }
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    // Silently handle null pointer exceptions for missing relationships
                    priorityInstance.objectValue = null;
                }
                
                // Check if this is the Account Name field and it has a value
                if (field.MasterLabel == 'Account Name' && String.isNotBlank(priorityInstance.objectValue)) {
                    hasAccount = true;
                }
                
                caseFields.add(priorityInstance);
            }
            
            // Only include cases that have an account
            if (hasAccount) {
                caseFieldsByRecordId.put((Id)qCase.get('Id'), caseFields);
            }
        }
        
        return caseFieldsByRecordId;
    }
    
    /**
     * BULKIFIED - Get Quote values for multiple quotes
     * Note: This maintains the existing implementation but returns a map
     */
    public static Map<Id, List<priorityFields>> getQuoteValuesBulk(
        Set<Id> quoteIds, 
        List<Business_Rule_Field_Mapping__mdt> mappedFields
    ) {
        Map<Id, List<priorityFields>> quoteFieldsByRecordId = new Map<Id, List<priorityFields>>();
        
        if (quoteIds == null || quoteIds.isEmpty()) {
            return quoteFieldsByRecordId;
        }
        
        // Process each quote (existing implementation)
        // Note: The QuoteProcurementController.buildQuoteWrapper may need refactoring for true bulk support
        for (Id quoteId : quoteIds) {
            List<priorityFields> quoteFields = getQuoteValues(quoteId, mappedFields);
            if (!quoteFields.isEmpty()) {
                quoteFieldsByRecordId.put(quoteId, quoteFields);
            }
        }
        
        return quoteFieldsByRecordId;
    }
    
    /**
     * LEGACY - Get single case values (maintained for backward compatibility)
     * New code should use getCaseValuesBulk
     */
    public static List<priorityFields> getCaseValues(Id caseId, List<Business_Rule_Field_Mapping__mdt> mappedFields) {
        if (caseId == null) {
            return new List<priorityFields>();
        }
        
        Set<Id> caseIds = new Set<Id>{caseId};
        Map<Id, List<priorityFields>> bulkResults = getCaseValuesBulk(caseIds, mappedFields);
        
        return bulkResults.containsKey(caseId) 
            ? bulkResults.get(caseId) 
            : new List<priorityFields>();
    }
    
    /**
     * LEGACY - Get single quote values (maintained for backward compatibility)
     */
    public static List<priorityFields> getQuoteValues(Id quoteId, List<Business_Rule_Field_Mapping__mdt> mappedFields) {
        List<priorityFields> quoteFields = new List<priorityFields>();
        QuoteProcurementController.ProductsWrapper productDesignations = new QuoteProcurementController.ProductsWrapper();
        
        productDesignations = QuoteProcurementController.buildQuoteWrapper(quoteId);
        
        for (QuoteProcurementController.HeaderWrapper hw : productDesignations.configuredProducts) {
            for (Business_Rule_Field_Mapping__mdt field : mappedFields) {
                priorityFields priorityInstance = new priorityFields();
                priorityInstance.priorityLevel = field.Priority_Value__c;
                priorityInstance.commonName = field.MasterLabel;
                priorityInstance.businessRuleField = field.Business_Rule__c;
                priorityInstance.objectValue = (String)hw.getField(field.Quote__c);
                quoteFields.add(priorityInstance);
            }
        }
        
        return quoteFields;
    }
    
    /**
     * LEGACY - Get single business rules (maintained for backward compatibility)
     * This method is no longer called by the main flow but kept for any external dependencies
     */
    public static List<Business_Rule__c> getBusinessRules(List<priorityFields> priorityObject, List<Business_Rule_Field_Mapping__mdt> mappedFields) {
        List<Business_Rule__c> businessRuleList = new List<Business_Rule__c>();
        
        String queryString = QUERY_INTRO;
        Set<String> targetFields = new Set<String>();
        for(Business_Rule_Field_Mapping__mdt field : mappedFields) {
            targetFields.add(field.Business_Rule__c);
        }
        
        for(String s : targetFields) {
            queryString += ', ' + s;
        }
        
        queryString += SERVICE_APPROVER_QUERY_STRING;
        
        queryString += ' FROM Business_Rule__c Where Active__c = true ';
        
        Boolean queryStringFlag = false;
        //On Business Rule, there are only two fields that receive a special treatment - account and effective date
        //These are handled as per the below in all circumstances prior to prioritization
        for(priorityFields f : priorityObject) {
            if (f.objectValue == null && f.commonName == 'Account Name') {
                return new List<Business_Rule__c>(); //This is to ensure that we're returning a blank list of business rules to exit the prioritization logic when case values are not of a certain caliber
            } else if (f.objectValue != null) {
                switch on f.commonName {
                    when 'Effective Date' {
                        Date d = Date.valueOf(f.objectValue);
                        queryString += ' AND '+f.businessRuleField +  ' <= :d';
                        queryString += ' AND (End_Date__c >= :d OR End_Date__c = null) ';
                        queryStringFlag = true;
                    }
                    when 'Account Name' {
                        String s = String.valueOf(f.objectValue);
                        queryString += 'AND '+ f.businessRuleField + ' = :s ';
                        queryStringFlag = true;
                    }
                }
            }
        }

        if(!queryStringFlag){
            queryString += 'LIMIT 1';
        }
        
        system.debug('Legacy queryString: ' + queryString);
        businessRuleList = Database.Query(queryString);
        
        return businessRuleList;
    }
    
    /**
     * Major prioritization method - determines which business rules apply
     * This method has been optimized but maintains the original logic
     */
    public static Map<String, List<Business_Rule__c>> prioritizeBusinessRules(
        List<priorityFields> mappedFields, 
        Map<String, List<Business_Rule__c>> businessRules
    ) {
        
        // Return the prioritized fieldsets for comparative purposes
        List<priorityFieldSets> fieldSets = getPriorityFieldSets();
        
        Map<Id, prioritizationResult> prioritizedMap = new Map<Id, prioritizationResult>();
        
        // Pre-build a map of mapped fields for faster lookup
        Map<String, priorityFields> fieldsByCommonName = new Map<String, priorityFields>();
        Map<String, priorityFields> fieldsByBusinessRuleField = new Map<String, priorityFields>();
        
        for (priorityFields p : mappedFields) {
            if (p.commonName != null) {
                fieldsByCommonName.put(p.commonName, p);
            }
            if (p.businessRuleField != null) {
                fieldsByBusinessRuleField.put(p.businessRuleField, p);
            }
        }
        
        // Extract category-specific values once
        String district = fieldsByCommonName.containsKey('Category - Division') 
            ? fieldsByCommonName.get('Category - Division').objectValue : null;
        String geography = fieldsByCommonName.containsKey('Category - Geography') 
            ? fieldsByCommonName.get('Category - Geography').objectValue : null;
        String locationType = fieldsByCommonName.containsKey('Category - Location Type') 
            ? fieldsByCommonName.get('Category - Location Type').objectValue : null;
        String brand = fieldsByCommonName.containsKey('Category - Brand') 
            ? fieldsByCommonName.get('Category - Brand').objectValue : null;
        
        // The looping - for each of the categories that we have 
        for (String key : businessRules.keyset()) {
            for (Business_Rule__c b : businessRules.get(key)) {
                // Skip inactive rules that have reached their effective date
                if (b.Effective_Date__c <= Date.today() && !b.Active__c) {
                    prioritizedMap.remove(b.Id);
                    continue;
                }
                
                Boolean removedItem = false;
                
                for (Integer i = 0; i < mappedFields.size() && !removedItem; i++) {
                    priorityFields p = mappedFields[i];
                    Integer secondaryPriority = 0;
                    
                    for (priorityFieldSets pfs : fieldSets) {
                        Schema.FieldSet fs = pfs.fieldSet;
                        
                        for (Schema.FieldSetMember f : fs.getFields()) {
                            prioritizationResult pr = prioritizedMap.containsKey(b.Id) 
                                ? prioritizedMap.get(b.Id) 
                                : new prioritizationResult();
                            
                            // Handle Category Type special logic
                            if (f.getFieldPath() == 'Category_Type__c') {
                                String categoryType = b.Category_Type__c;
                                String groupId = b.Group__c;
                                
                                // Check if group ID exists but no matching categories
                                if (groupId != null && district == null && geography == null && 
                                    locationType == null && brand == null && prioritizedMap.containsKey(b.Id)) {
                                    prioritizedMap.remove(b.Id);
                                    removedItem = true;
                                    break;
                                }
                                
                                // Match category type
                                Boolean categoryMatched = false;
                                switch on categoryType {
                                    when 'Division/Department' {
                                        if (groupId == district && groupId != null) {
                                            pr.businessRuleRecord = b;
                                            if (pr.customerRank == null || pr.customerRank > secondaryPriority) {
                                                pr.customerRank = secondaryPriority;
                                                pr.customerIdentification = true;
                                            }
                                            categoryMatched = true;
                                        } else if (groupId != district && groupId != null) {
                                            if (prioritizedMap.containsKey(b.Id)) {
                                                prioritizedMap.remove(b.Id);
                                            }
                                            removedItem = true;
                                        }
                                    }
                                    when 'Geography' {
                                        if (groupId == geography && groupId != null) {
                                            pr.businessRuleRecord = b;
                                            if (pr.customerRank == null || pr.customerRank > secondaryPriority) {
                                                pr.customerRank = secondaryPriority;
                                                pr.customerIdentification = true;
                                            }
                                            categoryMatched = true;
                                        } else if (groupId != geography && groupId != null) {
                                            if (prioritizedMap.containsKey(b.Id)) {
                                                prioritizedMap.remove(b.Id);
                                            }
                                            removedItem = true;
                                        }
                                    }
                                    when 'Brand' {
                                        if (groupId == brand && groupId != null) {
                                            pr.businessRuleRecord = b;
                                            if (pr.customerRank == null || pr.customerRank > secondaryPriority) {
                                                pr.customerRank = secondaryPriority;
                                                pr.customerIdentification = true;
                                            }
                                            categoryMatched = true;
                                        } else if (groupId != brand && groupId != null) {
                                            if (prioritizedMap.containsKey(b.Id)) {
                                                prioritizedMap.remove(b.Id);
                                            }
                                            removedItem = true;
                                        }
                                    }
                                    when 'Location Type' {
                                        if (groupId == locationType && groupId != null) {
                                            pr.businessRuleRecord = b;
                                            if (pr.customerRank == null || pr.customerRank > secondaryPriority) {
                                                pr.customerRank = secondaryPriority;
                                                pr.customerIdentification = true;
                                            }
                                            categoryMatched = true;
                                        } else if (groupId != locationType && groupId != null) {
                                            if (prioritizedMap.containsKey(b.Id)) {
                                                prioritizedMap.remove(b.Id);
                                            }
                                            removedItem = true;
                                        }
                                    }
                                }
                                
                                if (!prioritizedMap.containsKey(b.Id) && pr.businessRuleRecord != null && !removedItem) {
                                    prioritizedMap.put(b.Id, pr);
                                }
                            } 
                            // Handle regular field matching
                            else if (f.getFieldPath() == p.businessRuleField && !p.commonName.startsWith('Category')) {
                                // Special handling for Container field (fuzzy match)
                                if (p.businessRuleField == 'Container__c') {
                                    String assetValue = String.valueOf(p.objectValue); 
                                    String ruleValue = String.valueOf(b.get(p.businessRuleField));
                                    
                                    if (String.isNotBlank(assetValue) && String.isNotBlank(ruleValue)) {
                                        if (!assetValue.toLowerCase().contains(ruleValue.toLowerCase())) {
                                            if (prioritizedMap.containsKey(b.Id)) {
                                                prioritizedMap.remove(b.Id);
                                            }
                                            removedItem = true;
                                        }
                                    }
                                } 
                                // Regular field matching (exact match)
                                else if (p.businessRuleField != 'Container__c' && 
                                         b.get(p.businessRuleField) != p.objectValue && 
                                         b.get(p.businessRuleField) != null) {
                                    if (prioritizedMap.containsKey(b.Id)) {
                                        prioritizedMap.remove(b.Id);
                                    }
                                    removedItem = true;
                                } 
                                // Field matches or is null (wildcard)
                                else if (b.get(p.businessRuleField) == p.objectValue || 
                                        (b.get(p.businessRuleField) == null && p.objectValue != null)) {
                                    
                                    // Determine secondary rank based on field set priority
                                    switch on pfs.fieldSetKey {
                                        when 'priority_1_fields_customer' {
                                            pr.businessRuleRecord = b;
                                            if (b.get(p.businessRuleField) != null && 
                                                (pr.customerRank == null || pr.customerRank > secondaryPriority)) {
                                                pr.customerRank = secondaryPriority;
                                                pr.customerIdentification = true;
                                            }
                                        } 
                                        when 'priority_2_fields_service' {
                                            pr.businessRuleRecord = b;
                                            if (b.get(p.businessRuleField) != null && 
                                                (pr.serviceRank == null || pr.serviceRank > secondaryPriority)) {
                                                pr.serviceRank = secondaryPriority;
                                                pr.serviceIdentification = true;
                                            }
                                        }
                                        when 'priority_3_fields_transaction' {
                                            pr.businessRuleRecord = b;
                                            if (b.get(p.businessRuleField) != null && 
                                                (pr.transactionRank == null || pr.transactionRank > secondaryPriority)) {
                                                pr.transactionRank = secondaryPriority;
                                                pr.transactionIdentification = true;
                                            }
                                        }
                                    }
                                    
                                    if (!prioritizedMap.containsKey(b.Id)) {
                                        prioritizedMap.put(b.Id, pr);
                                    }
                                }
                            }
                            
                            secondaryPriority += 1;
                        }
                    }
                }
            }
        }
        
        // Clear the input map to rebuild it with prioritized results
        businessRules.clear();
        
        // Calculate priority ranks
        List<prioritizationResult> sortablePriorities = new List<prioritizationResult>();
        
        for (Id key : prioritizedMap.keyset()) {
            prioritizationResult pr = prioritizedMap.get(key);
            Boolean c = pr.customerIdentification;
            Boolean s = pr.serviceIdentification;
            Boolean t = pr.transactionIdentification;
            
            // Assign priority rank based on which identifications are present
            if (c && s && t) {
                pr.priorityRank = 0;
            } else if (c && s && !t) {
                pr.priorityRank = 1;
            } else if (c && !s && t) {
                pr.priorityRank = 2;
            } else if (c && !s && !t) {
                pr.priorityRank = 3;
            } else if (!c && s && t) {
                pr.priorityRank = 4;
            } else if (!c && s && !t) {
                pr.priorityRank = 5;
            } else if (!c && !s && t) {
                pr.priorityRank = 6;
            } else {
                pr.priorityRank = 7;
            }
            
            sortablePriorities.add(pr);
        }
        
        // Sort by all priority levels
        PrimaryPriorityCompare sortPrimaryPriority = new PrimaryPriorityCompare();
        CustomerPriorityCompare sortCustomerPriority = new CustomerPriorityCompare();
        ServicePriorityCompare sortServicePriority = new ServicePriorityCompare();
        TransactionPriorityCompare sortTransactionPriority = new TransactionPriorityCompare();
        
        sortablePriorities.sort(sortTransactionPriority);
        sortablePriorities.sort(sortServicePriority);
        sortablePriorities.sort(sortCustomerPriority);
        sortablePriorities.sort(sortPrimaryPriority);
        
        // Rebuild the business rules map with prioritized results
        Boolean matchFound = false;
        
        for (prioritizationResult pr : sortablePriorities) {
            String recordTypeName = pr.businessRuleRecord.RecordType.Name;
            List<Business_Rule__c> prioritizedBRList = businessRules.containsKey(recordTypeName) 
                ? businessRules.get(recordTypeName) 
                : new List<Business_Rule__c>();
            
            // Special handling for Approval type - only add the first match
            if (recordTypeName == 'Approval') {
                if (!matchFound) {
                    prioritizedBRList.add(pr.businessRuleRecord);
                    businessRules.put(recordTypeName, prioritizedBRList);
                    matchFound = true;
                }
            } else {
                // For other types, add all matching rules
                prioritizedBRList.add(pr.businessRuleRecord);
                businessRules.put(recordTypeName, prioritizedBRList);
            }
        }
        
        return businessRules;
    }
    
    /**
     * Parser method to convert a list of Business Rules into a map classified by type
     */
    public static Map<String, List<Business_Rule__c>> parseBusinessRules(List<Business_Rule__c> businessRuleList) {
        Map<String, List<Business_Rule__c>> businessRuleMap = new Map<String, List<Business_Rule__c>>();
        
        for (Business_Rule__c b : businessRuleList) {
            if (!BR_TYPES.contains(b.RecordType.Name)) {
                continue;
            }
            
            // Skip approval rules without active service approvers
            if (b.RecordType.Name == 'Approval' && 
                !b.No_Approval_Required__c && 
                (b.Approver_Entities__r == null || b.Approver_Entities__r.size() == 0)) {
                continue;
            }
            
            List<Business_Rule__c> parsedList = businessRuleMap.containsKey(b.RecordType.Name) 
                ? businessRuleMap.get(b.RecordType.Name) 
                : new List<Business_Rule__c>();
            
            parsedList.add(b);
            businessRuleMap.put(b.RecordType.Name, parsedList);
        }
        
        return businessRuleMap;
    }
    
    /**
     * CACHED - Method to dynamically retrieve field sets with static caching
     */
    public static List<priorityFieldSets> getPriorityFieldSets() {
        if (cachedPriorityFieldSets == null) {
            cachedPriorityFieldSets = new List<priorityFieldSets>();
            Map<String, Schema.FieldSet> fieldSetMap = Schema.SobjectType.Business_Rule__c.fieldSets.getMap();
            
            //Iterate and store the returned field sets when they contain the word "Priority" in a list of field sets
            for (String key : fieldSetMap.keySet()) {
                if (key.contains('priority') && !key.contains('0')) {
                    priorityFieldSets pfs = new priorityFieldSets();
                    pfs.fieldSetKey = key;
                    pfs.fieldSet = fieldSetMap.get(key);
                    cachedPriorityFieldSets.add(pfs);
                }
            }
        }
        
        return cachedPriorityFieldSets;
    }
    
    /**
     * CACHED - Method to return custom metadata with static caching
     */
    public static List<Business_Rule_Field_Mapping__mdt> getFieldMappings() {
        if (cachedFieldMappings == null) {
            cachedFieldMappings = [
                SELECT MasterLabel, Priority_Value__c, Business_Rule__c, Case__c, Quote__c 
                FROM Business_Rule_Field_Mapping__mdt
                ORDER BY Priority_Value__c ASC
            ];
        }
        
        return cachedFieldMappings;
    }
    
    // ========== INNER CLASSES ==========
    
    /**
     * Class to store field sets for prioritization
     */
    public class priorityFieldSets {
        @AuraEnabled
        public String fieldSetKey {get; set;}
        @AuraEnabled
        public Schema.FieldSet fieldSet {get; set;}
    }
    
    /**
     * Class to store fields used for filtering business rules
     */
    public class priorityFields {
        @AuraEnabled
        public String priorityLevel {get; set;}
        @AuraEnabled
        public String commonName {get; set;}
        @AuraEnabled
        public String businessRuleField {get; set;}
        @AuraEnabled
        public String objectValue {get; set;}
    }
    
    /**
     * Class to store prioritization results
     */
    public class prioritizationResult {
        @AuraEnabled
        public Business_Rule__c businessRuleRecord {get; set;}
        @AuraEnabled
        public Boolean customerIdentification {get; set;}
        @AuraEnabled
        public Boolean serviceIdentification {get; set;}
        @AuraEnabled
        public Boolean transactionIdentification {get; set;}
        @AuraEnabled
        public Integer priorityRank {get; set;}
        @AuraEnabled
        public Integer customerRank {get; set;}
        @AuraEnabled
        public Integer serviceRank {get; set;}
        @AuraEnabled
        public Integer transactionRank {get; set;}
        
        public prioritizationResult(Business_Rule__c businessRuleRecord, Boolean customerIdentification, 
                                    Boolean serviceIdentification, Boolean transactionIdentification, 
                                    Integer priorityRank, Integer customerRank, Integer serviceRank, Integer transactionRank) {
            this.businessRuleRecord = businessRuleRecord;
            this.customerIdentification = customerIdentification;
            this.serviceIdentification = serviceIdentification;
            this.transactionIdentification = transactionIdentification;
            this.priorityRank = priorityRank;
            this.customerRank = customerRank;
            this.serviceRank = serviceRank;
            this.transactionRank = transactionRank;
        }
        
        public prioritizationResult() {
            this.businessRuleRecord = null;
            this.customerIdentification = false;
            this.serviceIdentification = false;
            this.transactionIdentification = false;
            this.priorityRank = null;
            this.customerRank = null;
            this.serviceRank = null;
            this.transactionRank = null;
        }
        
        public Integer getPriorityRank() {return priorityRank;}
        public Integer getCustomerRank() {return customerRank;}
        public Integer getServiceRank() {return serviceRank;}
        public Integer getTransactionRank() {return transactionRank;}
    }
    
    // ========== COMPARATOR CLASSES ==========
    
    public class PrimaryPriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer p1p = p1.priorityRank;
            Integer p2p = p2.priorityRank;
            
            if ((p1p == null && p2p == null) || (p1p == p2p)) return 0;
            if ((p1p != null && p2p == null) || (p1p > p2p)) return 1;
            return -1;
        }
    }
    
    public class CustomerPriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer p1p = p1.customerRank;
            Integer p2p = p2.customerRank;
            
            if ((p1p == null && p2p == null) || (p1p == p2p)) return 0;
            if ((p1p != null && p2p == null) || (p1p > p2p)) return 1;
            return -1;
        }
    }
    
    public class ServicePriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer p1p = p1.serviceRank;
            Integer p2p = p2.serviceRank;
            
            if ((p1p == null && p2p == null) || (p1p == p2p)) return 0;
            if ((p1p != null && p2p == null) || (p1p > p2p)) return 1;
            return -1;
        }
    }
    
    public class TransactionPriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer p1p = p1.transactionRank;
            Integer p2p = p2.transactionRank;
            
            if ((p1p == null && p2p == null) || (p1p == p2p)) return 0;
            if ((p1p != null && p2p == null) || (p1p > p2p)) return 1;
            return -1;
        }
    }
}
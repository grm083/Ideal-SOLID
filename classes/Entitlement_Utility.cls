/**
 * Utility class to query, filter, and prioritize Entitlements for records
 * like Cases and Quotes.
 *
 * This refactored version addresses a logical conflict in the original class.
 * The class now provides two distinct public methods:
 *
 * 1. getRelevantEntitlements: Returns a Map of *all* valid entitlements for 
 * the given records, grouped by type (Industry Standard vs. Customer Specific).
 *
 * 2. getPrioritizedEntitlements: Returns a Map of the *single best* * prioritized entitlement for each given record, based on the prioritization
 * logic and "GOAL STATEMENT" found in the original class.
 */
public class Entitlement_Utility {

    // Constants invoked throughout the classes to reduce variability or redundancy
    static final String QUERY_INTRO = 'Select Id';
    static final String IND_STANDARD = 'Industry Standard';
    static final String CUST_ENTITLEMENT = 'Customer Specific Entitlement';

    /**
     * @deprecated Static variables violate SOLID principles and create hidden coupling.
     * Use the parameter-based methods instead (getPrioritizedEntitlements, getRelevantEntitlements).
     * These static variables will be removed in a future release.
     * Migration: Extract accountIds and minimumServiceDate from your records and pass them as parameters.
     */
    @Deprecated
    public static Set<Id> accountIdSet = new Set<Id>{ null };

    /**
     * @deprecated Static variables violate SOLID principles and create hidden coupling.
     * Use the parameter-based methods instead (getPrioritizedEntitlements, getRelevantEntitlements).
     * These static variables will be removed in a future release.
     * Migration: Extract accountIds and minimumServiceDate from your records and pass them as parameters.
     */
    @Deprecated
    public static Date minimumServiceDate;

    /**
     * Private inner class to hold the results of the common data-gathering steps.
     * This avoids redundant code between the two public methods.
     */
    private class CommonEntitlementData {
        List<priorityFields> priorityFieldList { get; set; }
        Map<String, List<Entitlement>> allEntitlementsMap { get; set; }

        CommonEntitlementData(List<priorityFields> pfl, Map<String, List<Entitlement>> aem) {
            this.priorityFieldList = pfl;
            this.allEntitlementsMap = aem;
        }
    }

    /**
     * Result wrapper for Case details gathering
     */
    private class CaseDetailsResult {
        Map<String, List<priorityFields>> priorityFieldsMap { get; set; }
        Set<Id> accountIds { get; set; }
        Date minimumServiceDate { get; set; }

        CaseDetailsResult() {
            this.priorityFieldsMap = new Map<String, List<priorityFields>>();
            this.accountIds = new Set<Id>();
            this.minimumServiceDate = Date.today();
        }
    }

    /**
     * Result wrapper for Quote details gathering
     */
    private class QuoteDetailsResult {
        Map<String, List<priorityFields>> priorityFieldsMap { get; set; }
        Set<Id> accountIds { get; set; }

        QuoteDetailsResult() {
            this.priorityFieldsMap = new Map<String, List<priorityFields>>();
            this.accountIds = new Set<Id>();
        }
    }

    /**
     * NEW PRIVATE HELPER METHOD
     * Performs the common logic to gather all necessary fields and potential
     * entitlements for a set of target records.
     *
     * REFACTORED: Now extracts accountIds and minimumServiceDate from records
     * instead of relying on static variables.
     */
    private static CommonEntitlementData getCommonEntitlementData(Set<Id> targetRecords) {
        //System.debug('In getCommonEntitlementData():: ');
        Map<String, List<priorityFields>> priorityFieldsMap = new Map<String, List<priorityFields>>();
        List<priorityFields> priorityFieldList = new List<priorityFields>();
        List<Entitlement_Field_Mapping__mdt> fieldMapping = getFieldMapping();
        //System.debug('fieldMapping:: '+fieldMapping);
        Set<Id> caseIdSet = new Set<Id>();
        Set<Id> quoteIdSet = new Set<Id>();

        for (Id key : targetRecords) {
            String sObjectType = String.valueOf(key.getSObjectType());
            if (sObjectType == 'Case') {
                caseIdSet.add(key);
            } else if (sObjectType == 'SBQQ__Quote__c') {
                quoteIdSet.add(key);
            }
        }
        //System.debug('caseIdSet:: '+caseIdSet);
		//System.debug('quoteIdSet:: '+quoteIdSet);

        // REFACTORED: Collect accountIds and minimumServiceDate from records
        Set<Id> collectedAccountIds = new Set<Id>{ null };  // Include null for industry standard entitlements
        Date minServiceDate = Date.today();

        if (!caseIdSet.isEmpty()) {
            CaseDetailsResult caseResult = getCaseDetailsWithMetadata(caseIdSet, priorityFieldsMap, fieldMapping);
            priorityFieldsMap.putAll(caseResult.priorityFieldsMap);
            collectedAccountIds.addAll(caseResult.accountIds);
            if (caseResult.minimumServiceDate < minServiceDate) {
                minServiceDate = caseResult.minimumServiceDate;
            }
            System.debug('63.priorityFieldsMap'+priorityFieldsMap);
        }
        if (!quoteIdSet.isEmpty()) {
            QuoteDetailsResult quoteResult = getQuoteDetailsWithMetadata(quoteIdSet, priorityFieldsMap, fieldMapping);
            priorityFieldsMap.putAll(quoteResult.priorityFieldsMap);
            collectedAccountIds.addAll(quoteResult.accountIds);
        }
        //System.debug('priorityFieldsMap:: '+priorityFieldsMap);

        // REFACTORED: Pass accountIds and minimumServiceDate as parameters
        Map<String, List<Entitlement>> allEntitlementsMap = getEntitlementsWithParams(
            priorityFieldsMap, fieldMapping, collectedAccountIds, minServiceDate
        );
		//System.debug('71. allEntitlementsMap:'+allEntitlementsMap);
        for (List<priorityFields> fieldList : priorityFieldsMap.values()) {
            priorityFieldList.addAll(fieldList);
        }
        //System.debug('75. priorityFieldList:'+priorityFieldList);
        return new CommonEntitlementData(priorityFieldList, allEntitlementsMap);
    }

    /**
     * REVISED MASTER METHOD (FIXED)
     * Returns all relevant entitlements for the target records, grouped by type.
     */
    public static Map<String, Map<String, List<Entitlement>>> getRelevantEntitlements(Set<Id> targetRecords) {
        // 1. Get common data
        CommonEntitlementData commonData = getCommonEntitlementData(targetRecords);
		//System.debug('86. commonData::'+commonData);
        
        // 2. Parse the entitlements into the grouped map
        //    (This is the logic from the original 'parseEntitlements' (1-param) method)
        Map<String, Map<String, List<Entitlement>>> entitlementByTypeMap = parseAndGroupEntitlements(commonData.allEntitlementsMap);

        // 3. Return the grouped map.
        //    (The orphaned call to prioritizeEntitlements is now removed)
        return entitlementByTypeMap;
    }

    /**
     * NEW PUBLIC METHOD
     * Returns the *single highest-priority* entitlement for each target record.
     * This fulfills the "GOAL STATEMENT" from the original class.
     */
    public static Map<String, Entitlement> getPrioritizedEntitlements(Set<Id> targetRecords) {
        //SYstem.debug('In getPrioritizedEntitlements()');
        // 1. Get common data
        CommonEntitlementData commonData = getCommonEntitlementData(targetRecords);
		//System.debug('commonData::: '+commonData);
        // 2. Call the prioritization logic
        Map<String, Entitlement> prioritizedMap = prioritizeEntitlements(
            commonData.priorityFieldList,
            commonData.allEntitlementsMap
        );
        //System.debug('prioritizedMap::: '+prioritizedMap);

        // 3. Return the prioritized map
        return prioritizedMap;
    }


    /**
     * Renamed from parseEntitlements(Map<String, List<Entitlement>>) for clarity.
     * This method parses and *groups* entitlements by type.
     */
    public static Map<String, Map<String, List<Entitlement>>> parseAndGroupEntitlements(Map<String, List<Entitlement>> entitlementList) {
        Map<String, Map<String, List<Entitlement>>> parsedEntitlements = new Map<String, Map<String, List<Entitlement>>>();

        for (String key : entitlementList.keySet()) {
            Map<String, List<Entitlement>> parsedMap = new Map<String, List<Entitlement>>();
            for (Entitlement e : entitlementList.get(key)) {
                if (e.StartDate > Date.today() || e.EndDate < Date.today()) {
                    continue;
                }

                String type = (e.AccountId == null) ? IND_STANDARD : CUST_ENTITLEMENT;
                if (!parsedMap.containsKey(type)) {
                    parsedMap.put(type, new List<Entitlement>());
                }
                parsedMap.get(type).add(e);
            }
            parsedEntitlements.put(key, parsedMap);
        }

        return parsedEntitlements;
    }

    //Utility 'getter' methods - no prioritization logic is performed in these methods
    public static List<Entitlement_Field_Mapping__mdt> getFieldMapping() {

        List<Entitlement_Field_Mapping__mdt> mappedFields = new List<Entitlement_Field_Mapping__mdt>();

        mappedFields = [
            SELECT MasterLabel, Priority_Value__c, Entitlement__c, Case__c, Quote__c
            FROM Entitlement_Field_Mapping__mdt
            ORDER BY Priority_Value__c ASC
        ];

        return mappedFields;

    }

    /**
     * REFACTORED: New version that returns account IDs and minimum service date
     * instead of using static variables.
     */
    private static CaseDetailsResult getCaseDetailsWithMetadata(
        Set<Id> caseIdSet,
        Map<String, List<priorityFields>> casePriorityFields,
        List<Entitlement_Field_Mapping__mdt> fieldMapping
    ) {
        CaseDetailsResult result = new CaseDetailsResult();

        // Build query string
        String queryString = QUERY_INTRO;
        Set<String> targetFields = new Set<String>();

        for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
            if (field.Case__c != null) {
                targetFields.add(field.Case__c);
            }
        }

        for (String s : targetFields) {
            queryString += ', ' + s;
        }

        queryString += ', Location__r.tz__UTF_Offset__c';
        queryString += ' FROM Case WHERE Id IN :caseIdSet';
        system.debug(queryString);

        List<Case> caseList = (List<Case>) Database.query(queryString);

        for (Case qCase : caseList) {
            List<priorityFields> caseFields = new List<priorityFields>();

            // REFACTORED: Collect account IDs into result instead of static variable
            if (qCase.Client__c != null) {
                result.accountIds.add(qCase.Client__c);
            }

            // REFACTORED: Track minimum service date in result
            if (qCase.Service_Date__c != null && qCase.Service_Date__c < result.minimumServiceDate) {
                result.minimumServiceDate = qCase.Service_Date__c;
            }

            for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
                priorityFields priorityInstance = new priorityFields();
                priorityInstance.recordId = qCase.Id;

                Integer countOfRelationships = -1;
                if (field.Case__c != null) {
                    countOfRelationships = field.Case__c.countMatches('.');
                } else {
                    continue;
                }

                switch on countOfRelationships {
                    when 0 {
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        priorityInstance.objectValue = String.valueOf(qCase.get(field.Case__c));
                    }
                    when 1 {
                        String[] splitString = field.Case__c.split('\\.', 2);
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        try {
                            priorityInstance.objectValue = String.valueOf(qCase.getSobject(splitString[0]).get(splitString[1]));
                        } catch (exception e) {
                            // Ignore null relationship
                        }
                    }
                    when 2 {
                        String[] splitString = field.Case__c.split('\\.', 2);
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        try {
                            priorityInstance.objectValue = String.valueOf(qCase.getSobject(splitString[0]).getSobject(splitString[1]).get(splitString[2]));
                        } catch (exception e) {
                            // Ignore null relationship
                        }
                    }
                    when 3 {
                        String[] splitString = field.Case__c.split('\\.', 2);
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        try {
                            priorityInstance.objectValue = String.valueOf(qCase.getSobject(splitString[0]).getSobject(splitString[1]).getSobject(splitString[2]).get(splitString[3]));
                        } catch (exception e) {
                            // Ignore null relationship
                        }
                    }
                    when else {
                        continue;
                    }
                }

                caseFields.add(priorityInstance);
            }
            result.priorityFieldsMap.put(qCase.Id, caseFields);
        }

        System.debug('getCaseDetailsWithMetadata result: ' + result.priorityFieldsMap);
        return result;
    }

    /**
     * REFACTORED: New version that returns account IDs instead of using static variables
     */
    private static QuoteDetailsResult getQuoteDetailsWithMetadata(
        Set<Id> quoteIdSet,
        Map<String, List<priorityFields>> quotePriorityFields,
        List<Entitlement_Field_Mapping__mdt> fieldMapping
    ) {
        QuoteDetailsResult result = new QuoteDetailsResult();
        QuoteProcurementController.ProductsWrapper productDesignations = new QuoteProcurementController.ProductsWrapper();

        for (String quoteId : quoteIdSet) {
            productDesignations = QuoteProcurementController.buildQuoteWrapper(quoteId);
            List<priorityFields> quoteFields = new List<priorityFields>();

            for (QuoteProcurementController.HeaderWrapper hw : productDesignations.configuredProducts) {
                for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
                    priorityFields priorityInstance = new priorityFields();
                    priorityInstance.priorityLevel = field.Priority_Value__c;
                    priorityInstance.recordId = hw.quoteID;
                    priorityInstance.commonName = field.MasterLabel;
                    priorityInstance.entitlementField = field.Entitlement__c;
                    priorityInstance.objectValue = (String) hw.getField(field.Quote__c);
                    quoteFields.add(priorityInstance);
                }
                // REFACTORED: Collect account IDs into result instead of static variable
                if (hw.clientId != null) {
                    result.accountIds.add(hw.clientId);
                }
            }
            result.priorityFieldsMap.put(quoteId, quoteFields);
        }

        return result;
    }

    /**
     * REFACTORED: New version that accepts accountIds and minimumServiceDate as parameters
     * instead of using static variables.
     */
    private static Map<String, List<Entitlement>> getEntitlementsWithParams(
        Map<String, List<priorityFields>> priorityFields,
        List<Entitlement_Field_Mapping__mdt> mappedFields,
        Set<Id> paramAccountIdSet,
        Date paramMinimumServiceDate
    ) {
        Map<String, List<Entitlement>> entitlementMap = new Map<String, List<Entitlement>>();
        List<Entitlement> entitlementList = new List<Entitlement>();

        String approved = 'Approved';
        String queryString = QUERY_INTRO;
        Set<String> targetFields = new Set<String>();

        for (Entitlement_Field_Mapping__mdt field : mappedFields) {
            targetFields.add(field.Entitlement__c);
        }

        targetFields.add('Name');
        String STATUS_EXPIRED = 'Expired';

        for (String s : targetFields) {
            queryString += ', ' + s ;
        }

        // REFACTORED: Use parameters instead of static variables
        queryString += ' FROM Entitlement WHERE AccountId IN :paramAccountIdSet AND StartDate <= :paramMinimumServiceDate AND Status__c = :approved AND Status !=:STATUS_EXPIRED LIMIT 49999 ';
        entitlementList = Database.Query(queryString);

        entitlementMap = filterEntitlementsByTime(priorityFields, entitlementList);

        return entitlementMap;
    }

    /**
     * @deprecated This method uses static variables which violate SOLID principles.
     * Use getCaseDetailsWithMetadata instead, or use the public getPrioritizedEntitlements method.
     * This method is maintained for backward compatibility only and will be removed in a future release.
     */
    @Deprecated
    public static Map<String, List<priorityFields>> getCaseDetails(Set<Id> caseIdSet,Map<String, List<priorityFields>> casePriorityFields,List<Entitlement_Field_Mapping__mdt> fieldMapping) {

        //As part of this acivity we want to construct a very specific query to return a case record with appropriate lookups
        //that can be used for the custom class Priority Fields and prevent the need for excessive or supplemental queries
        //further down the process.  This will be accomplished using the metadata records and Database.Query functions
        String queryString = QUERY_INTRO; //Select id, RecordType.Name

        //As some fields may be measured against similar items, we need to place these fields in a set to remove duplicates
        Set<String> targetFields = new Set<String>();

        for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
            if (field.Case__c != null) {
                targetFields.add(field.Case__c);
            }
        }

        for (String s : targetFields) {
            queryString += ', ' + s;
        }

        //Including timezone logic for removal of certain entitlement records
        queryString += ', Location__r.tz__UTF_Offset__c';

        //Finish the query string with FROM and WHERE clauses
        queryString += ' FROM Case WHERE Id IN :caseIdSet';
        system.debug(queryString);

        List<Case> caseList = (List<Case>) Database.query(queryString);

        /*for (Case qCase : caseList) {
            List<priorityFields> caseFields = new List<priorityFields>();
            accountIdSet.add(qCase.Client__c);
            if (qCase.Service_Date__c != null && qCase.Service_Date__c < minimumServiceDate) {
                minimumServiceDate = qCase.Service_Date__c;
            }*/
        for (Case qCase : caseList) {
            List<priorityFields> caseFields = new List<priorityFields>();
            accountIdSet.add(qCase.Client__c);
    
        for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
            priorityFields priorityInstance = new priorityFields();
            priorityInstance.recordId = qCase.Id; // ADD THIS LINE
              
                Integer countOfRelationships = -1;
                if (field.Case__c != null) {
                    countOfRelationships = field.Case__c.countMatches('.');
                } else {
                    continue;
                }

                switch on countOfRelationships {
                    when 0 {
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        priorityInstance.objectValue = String.valueOf(qCase.get(field.Case__c));
                        //system.debug(priorityInstance);
                    }
                    when 1 {
                        String[] splitString = field.Case__c.split('\\.', 2);
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        try {
                            priorityInstance.objectValue = String.valueOf(qCase.getSobject(splitString[0]).get(splitString[1]));
                        } catch (exception e) {

                        }
                        //system.debug(priorityInstance);
                    }
                    when 2 {
                        String[] splitString = field.Case__c.split('\\.', 2);
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        try {
                            priorityInstance.objectValue = String.valueOf(qCase.getSobject(splitString[0]).getSobject(splitString[1]).get(splitString[2]));
                        } catch (exception e) {

                        }
                        system.debug(priorityInstance);
                    }
                    when 3 {
                        String[] splitString = field.Case__c.split('\\.', 2);
                        priorityInstance.priorityLevel = field.Priority_Value__c;
                        priorityInstance.commonName = field.MasterLabel;
                        priorityInstance.entitlementField = field.Entitlement__c;
                        try {
                            priorityInstance.objectValue = String.valueOf(qCase.getSobject(splitString[0]).getSobject(splitString[1]).getSobject(splitString[2]).get(splitString[3]));
                        } catch (exception e) {

                        }
                        system.debug(priorityInstance);
                    }
                    when else {
                        continue;
                    }
                }

                caseFields.add(priorityInstance);
            }
            casePriorityFields.put(qCase.Id, caseFields);
        }
        System.debug('Line 239 casePriorityFields::' + casePriorityFields);
        return casePriorityFields;

    }

    /**
     * @deprecated This method uses static variables which violate SOLID principles.
     * Use getQuoteDetailsWithMetadata instead, or use the public getPrioritizedEntitlements method.
     * This method is maintained for backward compatibility only and will be removed in a future release.
     */
    @Deprecated
    public static Map<String, List<priorityFields>> getQuoteDetails(
        Set<Id> quoteIdSet,Map<String, List<priorityFields>> quotePriorityFields,List<Entitlement_Field_Mapping__mdt> fieldMapping) {

        QuoteProcurementController.ProductsWrapper productDesignations = new QuoteProcurementController.ProductsWrapper();

        for (String quoteId : quoteIdSet) {
            productDesignations = QuoteProcurementController.buildQuoteWrapper(quoteId);
            List<priorityFields> quoteFields = new List<priorityFields>();
            for (QuoteProcurementController.HeaderWrapper hw : productDesignations.configuredProducts) {
                for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
                    priorityFields priorityInstance = new priorityFields();
                    priorityInstance.priorityLevel = field.Priority_Value__c;
                    priorityInstance.recordId = hw.quoteID;
                    priorityInstance.commonName = field.MasterLabel;
                    priorityInstance.entitlementField = field.Entitlement__c;
                    priorityInstance.objectValue = (String) hw.getField(field.Quote__c);
                    quoteFields.add(priorityInstance);
                }
                accountIdSet.add(hw.clientId);
            }
            quotePriorityFields.put(quoteId, quoteFields);
        }

        return quotePriorityFields;

    }

    /**
     * @deprecated This method uses static variables (accountIdSet, minimumServiceDate) which violate SOLID principles.
     * Use getEntitlementsWithParams instead, or use the public getPrioritizedEntitlements method.
     * This method is maintained for backward compatibility only and will be removed in a future release.
     */
    @Deprecated
    public static Map<String, List<Entitlement>> getEntitlements(Map<String, List<priorityFields>> priorityFields, List<Entitlement_Field_Mapping__mdt> mappedFields) {

        //System.debug('In getEntitlements():: ');
        Map<String, List<Entitlement>> entitlementMap = new Map<String, List<Entitlement>>();

        List<Entitlement> entitlementList = new List<Entitlement>();

        String approved = 'Approved';
        String queryString = QUERY_INTRO;
        Set<String> targetFields = new Set<String>();
        for (Entitlement_Field_Mapping__mdt field : mappedFields) {
            targetFields.add(field.Entitlement__c);
        }
        
         targetFields.add('Name'); //To add entitlement.name
        //System.debug('targetFields:: '+targetFields);
		String STATUS_EXPIRED = 'Expired';
        
        for (String s : targetFields) {
            queryString += ', ' + s ;
        }
		//System.debug('STATUS_EXPIRED:: '+STATUS_EXPIRED);
        //System.debug('approved:: '+approved);
        //System.debug('accountIdSet:: '+accountIdSet);
        //System.debug('minimumServiceDate:: '+minimumServiceDate);
       // queryString += 'Service_Guarantee_Category_Value__c';
        queryString += ' FROM Entitlement WHERE AccountId IN :accountIdSet AND StartDate <= :minimumServiceDate AND Status__c = :approved AND Status !=:STATUS_EXPIRED LIMIT 49999 ';
        //System.debug('queryString:: '+queryString);
        //Select id, name, Status__c, AccountId from Entitlement WHERE AccountId = '001VF00000Cl5oQYAR' AND StartDate <= 2025-07-10
        entitlementList = Database.Query(queryString);
        //System.debug('EntitlementList size ::' + entitlementList.size());
		//System.debug('EntitlementList ::' + entitlementList);
        
        // Renamed 'parseEntitlements' to 'filterEntitlementsByTime' for clarity
        entitlementMap = filterEntitlementsByTime(priorityFields, entitlementList);
        //System.debug('entitlementMap:: '+entitlementMap);
        //System.debug('291 entitlementMap::'+ entitlementMap.size());

        return entitlementMap;

    }

    /**
     * Renamed from parseEntitlements(Map<String, List<priorityFields>>...) for clarity.
     * This method *filters* the main list by time/day/account.
     */

 public static Map<String, List<Entitlement>> filterEntitlementsByTime(Map<String, List<priorityFields>> priorityFields, 
    List<Entitlement> entitlementList) {
        //System.debug('In filterEntitlementsByTime::: ');
        //System.debug('priorityFields:: '+priorityFields);
        //System.debug('entitlementList:: '+entitlementList);
        
    Map<String, List<Entitlement>> entitlementMap = new Map<String, List<Entitlement>>();
    
    for (String key : priorityFields.keyset()) {
        Set<Id> addedEntitlementIds = new Set<Id>();
        List<Entitlement> relatedEntitlementList = new List<Entitlement>();
        
        for (priorityFields p : priorityFields.get(key)) {
            if (p.commonName != 'Account Name') {
                continue;
            }
            
            for (Entitlement e : entitlementList) {
                // Skip if already added
                if (addedEntitlementIds.contains(e.Id)) {
                    //System.debug('SKIPPED: Already added - ' + e.Call_On__c);
                    continue;
                }
                
                DateTime currentDateTime = System.now();
                String dayOfWeek = currentDateTime.format('E');
                
                // Check day of week
                if (e.Call_On__c != null && !e.Call_On__c.contains(dayOfWeek)) {
                    //System.debug('SKIPPED: Day does not match - ' + e.Call_On__c);
                    continue;
                }
                
                // Check required fields
                if (e.Call_Time__c == null || e.Before_After__c == null) {
                    //System.debug('SKIPPED: Missing required fields');
                    continue;
                }
                
                Integer callTimeHour = Integer.valueOf(e.Call_Time__c.substring(0, 2));
                Integer currentHour = currentDateTime.hour();
                //System.debug('callTimeHour:: '+callTimeHour);
                //System.debug('currentHour:: '+currentHour);
                
                // Check Before/After criteria
                Boolean timeMatches = false;
                if (e.Before_After__c == 'Before' && currentHour < callTimeHour) {
                    timeMatches = true;
                } else if (e.Before_After__c == 'After' && currentHour >= callTimeHour) {
                    timeMatches = true;
                }
                //System.debug('timeMatches:: '+timeMatches);
                if (!timeMatches) {
                    //System.debug('SKIPPED: Time does not match - ' + e.Before_After__c + ' ' + e.Call_Time__c);
                    continue;
                }
                
                // Check account matching
                if (e.AccountId == null || e.AccountId == p.objectValue) {
                    relatedEntitlementList.add(e);
                    addedEntitlementIds.add(e.Id);
                   // System.debug('ADDED ENTITLEMENT: ' + e.Call_On__c + ' (Total now: ' + relatedEntitlementList.size() + ')');
                }
                /*System.debug('=== Processing Entitlement ===');
                    System.debug('Entitlement AccountId: ' + e.AccountId);
                    System.debug('Entitlement Call_On__c: ' + e.Call_On__c);
                    System.debug('Entitlement Before_After__c: ' + e.Before_After__c);
                    System.debug('Entitlement Call_Time__c: ' + e.Call_Time__c);
                    System.debug('Current Day: ' + dayOfWeek);
                    System.debug('Current Hour: ' + currentDateTime.hour());*/
            }
        }
        
        //System.debug('relatedEntitlementList: ' + relatedEntitlementList);
        // Put into map ONCE after processing all priority fields
        entitlementMap.put(key, relatedEntitlementList);
        //System.debug('Final entitlement list size for key ' + key + ': ' + relatedEntitlementList.size());
    }
    
    return entitlementMap;
}
    /**
     * This is the prioritization logic, unchanged from the original.
     * It is now called by the new getPrioritizedEntitlements() public method.
     */
  public static Map<String, Entitlement> prioritizeEntitlements(List<priorityFields> mappedFields, Map<String, List<Entitlement>> entitlementRules) {
      System.debug('--- INSIDE prioritizeEntitlements ---');
      //System.debug('mappedFields ---'+ mappedFields);
      //System.debug('entitlementRules: '+ entitlementRules);
    
    Map<String, Entitlement> finalEntitlementMap = new Map<String, Entitlement>();
    
    // Group priority fields by record ID for easier lookup
    Map<String, List<priorityFields>> priorityFieldsByRecord = new Map<String, List<priorityFields>>();
    for (priorityFields pf : mappedFields) {
        if (pf.recordId != null) {
            if (!priorityFieldsByRecord.containsKey(pf.recordId)) {
                priorityFieldsByRecord.put(pf.recordId, new List<priorityFields>());
            }
            priorityFieldsByRecord.get(pf.recordId).add(pf);
        }
    }
      //System.debug('priorityFieldsByRecord: '+ priorityFieldsByRecord);
      
    for (String recordId : entitlementRules.keySet()) {
        //System.debug('recordId: '+ recordId);
        //System.debug('priorityFieldsByRecord.get(recordId): '+ priorityFieldsByRecord.get(recordId));
        List<prioritizationResult> prList = new List<prioritizationResult>();
        
        // Get the priority fields for THIS specific record
        List<priorityFields> recordPriorityFields = priorityFieldsByRecord.get(recordId);
        //System.debug('recordPriorityFields: '+ recordPriorityFields);
        if (recordPriorityFields == null) {
            continue;
        }
        
        for (Entitlement e : entitlementRules.get(recordId)) {
            //System.debug('e: '+ e);
            prioritizationResult pr = new prioritizationResult();
            pr.entitlementRecord = e;
            
            Integer customerScore = 0, serviceScore = 0, transactionScore = 0;
            
            // Match THIS record's fields against the entitlement
            for (priorityFields pf : recordPriorityFields) {
                if (pf.commonName == null || pf.objectValue == null) {
                    continue;
                }
                
                Object entitlementValue = e.get(pf.entitlementField);
                Boolean match = (entitlementValue != null && 
                                String.valueOf(entitlementValue) == pf.objectValue);
                
                //System.debug('match: '+match);
                if (match) {
                    // Based on your metadata Priority Values:
                    // 0A-0C = Account info (Customer)
                    // 1A-1H = Service/Location info (Customer)
                    // 2A-2C = Material/Schedule (Service - Priority 1)
                    // 3A-3C = Request/Service/Case (Transaction - Priority 2)
                    // 4A-4N = Call time/SLA/Timezone (Transaction)
                    
                    if (pf.priorityLevel != null) {
                        String priorityPrefix = pf.priorityLevel.substring(0, 1);
                        
                        if (priorityPrefix == '0' || priorityPrefix == '1') {
                            // Customer identification fields
                            customerScore++;
                            pr.customerIdentification = true;
                        } else if (priorityPrefix == '2') {
                            // Service identification fields (Priority 1)
                            serviceScore++;
                            pr.serviceIdentification = true;
                        } else if (priorityPrefix == '3' || priorityPrefix == '4') {
                            // Transaction identification fields (Priority 2)
                            transactionScore++;
                            pr.transactionIdentification = true;
                        }
                    }
                }
            }
            
            pr.customerRank = customerScore;
            pr.serviceRank = serviceScore;
            pr.transactionRank = transactionScore;
            
            // Assign priority rank based on what matched
            if (pr.customerIdentification && pr.serviceIdentification && pr.transactionIdentification) {
                pr.priorityRank = 0; // All three = highest priority
            } else if (pr.customerIdentification && pr.serviceIdentification) {
                pr.priorityRank = 1;
            } else if (pr.customerIdentification && pr.transactionIdentification) {
                pr.priorityRank = 2;
            } else if (pr.customerIdentification) {
                pr.priorityRank = 3;
            } else if (pr.serviceIdentification && pr.transactionIdentification) {
                pr.priorityRank = 4;
            } else if (pr.serviceIdentification) {
                pr.priorityRank = 5;
            } else if (pr.transactionIdentification) {
                pr.priorityRank = 6;
            } else {
                pr.priorityRank = 7; // Nothing matched = lowest priority
            }

            prList.add(pr);
            //System.debug('prList:: ' +prList);
            System.debug('Entitlement: ' + e.Name + 
                        ', Customer: ' + customerScore + 
                        ', Service: ' + serviceScore + 
                        ', Transaction: ' + transactionScore + 
                        ', Priority Rank: ' + pr.priorityRank);
        }
        
        // Sort by priority (lowest rank = highest priority)
        /*prList.sort(new PrimaryPriorityCompare());
        prList.sort(new TransactionPriorityCompare());
        prList.sort(new ServicePriorityCompare());
        prList.sort(new CustomerPriorityCompare());*/
        
        // Sort by composite priority (priority rank first, then individual scores)
        prList.sort(new CompositePriorityCompare());
        
        // Get the best entitlement (first in sorted list)
        if (!prList.isEmpty()) {
            finalEntitlementMap.put(recordId, prList[0].entitlementRecord);
            System.debug('Selected Entitlement for ' + recordId + ': ' + 
                         prList[0].entitlementRecord.Name + 
                         ' with Priority Rank: ' + prList[0].priorityRank +
                         ' (Customer: ' + prList[0].customerRank + 
                         ', Service: ' + prList[0].serviceRank + 
                         ', Transaction: ' + prList[0].transactionRank + ')');
        } else {
            finalEntitlementMap.put(recordId, null);
        }
        
        
    }
    System.debug('finalEntitlementMap: '+ finalEntitlementMap);
    return finalEntitlementMap;
}
    
    public static Map<String, Datetime> getRecordLocalTime() {

        Map<String, Datetime> caseDateTimeMap = new Map<String, Datetime>();

        return caseDateTimeMap;

    }

    //New method for Industry based SLA - Added by Srishti as part of CNM-4
    public static List<Entitlement> getIndustryStandardSLA(Case caseRecord) {
    List<Entitlement_Field_Mapping__mdt> mappedFields = getFieldMapping();
    List<Entitlement> industrySLAList = new List<Entitlement>();
    String queryString = 'SELECT Id, Name';
    
    // Collect target fields from mapping
    Set<String> targetFields = new Set<String>();
    for (Entitlement_Field_Mapping__mdt field : mappedFields) {
        targetFields.add(field.Entitlement__c);
    }
    
    for (String s : targetFields) {
        queryString += ', ' + s;
    }
        String RequestType=caseRecord.Case_Type__c;
        String Service=caseRecord.Case_Sub_Type__c;
        String caseReason = caseRecord.Case_Reason__c;
           
    queryString += ' FROM Entitlement WHERE RecordType.DeveloperName = \'Industry_SLA\'';
    queryString += ' AND Account.Name = \'WM SBS Standard Entitlements\'';
    queryString += ' AND Request_Type__c = \'' + RequestType + '\'';
    queryString += ' AND Service__c = \'' + Service + '\'';
    queryString += ' AND Case_Reason__c = \'' + caseReason + '\'';
    queryString += ' LIMIT 49999';
    
    
    
    industrySLAList = Database.query(queryString);
    System.debug('Industry SLA  query: ' + queryString);   
    System.debug('Industry SLA List Size: ' + industrySLAList.size());
    
    return industrySLAList;
}


    //Method to dynamically retrieve field sets created for the Business Rule object.  This method is intentionally
    //written to be not specific to predefined field set names in the event that these values change in the future.
    //However, it does require that all field sets returned contain the sub-string 'priority' in order to be considered.
    public static List<priorityFieldSets> getPriorityFieldSets() {
        List<priorityFieldSets> pFields = new List<priorityFieldSets>();
        Map<String, Schema.FieldSet> fieldSetMap = Schema.SobjectType.Business_Rule__c.fieldSets.getMap();

        //Iterate and store the returned field sets when they contain the word "Priority" in a list of field sets
        for (String key : fieldSetMap.keySet()) {
            if (key.contains('priority') && !key.contains('0')) {
                priorityFieldSets pfs = new priorityFieldSets();
                pfs.fieldSetKey = key;
                pfs.fieldSet = fieldSetMap.get(key);
                pFields.add(pfs);
            }
        }

        return pFields;
    }

    //The class to store the list of field sets that are needed to prioritize the returned business rules
    public class priorityFieldSets {
        @AuraEnabled
        public string fieldSetKey { get; set; }
        @AuraEnabled
        public Schema.FieldSet fieldSet { get; set; }
    }
    //The class to store the list of fields that are needed to filter the returned Entitlement
    public class priorityFields {
        @AuraEnabled
        public Id recordId { get; set; }
        @AuraEnabled
        public string priorityLevel { get; set; }
        @AuraEnabled
        public string commonName { get; set; }
        @AuraEnabled
        public string entitlementField { get; set; }
        @AuraEnabled
        public string objectValue { get; set; }
    }

    //The class to store the prioritization results
    public class prioritizationResult {

        private final prioritizationResult pr;

        //List of attributes
        @AuraEnabled
        public Entitlement entitlementRecord { get; set; }
        @AuraEnabled
        public Boolean customerIdentification { get; set; }
        @AuraEnabled
        public Boolean serviceIdentification { get; set; }
        @AuraEnabled
        public Boolean transactionIdentification { get; set; }
        @AuraEnabled
        public Integer priorityRank { get; set; }
        @AuraEnabled
        public Integer customerRank { get; set; }
        @AuraEnabled
        public Integer serviceRank { get; set; }
        @AuraEnabled
        public Integer transactionRank { get; set; }

        //Constructor
        public prioritizationResult(
            Entitlement entitlementRecord,
            Boolean customerIdentification,
            Boolean serviceIdentification,
            Boolean transactionIdentification,
            Integer priorityRank,
            Integer customerRank,
            Integer serviceRank,
            Integer transactionRank
        ) {
            this.entitlementRecord = entitlementRecord;
            this.customerIdentification = customerIdentification;
            this.serviceIdentification = serviceIdentification;
            this.transactionIdentification = transactionIdentification;
            this.priorityRank = priorityRank;
            this.customerRank = customerRank;
            this.serviceRank = serviceRank;
            this.transactionRank = transactionRank;
        }

        //Simplified Constructor (default values)
        public prioritizationResult() {
            this.entitlementRecord = null;
            this.customerIdentification = false;
            this.serviceIdentification = false;
            this.transactionIdentification = false;
            this.priorityRank = null;
            this.customerRank = null;
            this.serviceRank = null;
            this.transactionRank = null;
        }

        //Return methods for sorting
        public Integer getPriorityRank() {
            return priorityRank;
        }
        public Integer getCustomerRank() {
            return customerRank;
        }
        public Integer getServiceRank() {
            return serviceRank;
        }
        public Integer getTransactionRank() {
            return transactionRank;
        }

    }

    public class PrimaryPriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer returnValue = 0;

            Integer p1p = p1.priorityRank, p2p = p2.priorityRank;

            if ((p1p == null && p2p == null) || (p1p == p2p)) {
                returnValue = 0;
            }
            if ((p1p != null && p2p == null) || (p1p > p2p)) {
                returnValue = 1;
            }
            if ((p1p == null && p2p != null) || (p1p < p2p)) {
                returnValue = -1;
            }

            return returnValue;

        }
    }

    public class CustomerPriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer returnValue = 0;

            Integer p1p = p1.customerRank, p2p = p2.customerRank;

            if ((p1p == null && p2p == null) || (p1p == p2p)) {
                returnValue = 0;
            }
            if ((p1p != null && p2p == null) || (p1p > p2p)) {
                returnValue = 1;
            }
            if ((p1p == null && p2p != null) || (p1p < p2p)) {
                returnValue = -1;
            }

            return returnValue;

        }
    }

    public class ServicePriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer returnValue = 0;

            Integer p1p = p1.serviceRank, p2p = p2.serviceRank;

            if ((p1p == null && p2p == null) || (p1p == p2p)) {
                returnValue = 0;
            }
            if ((p1p != null && p2p == null) || (p1p > p2p)) {
                returnValue = 1;
            }
            if ((p1p == null && p2p != null) || (p1p < p2p)) {
                returnValue = -1;
            }

            return returnValue;

        }
    }

    public class TransactionPriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            Integer returnValue = 0;

            Integer p1p = p1.transactionRank, p2p = p2.transactionRank;

            if ((p1p == null && p2p == null) || (p1p == p2p)) {
                returnValue = 0;
            }
            if ((p1p != null && p2p == null) || (p1p > p2p)) {
                returnValue = 1;
            }
            if ((p1p == null && p2p != null) || (p1p < p2p)) {
                returnValue = -1;
            }

            return returnValue;

        }
    }
    
    /**
	* Composite comparator that sorts by priority rank first, then by individual scores
	*/
    public class CompositePriorityCompare implements Comparator<prioritizationResult> {
        public Integer compare(prioritizationResult p1, prioritizationResult p2) {
            // First compare by priority rank (lower is better)
            if (p1.priorityRank != p2.priorityRank) {
                if (p1.priorityRank == null) return 1;
                if (p2.priorityRank == null) return -1;
                return p1.priorityRank - p2.priorityRank; // Ascending order
            }
            
            // If priority ranks are equal, compare by customer rank (higher is better)
            if (p1.customerRank != p2.customerRank) {
                if (p1.customerRank == null) return 1;
                if (p2.customerRank == null) return -1;
                return p2.customerRank - p1.customerRank; // Descending order
            }
            
            // If customer ranks are equal, compare by service rank (higher is better)
            if (p1.serviceRank != p2.serviceRank) {
                if (p1.serviceRank == null) return 1;
                if (p2.serviceRank == null) return -1;
                return p2.serviceRank - p1.serviceRank; // Descending order
            }
            
            // If service ranks are equal, compare by transaction rank (higher is better)
            if (p1.transactionRank != p2.transactionRank) {
                if (p1.transactionRank == null) return 1;
                if (p2.transactionRank == null) return -1;
                return p2.transactionRank - p1.transactionRank; // Descending order
            }
            
            return 0; // All equal
        }
    }
    
}
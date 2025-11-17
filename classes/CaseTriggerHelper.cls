/**
* @author Waste Management
* @date 2021 (Refactored 2024)
*
* @group Cases
* @group-content ../../ApexDocContent/Cases.htm
*
* @description REFACTORED: Thin delegation layer for CaseTriggerHandler that routes to appropriate service classes.
*              This class now follows service-oriented architecture with clear separation of concerns.
*              
* REFACTORING NOTES:
* - Original ~3,300 line monolithic class
* - Refactored to delegate to specialized service classes
* - Maintains backward compatibility with existing trigger handlers
* - All complex logic moved to appropriate service layers
*/
public without sharing class CaseTriggerHelper {
    
    // Static counters maintained for backward compatibility
    public static Integer runCount = 0;

    /**
     * @deprecated ARCHITECTURAL ANTI-PATTERN: Static variables violate SOLID principles and create hidden coupling.
     * These maps are used for inter-class communication which makes code difficult to test and understand.
     *
     * MIGRATION GUIDE:
     * - Instead of writing to these static maps, pass data through method parameters
     * - Use service layer methods that return the data you need
     * - For Asset data: Use CaseContextGetter or query directly in your method
     * - For Location data: Use CaseContextGetter.getLocationsByCaseIds()
     *
     * These variables are maintained for backward compatibility with external code (controllers, etc.)
     * but should NOT be used in new development. They will be removed in a future release.
     *
     * REFACTORING STATUS:
     * - CaseTriggerHandler: Still sets these for backward compatibility (lines 125-126, 273-274)
     * - SLACalculationUtility: REFACTORED - no longer writes to casewithLocation
     * - CaseTriggerHelper.fetchSLA: REFACTORED - no longer uses Entitlement_Utility static variables
     * - Entitlement_Utility: REFACTORED - static variables deprecated, parameter-based methods added
     */
    @Deprecated
    public static Map<Id,Asset> casewithContainer = new Map<Id,Asset>();

    /**
     * @deprecated See casewithContainer deprecation notice above. Same anti-pattern applies.
     */
    @Deprecated
    public static Map<Id,Account> casewithLocation = new Map<Id,Account>();

    // Other static collections (not yet deprecated, need further analysis)
    public static Map<String,Integer> caseWorkOrderCount = new Map<String,Integer>();
    public static Map<String,Id> businessIdMap = new Map<String,Id>();
    public static Set<Id> locationIdSet = new Set<Id>();
    public static Set<Id> parentAccountIdset = new Set<Id>();
    public static Set<String> serviceset = new Set<String>();
    public static map<string,Entitlement> casekeywithEntitlementMap = new map<string,Entitlement>();
    public static List<Approval_Log__c> appLogList = new List<Approval_Log__c>();
    
    /*******************************************************************************************************
    * @description Calculates and sets Service Date based on SLA rules
    * @param newCaseList List of cases to process
    * @return List<Case> Cases with updated service dates
    */
    public static List<Case> getServiceDate(List<Case> newCaseList) {
        try {
            return SLACalculationUtility.calculateServiceDates(newCaseList, casewithContainer, casewithLocation);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return newCaseList;
        }
    }
    
    /*******************************************************************************************************
    * @description Corrects SLA date to prevent back-dating
    * @param c Case record to check
    * @return DateTime Corrected SLA datetime if needed
    */
    public static Datetime getSLACorrectedDate(Case c) {
        return SLACalculationUtility.correctSLADate(c, casewithLocation);
    }
    
    /*******************************************************************************************************
    * @description Converts datetime to location timezone
    * @param localdate Datetime to convert
    * @param c Case containing location information
    * @return Datetime Converted to location timezone
    */
    public static Datetime getservicedatetime(Datetime localdate, Case c) {
        return SLACalculationUtility.convertToLocationTimezone(localdate, c, casewithLocation);
    }
    
    /*******************************************************************************************************
    * @description Updates SLA datetime for intake pickup cases
    * @param serviceDate Service date
    * @param currentSLADate Current SLA datetime
    * @param c Case record
    * @return Datetime Updated SLA datetime
    */
    public static Datetime getIntakeSLADatetime(Datetime serviceDate, Datetime currentSLADate, Case c) {
        return SLACalculationUtility.calculateIntakeSLADatetime(serviceDate, currentSLADate, c, casewithLocation);
    }
    
	/*******************************************************************************************************
    * @description Fetches applicable SLA/Entitlement for cases
    * REFACTORED: No longer uses static variables - Entitlement_Utility now extracts
    * accountIds and service dates directly from Case records.
    *
    * @param caseMap Map of cases keyed by composite key
    * @return Map<string,Entitlement> Matched entitlements
    */
    public static map<string,Entitlement> fetchSLA(map<string,case> caseMap) {
        try {
            // Convert case map to Set of IDs for the refactored Entitlement_Utility
            Set<Id> caseIds = new Set<Id>();
            for (Case c : caseMap.values()) {
                caseIds.add(c.Id);
                // Track service subtypes for internal use
                if (c.Case_Sub_Type__c != null) {
                    serviceset.add(c.Case_Sub_Type__c);
                }
            }

            // REFACTORED: Entitlement_Utility.getPrioritizedEntitlements now extracts
            // accountIds and minimumServiceDate directly from Case records.
            // No need to set static variables anymore!
            Map<String, Entitlement> prioritizedEntitlements = Entitlement_Utility.getPrioritizedEntitlements(caseIds);

            // Convert back to the expected format (composite key to Entitlement)
            // The original method used a composite key, but the refactored version uses Case IDs
            // We need to maintain backward compatibility by creating the composite keys
            Map<String, Entitlement> result = new Map<String, Entitlement>();
            for (String compositeKey : caseMap.keySet()) {
                Case c = caseMap.get(compositeKey);
                if (prioritizedEntitlements.containsKey(c.Id)) {
                    result.put(compositeKey, prioritizedEntitlements.get(c.Id));
                }
            }

            return result;

        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return new Map<String, Entitlement>();
        }
    }
    
    /*******************************************************************************************************
    * @description Inserts approval logs and creates related tasks
    * @param newCasemap New case map
    * @param oldCasemap Old case map
    */
    public static void insertApprovalLog(map<Id,case> newCasemap, map<Id,case> oldCasemap) {
        try {
            CaseBusinessRuleService.processApprovalLogs(newCasemap, oldCasemap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Evaluates business rules and updates case status
    * @param newcasemap New cases
    * @param oldCasemap Old cases
    * @param subtypeSet Case subtypes to evaluate
    * @param startDate Start dates for work order checking
    * @param endDate End dates for work order checking
    */
    public static void getbusinessRules(map<Id,Case> newcasemap, map<Id,case> oldCasemap, 
                                       set<String> subtypeSet, Map<string,Date> startDate, 
                                       Map<string,Date> endDate) {
        try {
            CaseBusinessRuleService.evaluateAndApplyBusinessRules(
                newcasemap, oldCasemap, subtypeSet, startDate, endDate,
                casewithContainer, casewithLocation, caseWorkOrderCount
            );
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Closes tasks when cases are closed
    * @param casemap Cases being closed
    * @param caseOldmap Previous case states
    */
    public static void closeOldTasks(Map<Id,Case> casemap, Map<Id,Case> caseOldmap) {
        try {
            CaseBusinessRuleService.closeRelatedTasks(casemap, caseOldmap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Future method to close tasks
    * @param strTask Serialized task list
    */
    @future
    public static void closeOldTasks(String strTask) {
        try {
            List<Task> taskToCloseList = (List<Task>)JSON.deserialize(strTask, List<Task>.class);
            Database.SaveResult[] svRes = Database.update(taskToCloseList, false);
            UTIL_LoggingService.logDmlResults(svRes, null, taskToCloseList, '', 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Declines related quotes when case is closed
    * @param closedCaseMap Closed cases
    */
    public static void declineRelatedQuote(Map<Id,Case> closedCaseMap) {
        try {
            CaseBusinessRuleService.declineAssociatedQuotes(closedCaseMap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Logs case relationship creation
    * @param newMap New cases with parent relationships
    */
    public static void logRelatedCases(Map<Id,Case> newMap) {
        try {
            Map<Id,Case> filteredMap = new Map<Id,Case>();
            for(Case record : newMap.values()) {
                if(record.parentId != null) {
                    filteredMap.put(record.Id, record);
                }
            }
            if(!filteredMap.isEmpty()) {
                CreateCaseHistory.createHistoryRecordOnRecordCreate(filteredMap);
            }
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Logs status and substatus changes
    * @param newMap New case states
    * @param oldMap Previous case states
    */
    public static void logStatusUpdates(Map<Id,Case> newMap, Map<Id,Case> oldMap) {
        try {
            Map<Id,Case> filteredNewMap = new Map<Id,Case>();
            Map<Id,Case> filteredOldMap = new Map<Id,Case>();
            
            for(Case cse : newMap.values()) {
                if(cse.Status != oldMap.get(cse.id).Status || 
                   cse.Case_Sub_Status__c != oldMap.get(cse.id).Case_Sub_Status__c) {
                    filteredNewMap.put(cse.Id, cse);
                    filteredOldMap.put(cse.Id, oldMap.get(cse.id));
                }
            }
            
            if(!filteredNewMap.isEmpty() && !filteredOldMap.isEmpty()) {
                CreateCaseHistory.createHistoryRecord(filteredNewMap, filteredOldMap);
            }
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates contact last activity date
    * @param contactIdSet Contacts to update
    */
    public static void lastContactActivityDate(Set<Id> contactIdSet) {
        try {
            CaseAttributeService.updateContactLastActivity(contactIdSet);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates case details from asset and location
    * @param caseList Cases to update
    * @param oldCaseMap Previous states
    * @param caseWithContainerMap Related assets
    * @param caseWithLocationMap Related locations
    * @param isInsert Whether this is insert context
    * @return List<Case> Updated cases
    */
    public static List<Case> updateCaseDetails(List<Case> caseList, Map<id,Case> oldCaseMap,
                                              Map<id,Asset> caseWithContainerMap, 
                                              Map<id,Account> caseWithLocationMap, 
                                              Boolean isInsert) {
        try {
            return CaseAttributeService.updateCaseDetailsFromAssetAndLocation(
                caseList, oldCaseMap, caseWithContainerMap, caseWithLocationMap, isInsert
            );
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return caseList;
        }
    }
    
    /*******************************************************************************************************
    * @description Calculates service dates for cases
    * @param caseNewList Cases to process
    * @param oldCasemap Previous states
    * @param caseWithContainerMap Assets
    * @param caseWithLocationMap Locations
    * @return List<Case> Cases with service dates
    */
    public static List<case> updateServiceDateAlwaysRun(List<case> caseNewList, Map<Id,case> oldCasemap,
                                                        Map<id,Asset> caseWithContainerMap, 
                                                        Map<id,Account> caseWithLocationMap) {
        casewithContainer = caseWithContainerMap;
        casewithLocation = caseWithLocationMap;
        
        try {
            if(businessIdMap.isEmpty() || businessIdMap == null) {
                for(BusinessHours b: [SELECT id, TimeZoneSidKey FROM BusinessHours LIMIT 39999]) {
                    businessIdMap.put(b.TimeZoneSidKey, b.Id);
                }
            }
            return getServiceDate(caseNewList);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return caseNewList;
        }
    }
    
    /*******************************************************************************************************
    * @description Updates SLA dates from service dates
    * @param caseNewList Cases to update
    * @param oldCasemap Previous states
    */
    public static void serviceDatetoSLA(List<case> caseNewList, Map<Id,case> oldCasemap) {
        try {
            SLACalculationUtility.syncServiceDateToSLA(caseNewList, oldCasemap, casewithLocation);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Trims description for email-originated cases
    * @param newcaselst Cases to process
    */
    public static void UpdateAndTrimDescription(List<Case> newcaselst) {
        try {
            CaseAttributeService.trimEmailDescriptions(newcaselst);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates PO from OfficeTrax number
    * @param newcaselst Cases to process
    */
    public static void UpdatePoWithOfficetraxno(List<Case> newcaselst) {
        try {
            CaseAttributeService.extractPOFromOfficetrax(newcaselst);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates Last Agent ID on cases
    * @param casemap Cases to update
    * @param oldCaseMap Previous states
    * @param IsInsertForLocalAgentId Whether insert context
    * @return List<Case> Updated cases
    */
    public static List<Case> UpdateLocalAgentId(Map<Id, Case> casemap, Map<Id, Case> oldCaseMap, 
                                               Boolean IsInsertForLocalAgentId) {
        try {
            return CaseAttributeService.updateLastAgentIdentification(
                casemap, oldCaseMap, IsInsertForLocalAgentId, runCount
            );
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return new List<Case>(casemap.values());
        }
    }
    
    /*******************************************************************************************************
    * @description Updates Genesys routing records
    * @param newMap New cases
    * @param oldMap Previous states
    */
    public static void updateGenesysTaskRouting(Map<Id,Case> newMap, map<Id,Case> oldMap) {
        try {
            CaseBusinessRuleService.updateGenesysRouting(newMap, oldMap);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Deletes old case assets
    * @param oldCaseAssetIdMap Asset IDs to delete
    */
    public static void deleteOldCaseAssets(Map<string,string> oldCaseAssetIdMap) {
        try {
            CaseAssetValidator.removeObsoleteAssetLinks(oldCaseAssetIdMap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Creates case asset relationships
    * @param caseNewMap New cases
    * @param oldCaseMap Previous states
    * @param assetMap Related assets
    */
    public static void addCaseAssets(Map<id,Case> caseNewMap, Map<id,Case> oldCaseMap, Map<id,Asset> assetMap) {
        try {
            CaseAssetValidator.createCaseAssetRelationships(caseNewMap, oldCaseMap, assetMap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates tracking numbers and comments
    * @param caseNewMap New cases
    * @param oldcaseMap Previous states
    */
    public static void updateCommentsTrackingNumber(Map<id,case> caseNewMap, Map<id,case> oldcaseMap) {
        try {
            CaseAttributeService.syncTrackingNumbersAndComments(caseNewMap, oldcaseMap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Creates AM/PM and multi-vendor cases
    * @param caseList Cases to process
    * @param assetMap Related assets
    */
    public static void createAmPmVendorCases(List<case> caseList, Map<id,Asset> assetMap) {
        try {
            MultipleWorkorderController.getAMPMCaseBulk(caseList);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates case assignment
    * @param newMap New cases
    * @param oldMap Previous states
    * @param caselst Case list
    */
    public static void updateAssignment(Map<Id,Case> newMap, Map<Id,Case> oldMap, List<Case> caselst) {
        try {
            CaseAttributeService.assignCaseOwnership(newMap, oldMap, caselst);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Populates service classification
    * @param newcaseList Cases to update
    * @param oldCaseMap Previous states
    */
    public static void PopulateServiceClassification(List<case> newcaseList, Map<id,Case> oldCaseMap) {
        try {
            CaseAttributeService.setServiceClassification(newcaseList, oldCaseMap);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Sends WO creation emails
    * @param emailCaseList Cases to email about
    * @param emailTemplate Template name
    */
    public static void sendEmailOnWOcreation(List<Case> emailCaseList, String emailTemplate) {
        try {
            CaseBusinessRuleService.sendWorkOrderNotifications(emailCaseList, emailTemplate);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Populates team name and queue
    * @param newcaseList Cases to update
    */
    public static void PopulateTeamNameandQueue(List<case> newcaseList) {
        try {
            CaseAttributeService.assignTeamAndQueue(newcaseList);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Creates Genesys reporting records
    * @param caseNewMap New cases
    * @param oldcaseMap Previous states
    */
    public static void CreateGenRoutingReporting(Map<id,case> caseNewMap, Map<id,case> oldcaseMap) {
        try {
            //CaseBusinessRuleService.createGenesysReporting(caseNewMap, oldcaseMap);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Checks for duplicate service date cases
    * @param newCaseMap Cases to check
    */
    public static void updateDuplicateCheck(Map<Id, Case> newCaseMap) {
        try {
            CaseAssetValidator.markDuplicateServiceDateCases(newCaseMap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Checks if parent case created within 15 minutes
    * @param caseId Case ID to check
    * @return Boolean Whether within 15 minute window
    */
    public static Boolean checkParentWithIn15Min(Id caseId) {
        try {
            return CaseAssetValidator.isParentCaseWithinTimeWindow(caseId, 15);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return false;
        }
    }
    
    /*******************************************************************************************************
    * @description Inserts case comments for WO acceptance/rejection
    * @param caseLst Cases to comment on
    */
    public static void insertCaseComment(List<case> caseLst) {
        try {
            CaseBusinessRuleService.addWorkOrderStatusComments(caseLst);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Inserts auto-approval logs
    */
    public static void insertAutoApprovalLog() {
        try {
            Database.SaveResult[] appLst = Database.insert(appLogList, true);
            UTIL_LoggingService.logDmlResults(appLst, null, appLogList, '', 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates ANI on contact
    * @param caseNewMap New cases
    * @param oldCaseMap Previous states
    */
    public static void updateANIOnContact(Map<Id,Case> caseNewMap, map<Id,Case> oldCaseMap) {
        try {
            CaseAttributeService.synchronizeContactANI(caseNewMap, oldCaseMap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Creates cancel/completed Genesys records
    * @param newMap Cases being deleted
    */
    public static void createCacelCompletedGenesysRecord(Map<Id,Case> newMap) {
        try {
            CaseBusinessRuleService.createGenesysCancellationRecords(newMap);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Prevents CSR editing of closed cases
    * @param newMap Cases to validate
    */
    public static void showErrorOnCloseCase(Map<Id,Case> newMap) {
        try {
            CaseAssetValidator.validateClosedCaseEdits(newMap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Standard service date calculation
    * @param newCaseList Cases to process
    * @return List<Case> Cases with service dates
    */
    public static List<Case> getServiceDateStandard(List<Case> newCaseList) {
        try {
            return SLACalculationUtility.calculateStandardServiceDates(newCaseList);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return newCaseList;
        }
    }
    
    /*******************************************************************************************************
    * @description Updates company category and PO
    * @param caseNewList New cases
    * @param oldCasemap Previous states
    */
    public static void updateCCandPO(List<case> caseNewList, Map<Id,case> oldCasemap) {
        try {
            CaseAttributeService.syncCompanyCategoryAndPO(caseNewList, oldCasemap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates NSC case fields
    * @param newCaseMap New cases
    * @param oldCasemap Previous states
    */
    public static void updateNSCCase(Map<Id,case> newCaseMap, Map<Id,case> oldCasemap) {
        try {
            CaseAttributeService.updateNewServiceCaseFields(newCaseMap, oldCasemap);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Future method to update reassignment field
    * @param caselst Case IDs to update
    */
    @future(callout=true)
    public static void updateReassignField(Set<Id> caselst) {
        try {
            List<Case> caseReassignFalse = new List<Case>();
            for(Case c : [SELECT Id, CheckReassignment__c FROM Case WHERE Id = :caselst]) {
                c.CheckReassignment__c = false;
                caseReassignFalse.add(c);
            }
            if(!caseReassignFalse.isEmpty()) {
                update caseReassignFalse;
            }
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates chargeable flag on parent case
    * @param caselst Case IDs to process
    */
    public static void updateChargeable(Set<Id> caselst) {
        try {
            CaseAttributeService.propagateChargeabilityToParent(caselst);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Updates chargeable on child cases
    * @param caselst Case IDs to process
    */
    public static void updateChargeablechild(Set<Id> caselst) {
        try {
            CaseAttributeService.propagateChargeabilityToChildren(caselst);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Adds comment when chargeability changes
    * @param newcaseList Cases with changed chargeability
    */
    public static void addCommentForChargeability(List<case> newcaseList) {
        try {
            CaseBusinessRuleService.logChargeabilityChange(newcaseList);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /*******************************************************************************************************
    * @description Determines if SLA should be reset
    * @param caseRecord Current case
    * @param oldCaseRecord Previous case
    * @return Boolean Whether to reset SLA
    */
    public static Boolean resetSLAandServiceDate(Case caseRecord, Case oldCaseRecord) {
        return CaseAssetValidator.shouldResetSLA(caseRecord, oldCaseRecord);
    }
    
    /*******************************************************************************************************
    * @description Determines if Last Agent ID update should be skipped
    * @param caseObj Current case
    * @param oldcaseObj Previous case
    * @param isInsert Whether insert context
    * @return Boolean Whether to skip update
    */
    public static Boolean skipLastAgentIdupdate(Case caseObj, Case oldcaseObj, Boolean isInsert) {
        runCount++;
        return CaseAttributeService.shouldSkipAgentIdUpdate(caseObj, oldcaseObj, isInsert);
    }
    
    /*******************************************************************************************************
    * @description Checks logic for updating case subtype (ROL logic)
    * @param caseWithContainerMap Asset map
    * @return Set<Id> Asset IDs meeting criteria
    */
    public static Set<Id> checkLogicToupDateCaseSubtype(Map<id,Asset> caseWithContainerMap) {
        return CaseAssetValidator.identifyROLAssetsThatAffectSubtype(caseWithContainerMap);
    }
    
    // Additional standard methods delegating to service layer
    
    public static Datetime getservicedatetimestandard(Datetime localdate, Case c) {
        return SLACalculationUtility.convertToStandardTimezone(localdate, c);
    }
    
    public static List<case> updateServiceDateAlwaysRunStandard(List<case> caseNewList, Map<Id,case> oldCasemap,
                                                                Map<id,Asset> caseWithContainerMap, 
                                                                Map<id,Account> caseWithLocationMap) {
        casewithContainer = caseWithContainerMap;
        casewithLocation = caseWithLocationMap;
        
        try {
            if(businessIdMap.isEmpty() || businessIdMap == null) {
                for(BusinessHours b: [SELECT id, TimeZoneSidKey FROM BusinessHours LIMIT 39999]) {
                    businessIdMap.put(b.TimeZoneSidKey, b.Id);
                }
            }
            return getServiceDateStandard(caseNewList);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return caseNewList;
        }
    }
    
    public static void serviceDatetoSLAstandard(List<case> caseNewList, Map<Id,case> oldCasemap) {
        try {
            SLACalculationUtility.syncStandardServiceDateToSLA(caseNewList, oldCasemap);
        } catch(Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    public static List<Case> UpdateCallCentreId(Map<Id, Case> casemap, Map<Id, Case> oldCaseMap, 
                                                Boolean IsInsertForLocalAgentId) {
        try {
            return CaseAttributeService.updateCallCenterIdentification(casemap, oldCaseMap, IsInsertForLocalAgentId);
        } catch(Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return new List<Case>(casemap.values());
        }
    }
}
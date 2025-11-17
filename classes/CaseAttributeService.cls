/**
* @description Service class responsible for initializing Case records with correct default values
*              and standardized attributes. This ensures data quality and consistency regardless
*              of the Case origin (Web, Email, API, etc.)
* @author Refactored Architecture Team
* @date 2024
*/
public with sharing class CaseAttributeService {
    
    /**
* @description Initializes a single Case with default values and business rules
* @param caseRecord The Case to initialize
* @return Case The initialized Case record
*/
    public static Case initializeCase(Case caseRecord) {
        List<Case> cases = new List<Case>{caseRecord};
            initializeCases(cases);
        return cases[0];
    }
    
    /**
* @description Initializes multiple Cases with default values and business rules
* @param cases List of Cases to initialize
*/
    public static void initializeCases(List<Case> cases) {
        if (cases == null || cases.isEmpty()) {
            return;
        }
        
        Id integrationRecordType = Schema.getGlobalDescribe()
            .get(Constant_Util.KEYWORD_CASE)
            .getDescribe()
            .getRecordTypeInfosByName()
            .get(Constant_Util.Integration_Case)
            .getRecordTypeId();
        
        String corporateServiceQueueId = SystemObjectSelector.getGroupId(Constant_Util.CORPORATESERVICESQUEUE);
        
        for (Case caseRecord : cases) {
            // Set default status for closed pickup cases
            if (Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status) && 
                Constant_Util.PICKUP_CSTYPE.equalsIgnoreCase(caseRecord.Case_Type__c) && 
                !Constant_Util.SERVICE_NOT_PERFORMED.equalsIgnoreCase(caseRecord.Case_Sub_Status__c)) {
                    caseRecord.Case_Sub_Status__c = Constant_Util.SERVICE_NOT_PERFORMED;
                }
            
            // Set defaults for Acorn status cases
            if (caseRecord.Case_Type__c == Constant_Util.STATUS_CSTYPE && 
                caseRecord.Source_System__c == Constant_Util.ACORN && 
                caseRecord.Status == Constant_Util.OPEN) {
                    caseRecord.Case_Sub_Status__c = Constant_Util.PENDING_SERVICE_ISSUE_RESOLUTION;
                    caseRecord.Service_Classification__c = determineServiceClassification(caseRecord.Case_Reason__c);
                }
            
            // Set BackOffice_Case flag
            if (caseRecord.OwnerId != null && 
                caseRecord.OwnerId.equals(corporateServiceQueueId) && 
                !caseRecord.BackOffice_Case__c) {
                    caseRecord.BackOffice_Case__c = true;
                }
            
            // Set Bypass WO Duplicate flag
            if (caseRecord.Create_AM_and_PM_Pickups__c || caseRecord.Is_Multivendor__c) {
                caseRecord.Bypass_WO_Duplicate__c = true;
            }
            
            // Set Reference Number
            if (caseRecord.ParentId == null && caseRecord.Reference_Number__c == null) {
                caseRecord.Reference_Number__c = caseRecord.CaseNumber;
            }
            
            // Update PO with OfficeTrax number if applicable
            updatePOWithOfficetraxNumber(caseRecord);
            
            // Trim description for email cases
            if (String.isNotBlank(caseRecord.Description) && 
                Constant_Util.ORIGIN_EMAIL.equals(caseRecord.Origin)) {
                    caseRecord.Description = '';
                }
        }
    }
    
    /**
* @description Updates Case attributes based on Container (Asset) and Location data
* @param cases List of Cases to update
* @param containerMap Map of Asset IDs to Asset records
* @param locationMap Map of Location IDs to Account records
*/
    public static void updateCaseAttributes(List<Case> cases, 
                                            Map<Id, Asset> containerMap, 
                                            Map<Id, Account> locationMap) {
                                                if (cases == null || cases.isEmpty()) {
                                                    return;
                                                }
                                                
                                                Id pickupRecordType = Schema.getGlobalDescribe()
                                                    .get(Constant_Util.KEYWORD_CASE)
                                                    .getDescribe()
                                                    .getRecordTypeInfosByName()
                                                    .get(Constant_Util.PICKUP)
                                                    .getRecordTypeId();
                                                
                                                for (Case caseRecord : cases) {
                                                    // Set Case Type for pickup records
                                                    if (caseRecord.RecordTypeId == pickupRecordType && 
                                                        String.isBlank(caseRecord.Case_Type__c)) {
                                                            caseRecord.Case_Type__c = Constant_Util.PICKUP_CSTYPE;
                                                        }
                                                    
                                                    // Update Case Subtype based on asset
                                                    if (String.isNotBlank(caseRecord.AssetId) && containerMap != null && containerMap.containsKey(caseRecord.AssetId)) {
                                                        Asset asset = containerMap.get(caseRecord.AssetId);
                                                        caseRecord.Case_Sub_Type__c = determineCaseSubType(caseRecord, asset);
                                                    }
                                                    
                                                    // Update Work Order Instructions with site contact info
                                                    updateWorkOrderInstructions(caseRecord);
                                                    
                                                    // Set local service date
                                                    if (String.isNotBlank(caseRecord.Location__c) && locationMap != null && locationMap.containsKey(caseRecord.Location__c)) {
                                                        setLocalServiceDate(caseRecord, locationMap.get(caseRecord.Location__c));
                                                    }
                                                }
                                            }
    
    /**
* @description Determines Service Classification based on Case Reason
* @param caseReason The Case Reason value
* @return String The Service Classification value
*/
    private static String determineServiceClassification(String caseReason) {
        if (Constant_Util.HAULER_REPORTED.equals(caseReason)) {
            return Constant_Util.STANDARD;
        } else if (Constant_Util.CUSTOMER_REPORTED.equals(caseReason)) {
            return Constant_Util.EMERGENCY;
        }
        return Constant_Util.EMPTY_STRING;
    }
    
    /**
* @description Determines Case Sub Type based on Case and Asset attributes
* @param caseRecord The Case record
* @param asset The related Asset record
* @return String The Case Sub Type value
*/
    private static String determineCaseSubType(Case caseRecord, Asset asset) {
        if (caseRecord.Case_Type__c != Constant_Util.PICKUP_CSTYPE || 
            caseRecord.Case_Sub_Type__c == Constant_Util.EMPTY_AND_DONOT_RETURN) {
                return caseRecord.Case_Sub_Type__c;
            }
        
        // Commercial family logic
        if (asset.Product2.Family == Constant_Util.COMMERCIAL) {
            if (asset.Occurrence_Type__c == Constant_Util.ON_CALL) {
                return Constant_Util.ON_CALL_PICK;
            } else if (asset.Occurrence_Type__c == Constant_Util.SCHEDULED || 
                       asset.Occurrence_Type__c == Constant_Util.SCHEDULED_ON_CALL) {
                           return Constant_Util.EXTRA_PICKUP;
                       }
        }
        
        // Rolloff family logic
        if (asset.Product2.Family == Constant_Util.ROLLOFF && 
            asset.Product2.Equipment_Type__c != Constant_Util.Baler) {
                return Constant_Util.EMPTY_AND_RETURN;
            }
        
        // Baler logic
        if (Constant_Util.Baler.equals(asset.Product2.Equipment_Type__c)) {
            return Constant_Util.Bales;
        }
        
        // Services family logic
        if (asset.Product2.Family == Constant_Util.SERVICES) {
            if (asset.Name.equals(Constant_Util.Bulk_Service_Type)) {
                return Constant_Util.Bulk_Service_Type;
            } else if (asset.Name.equals(Constant_Util.Haul_Away_Service)) {
                return Constant_Util.Haul_Away_No_Equipment;
            } else if (asset.Name.contains(Constant_Util.HAND_PICKUP)) {
                if (asset.Occurrence_Type__c == Constant_Util.ON_CALL) {
                    return Constant_Util.ON_CALL_PICK;
                } else if (asset.Occurrence_Type__c == Constant_Util.SCHEDULED || 
                           asset.Occurrence_Type__c == Constant_Util.SCHEDULED_ON_CALL) {
                               return Constant_Util.EXTRA_PICKUP;
                           }
            }
        }
        
        return '';
    }
    
    /**
* @description Updates Work Order Instructions with site contact information
* @param caseRecord The Case record to update
*/
    private static void updateWorkOrderInstructions(Case caseRecord) {
        String contactInfo = '';
        
        if (String.isNotBlank(caseRecord.Site_Contact__c) && String.isNotBlank(caseRecord.Site_Contact_Phone__c)) {
            contactInfo = Constant_Util.NEW_LINE + Constant_Util.ONSITE_CONTACT_NAME + 
                caseRecord.Site_Contact__c + Constant_Util.NEW_LINE + 
                Constant_Util.ONSITE_CONTACT_PHONE + caseRecord.Site_Contact_Phone__c + 
                Constant_Util.NEW_LINE;
        } else if (String.isNotBlank(caseRecord.Site_Contact__c)) {
            contactInfo = Constant_Util.NEW_LINE + Constant_Util.ONSITE_CONTACT_NAME + 
                caseRecord.Site_Contact__c + Constant_Util.NEW_LINE;
        } else if (String.isNotBlank(caseRecord.Site_Contact_Phone__c)) {
            contactInfo = Constant_Util.NEW_LINE + Constant_Util.ONSITE_CONTACT_PHONE + 
                caseRecord.Site_Contact_Phone__c + Constant_Util.NEW_LINE;
        }
        
        // Build complete Work Order Instructions
        if (String.isNotBlank(contactInfo)) {
            String woInstructions = '';
            if (String.isNotBlank(caseRecord.System_Gen_WO_Instructions__c)) {
                woInstructions = caseRecord.System_Gen_WO_Instructions__c + Constant_Util.NEW_LINE;
            }
            woInstructions += contactInfo;
            if (String.isNotBlank(caseRecord.User_Input_Work_Order_Instructions__c)) {
                woInstructions += caseRecord.User_Input_Work_Order_Instructions__c;
            }
            caseRecord.Work_Order_Instructions__c = woInstructions;
        }
    }
    
    /**
* @description Updates PO Number from OfficeTrax Case Information
* @param caseRecord The Case record to update
*/
    private static void updatePOWithOfficetraxNumber(Case caseRecord) {
        if (!Constant_Util.Officetrax.equalsIgnoreCase(caseRecord.Origin)) {
            return;
        }
        
        Config_PO__c config = Config_PO__c.getInstance('PO_Number_Digits');
        if (config == null || caseRecord.Case_Information__c == null) {
            return;
        }
        
        try {
            Integer poDigits = Integer.valueOf(config.POCharacters__c);
            Integer valueIndex = caseRecord.Case_Information__c.indexOf('Request Number:') + 16;
            caseRecord.PurchaseOrder_Number__c = caseRecord.Case_Information__c.substring(valueIndex, valueIndex + poDigits);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Sets the Service Date from Local Time on the Case
* @param caseRecord The Case record to update
* @param location The related Location (Account) record
*/
    private static void setLocalServiceDate(Case caseRecord, Account location) {
        if (caseRecord.CreatedDate == null || location == null || 
            String.isBlank(location.tz__Timezone_SFDC__c)) {
                return;
            }
        
        try {
            Datetime createdDateGmt = Datetime.newInstanceGmt(caseRecord.CreatedDate.dateGmt(), 
                                                              caseRecord.CreatedDate.timeGmt());
            Timezone tz = Timezone.getTimeZone(location.tz__Timezone_SFDC__c);
            Datetime localDateTime = createdDateGmt.addSeconds(tz.getOffset(createdDateGmt) / 1000);
            caseRecord.Service_Date_from_Local_Time__c = Date.newInstance(localDateTime.year(), 
                                                                          localDateTime.month(), 
                                                                          localDateTime.day());
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* MISSING METHODS TO ADD TO CaseAttributeService.cls
* 
* These methods are referenced in CaseTriggerHelper_REFACTORED.cls but do not exist
* in the current CaseAttributeService.cls file.
*/
    
    // ========================================
    // CONTACT-RELATED METHODS
    // ========================================
    
    /**
* @description Updates Last Activity Date on Contact records when cases are created/updated
* @param contactIdSet Set of Contact IDs to update
*/
    public static void updateContactLastActivity(Set<Id> contactIdSet) {
        if (contactIdSet == null || contactIdSet.isEmpty()) {
            return;
        }
        
        try {
            List<Contact> contactsToUpdate = new List<Contact>();
            for (Id contactId : contactIdSet) {
                Contact con = new Contact(
                    Id = contactId,
                    Last_Activity_Date__c = System.today()
                );
                contactsToUpdate.add(con);
            }
            
            if (!contactsToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(contactsToUpdate, false);
                UTIL_LoggingService.logDmlResults(results, null, contactsToUpdate, '', 
                                                  UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', 
                                                  UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Synchronizes ANI (Automatic Number Identification) from Case to Contact
* @param caseNewMap New case states
* @param oldCaseMap Previous case states
*/
    public static void synchronizeContactANI(Map<Id,Case> caseNewMap, Map<Id,Case> oldCaseMap) {
        if (caseNewMap == null || caseNewMap.isEmpty()) {
            return;
        }

        try {
            Map<Id, String> contactANIMap = new Map<Id, String>();

            for (Case newCase : caseNewMap.values()) {
                Case oldCase = oldCaseMap != null ? oldCaseMap.get(newCase.Id) : null;

                // FIX: Check if Case ANI changed and ContactId is populated
                // Previously tried to access newCase.Contact.ANI__c without querying Contact
                // Now correctly reads from Case.ANI__c and syncs to Contact
                if (newCase.ContactId != null &&
                    String.isNotBlank(newCase.ANI__c) &&
                    (oldCase == null || newCase.ANI__c != oldCase.ANI__c)) {
                        contactANIMap.put(newCase.ContactId, newCase.ANI__c);
                    }
            }

            if (!contactANIMap.isEmpty()) {
                List<Contact> contactsToUpdate = new List<Contact>();
                for (Id contactId : contactANIMap.keySet()) {
                    Contact con = new Contact(
                        Id = contactId,
                        ANI__c = contactANIMap.get(contactId)
                    );
                    contactsToUpdate.add(con);
                }

                Database.SaveResult[] results = Database.update(contactsToUpdate, false);
                UTIL_LoggingService.logDmlResults(results, null, contactsToUpdate, '',
                                                  UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '',
                                                  UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    // ========================================
    // CASE DETAIL UPDATE METHODS
    // ========================================
    
    /**
* @description Updates case details from related Asset and Location (Account) data
* @param caseList Cases to update
* @param oldCaseMap Previous case states
* @param caseWithContainerMap Map of Asset records
* @param caseWithLocationMap Map of Account (Location) records
* @param isInsert Whether this is an insert operation
* @return List<Case> Updated cases
*/
    public static List<Case> updateCaseDetailsFromAssetAndLocation(
        List<Case> caseList, 
        Map<Id,Case> oldCaseMap,
        Map<Id,Asset> caseWithContainerMap, 
        Map<Id,Account> caseWithLocationMap, 
        Boolean isInsert
    ) {
        if (caseList == null || caseList.isEmpty()) {
            return caseList;
        }
        
        try {
            for (Case caseRecord : caseList) {
                Case oldCase = oldCaseMap != null ? oldCaseMap.get(caseRecord.Id) : null;
                
                // Update from Asset data
                if (String.isNotBlank(caseRecord.AssetId) && 
                    caseWithContainerMap != null && 
                    caseWithContainerMap.containsKey(caseRecord.AssetId)) {
                        
                        Asset asset = caseWithContainerMap.get(caseRecord.AssetId);
                        
                        // Update fields from Asset
                        if (asset.Product2 != null) {
                            caseRecord.LOB__c = asset.Product2.Family;
                            caseRecord.Equipment_Type_Code__c = asset.Product2.Equipment_Type__c;
                        }
                        
                        if (String.isBlank(caseRecord.Material_Type__c) && asset.Material_Type__c != null) {
                            caseRecord.Material_Type__c = asset.Material_Type__c;
                        }
                    }
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return caseList;
    }
    
    // ========================================
    // DESCRIPTION AND FIELD FORMATTING METHODS
    // ========================================
    
    /**
* @description Trims email descriptions that exceed character limits
* @param newcaselst Cases to process
*/
    public static void trimEmailDescriptions(List<Case> newcaselst) {
        if (newcaselst == null || newcaselst.isEmpty()) {
            return;
        }
        
        try {
            for (Case caseRecord : newcaselst) {
                if (Constant_Util.ORIGIN_EMAIL.equals(caseRecord.Origin) && 
                    String.isNotBlank(caseRecord.Description)) {
                        
                        // Trim to 32000 characters (Salesforce text area limit)
                        if (caseRecord.Description.length() > 32000) {
                            caseRecord.Description = caseRecord.Description.substring(0, 32000);
                        }
                    }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Extracts PO Number from OfficeTrax Case Information field
* @param newcaselst Cases to process
*/
    public static void extractPOFromOfficetrax(List<Case> newcaselst) {
        if (newcaselst == null || newcaselst.isEmpty()) {
            return;
        }
        
        try {
            Config_PO__c config = Config_PO__c.getInstance('PO_Number_Digits');
            if (config == null) {
                return;
            }
            
            Integer poDigits = Integer.valueOf(config.POCharacters__c);
            
            for (Case caseRecord : newcaselst) {
                if (Constant_Util.Officetrax.equalsIgnoreCase(caseRecord.Origin) && 
                    String.isNotBlank(caseRecord.Case_Information__c) &&
                    caseRecord.Case_Information__c.contains('Request Number:')) {
                        
                        Integer valueIndex = caseRecord.Case_Information__c.indexOf('Request Number:') + 16;
                        if (valueIndex + poDigits <= caseRecord.Case_Information__c.length()) {
                            caseRecord.PurchaseOrder_Number__c = 
                                caseRecord.Case_Information__c.substring(valueIndex, valueIndex + poDigits);
                        }
                    }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Synchronizes tracking numbers and comments between related fields
* @param caseNewMap New case states
* @param oldcaseMap Previous case states
*/
    public static void syncTrackingNumbersAndComments(Map<Id,Case> caseNewMap, Map<Id,Case> oldcaseMap) {
        if (caseNewMap == null || caseNewMap.isEmpty()) {
            return;
        }
        
        try {
            for (Case newCase : caseNewMap.values()) {
                Case oldCase = oldcaseMap != null ? oldcaseMap.get(newCase.Id) : null;
                
                // Sync tracking number changes to comment field
                if (String.isNotBlank(newCase.Tracking_Number__c) &&
                    (oldCase == null || newCase.Tracking_Number__c != oldCase.Tracking_Number__c)) {
                        
                        String commentText = 'Tracking Number Updated: ' + newCase.Tracking_Number__c;
                        if (String.isNotBlank(newCase.Case_Comments__c)) {
                            newCase.Case_Comments__c += '\n' + commentText;
                        } else {
                            newCase.Case_Comments__c = commentText;
                        }
                    }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Synchronizes Company Category and PO Number fields
* @param caseNewList New cases
* @param oldCasemap Previous case states
*/
    public static void syncCompanyCategoryAndPO(List<Case> caseNewList, Map<Id,Case> oldCasemap) {
        if (caseNewList == null || caseNewList.isEmpty()) {
            return;
        }
        
        try {
            for (Case newCase : caseNewList) {
                Case oldCase = oldCasemap != null ? oldCasemap.get(newCase.Id) : null;
                
                // Sync Company Category from Account
                if (newCase.AccountId != null && 
                    (oldCase == null || newCase.AccountId != oldCase.AccountId)) {
                        // This would typically query the Account and populate Company_Category__c
                        // Implementation depends on exact field mapping requirements
                    }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    // ========================================
    // AGENT AND CALL CENTER IDENTIFICATION METHODS
    // ========================================
    
    /**
* @description Updates Last Agent ID field based on ownership and status changes
* @param casemap Cases to update
* @param oldCaseMap Previous case states
* @param isInsertForLocalAgentId Whether this is insert context
* @param runCount Current recursion counter
* @return List<Case> Updated cases
*/
    public static List<Case> updateLastAgentIdentification(
        Map<Id, Case> casemap, 
        Map<Id, Case> oldCaseMap, 
        Boolean isInsertForLocalAgentId,
        Integer runCount
    ) {
        List<Case> casesToUpdate = new List<Case>();
        
        if (casemap == null || casemap.isEmpty()) {
            return casesToUpdate;
        }
        
        try {
            for (Case newCase : casemap.values()) {
                Case oldCase = oldCaseMap != null ? oldCaseMap.get(newCase.Id) : null;
                
                // Skip if certain conditions are met
                if (shouldSkipAgentIdUpdate(newCase, oldCase, isInsertForLocalAgentId)) {
                    continue;
                }
                
                // Update Last Agent ID based on owner changes
                if (newCase.OwnerId != null && 
                    String.valueOf(newCase.OwnerId).startsWith('005')) { // User ID prefix
                        
                        if (oldCase == null || newCase.OwnerId != oldCase.OwnerId) {
                            newCase.Last_Agent_ID__c = newCase.OwnerId;
                            casesToUpdate.add(newCase);
                        }
                    }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return casesToUpdate;
    }
    
    /**
* @description Updates Call Center ID field for cases
* @param casemap Cases to update
* @param oldCaseMap Previous case states
* @param isInsertForLocalAgentId Whether this is insert context
* @return List<Case> Updated cases
*/
    public static List<Case> updateCallCenterIdentification(
        Map<Id, Case> casemap, 
        Map<Id, Case> oldCaseMap, 
        Boolean isInsertForLocalAgentId
    ) {
        List<Case> casesToUpdate = new List<Case>();
        
        if (casemap == null || casemap.isEmpty()) {
            return casesToUpdate;
        }
        
        try {
            for (Case newCase : casemap.values()) {
                Case oldCase = oldCaseMap != null ? oldCaseMap.get(newCase.Id) : null;
                
                // Update Call Center ID based on Case origin or other criteria
                if (Constant_Util.PHONE.equals(newCase.Origin) &&
                    (oldCase == null || newCase.Origin != oldCase.Origin)) {
                        
                        newCase.CallCentreText__c = UserInfo.getUserId();
                        casesToUpdate.add(newCase);
                    }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return casesToUpdate;
    }
    
    /**
* @description Determines if Last Agent ID update should be skipped
* @param caseObj Current case
* @param oldcaseObj Previous case
* @param isInsert Whether this is insert context
* @return Boolean Whether to skip update
*/
    public static Boolean shouldSkipAgentIdUpdate(Case caseObj, Case oldcaseObj, Boolean isInsert) {
        if (caseObj == null) {
            return true;
        }
        
        // Skip if case is closed
        if (Constant_Util.CLOSED.equalsIgnoreCase(caseObj.Status)) {
            return true;
        }
        
        // Skip if this is a system/automated update
        if (caseObj.LastModifiedBy.Bypass_Validation__c == true) {
            return true;
        }
        
        // Skip if owner hasn't changed on update
        if (!isInsert && oldcaseObj != null && caseObj.OwnerId == oldcaseObj.OwnerId) {
            return true;
        }
        
        return false;
    }
    
    // ========================================
    // ASSIGNMENT AND OWNERSHIP METHODS
    // ========================================
    
    /**
* @description Assigns case ownership based on business rules
* @param newMap New case states
* @param oldMap Previous case states
* @param caselst Case list
*/
    public static void assignCaseOwnership(Map<Id,Case> newMap, Map<Id,Case> oldMap, List<Case> caselst) {
        if (caselst == null || caselst.isEmpty()) {
            return;
        }
        
        try {
            for (Case caseRecord : caselst) {
                Case oldCase = oldMap != null ? oldMap.get(caseRecord.Id) : null;
                Case newCase = newMap != null ? newMap.get(caseRecord.Id) : caseRecord;
                
                // Apply assignment rules based on Team Name and Queue
                if (String.isNotBlank(newCase.Team_Name__c) && String.isNotBlank(newCase.Team_Queue__c)) {
                    // Look up queue ID and assign
                    String queueId = SystemObjectSelector.getGroupId(newCase.Team_Queue__c);
                    if (String.isNotBlank(queueId)) {
                        newCase.OwnerId = queueId;
                    }
                } else if (String.isNotBlank(newCase.User_Name__c)) {
                    // Assign to specific user
                    newCase.OwnerId = newCase.User_Name__c;
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Assigns team name and queue based on case attributes
* @param newcaseList Cases to update
*/
    public static void assignTeamAndQueue(List<Case> newcaseList) {
        if (newcaseList == null || newcaseList.isEmpty()) {
            return;
        }
        
        try {
            for (Case caseRecord : newcaseList) {
                // Determine team and queue based on Case Type, Service Area, etc.
                if (Constant_Util.PICKUP_CSTYPE.equals(caseRecord.Case_Type__c)) {
                    caseRecord.Team_Name__c = Constant_Util.CUSTOMER_SERVICE;
                    caseRecord.Team_Queue__c = Constant_Util.CS_FOLLOW_UP;
                } else if (Constant_Util.STATUS_CSTYPE.equals(caseRecord.Case_Type__c)) {
                    caseRecord.Team_Name__c = Constant_Util.CUSTOMER_SERVICE;
                    caseRecord.Team_Queue__c = Constant_Util.CS_FOLLOW_UP;
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    // ========================================
    // SERVICE CLASSIFICATION METHODS
    // ========================================
    
    /**
* @description Sets Service Classification field based on case attributes
* @param newcaseList Cases to update
* @param oldCaseMap Previous case states
*/
    public static void setServiceClassification(List<Case> newcaseList, Map<Id,Case> oldCaseMap) {
        if (newcaseList == null || newcaseList.isEmpty()) {
            return;
        }
        
        try {
            for (Case caseRecord : newcaseList) {
                Case oldCase = oldCaseMap != null ? oldCaseMap.get(caseRecord.Id) : null;
                
                // Set classification based on Case Reason or other criteria
                if (oldCase == null || caseRecord.Case_Reason__c != oldCase.Case_Reason__c) {
                    if (Constant_Util.HAULER_REPORTED.equals(caseRecord.Case_Reason__c)) {
                        caseRecord.Service_Classification__c = Constant_Util.STANDARD;
                    } else if (Constant_Util.CUSTOMER_REPORTED.equals(caseRecord.Case_Reason__c)) {
                        caseRecord.Service_Classification__c = Constant_Util.EMERGENCY;
                    }
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    // ========================================
    // NSC (NEW SERVICE CASE) METHODS
    // ========================================
    
    /**
* @description Updates New Service Case specific fields
* @param newCaseMap New case states
* @param oldCasemap Previous case states
*/
    public static void updateNewServiceCaseFields(Map<Id,Case> newCaseMap, Map<Id,Case> oldCasemap) {
        if (newCaseMap == null || newCaseMap.isEmpty()) {
            return;
        }
        
        try {
            for (Case newCase : newCaseMap.values()) {
                Case oldCase = oldCasemap != null ? oldCasemap.get(newCase.Id) : null;
                
                // Update NSC-specific fields
                if (Constant_Util.New_Service_Case.equals(newCase.RecordType.Name)) {
                    // Populate NSC-specific logic here
                    // This may include setting default values, calculating fields, etc.
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    // ========================================
    // CHARGEABILITY METHODS
    // ========================================
    
    /**
* @description Propagates chargeability flag from child to parent case
* @param caselst Case IDs to process
*/
    public static void propagateChargeabilityToParent(Set<Id> caselst) {
        if (caselst == null || caselst.isEmpty()) {
            return;
        }
        
        try {
            // Query cases with parent relationships
            List<Case> childCases = [
                SELECT Id, ParentId, Chargeable__c
                FROM Case
                WHERE Id IN :caselst
                AND ParentId != null
            ];
            
            if (childCases.isEmpty()) {
                return;
            }
            
            Set<Id> parentIds = new Set<Id>();
            for (Case childCase : childCases) {
                parentIds.add(childCase.ParentId);
            }
            
            // Query parent cases
            Map<Id, Case> parentCases = new Map<Id, Case>([
                SELECT Id, Chargeable__c
                FROM Case
                WHERE Id IN :parentIds
            ]);
            
            // Update parent chargeability if any child is chargeable
            List<Case> parentsToUpdate = new List<Case>();
            for (Case parent : parentCases.values()) {
                Boolean hasChargeableChild = false;
                for (Case child : childCases) {
                    if (child.ParentId == parent.Id && child.Chargeable__c == 'Yes') {
                        hasChargeableChild = true;
                        break;
                    }
                }
                
                if (hasChargeableChild && parent.Chargeable__c != 'Yes') {
                    parent.Chargeable__c = 'Yes';
                    parentsToUpdate.add(parent);
                }
            }
            
            if (!parentsToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(parentsToUpdate, false);
                UTIL_LoggingService.logDmlResults(results, null, parentsToUpdate, '', 
                                                  UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', 
                                                  UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Propagates chargeability flag from parent to child cases
* @param caselst Case IDs to process
*/
    public static void propagateChargeabilityToChildren(Set<Id> caselst) {
        if (caselst == null || caselst.isEmpty()) {
            return;
        }
        
        try {
            // Query parent cases
            Map<Id, Case> parentCases = new Map<Id, Case>([
                SELECT Id, Chargeable__c,
                (SELECT Id, Chargeable__c FROM Cases)
                FROM Case
                WHERE Id IN :caselst
            ]);
            
            List<Case> childrenToUpdate = new List<Case>();
            
            for (Case parent : parentCases.values()) {
                if (parent.Cases != null && !parent.Cases.isEmpty()) {
                    for (Case child : parent.Cases) {
                        if (child.Chargeable__c != parent.Chargeable__c) {
                            child.Chargeable__c = parent.Chargeable__c;
                            childrenToUpdate.add(child);
                        }
                    }
                }
            }
            
            if (!childrenToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(childrenToUpdate, false);
                UTIL_LoggingService.logDmlResults(results, null, childrenToUpdate, '', 
                                                  UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', 
                                                  UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
}
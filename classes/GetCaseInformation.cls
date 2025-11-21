/**
* @author Accenture
* @date 3/1/2019
* @description Apex class GetCaseInformation - REFACTORED
* 
* REFACTORING COMPLETE: This class has been refactored to use the service layer architecture.
* All business logic delegated to CaseBusinessRuleService, data retrieval to CaseContextGetter,
* and UI-specific logic to CaseUIService.
* 
* This class now serves as a thin delegation layer maintaining backward compatibility
* while routing to appropriate service classes.
* 
* @see CaseUIService
* @see CaseContextGetter
* @see CaseBusinessRuleService
* @see CaseAssetValidator
*/
public with sharing class GetCaseInformation {
    
    // ========================================================================
    // CONSTANTS AND LEGACY COMPATIBILITY
    // ========================================================================
    
    public static String ADD_QUOTE_ERROR_SERVICE_REQ_CASE = 'If you are trying to create a Bulk Pickup, Check Sammy, or Got Junk request, please use Acorn to execute this request';
    public static String LoggedInUserProfile ='';
    
    // ========================================================================
    // PRIMARY UI METHODS - DELEGATED TO CASEUISERVICE
    // ========================================================================
    
    /**
* @description Get case messages with all validations and business rules
* @param caseId Case ID
* @return Wrapper with comprehensive case information
*/
    @AuraEnabled
    public static Wrapper getMessage(Id caseId){
        try {
            System.debug('GetCaseInformation.getMessage - START for caseId: ' + caseId);
            CaseUIService.CaseUIWrapper uiWrapper = CaseUIService.getCaseMessages(caseId);
            System.debug('GetCaseInformation.getMessage - uiWrapper: ' + JSON.serializePretty(uiWrapper));

            Wrapper result = convertToLegacyWrapper(uiWrapper);
            System.debug('GetCaseInformation.getMessage - result: ' + JSON.serializePretty(result));
            return result;
        } catch(Exception ex){
            System.debug(LoggingLevel.ERROR, 'GetCaseInformation.getMessage - ERROR: ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, 'GetCaseInformation.getMessage - STACK TRACE: ' + ex.getStackTraceString());

            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                    UTIL_ErrorConstants.ERROR_APPLICATION,
                                                    LoggingLevel.ERROR);

            // Return empty wrapper with error indicator
            Wrapper errorWrapper = new Wrapper();
            errorWrapper.caseInfo = 'ERROR: ' + ex.getMessage() + ' - Check debug logs for details';
            return errorWrapper;
        }
    }
    
    /**
* @description Get business rule channel requirements and special instructions
* @param caseId Case ID
* @return Wrapper with business rule information
*/
    @AuraEnabled
    public static Wrapper getBusinessRule(Id caseId) {
        Wrapper wrapper = new Wrapper();
        try {
            CaseUIService.BusinessRuleUIWrapper brWrapper = CaseUIService.getBusinessRule(caseId);
            wrapper.channelReq = brWrapper.channelReq;
            wrapper.channelName = brWrapper.channelName;
            wrapper.specialInstructions = brWrapper.specialInstructions;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
        }
        return wrapper;
    }
    
    /**
* @description Get SLA instructions from entitlement
* @param caseId Case ID
* @return Wrapper with SLA information
*/
    @AuraEnabled
    public static Wrapper getEntitlement(Id caseId){
        Wrapper wrapper = new Wrapper();
        try {
            CaseUIService.SLAUIWrapper slaWrapper = CaseUIService.getEntitlement(caseId);
            wrapper.slaInstrctuions = slaWrapper.slaInstructions;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
        }
        return wrapper;
    }
    
    /**
* @description Get comprehensive case messages (alternate method name)
* @param caseId Case ID
* @return Wrapper with complete case information
*/
    @AuraEnabled
    public static Wrapper getCaseMessages(Id caseId) {
        return getMessage(caseId);
    }
    
    // ========================================================================
    // CASE SUMMARY AND RELATED CASES - DELEGATED TO CASEUISERVICE
    // ========================================================================
    
    /**
* @description Get case summary for related cases
* @param caseId Case ID
* @param referenceNo Reference number
* @param parentId Parent case ID
* @return List of related cases
*/
    @AuraEnabled
    public static List<Case> getCaseSummary(String caseId, String referenceNo, String parentId){
        try {
            return CaseUIService.getCaseSummary(caseId, referenceNo, parentId);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new List<Case>();
        }
    }
    
    /**
* @description Get related cases by case ID
* @param caseId Case ID
* @return List of related cases
*/
    @AuraEnabled
    public static List<Case> getRelatedCase(String caseId){
        try {
            Case caseObj = CaseContextGetter.getCaseById(caseId);
            if (caseObj == null) {
                return new List<Case>();
            }
            return [
                SELECT Id, Reference_Number__c, CaseNumber, isWorkOrderCreated__c, 
                Status, Case_Sub_Status__c
                FROM Case
                WHERE Reference_Number__c = :caseObj.Reference_Number__c
                AND Status = :Constant_Util.STATUS_NEW
                AND Id != :caseId
            ];
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new List<Case>();
        }
    }
    
    // ========================================================================
    // RECORD TYPE AND CASE DETAILS - DELEGATED TO CASEUISERVICE
    // ========================================================================
    
    /**
* @description Get list of case record types
* @return List of record type names
*/
    @AuraEnabled
    public static List<String> getCaseRecordTypeList(){
        try {
            return CaseUIService.getCaseRecordTypeList();
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new List<String>();
        }
    }
    
    /**
* @description Get record type ID for case
* @param caseId Case ID
* @return Record type ID
*/
    @AuraEnabled
    public static String getRecordTypeId(Id caseId){
        try {
            return CaseUIService.getRecordTypeId(caseId);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return null;
        }
    }
    
    /**
* @description Get case record details
* @param caseId Case ID
* @return List of case details
*/
    @AuraEnabled
    public static List<String> getCaseRecordDetails(Id caseId){
        try {
            return CaseUIService.getCaseRecordDetails(caseId);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new List<String>();
        }
    }
    
    /**
* @description Get case asset details
* @param caseId Case ID
* @return List of cases with asset details
*/
    @AuraEnabled(cacheable=true)
    public static List<Case> getcaseAssetDetails(String caseId){
        try {
            return CaseUIService.getCaseAssetDetails(caseId);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new List<Case>();
        }
    }
    
    /**
* @description Get case details (basic info)
* @param caseRecId Case ID
* @return Case record
*/
    @AuraEnabled
    public static Case getCaseDetails(String caseRecId){  
        try {
            return CaseContextGetter.getCaseById(caseRecId);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return null;
        }
    }
    
    // ========================================================================
    // ASSET VALIDATION METHODS - DELEGATED TO CASEASSETVALIDATOR
    // ========================================================================
    
    /**
* @description Get asset validation details for pickup cases
* @param assetParam Map of Asset ID to Service Date
* @return Map of Asset ID to validation message
*/
    public static Map<Id, String> getAssetDetail(Map<Id, Date> assetParam){
        try {
            return CaseAssetValidator.validatePickupAssets(assetParam);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new Map<Id, String>();
        }
    }
    
    /**
* @description Get asset validation details for non-pickup cases
* @param assetParam Map of Asset ID to Service Date
* @return Map of Asset ID to validation message
*/
    public static Map<Id, String> getAssetDetailNonPickup(Map<Id, Date> assetParam){
        try {
            return CaseAssetValidator.validateNonPickupAssets(assetParam);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new Map<Id, String>();
        }
    }
    
    // ========================================================================
    // WORK ORDER METHODS - DELEGATED TO CASEBUSINESSRULESERVICE
    // ========================================================================
    
    /**
* @description Initiate work order creation for cases
* @param caseId Primary case ID
* @param caseIdList List of case IDs to create work orders for
* @return SUCCESS or FAILURE status
*/
    @AuraEnabled
    public static String initiateWorkOrder(String caseId, List<String> caseIdList){
        try {
            // REFACTORED (Phase 5E): Delegate to CaseWorkOrderService
            return CaseWorkOrderService.initiateWorkOrderCreation(caseId, caseIdList);
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                    UTIL_ErrorConstants.ERROR_APPLICATION,
                                                    LoggingLevel.ERROR);
            return Constant_Util.Failure;
        }
    }
    
    /**
* @description Add work order details to cases
* @param caseWoFields Case with WO field values
* @param caseIdList List of case IDs to update
* @return SUCCESS or FAILURE status
*/
    @AuraEnabled
    public static String addWorkOrderDetails(Case caseWoFields, List<String> caseIdList){
        String status = null;
        List<Case> caseList = new List<Case>();
        Set<String> caseIdset = new Set<String>();
        
        try {
            caseIdset.addAll(caseIdList);
            
            // Get cases using CaseContextGetter
            Map<Id, Case> caseMap = new Map<Id, Case>();
            for (String cId : caseIdset) {
                Case c = CaseContextGetter.getCaseById(cId);
                if (c != null) {
                    caseMap.put(c.Id, c);
                }
            }
            
            // Update WO fields
            for (Case c : caseMap.values()) {
                c.Site_Contact__c = caseWoFields.Site_Contact__c;
                c.Site_Contact_Phone__c = caseWoFields.Site_Contact_Phone__c;
                c.User_Input_Work_Order_Instructions__c = caseWoFields.User_Input_Work_Order_Instructions__c;
                c.Is_ByPassWO__c = caseWoFields.Is_ByPassWO__c;
                caseList.add(c);
            }
            
            // Use CaseDMLService for updates
            CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCases(caseList);
            status = result.isSuccess() ? Constant_Util.SUCCESS : Constant_Util.Failure;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            status = Constant_Util.Failure;
        }
        
        return status;
    }
    
    // ========================================================================
    // USER PERMISSION METHODS - DELEGATED TO CASEUISERVICE
    // ========================================================================
    
    /**
* @description Check if user has CPQ license and permissions
* @return True if user has CPQ access
*/
    public static Boolean getUserDetail() { 
        try {
            User u = [SELECT Id, CPQ_Active_User__c,Profile.Name FROM User WHERE Id =: UserInfo.getUserId()];
            LoggedInUserProfile = u.Profile.Name;
            return CaseUIService.hasCPQAccess();
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return false;
        }
    }
    
    /**
* @description Check if user can update active assets
* @return True if user has update asset permissions
*/
    public static Boolean getActiveAssetUserDetail() {
        try {
            return CaseUIService.hasUpdateAssetAccess();
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return false;
        }
    }
    
    // ========================================================================
    // ACORN COMMENT COPY - DELEGATED TO CASEBUSINESSRULESERVICE
    // ========================================================================
    
    /**
* @description Copy Acorn comments from parent to child case
* @param recordId Parent case ID
* @param caseObj Child case object
*/
    public static void copyAcornCommentsToChildCase(String recordId, Case caseObj){
        try {
            CaseBusinessRuleService.copyAcornComments(recordId, caseObj);
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
        }
    }
    
    @AuraEnabled
    public static Boolean IsWMCapacityPlannerVisible(string caseRecId){
        Boolean isWMcapacityVisible;
        isWMcapacityVisible=ServiceDateContainerController.IsWMCapacityPlannerVisible(caseRecId);
        return isWMcapacityVisible;
    }
    
    // ============================================
    // Legacy methods needed for backwards compatibility
    // ============================================
    
    @AuraEnabled
    public static Boolean launchCPQQuoteValidation(String CaseId) {
        //Call the validation flow for CPQ via Apex for the ShowCaseMessages aura bundle
        
        Boolean eligibility = false;
        
        Map<String, Object> flowParams = new Map<String, Object>();
        flowParams.put('caseRecordId', CaseId);
        Flow.Interview.Validation_Add_Change_Scope_Evaluation validationFlow = new Flow.Interview.Validation_Add_Change_Scope_Evaluation(flowParams);
        validationFlow.start();
        
        eligibility = (Boolean)validationFlow.getvariableValue('OutputQuoteEligible');
        
        return eligibility;
    }
    
    /**
* @author WM
* @date 10/28/2021
* @description : Apex method SaveAdditionalTemplate to save Workorder Details on Case
* REFACTORED: Use CaseDMLService instead of direct DML
**/
    @AuraEnabled
    public static String saveAdditionalTemplate(String emailTempDesc,List<String> caseId){
        String Status = null;
        //System.debug('======='+caseId);
        try{
            if(caseId !=null){
                Case c = new Case();
                c.Id = caseId[0] ;
                c.EmailTemplateAdditionalComments__c =emailTempDesc ;

                // REFACTORED: Use CaseDMLService instead of direct database.update
                List<Case> casesToUpdate = new List<Case>{c};
                CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCases(casesToUpdate);

                status = result.isSuccess() ? Constant_Util.SUCCESS : Constant_Util.Failure;
            }

        }Catch(Exception ex){
            status = Constant_Util.Failure;
            System.debug('New Error:'+ ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
        return status;

    } 
    
    /**
     * @description Creates Opportunity and Quote from Case
     * This method is maintained for backward compatibility only.
     * All CPQ logic has been moved to CaseCPQService.
     *
     * @param CaseId Case ID
     * @return Quote ID of created quote
     */
    @AuraEnabled
    public static String createOppQuote(String CaseId) {
        // REFACTORED (Phase 5C): Delegate to CaseCPQService
        return CaseCPQService.createQuoteFromCase(CaseId);
    }
    
    @AuraEnabled
    public static List<QuoteProcurementController.ProductsWrapper> ShowExistingQuotes(String CaseId) {
        List<QuoteProcurementController.ProductsWrapper> pwList = new List<QuoteProcurementController.ProductsWrapper>();
        pwList = QuoteProcurementController.getDuplicates(CaseId);
        return pwList;
    }
    
    @AuraEnabled
    public static Boolean updateThisCaseToClose(String CaseId){
        try{
            Case c = [Select Id,Close_Irrelevant_Case__c,Close_Case_Reason__c, Status from Case where Id =: caseId];
            c.Close_Irrelevant_Case__c = true;
            c.Close_Case_Reason__c  = 'Duplicate';
            c.Case_Close_Reason__c = 'As Location already has active Quotes, this case is not required.';
            if(c != null) {
                // REFACTORED: Use CaseDMLService instead of direct update
                List<Case> casesToUpdate = new List<Case>{c};
                CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCases(casesToUpdate);
                return result.isSuccess();
            }
        }
        Catch(Exception ex){
            System.debug('Exception::::'+ex.getStackTraceString());
            return null;
        }
        return true;
    }
    
    @AuraEnabled
    public static Boolean IsTemplateVisible(string caseRecId){
        Set<Id> contactIdSet = new Set<Id>();
        Set<Id> containerIdSet = new Set<Id>();
        Set<Id> locationIdSet = new Set<Id>();
        set<Id> accountIdset = new set<Id>();
        set<Id> recordTypeIdSet = new set<Id>();
        set<string> requestTypeSet = new Set<string>();
        set<string> ServiceTypeSet = new Set<string>();
        
        Map<Id,Asset> casewithContainerMap = new Map<Id,Asset>();
        Map<Id,Account> casewithLocationMap = new Map<Id,Account>();
        List<Case> processCaseSubtypeList = new List<Case>();
        Id pickupRcdType = Schema.getGlobalDescribe().get(Constant_Util.KEYWORD_CASE).getDescribe().getRecordTypeInfosByName().get(Constant_Util.PICKUP).getRecordTypeId();
        Id newServiceRcdType = Schema.getGlobalDescribe().get(Constant_Util.KEYWORD_CASE).getDescribe().getRecordTypeInfosByName().get(Constant_Util.New_Service_Case).getRecordTypeId();
        Id IntegrationRcdType = Schema.getGlobalDescribe().get(Constant_Util.KEYWORD_CASE).getDescribe().getRecordTypeInfosByName().get(Constant_Util.Integration_Case).getRecordTypeId();
        Id approvalRecTypeId = Schema.SObjectType.Business_Rule__c.getRecordTypeInfosByName().get(Constant_Util.APPROVAL).getRecordTypeId();
        Id reqInfoRecTypeId = Schema.SObjectType.Business_Rule__c.getRecordTypeInfosByName().get(Constant_Util.REQUIRED_INFORMATION).getRecordTypeId();
        recordTypeIdSet.add(approvalRecTypeId);
        recordTypeIdSet.add(reqInfoRecTypeId);
        
        for(Case caseRecord : [select id,contactId,RecordTypeId,Case_type__c,Is_Multivendor__c,AssetId,Case_Sub_Type__c,
                               Location__c,Client__c,Case_Sub_Status__c,Status,Case_Reason__c from case where id =: caseRecId]){
                                   
                                   if(caseRecord.RecordTypeId == newServiceRcdType || caseRecord.RecordTypeId == pickupRcdType || ((caseRecord.RecordTypeId == newServiceRcdType ||
                                                                                                                                    caseRecord.RecordTypeId != IntegrationRcdType  ||
                                                                                                                                    (caseRecord.RecordTypeId != IntegrationRcdType && (String.isNotBlank(caseRecord.Case_type__c) && 
                                                                                                                                                                                       sla_calculation__c.getValues(caseRecord.Case_type__c) != null  && 
                                                                                                                                                                                       sla_calculation__c.getValues(caseRecord.Case_type__c).Enabled__c))) && !caseRecord.Is_Multivendor__c && String.isBlank(caseRecord.Case_Sub_Type__c))){
                                                                                                                                                                                           
                                                                                                                                                                                           //System.debug('caseRecord.AssetId====='+caseRecord.AssetId+'====='+caseRecord.Location__c);          
                                                                                                                                                                                           if(String.isNotBlank(caseRecord.AssetId)){
                                                                                                                                                                                               containerIdSet.add(caseRecord.AssetId);   
                                                                                                                                                                                           }
                                                                                                                                                                                           if(String.isNotBlank(caseRecord.Location__c)){       
                                                                                                                                                                                               locationIdSet.add(caseRecord.Location__c); 
                                                                                                                                                                                           }
                                                                                                                                                                                           if(String.isNotBlank(caseRecord.contactId)){       
                                                                                                                                                                                               contactIdSet.add(caseRecord.contactId); 
                                                                                                                                                                                           }
                                                                                                                                                                                           
                                                                                                                                                                                           
                                                                                                                                                                                           
                                                                                                                                                                                           processCaseSubtypeList.add(caseRecord); 
                                                                                                                                                                                           
                                                                                                                                                                                       }
                                   if(!String.ISBlank(caseRecord.Case_Sub_type__c)){// 
                                       
                                       accountIdset.add(caseRecord.Client__c); 
                                       requestTypeSet.add(caseRecord.Case_Type__c);
                                       ServiceTypeSet.add(caseRecord.Case_Sub_type__c);
                                   }                       
                                   
                               }
        
        if(containerIdSet != null && !containerIdSet.isEmpty()){
            casewithContainerMap = CaseTriggerHandler.getAssetRecordValue(containerIdSet,true);
            //system.debug('casewithContainerMap===='+casewithContainerMap);
        } 
        if(locationIdSet != null && !locationIdSet.isEmpty()){
            casewithLocationMap = CaseTriggerHandler.getLocationRecordValue(locationIdSet);
            //system.debug('casewithLocationMap===='+casewithLocationMap);
        }
        
        Boolean isTemplateVisible=false ;
        List<BusinessRuleHelper.BusinessRulewrapper> businessRulewrapperlst = new List<BusinessRuleHelper.BusinessRulewrapper>();
        if((processCaseSubtypeList != null && !processCaseSubtypeList .isEmpty()) && (casewithLocationMap != null && !casewithLocationMap.isEmpty())){
            //businessRulewrapperlst = BusinessRuleHelper.businessRuleSelection(processCaseSubtypeList,recordTypeIdSet,accountIdset,requestTypeSet,ServiceTypeSet,casewithContainerMap,casewithLocationMap);
            for (Case c : processCaseSubtypeList) {
                businessRulewrapperlst = BusinessRuleHelper.businessRuleSelection(c.Id,recordTypeIdSet);
            }
            
            //System.debug('&&&&'+businessRulewrapperlst);
            
            if(businessRulewrapperlst != null && businessRulewrapperlst.size() > 0){
                
                isTemplateVisible =true ;
                set<Id> businessruleIDSet = new Set<Id>();
                for(BusinessRuleHelper.BusinessRulewrapper businessWrap :businessRulewrapperlst){
                    businessruleIDSet.add(businessWrap.bRule.Id) ;
                    
                }
                for(Business_Rule__c rule : [select id,No_Approval_Required__c,Active__c,Is_Auto_Email__c from Business_Rule__c where Active__c =true AND id IN:businessruleIDSet]){
                    
                    if(rule.No_Approval_Required__c || !rule.Is_Auto_Email__c){
                        isTemplateVisible =false ;
                    }
                }
                for(Service_Approver__c serApprover : [Select id,Business_Rule__c,Email__c,Approver_Contact__c from Service_Approver__c where Business_Rule__c IN:businessruleIDSet and Approver_Contact__c IN :contactIdSet and Active__c=true]){
                    isTemplateVisible =false ;
                }
                
                
            }
        }         
        
        return isTemplateVisible;
    }
    
    @AuraEnabled
    public static String createAcornComment(String comment, String caseId) {
        //System.debug('Case Id: ' + caseId);
        if (!caseId.startsWith('500')) {
            return 'Invalid Case Id.  You need to be viewing a Case when creating an Acorn Note.';
        } else{}
        
        Id recordTypeId = Schema.getGlobalDescribe().get('Comment__c').getDescribe().getRecordTypeInfosByDeveloperName().get('Acorn_Ticket_Comment').getRecordTypeId();
        Case curCase = [select CaseNumber, Tracking_Number__c from Case where Id =: caseId limit 1];
        
        Decimal acornUserId = [select Acorn_SUser_ID__c from User where ID =: System.UserInfo.getUserId()].Acorn_SUser_ID__c;
        //System.debug('Acorn User Id: ' + acornUserId);
        
        Comment__c note = new Comment__c();
        note.Case__c = caseId;
        note.Comment__c = 'Case Close Reason-'+comment;
        note.Communication_Log_Type_Name__c = 'Internal';
        note.Case_Number__c = curCase.CaseNumber;
        note.recordTypeId = recordTypeId;
        if (String.isNotEmpty(curCase.Tracking_Number__c)) note.Acorn_Tracking_Number__c = curCase.Tracking_Number__c;
        note.Workflow_Action__c = '';
        note.Workflow_TeamUser__c = System.UserInfo.getName();
        note.Acorn_SUser_ID__c = acornUserId;
        note.Type__c = Constant_Util.OBJECT_CASE;
        
        // Modified for SDT-33453 Start
        if(note != null){
            insert note;
        }
        // Modified for SDT-33453 End
        return 'ok';
    }
    
    @AuraEnabled
    public static void insertPlannerComment(Id caseId,String selectedDate,Boolean isAvailDates,Boolean isDateNotListed)
    {
        String comment;
        if(isAvailDates && !isDateNotListed)
        {
            comment = Constant_Util.CAPACITY_PLANNER_USERSELECT+selectedDate;
        }
        else if(isAvailDates && isDateNotListed)
        {
            comment = Constant_Util.CAPACITY_PLANNER_AVAILNOTSELECT;
        }
        else
        {
            comment = Constant_Util.CAPACITY_PLANNER_NOTAVAIL;
        }
        try{
            AcornController.createAcornComment(comment,caseId);
        }
        catch(Exception ex)
        {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION,LoggingLevel.ERROR);    
        }
    }
    
    @AuraEnabled
    public static List<Map<String, String>> getCompanyCategory(string caseId) {
		List<Map<String, String>> companyList = new List<Map<String, String>>();
        try{
            Case caseObj = [SELECT Id, Client__r.AccountNumber FROM Case WHERE Id =: caseId];
            Map<String, String> companyCategoriesMap = AcornCompanyDetails.getAcornCCMap(caseObj.Client__r.AccountNumber);
            List<sortingWrapper> sortedList = new List<sortingWrapper>();
    
            if(companyCategoriesMap != null && !companyCategoriesMap.isEmpty()) {
                for(string sobjName : companyCategoriesMap.keyset()) {
                    Map<String, String> sObjMap = new Map<String, String>();
                        sObjMap.put('label', companyCategoriesMap.get(sobjName));
                        sObjMap.put('value', sobjName);
                        sortedList.add(new sortingWrapper(sObjMap));
                }
            }
    
            sortedList.sort();
            for(sortingWrapper sortObjMap : sortedList) {
                companyList.add(sortObjMap.sObjFldsMap);
            }
        } catch(Exception ex)
        {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION,LoggingLevel.ERROR);    
        }
        return companyList;
    }
    
    public class sortingWrapper implements Comparable {
        public Map<String, String> sObjFldsMap;

        public sortingWrapper(Map<String, String> sObjFldsMap) {
            this.sObjFldsMap = sObjFldsMap;
        }

        public Integer compareTo(Object compareTo) {
            return sObjFldsMap.get('label').compareTo(((sortingWrapper)compareTo).sObjFldsMap.get('label'));
        }
    }

    /**
     * @description Checks if a quote can be added for the given case
     * @param CaseId The ID of the case to check
     * @return 'SUCCESS' if quote can be added, 'quoteExists' if quotes already exist, or error message
     */
    @AuraEnabled
    public static String addQuoteCheck(String CaseId) {
        try {
            // Check if opportunity/quote already exists for this case
            List<Opportunity> existingOpps = [
                SELECT Id, SBQQ__PrimaryQuote__c
                FROM Opportunity
                WHERE Case__c = :CaseId
                LIMIT 1
            ];

            if (!existingOpps.isEmpty() && existingOpps[0].SBQQ__PrimaryQuote__c != null) {
                return 'quoteExists';
            }

            // Check for existing quotes at the same location and service date
            List<QuoteProcurementController.ProductsWrapper> duplicates =
                QuoteProcurementController.getDuplicates(CaseId);

            if (duplicates != null && !duplicates.isEmpty()) {
                return 'quoteExists';
            }

            // All checks passed
            return 'SUCCESS';

        } catch (Exception e) {
            System.debug('Error in addQuoteCheck: ' + e.getMessage());
            return 'Error checking quote eligibility: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static string getAddProductId() {

        String addProduct = [SELECT Id FROM SBQQ__CustomAction__c WHERE Name =: Constant_Util.ADD_PRODUCTS].Id;

        return addProduct;
        
    }
    
    // ========================================================================
    // HELPER METHODS - CONVERSION
    // ========================================================================
    
    /**
* @description Convert CaseUIWrapper to legacy Wrapper format for backward compatibility
* @param uiWrapper Modern CaseUIWrapper from CaseUIService
* @return Legacy Wrapper object
*/
    private static Wrapper convertToLegacyWrapper(CaseUIService.CaseUIWrapper uiWrapper) {
        Wrapper wrapper = new Wrapper();
        
        wrapper.caseId = uiWrapper.caseId;
        wrapper.caseInfo = uiWrapper.caseInfo;
        wrapper.reqInfo = uiWrapper.reqInfo;
        wrapper.approvalInfo = uiWrapper.approvalInfo;
        wrapper.CaseType = uiWrapper.caseType;
        wrapper.CaseSubType = uiWrapper.caseSubType;
        wrapper.CaseReason = uiWrapper.caseReason;
        wrapper.CaseStatus = uiWrapper.caseStatus;
        wrapper.caseRecordType = uiWrapper.caseRecordType;
        wrapper.assetSCode = uiWrapper.assetSCode;
        wrapper.enableapprovalInfo = uiWrapper.enableapprovalInfo;
        wrapper.disableMultiCase = uiWrapper.disableMultiCase;
        wrapper.relatedCaseList = uiWrapper.relatedCaseList;
        wrapper.multiAssetSelections = uiWrapper.multiAssetSelections;
        wrapper.assetValidation = uiWrapper.assetValidation;
        wrapper.referenceNo = uiWrapper.referenceNo;
        wrapper.WorkOrderCreation = uiWrapper.workOrderCreation;
        wrapper.isManualCaseAsset = uiWrapper.isManualCaseAsset;
        wrapper.isAssetMandatory = uiWrapper.isAssetMandatory;
        wrapper.caseData = uiWrapper.caseData;
        wrapper.isOpportunityCreated = uiWrapper.isOpportunityCreated;
        wrapper.Is_NewServiceCPQ = uiWrapper.isCPQUser;
        wrapper.Is_UserHaveCPQLicence = uiWrapper.isCPQUser;
        wrapper.caseRecordTypeList = uiWrapper.caseRecordTypeList;
        wrapper.CPQProduct = uiWrapper.cpqProduct;
        wrapper.assetId = uiWrapper.assetId;
        wrapper.Is_UpdateAssetActiveUser = uiWrapper.isUpdateAssetActiveUser;
        wrapper.progressCaseVisibility = uiWrapper.progressCaseVisibility;
        wrapper.addQuoteVisibility = uiWrapper.addQuoteVisibility;
        wrapper.isAddCaseAsset = uiWrapper.isAddCaseAsset;
        wrapper.isCaseInfoReady = uiWrapper.isCaseInfoReady;
        wrapper.caseAppliedRules = uiWrapper.caseAppliedRules;
        wrapper.IsHaulAwayService = uiWrapper.isHaulAwayService;
        
        return wrapper;
    }
    
    // ========================================================================
    // LEGACY WRAPPER CLASS - MAINTAINED FOR BACKWARD COMPATIBILITY
    // ========================================================================
    
    /**
* @description Legacy wrapper class for Case UI data
*/
    public with sharing class Wrapper {
        @AuraEnabled public List<String> caseRecordTypeList {get;set;}
        @AuraEnabled public Id CPQProduct {get;set;}
        @AuraEnabled public String channelReq {get;set;}
        @AuraEnabled public String specialInstructions {get;set;}
        @AuraEnabled public String slaInstrctuions {get;set;}
        @AuraEnabled public String channelName {get;set;}
        @AuraEnabled public String reqInfo {get;set;}
        @AuraEnabled public String approvalInfo {get;set;}
        @AuraEnabled public String caseInfo {get;set;}
        @AuraEnabled public Boolean enableapprovalInfo {get;set;}
        @AuraEnabled public Id caseId {get;set;}
        @AuraEnabled public String CaseSubType {get;set;}
        @AuraEnabled public Boolean disableMultiCase {get;set;}
        @AuraEnabled public List<Case> relatedCaseList {get;set;}
        @AuraEnabled public String assetSCode {get;set;}
        @AuraEnabled public String CaseType {get;set;}
        @AuraEnabled public String CaseReason {get;set;}
        @AuraEnabled public String CaseStatus {get;set;}
        @AuraEnabled public String[] multiAssetSelections;
        @AuraEnabled public Boolean assetValidation {get;set;}
        @AuraEnabled public String referenceNo {get;set;}
        @AuraEnabled public Boolean WorkOrderCreation {get;set;}
        @AuraEnabled public Boolean isManualCaseAsset {get;set;}
        @AuraEnabled public Case caseData {get;set;}
        @AuraEnabled public String caseAppliedRules {get;set;}
        @AuraEnabled public Boolean isAssetMandatory {get;set;}
        @AuraEnabled public Boolean isOpportunityCreated {get;set;}
        @AuraEnabled public Boolean Is_NewServiceCPQ {get;set;}
        @AuraEnabled public Boolean Is_UserHaveCPQLicence {get;set;}
        @AuraEnabled public String caseRecordType {get;set;}
        @AuraEnabled public String assetId {get;set;}
        @AuraEnabled public Boolean Is_UpdateAssetActiveUser {get;set;}
        @AuraEnabled public Boolean progressCaseVisibility {get;set;}
        @AuraEnabled public Boolean addQuoteVisibility {get;set;}
        @AuraEnabled public Boolean isAddCaseAsset {get;set;}
        @AuraEnabled public Boolean isCaseInfoReady {get;set;}
        @AuraEnabled public Boolean IsHaulAwayService {get;set;}
        
        public Wrapper() {
            this.caseInfo = Constant_Util.EMPTY_STRING;
            this.reqInfo = Constant_Util.EMPTY_STRING;
            this.approvalInfo = Constant_Util.EMPTY_STRING;
            this.enableapprovalInfo = false;
            this.assetValidation = false;
            this.WorkOrderCreation = true;
            this.isAssetMandatory = true;
            this.isCaseInfoReady = true;
            this.relatedCaseList = new List<Case>();
            this.multiAssetSelections = new List<String>();
        }
    }
}
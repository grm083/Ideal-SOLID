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
* @deprecated Use CaseUIService.getCaseMessages() instead
* @param caseId Case ID
* @return Wrapper with comprehensive case information
*/
    @AuraEnabled
    public static Wrapper getMessage(Id caseId){
        try {
            CaseUIService.CaseUIWrapper uiWrapper = CaseUIService.getCaseMessages(caseId);
            return convertToLegacyWrapper(uiWrapper);
        } catch(Exception ex){
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, 
                                                    LoggingLevel.ERROR);
            return new Wrapper();
        }
    }
    
    /**
* @description Get business rule channel requirements and special instructions
* @deprecated Use CaseUIService.getBusinessRule() instead
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
* @deprecated Use CaseUIService.getEntitlement() instead
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
* @deprecated Use CaseUIService.getCaseSummary() instead
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
* @deprecated Use CaseUIService.getCaseRecordTypeList() instead
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
* @deprecated Use CaseUIService.getRecordTypeId() instead
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
* @deprecated Use CaseUIService.getCaseRecordDetails() instead
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
* @deprecated Use CaseUIService.getCaseAssetDetails() instead
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
* @deprecated Use CaseAssetValidator.validatePickupAssets() instead
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
* @deprecated Use CaseAssetValidator.validateNonPickupAssets() instead
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
            return CaseBusinessRuleService.initiateWorkOrderCreation(caseId, caseIdList);
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
* @deprecated Use CaseUIService.hasCPQAccess() instead
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
* @deprecated Use CaseUIService.hasUpdateAssetAccess() instead
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
* @deprecated Use CaseBusinessRuleService.copyAcornComments() instead
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
                database.update(c);            
                status = Constant_Util.SUCCESS;
            }
            
        }Catch(Exception ex){
            status = Constant_Util.Failure;            
            System.debug('New Error:'+ ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
        return status;
        
    } 
    
    @AuraEnabled    
    public static String createOppQuote(String CaseId) {
        
        
        //system.debug('createOppQuote--->');
        Opportunity opp = new Opportunity();
        String quoteStatus;
        
        //SDT38061 Case_Reason__c
        Case c = [SELECT Id, Status,AssetId, Asset.Duration__c, Location__c, ContactId, CaseNumber, Service_Date__c,Case_Sub_Type__c,Case_Reason__c, Reference_Number__c, Tracking_Number__c, Integrate_with_Acorn__c, Case_Type__c,
                  Case_Record_Type__c,Quote_Only__c,Is_Haul_Away_Service__c,Haul_Away_information__c, Haul_Away_Vendor__c //SDT-41473
                  FROM Case
                  WHERE Id =: CaseId];
        
        Account loc = [SELECT Id, Primary_Segment__c,ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode
                       FROM Account
                       WHERE Id =: c.Location__c];
        
        
        opp.Name = c.CaseNumber;
        opp.AccountId = loc.Id;
        opp.StageName = Constant_Util.PRODUCT_CONFIGURATION;
        opp.CloseDate = date.today() + 4;
        opp.SBQQ__QuotePricebookId__c = [SELECT Id FROM PriceBook2 WHERE Name = 'Standard Price Book' LIMIT 1].Id;
        opp.Case__c = c.Id;
        
        //SDT-41473
        Boolean isHaulAway = HaulAwayService.getIsHaulAwayService(c);
        
        // Changes for SDT-25790
        if(isHaulAway)  //SDT-41473
            opp.Duration__c = 'Temporary';       
        else if(!String.isempty(c.Case_Type__c) && c.Case_Type__c == Constant_Util.NEW_SERVICE)
            opp.Duration__c = c.Case_Sub_Type__c;
        else
            opp.Duration__c = c.Asset.Duration__c !=null ? c.Asset.Duration__c : c.Case_Sub_Type__c;
        //system.debug('Opp--->'+ opp);
        
        try {
            // Modified for SDT-33453 Start
            if(opp != null){               
                insert opp;
            }
            // Modified for SDT-33453 End
            //system.debug('Opp1--->'+ opp);
            
        } catch (dmlException e) {
            system.debug(e.getMessage());
        }
        
        SBQQ__Quote__c q = new SBQQ__Quote__c();
        q.SBQQ__Opportunity2__c = opp.Id;
        q.SBQQ__Account__c = loc.Id;
        q.SBQQ__Primary__c = true;
        /* if (loc.Primary_Segment__c == Constant_Util.Broker){
q.SBQQ__ExpirationDate__c = date.today() + 30;
}
else {
q.SBQQ__ExpirationDate__c = date.today() + 60;
} */
        q.SBQQ__StartDate__c = c.Service_Date__c;
        q.SBQQ__ShippingStreet__c = loc.ShippingStreet;
        q.SBQQ__ShippingCity__c = loc.ShippingCity;
        q.SBQQ__ShippingState__c = loc.ShippingState;
        q.SBQQ__ShippingPostalCode__c = loc.ShippingPostalCode;
        q.SBQQ__PrimaryContact__c = c.ContactId;
        q.Duration__c = opp.Duration__c;
        
        //Added by jatan for SDT-40344 IVR
        q.Quote_Only__c = c.Quote_Only__c;
        
        //pkulkarn-TCS-7-Mar-23-Added for SDT-26868-Start
        String quoteTypeConst = ''; 
        Schema.DescribeFieldResult quoteTypeDesc = SBQQ__Quote__c.SBQQ__Type__c.getDescribe();
        List<Schema.PicklistEntry> quoteTypes = quoteTypeDesc.getPicklistValues();
        
        Map<String, String> TypePLMap = new Map<String, String>();
        for(Schema.PicklistEntry plEntry : quoteTypes)
            if(plEntry.isActive())
            TypePLMap.put(plEntry.getValue(), plEntry.getLabel());
        
        //SDT 38061 adding 2nd if condition
        boolean isInternalCorrectionsTeamUser=UserServices.isInternalCorrectionTeamUser(UserInfo.getUserId());
        
        //SDT-41473
        if((c.Case_Record_Type__c == Constant_Util.New_Service_Case)||(c.Is_Haul_Away_Service__c))
            quoteTypeConst = Constant_Util.QUOTE;
        else if(c.Case_Record_Type__c == Constant_Util.MODIFY_EXISTING_SERVICE_CASE && c.Case_Type__c == Constant_Util.Change_Service 
                && c.Case_Sub_Type__c == Constant_Util.Change_Correction && c.Case_Reason__c == Constant_Util.CASE_REASON_DAYSOFSERVICE && !isInternalCorrectionsTeamUser)
            quoteTypeConst = Constant_Util.QUOTE_TYPE_AMEND;
        else if(c.Case_Record_Type__c == Constant_Util.UPDATE_ASSET_CASE)
            quoteTypeConst = Constant_Util.QUOTE_TYPE_AMEND;
        else if(c.Case_Record_Type__c == Constant_Util.MODIFY_EXISTING_SERVICE_CASE && c.Case_Type__c == Constant_Util.Change_Service && c.Case_Sub_Type__c == Constant_Util.Change_Correction)
            quoteTypeConst = Constant_Util.QUOTE_TYPE_CORRECTION;
        else if(c.Case_Record_Type__c == Constant_Util.MODIFY_EXISTING_SERVICE_CASE && c.Case_Type__c == Constant_Util.Change_Service && (c.Case_Sub_Type__c == Constant_Util.WASTE_STREAM || c.Case_Sub_Type__c == Constant_Util.Decrease || c.Case_Sub_Type__c == Constant_Util.Increase || c.Case_Sub_Type__c == Constant_Util.Rightsizing_Load_Max ||  c.Case_Sub_Type__c == Constant_Util.VENDOR))
            quoteTypeConst = Constant_Util.QUOTE_TYPE_AMEND;
        else
            quoteTypeConst = Constant_Util.KEYWORD_EXCEPTION;
        if(TypePLMap.containsKey(quoteTypeConst))
            q.SBQQ__Type__c = TypePLMap.get(quoteTypeConst);
        //pkulkarn-TCS-7-Mar-23-Added for SDT-26868-End
        
        try {
            // Modified for SDT-33453 Start
            if(q != null){
                insert q;
            }
            // Modified for SDT-33453 End
            SBQQ__Quote__c quote = [Select Id, Name from SBQQ__Quote__c Where Id =: q.Id];
            
            String sComments = 'SFDC Quote: '+ quote.Name +'\n';
            if (c.Tracking_Number__c != Null){
                sComments += 'SFDC Case: '+ c.CaseNumber + ' - Tracking Number: '+ c.Tracking_Number__c+'\n';
            }
            else {
                sComments += 'SFDC Case: '+ c.CaseNumber +'\n';
            }
            sComments += 'SFDC Reference #: '+ c.Reference_Number__c +'\n';
            
            q.Case_Comments__c = sComments;
            
            // Modified for SDT-33453 Start
            if(q != null){
                update q; 
            }
            // Modified for SDT-33453 End
            c.IsOpportunity_Created__c = true;
            c.Integrate_with_Acorn__c = false; //21433
            c.Status = Constant_Util.OPEN; //21433
            //c.Status = Constant_Util.PENDING; //21433
            //SDT-26868 - Start - Set field 'Master_Intake_Complete__c' of case as True - by dojha
            c.Master_Intake_Complete__c = true;
            //SDT-26868 - End
            //Haul Away SDT 42654 Seema
            if(isHaulAway){
                c.Material_Grade__c = 'No Grade'; //Need to check where we use it
                c.Material_Type__c = Constant_Util.BULK_MATERIAL_PRODUCTCODE;
                c.Equipment_Type_Code__c = 'UNK';
                c.Equipment_Size_Code__c = 'UNK';
                c.Service_Occurrence_Type_Code__c = 'OC';
                // c.Origin = 'SFDC Default'; //Comment as a part of SDT-47951
            }
            // Modified for SDT-33453 Start
            if(c != null){
                update c;
                //Haul Away SDT 42654 Seema
                if(isHaulAway){
                    Map<String,sobject>  returnMap = new Map<String,sobject>();
                    returnMap.put(String.valueof(c.Id),(SObject)c);
                    returnMap.put(String.valueof(q.Id),(sObject)q);
                    QuoteLineCreationHandler.execute(returnMap);
                }
            }
            // Modified for SDT-33453 End
        } catch (Exception e) {	//TCS-SDT-41546-Changed exception type from DmlException to Exception
            system.debug(e.getMessage());
            throw e;	//TCS-SDT-41546-Added
        }
        
        return q.Id;  
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
                update c;
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
* @deprecated Use CaseUIService.CaseUIWrapper instead
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
/**
* @author Accenture
* @date 2/28/2019
* @description : Apex class CustomCaseHighlightPanelCntrl
*
* REFACTORED (Phase 5A):
* - Removed static variable anti-patterns (myCases, myCasesList, POProfileReqMap)
* - Converted to method-scoped variables for thread safety and testability
* - Removed writes to deprecated CaseTriggerHelper static maps (Phase 4)
**/
public without sharing class CustomCaseHighlightPanelCntrl {

    /**
     * REFACTORED: Removed static variables - now method-scoped for proper encapsulation
     * OLD CODE (Anti-pattern):
     *   private static Case myCases = new case();
     *   private static List<Case> myCasesList = new List<case>();
     *   private static Map<String,Boolean> POProfileReqMap = new Map<String,Boolean>();
     */

    //Method created to extract Custom Metadata  SDT-20936 . Custom Metadata controls visiblity of PO/Profile based on Case Type.
    public static Map<String,Boolean> getMetadata(){
        // REFACTORED: Made method-scoped instead of static class variable
        Map<String,Boolean> poProfileReqMap = new Map<String,Boolean>();

        List<POProfileDisable__mdt> lstPOProfileReq = POProfileDisable__mdt.getAll().values();
         for(POProfileDisable__mdt poPF :lstPOProfileReq){
           poProfileReqMap.put(poPF.CaseType__c,poPF.IsEnable__c);
     }
        return poProfileReqMap;
   }
         
/**
* @author Accenture
* @date 2/28/2019
* @description : Apex method getCaseHighlightDetails to display the case details in highlight panel
* REFACTORED (Phase 5A): Made myCases method-scoped instead of static class variable
**/
    @AuraEnabled
    public static Wrapper getCaseHighlightDetails(Id caseId){
        Wrapper wrapperClass = new Wrapper();
        Boolean POFlag ;

        // REFACTORED: Made method-scoped instead of static class variable
        Case myCases;

      try{
            // REFACTORED (Phase 5D): Use CaseContextGetter for centralized query
            myCases = CaseContextGetter.getCaseWithHighlightPanelFields(caseId);
            if(myCases.Service_Date__c!= null){
                myCases.Service_Date_Text__c = myCases.Service_Date__c.format();
                }else{
                    //nova cop fix
                }
	  if( String.isBlank(myCases.PurchaseOrder_Number__c) && String.isBlank(myCases.Chargeable__c) && String.isBlank(myCases.Company_Category__c) && myCases.PSI__c == null){
              wrapperClass.isReqInfoEmpty = true;
          }else{
              wrapperClass.isReqInfoEmpty = false;
          }
            wrapperClass.CPQUser = GetCaseInformation.getUserDetail();
            wrapperClass.myCase = myCases;         
	    List<String> resList = getRequiredInformation(myCases);
          //system.debug('resList :'+resList);
          if(resList.size() > 0 && resList!=null && !resList.isEmpty()){
              if(resList[0]!=null && String.isNotBlank(resList[0])){
                  wrapperClass.reqInfo = resList[0];
                  if(resList[1]!=null && String.isNotBlank(resList[1])){
                      wrapperClass.businessRuleId = resList[1];
                      wrapperClass.requiredInfo = resList[2];
                  }
              }else if(resList.size() > 1){
                  if(resList[1]!=null && String.isNotBlank(resList[1]) && String.isNotBlank(resList[2])){
                      wrapperClass.businessRuleId = resList[1];
                      wrapperClass.requiredInfo = resList[2];
                  }
              }
          }
            wrapperClass.isAssetMandatory = true;
             //SDT-39047 
            wrapperClass.allowProgressCase = true;
            if(myCases != null && string.isNotBlank(myCases.Case_Type__c) && string.isNotBlank(myCases.Case_Sub_type__c)){
                //SDT-39047
                BillingService billing = new BillingService();
                wrapperClass.allowProgressCase = billing.isBillingDataBlank(myCases,GetCaseInformation.LoggedInUserProfile);
                for(WOCreation__mdt wo : [SELECT Id,Case_Type__c,Case_Subtype__c ,Case_Reason__c,WO_Needed__c,Is_Asset_Mandatory__c 
                                          FROM WOCreation__mdt 
                                          WHERE Case_Type__c =: myCases.Case_Type__c and Case_Subtype__c =:myCases.Case_Sub_type__c]){                    
                    if(String.isNotBlank(myCases.Case_Reason__c) && myCases.Case_Reason__c.equals(wo.Case_Reason__c)){
                        wrapperClass.isAssetMandatory = wo.Is_Asset_Mandatory__c ;
			    break;
                    }else {
                        wrapperClass.isAssetMandatory = wo.Is_Asset_Mandatory__c ;
                    }
                }
            } 
	   if(myCases.Case_Sub_type__c == Constant_Util.BALES){
                wrapperClass.isAssetMandatory = FALSE;
            }
            /*if(string.IsBlank(wrapperClass.reqInfo)){
                wrapperClass.caseInfo = Constant_Util.READY;
            } */

            // REFACTORED (Phase 5F): Use CaseTaskService instead of direct SOQL query
            // OLD CODE: List<Task> tskLst = [SELECT ... FROM Task WHERE ...];
            Integer openTaskCount = CaseTaskService.getOpenTaskCount(caseId);
            if(openTaskCount > 0 || myCases.Case_Sub_Status__c == Constant_Util.INTEGRATION_ERROR) {
                wrapperClass.isOpenTask = true;
            }


       //Setting IsPOProfileDisable flag to disable PO/Profile -- SDT-20936
            // REFACTORED: Use method-scoped variable instead of static
            Map<String,Boolean> poProfileReqMap = getMetadata();
          if(poProfileReqMap.get(myCases.Case_Type__c) != null){
           wrapperClass.IsPOProfileDisable = poProfileReqMap.get(myCases.Case_Type__c);
          }
                       
           
                             
        }Catch(exception ex){
            system.debug('ex Error :'+ ex.getMessage());
            return null;
        }		        
        return wrapperClass;
    }
    
    
/**
* @author Accenture
* @date 2/28/2019
* @description : Apex method to get po/profileNumber/psi information
* REFACTORED (Phase 5A): Made myCasesList method-scoped instead of static class variable
**/
    public static List<String> getRequiredInformation(Case myCases) {
        String reqInfo = '';
        set<Id> accountIdset = new set<Id>();
        set<string> requestTypeSet = new Set<string>();
        set<string> ServiceTypeSet = new Set<string>();
        set<Id> relatedCaseIdSet = new set<Id>();
        set<Id> recordTypeIdSet = new set<Id>();
        accountIdset.add(myCases.Client__c);
        requestTypeSet.add(myCases.Case_Type__c);
        ServiceTypeSet.add(myCases.Case_Sub_type__c);
        List<String> resultList = new List<String>();

        // REFACTORED: Made method-scoped instead of static class variable
        List<Case> myCasesList = new List<Case>();

        // for po/profile/psi
            myCasesList.add(myCases);
            map<Id,Business_Rule__c> reqInfomap = new map<Id,Business_Rule__c>();

            // REFACTORED (Phase 5A): Create local maps instead of writing to deprecated static variables
            // OLD CODE (Anti-pattern): CaseTriggerHelper.casewithContainer.put() - DEPRECATED in Phase 4
            // OLD CODE (Anti-pattern): CaseTriggerHelper.casewithLocation.put() - DEPRECATED in Phase 4
            Map<Id,Asset> localAssetMap = new Map<Id,Asset>();
            Map<Id,Account> localLocationMap = new Map<Id,Account>();

            if(myCases.Status.equals(Constant_Util.STATUS_New) || myCases.Status.equals(Constant_Util.PENDING) || (myCases.Status.equals(Constant_Util.OPEN) && myCases.Case_Record_Type__c == Constant_Util.New_Service_Case)){
            for(Asset a : [SELECT Id,Product2.ProductTypeSelected__c,Duration__c,Material_Type__c,Project_Code__c,Active__c,Sensitivity_Code__c,End_Date_Based_on_Project_code__c
                           FROM Asset WHERE Id =: myCases.AssetId LIMIT 49999]){
                               // REFACTORED: Use local map instead of deprecated static variable
                               localAssetMap.put(a.Id,a);
                           }
            for(Account loc: [SELECT Id,Brand__c,Geography__c,Division__c,Location_Type__c
                              FROM Account WHERE Id =: myCases.Location__c LIMIT 49999]){
                                  // REFACTORED: Use local map instead of deprecated static variable
                                  localLocationMap.put(loc.Id,loc);
                              }
                Id reqInfoRecTypeId = Schema.SObjectType.Business_Rule__c.getRecordTypeInfosByName().get(Constant_Util.REQUIRED_INFORMATION).getRecordTypeId();
                if(myCases.Status.equals(Constant_Util.STATUS_New) || myCases.Status.equals(Constant_Util.OPEN)){
                    recordTypeIdSet.add(reqInfoRecTypeId);
                }
                if(myCases.Case_Record_Type__c == Constant_Util.New_Service_Case){
                    //List<BusinessRuleNSCHelper.BusinessRulewrapper> businessRulewrapperlst = BusinessRuleNSCHelper.selectBusinessRules(myCasesList);
                    List<BusinessRuleHelper.BusinessRulewrapper> businessRulewrapperlst = new List<BusinessRuleHelper.BusinessRulewrapper>();
                    for (Case c : myCasesList) {
                        businessRulewrapperlst.addAll(BusinessRuleHelper.businessRuleSelection(c.Id,recordTypeIdSet));
                    }
                    if(businessRulewrapperlst != null && businessRulewrapperlst.size() > 0){
                        //for(BusinessRuleNSCHelper.BusinessRulewrapper brw : businessRulewrapperlst){
                        for(BusinessRuleHelper.BusinessRulewrapper brw : businessRulewrapperlst){
                            if(reqInfoRecTypeId.equals(brw.bRule.RecordTypeId)){
                                reqInfomap.put(brw.caseId,brw.bRule);
                            }
                        }
                	}
                }else{
                    // REFACTORED (Phase 5A): Pass local maps instead of deprecated static variables
                    List<BusinessRuleHelper.BusinessRulewrapper> businessRulewrapperlst = BusinessRuleHelper.businessRuleSelection(myCasesList,recordTypeIdSet,accountIdset,requestTypeSet,ServiceTypeSet,localAssetMap,localLocationMap);
                    //List<BusinessRuleHelper.BusinessRulewrapper> businessRulewrapperlst = BusinessRuleHelper.businessRuleSelection(myCases.Id,recordTypeIdSet);
                    if(businessRulewrapperlst != null && businessRulewrapperlst.size() > 0){
                        for(BusinessRuleHelper.BusinessRulewrapper brw : businessRulewrapperlst){
                            if(reqInfoRecTypeId.equals(brw.bRule.RecordTypeId)){
                                reqInfomap.put(brw.caseId,brw.bRule);
                            }
                        }
                    }
                }
            }
            if(myCases.Status.equals(Constant_Util.STATUS_New) || (myCases.Status.equals(Constant_Util.OPEN) && myCases.Case_Record_Type__c == Constant_Util.New_Service_Case)){
                reqInfo = Constant_Util.EMPTY_STRING;
                Business_Rule__c caseRule = new Business_Rule__c();
                caseRule = reqInfomap != null && reqInfomap.size() > 0 && reqInfomap.containskey(myCases.Id) ? reqInfomap.get(myCases.Id) : null;
                    if(caseRule !=null && caseRule.Required_Information__c.contains(Constant_Util.PO_NUMBER) && String.isBlank(myCases.PurchaseOrder_Number__c) && !(myCases.Override_PO_Create_Task__c)){
                        reqInfo += Constant_Util.PO_MSG + Constant_Util.NEW_LINE;            
                    }
                    //commented as part of sdt 33312
                    /*if(caseRule !=null && caseRule.Required_Information__c.contains(Constant_Util.PROFILE_NUMBER) && String.isBlank(myCases.Profile_Number__c) && !(myCases.Override_Profile_Number_Task__c)){
                        reqInfo += Constant_Util.PROFILE_MSG + Constant_Util.NEW_LINE;            
                    }*/
                    if(caseRule !=null && caseRule.Required_Information__c.contains(Constant_Util.PSI) && myCases.PSI__c == null){
                        if(myCases.PSI_Override_Reason__c == null){ 
                            reqInfo += Constant_Util.PSI_REQUIRED + Constant_Util.NEW_LINE;
                        }
                        else if(myCases.PSI_Override_Reason__c != null && myCases.PSI_Override_Reason__c == Constant_Util.OTHER_API && myCases.PSI_Comments__c == null)  {
                            reqInfo += Constant_Util.PSI_COMMENTS + Constant_Util.NEW_LINE;
                        }
                        else{
                            //Nova cop fix
                        }
                    }
                    if(caseRule !=null && caseRule.Required_Information__c.contains(Constant_Util.COMPANY_CATEGORY) && String.isBlank(myCases.Company_Category__c) && !(myCases.Override_Company_Category_Create_Task__c)){
                        reqInfo += Constant_Util.CC_MSG + Constant_Util.NEW_LINE;
                    }
                
                resultList.add(reqInfo);
                if(caseRule!=null && caseRule.Id!=null && caseRule.Required_Information__c!=null){
                    resultList.add(caseRule.Id);
                    resultList.add(caseRule.Required_Information__c);
            	}
            }        
   
        return resultList;//reqInfo;
    }
    
    public with sharing class Wrapper {
        @AuraEnabled public string reqInfo {get;set;}
        @AuraEnabled public Case myCase {get;set;}
        @AuraEnabled public Boolean CPQUser {get; set;}
        @AuraEnabled public Boolean isOpenTask {get;set;}   
        @AuraEnabled public Boolean isAssetMandatory {get;set;}   
        @AuraEnabled public Boolean IsPOProfileDisable {get;set;}
        @AuraEnabled public Boolean isReqInfoEmpty {get;set;}
        @AuraEnabled public String businessRuleId {get;set;}
        @AuraEnabled public String requiredInfo {get;set;}
        //SDT39047
        @AuraEnabled public Boolean allowProgressCase {get;set;}
    } 
    /* Author- WM
	* Date- 04/30/2020
	* Description- method to get wm capacity planner visibility as per SDT-12786
	*/
    @AuraEnabled
    public static Boolean getCapacityEligibilty(String caseId){
        Boolean isEligible=false;
        isEligible = ServiceDateContainerController.IsWMCapacityPlannerVisible(caseId);
        return isEligible;
    }
    /* Author- WM
	* Date- 03/01/2022
	* Description- method to get Queue name as per SDT-23166
	*/	
	@AuraEnabled
    public static String getQueueName(String trackingNumber){
        String queueName = '';
        RESTHelper.AcornResponse jsonResp;
        try{
            String result = IntegrationHandlerUtil.getQueueMetadataDetails('Get_Assignment',trackingNumber);
            Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(result);
            Map<String, Object> m2 = (Map<String, Object>) parsedResponse.get('data');
            if(m2 != null)
            {
                String teamName = (String)m2.get('teamName');
                String userName = (String)m2.get('userName');
                if(teamName != null && userName != null)
                {
                    queueName = userName+' / '+ teamName;
                }
                else if(teamName == null && userName != null)
                {
                    queueName = userName;
                }
                else if(teamName != null && userName == null)
                {
                    queueName = teamName;
                }
                else if(teamName == null && userName == null)
                {
                    jsonResp = (RESTHelper.AcornResponse) JSON.deserialize(result, RESTHelper.AcornResponse.Class);
                    queueName = 'Error: '+jsonResp.Problem.Title + ': ' + jsonResp.Problem.Errors[0].Message;
                }
                return queueName;
            }
            else
            {
                jsonResp = (RESTHelper.AcornResponse) JSON.deserialize(result, RESTHelper.AcornResponse.Class);
                queueName = 'Error: '+jsonResp.Problem.Title + ': ' + jsonResp.Problem.Errors[0].Message;
                return queueName;
            }
        }
        catch(Exception ex)
        {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION,LoggingLevel.ERROR);
            return queueName;
        }
    }

    @AuraEnabled
    public static String updateBRonCase(String caseId,String brId,String reqInfo){
// Modified for SDT-33454 Start
        try {
            If(String.isNotBlank(brId)){
                Case newUpdate = new Case(Id=caseId,Business_RuleId__c=brId,Required_Information__c=reqInfo);
                if(newUpdate != null){
                    // REFACTORED: Use CaseDMLService instead of direct update
                    List<Case> casesToUpdate = new List<Case>{newUpdate};
                    CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCases(casesToUpdate);

                    if(!result.isSuccess()){
                        return 'error';
                    }
                }
            }
        } catch (DmlException e) {
            //System.debug('A DML exception has occurred: ' + e.getMessage());
            STPExceptionUtil.setStepByStepExceptionObj('updateBRonCase', 'Case Screen',e.getMessage());
            return 'error';
        }
        // Modified for SDT-33454 End
        return 'success';
    }

    /**
     * @description Recalculates SLA for a case after Case Type/Sub-Type/Reason changes
     * This method was restored after being removed during service layer refactoring.
     * It delegates to SLACalculationUtility.setServiceDate() for the actual calculation.
     *
     * USAGE: Called by fillCaseSubTypeLWC and FillCaseSubType (Aura) after case type changes
     *
     * @param caseId The ID of the case to update SLA for
     * @return String 'success' or 'error'
     */
    @AuraEnabled
    public static String updateSLA(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return 'error';
            }

            // Retrieve the case with necessary fields for SLA calculation
            Case caseToUpdate = [
                SELECT Id, Case_Type__c, Case_Sub_Type__c, Case_Reason__c,
                       CreatedDate, EntitlementId, Service_Date__c,
                       SLA_Service_Date__c, SLA_Service_Date_Time__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (caseToUpdate == null) {
                return 'error';
            }

            // Clear existing SLA dates to force recalculation
            // SLACalculationUtility only calculates if SLA_Service_Date_Time__c is null
            caseToUpdate.SLA_Service_Date_Time__c = null;
            caseToUpdate.SLA_Service_Date__c = null;

            // Use SLACalculationUtility to recalculate SLA
            // Note: setServiceDate is an @InvocableMethod, so we need to pass a list
            List<Case> casesToProcess = new List<Case>{caseToUpdate};
            SLACalculationUtility.setServiceDate(casesToProcess);

            return 'success';

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            STPExceptionUtil.setStepByStepExceptionObj('updateSLA', 'Case Screen', ex.getMessage());
            return 'error';
        }
    }

}
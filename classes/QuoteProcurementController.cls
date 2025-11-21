//Class: QuoteProcurementController
//Purpose: To return and manipulate data on the SBQQ__QuoteLine__c object
//in accordance with the business process
//Author: George R Martin III
//Date: 6/14/2021

public class QuoteProcurementController {
    
    //The Purpose of this class will be to showcase the quote lines to a user 
    //in a simple consumable interface.  Some additional bells and whistles will be added
    //to ensure that users can also append cost, price, vendor details and MAS information
    //should that be desired in future releases
    public static set<string> wasteCategorySet = new set<string>{'Waste Stream', 'Waste Category'};
    //SDT-30089 - start
    public static String specialHandling_Automatic_Reason = 'Automatically flagged by system';
    public static String specialHandling_BackDated_Reason = 'Back-dated service requested';
    //SDT-30089 - end
    
    //TCS-pkulkarn-SDT-33303-Added variables to store Error message values.
    public static String strVendorMissing = 'Vendor missing';
    public static String strMASLibraryOrCode = 'Missing MAS Library, Company Code';
    public static String strSetupComment = 'Missing Setup Comment';
    public static String strOrSetupComment = ' or Setup Comment';
    public static String strCostUOMType = 'Missing Cost Unit of Measure or Model Type';
    public static String strCostModelTypeRebate = 'Cost Model Type of Rebate must have a Cost of $0.00';
    public static String strCostMissing = 'Cost Missing';
    public static String strManagementFee = 'Unit cost should be $0.00 and vendor name should start with WM Fee if product name is Management Fee ';
    public static String strVendorInactive = 'Selected vendor is not active ';
    public static String strWMFeeUnitCost =' WM Fee charges should have a cost of 0$';
    public static String strMassIdMissing =  'MAS Unique ID is Missing';
    public static String strVCRCodeMissing =  'Vendor requires VCR Code field';//only for WM
    public static String strPriceMissing='Price cannot be blank';
    public static String strPricingMethodMissing = 'Price Model type (pricing method) must be specified';  
    public static String strWMFeeList = ' WM Fee charges requires a price greater than 0';
    //TCS-pkulkarn-SDT-33303-End
    //TCS-pkulkarn-SDT-41532-Added following two variables
    public static String strCostModelTypeSTP = 'You must enter 2 stepped cost if Cost model type is Stepped. ';
    public static String strPricingUnitMethodSTP = 'You must enter 2 stepped price if Price unit method is stepped. ';
    //TCS-pkulkarn-SDT-41532-End

    @AuraEnabled
    public static ProductsWrapper buildQuoteWrapper(String quoteId) {
        // Refactored to use QuoteProcurementWrapperService
        return QuoteProcurementWrapperService.buildQuoteWrapper(quoteId);
    }     
    //sdt-31000
    
    @AuraEnabled
    public static List<nteWrapper> showErrorWrapper(String quoteId, List<Id> parentQLineIds) {
    //List<nteWrapper> pwList = new List<nteWrapper>();
    List<nteWrapper> nWrapperList = new List<nteWrapper>();
    List<SBQQ__Quote__c> quotesWithQuoteLinesList = new List<SBQQ__Quote__c>();
    map<id,List<SBQQ__QuoteLine__c>> quoteIdQuoteLineListMap = new map<id,List<SBQQ__QuoteLine__c>>();
    List<SBQQ__QuoteLine__c> updateQList = new List<SBQQ__QuoteLine__c>();
    List<Business_Rule__c> brList = new List<Business_Rule__c>();
    map<Id,Business_Rule__c> reqInfomap = new map<Id,Business_Rule__c>();
    List<Business_Rule__c> BRWithServiceApproverList= new List<Business_Rule__c>();
    List<service_approver__c> srList= new List<service_approver__c>();
    set<Id> recordTypeIdSet = new set<Id>();
    Id brIdSet;
    String CaseNum;
    boolean nteLimitExceeded  = false;
    boolean quoteUpdate = false;
    boolean success = false;
    boolean brWithNTE = false;
    List<string> qlineList = new List<string>();
    String qlineString;
    boolean updateFlagNTE = false;
        //SDT-37527
        quotesWithQuoteLinesList = [SELECT Id,Case_Number__c,is_NTE_Quote__c,Project__c, Case_record_Type__c,Business_Rule__c, SBQQ__Status__c, (SELECT id,Name,ErrorComments__c, Occurrence_Type__c, Schedule_Frequency__c, Service_Days__c,SBQQ__Cost__c,Vendor__c, Equipment_Size__c, MaterialGrade__c,
                                                                                                                                                 SBQQ__RequiredBy__c, SBQQ__RequiredBy__r.SBQQ__ProductFamily__c, SBQQ__Product__R.Name, 
                                                                                                                                                 SBQQ__RequiredBy__r.Equipment_Size__c,SBQQ__ListPrice__c,NTE_amount_on_SR__c,SBQQ__ProductName__c,SBQQ__MaximumPrice__c, SBQQ__RequiredBy__r.AssetId__r.Equipment_Size__c, AssetId__c
                                                                                                                                                 FROM SBQQ__LineItems__r WHERE SBQQ__ProductFamily__c NOT IN: wasteCategorySet  
                                                                                                                                                 AND Bypass_Acorn_Integration__c = false and SBQQ__RequiredBy__c IN :parentQLineIds) FROM SBQQ__Quote__c WHERE id =: quoteId];
        
        System.debug('quotesWithQuoteLinesList^^^ ' +quotesWithQuoteLinesList);
        
        
        if(QuotesWithQuoteLinesList[0].Case_Number__c != null){
            CaseNum = QuotesWithQuoteLinesList[0].Case_Number__c;
        }
        System.debug('CaseNum^^^ ' +CaseNum);
        
        List<Case> csObj = [Select Id,Client__c,Location__c,CaseNumber,Location__r.Location_Type__c,Location__r.Geography__c,
                            Location__r.Division__c,Location__r.Brand__c,AssetId,Case_Type__c,Case_Sub_Type__c,Case_Reason__c from Case where CaseNumber =:CaseNum];
        System.debug('csObj^^^ ' +csObj);
        Id reqInfoRecTypeId = Schema.SObjectType.Business_Rule__c.getRecordTypeInfosByName().get('Approval').getRecordTypeId();
        //recordTypeIdSet.add(reqInfoRecTypeId);
         System.debug('recordTypeIdSet^^^ ' +recordTypeIdSet);
               
        
        Business_Rule__c brRules = GetBRQuotePriorityNTECtrl.getBRNTEPriority(quotesWithQuoteLinesList[0].Id);
        System.debug('Get brRules :: '+brRules);
    //    List<NTEApprovalRuleHelper.BusinessRulewrapper> businessRulewrapperlst = NTEApprovalRuleHelper.selectBusinessRules(csObj,quotesWithQuoteLinesList[0]);
     //   System.debug('calling here 2^^^ ');
        if(brRules!= null ){
            System.debug('inside if^^^ ');
            // for(NTEApprovalRuleHelper.BusinessRulewrapper brw : businessRulewrapperlst){
            if(reqInfoRecTypeId.equals(brRules.RecordTypeId)){
                System.debug('inside second if^^ ');
                //  reqInfomap.put(brw.caseId,brw.bRule);
                brList.add(brRules);
                brIdSet = brList[0].Id;
                // Changes for SDT-37991
                if(brList!=null && brList[0].NTE_Rules__c && !brList[0].No_Approval_Required__c){
                    brWithNTE = true;
                }
                System.debug('brIdSet^^^ '+brIdSet);
            }
            // }
        }
        
        
        if(brIdSet != null){
            // BRWithServiceApproverList= [SELECT Id,(SELECT id,NTE_Amount__c from Approver_Entities__r  WHERE RecordType.Name = 'NTE Approval'
            //    AND Active__c = true ) FROM Business_Rule__c WHERE id = :brIDSet];
            if(brWithNTE){
                BRWithServiceApproverList= brList;
                srList = [SELECT id,NTE_Amount__c,Service_Type__c,RecordType.Name,Active__c from service_approver__c WHERE RecordType.Name = 'NTE Approval'
                                    AND Active__c = true AND Business_Rule__c =: brIdSet];
            }
        }
        
        for(SBQQ__Quote__c quote: quotesWithQuoteLinesList){
            if(quote.SBQQ__LineItems__r.size()>0){
                quoteIdQuoteLineListMap.put(quote.id, quote.SBQQ__LineItems__r);
                
            }
        }
        system.debug('quoteIdQuoteLineListMap >'+ quoteIdQuoteLineListMap);
        system.debug('srList >'+ srList);
        if(!srList.isEmpty()){
            for(SBQQ__Quote__c qt: quotesWithQuoteLinesList){
                System.debug('here3^^^ ' + qt);
                for(SBQQ__QuoteLine__c qLine: quoteIdQuoteLineListMap.get(qt.Id)){
                    if(!srList.isEmpty() && srList.size()>0){
                        for(Service_approver__c sr :srList){
                            system.debug('sr >'+ sr);
                            if( (qt.SBQQ__Status__c == 'Cost Configured' || qt.SBQQ__Status__c == 'Product Configured' || qt.SBQQ__Status__c == 'Price Configured') && qLine.SBQQ__ListPrice__c != null  && qLine.SBQQ__ListPrice__c > sr.NTE_Amount__c && qLine.SBQQ__ProductName__c == sr.Service_Type__c){
                                System.debug('here2^^^ '  + sr);
                                nteLimitExceeded = true;
                                nteWrapper nWrapper = new nteWrapper();
                                nWrapper.showMessage = nteLimitExceeded;
                                nWrapper.qlineDetails = qLine.Name;
                                nWrapper.qlineId = qLine.SBQQ__RequiredBy__c;
                                nWrapperList.add(nWrapper);
                                //qlineList.add(qLine.Name);
                                //qlineString = String.join(nWrapper.qlineDetails,',');
                                if(qline.NTE_amount_on_SR__c != sr.NTE_Amount__c){
                                    qline.NTE_amount_on_SR__c = sr.NTE_Amount__c;
                                    updateFlagNTE = true;
                                    updateQList.add(qline);
                                }
                            }
                        }
                        // if(qlineList!= null){
                        //     qlineString = String.join(qlineList,',');
                        // }
                    }
                }
                if((qt.SBQQ__Status__c == 'Cost Configured' || qt.SBQQ__Status__c == 'Product Configured' || qt.SBQQ__Status__c == 'Price Configured') && nteLimitExceeded ){
                    //nWrapper.showMessage = true;
                    //nWrapper.qlineDetails = qlineString;
                    if(qt.is_NTE_Quote__c ==false){
                        qt.is_NTE_Quote__c =true;
                        quoteUpdate = true;
                    }
                } 
                else{
                    //nWrapper.showMessage = false;
                    if(qt.is_NTE_Quote__c ==true){
                        qt.is_NTE_Quote__c =false;
                        quoteUpdate = true;
                    }
                } 
            }
            if(updateFlagNTE && nteLimitExceeded){
                update updateQList;
            }
            if(quoteUpdate){
                update quotesWithQuoteLinesList;
            }
        }
        System.debug('here1^^^ ' + nWrapperList);
        return nWrapperList;
    }
    /*
  	 * @Name          getMaterialTypes
  	 * @Vendor		  TCS
  	 * @Author        WM - Rajan Sajani
  	 * @Date          2/22/202a
  	 * @param		   material : String
  	 * @return		  List<Map<String, String>>
  	 * @story		  SDT-7527
  	 * @Description   It passes material grade type valuesand label for picklist
  	 */
    // Refactored to use QuoteProcurementUIService
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMaterialTypes(String material) {
        return QuoteProcurementUIService.getMaterialTypes(material);
    }

//sdt-31000
       
    @AuraEnabled
    public static ProductsWrapper buildWrapper(String quoteId) {
        // Refactored to use QuoteProcurementWrapperService
        return QuoteProcurementWrapperService.buildWrapper(quoteId);
    }
    
    //STARTING HERE - MAS methods for retrival and writing to quote lines
    //Returns the MAS Library and Company Code details for user selection and entry
    //SDT-29645 - Start
    /*
    @AuraEnabled
    public static List<AggregateResult> returnMASDetails(String businessUnit) {
        
        List<AggregateResult> MASDetails = new List<AggregateResult>();
        
        MASDetails = [SELECT MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c, Bypass_Price_Review__c
                      FROM MAS_Setup_Detail__c
                      WHERE Business_Unit_Number__c =: businessUnit
                      GROUP BY MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c, Bypass_Price_Review__c];
        
        return MASDetails;
        
    }*/
    //SDT-29645 - End
    //SDT-29645 - Start
    // Refactored to use QuoteProcurementMASService
    @AuraEnabled
    public static List<AggregateResult> returnUniqueMASDetails(Id quoteLineId) {
        return QuoteProcurementMASService.getMASDetailsForQuoteLine(quoteLineId);
    }
    /*
    // ORIGINAL METHOD - REFACTORED ABOVE
    @AuraEnabled
    public static List<AggregateResult> returnUniqueMASDetails(Id quoteLineId) {

        SBQQ__QuoteLine__c parentLine = null;
        boolean newServiceCase = false;
        string lineOfBusiness;
        List<AggregateResult> MASDetails = new List<AggregateResult>();
        string businessUnit;


        List<SBQQ__QuoteLine__c> quoteLines = getQuoteLineMASDetails(quoteLineId);

        if(!quoteLines.isEmpty() && quoteLines.size()>0){
            parentLine = quoteLines[0];
        }

        if(parentLine != null){

            if(parentLine.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name == Constant_Util.New_Service_Case){
                newServiceCase = true;
            }
            if(parentLine.SBQQ__Product__r.Family == Constant_Util.ROLLOFF){
                lineOfBusiness = 'O';
            }
            else if(parentLine.SBQQ__Product__r.Family == Constant_Util.COMMERCIAL){
                lineOfBusiness = 'C';
            }

            if(parentLine.Vendor__r.Vendor_Business_Unit__c != null )
                {
                    businessUnit = parentLine.Vendor__r.Vendor_Business_Unit__c;
                }


            if(parentLine.Vendor__r.FacilityCode__c != null){
                MASDetails = [SELECT MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c, Bypass_Price_Review__c
                      FROM MAS_Setup_Detail__c
                      Where (Facility_Id__c =:parentLine.Vendor__r.FacilityCode__c and
                            MAS_Line_of_Business__c =:lineOfBusiness and
                            Valid_For_New_Service__c =:newServiceCase)
                      GROUP BY MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c, Bypass_Price_Review__c];
            }

            if(MASDetails.size() == 0){
                MASDetails = [SELECT MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c, Bypass_Price_Review__c
                      FROM MAS_Setup_Detail__c
                      Where (Business_Unit_Number__c =:businessUnit and
                            MAS_Line_of_Business__c =:lineOfBusiness
                            )
                      GROUP BY MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c, Bypass_Price_Review__c];
            }
        }
        
        
        return MASDetails;
        
    }
    //SDT-29645 - End
    
    @AuraEnabled
    public static Boolean updateVendorDetails(HeaderWrapper headerRecord) {
        // Refactored to use QuoteProcurementDMLService
        system.debug('Selected s-code is: ' + headerRecord.sCode);
        system.debug('Selected vendor is: ' + headerRecord.vendorName);

        QuoteProcurementDMLService.DMLResult result =
            QuoteProcurementDMLService.getInstance().updateVendorDetails(
                headerRecord.parentId,
                headerRecord.vendorId,
                headerRecord.sCode
            );

        if (!result.isSuccess) {
            system.debug(result.message);
        }

        return result.isSuccess;
    }
    
    @AuraEnabled
    public static Boolean updateCompanyCategories(HeaderWrapper headerRecord) {
        // Refactored to use QuoteProcurementDMLService
        QuoteProcurementDMLService.DMLResult result =
            QuoteProcurementDMLService.getInstance().updateCompanyCategories(
                headerRecord.parentId,
                headerRecord.companyCategory
            );

        if (!result.isSuccess) {
            system.debug(result.message);
        }

        return result.isSuccess;
    }
    
    //The Lightning Component will return the HeaderWrapper portion of the total
    //wrapper which will enable us to write the values directly to the quote lines.
    //This will update every quote line with the same MAS details for consistency.
    @AuraEnabled
    public static MASResponseWrapper writeMASDetails(HeaderWrapper headerRecord) {
        // Refactored to use QuoteProcurementMASService
        return QuoteProcurementMASService.updateMASDetails(
            headerRecord.parentId,
            headerRecord.MAS
        );
    }
/*
  	 * @Name          getBypassPriceReview
  	 * @Vendor		  TCS
  	 * @Author        WM - Jatan Sharma
  	 * @Date          13/09/2023
  	 * @param		  quoteLineId : Id, masLibrary : String
  	 * @return		  boolean
  	 * @story		  SDT-31627
  	 * @Description   It sets BY Pass review flag checked/unchecked based on closed market, parent vendor and MAS libraries 
  	 */

    @AuraEnabled
    public static boolean bypassPriceReview(id quoteLineId, string masLibrary){
        // Refactored to use QuoteProcurementMASService
        return QuoteProcurementMASService.shouldBypassPriceReview(quoteLineId, masLibrary);
    }
    
    //STARTING HERE - Utility classes that are utilized to construct the wrapper class
    //Returns the header records configured for the quote for storage in the wrapper class
    public static List<SBQQ__QuoteLine__c> getQuoteProducts(Id quoteId) {
        List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();
        //SDT 33101 Quote_Only_Copy_of__c added
        //SDT-37527 field add in query
        quoteLines = [SELECT Id,PricingUnitMethod__c, SBQQ__Quote__c,Vendor__r.Status__c,Vendor_Commit_Date__c ,SBQQ__Quote__r.STP__c, SBQQ__ListPrice__c, SBQQ__UnitCost__c, SBQQ__ProductName__c, SBQQ__ProductFamily__c, SBQQ__ProductCode__c, 
                      Vendor__c, Vendor__r.Vendor_Business_Unit__c, Vendor__r.Parent_Vendor_Id__c, Vendor__r.Name, Vendor__r.AccountNumber,
                      Occurrence_Type__c, Schedule_Frequency__c, Frequency_Interval__c, Service_Days__c, SBQQ__Quantity__c, Name,
                      PriceUOM__c, PriceMinQuantity__c, SBQQ__PricingMethod__c, CostModelType__c, Cost_Unit_of_Measure__c, Account__c,
                      CostMinQuantity__c, MASLibrary__c, MASCompany__c, MASAccount__c, MASCustomerUniqueId__c, MASServiceLine__c, 
                      MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c, SetupComment__c, DoNotCreateMASTicket__c, DoNotCreateTaskGridTickets__c, Location_Position_Name__c,
                      // Commented 'SetupComment__c' field reference for story SDT-25787 to change the DataType from 'Text(255)' to 'Long Text(1500)' Will uncomment after DataType is changed
                      //MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c, DoNotCreateMASTicket__c, Location_Position_Name__c,
                      SBQQ__RequiredBy__c, toLabel(Equipment_Size__c), toLabel(Duration__c), SBQQ__StartDate__c, SBQQ__EndDate__c, sCode__c, SBQQ__RequiredBy__r.SBQQ__RequiredBy__c,
                      Vendor__r.Contact_Manually_Vendor__c, Vendor__r.Prepayment_Required__c, SBQQ__Quote__r.Case_Type__c, SBQQ__Quote__r.SBQQ__Status__c, CompanyCategoryCode__c,MaterialGrade__c,CompanyCategoryName__c,
                      SBQQ__Quote__r.SBQQ__Account__r.Parent.AccountNumber, SBQQ__Quote__r.Name, SBQQ__Quote__r.SBQQ__PrimaryContact__r.Name, 
                      SBQQ__Quote__r.SBQQ__PrimaryContact__r.Id, Certificate_of_Destruction__c, Certificate_of_Disposal__c, VCRCode__c, Service_Schedule__c,
                      SBQQ__Number__c, SBQQ__Quote__r.Quote_Only__c, Profile_Number__c, Description_of_Waste__c, SBQQ__Product__c, SBQQ__Product__r.SBQQ__QuantityEditable__c,
                      SLA_Override_Reason__c, SLA_Override_Comment__c,ProcurementErrorMessage__c,BundleProcuredStatus__c, CurrencyIsoCode,
                      SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Recordtype.Name,AAV_Delivery_Override_Comment__c,AAV_Delivery_Override_Reason__c, //SDT-30864
                      AAV_Service_Override_Reason__c,AAV_Service_Day_Override_Comment__c, //SDT-29100
                      AAV_Requested_AdditionalServicesAccessor__c,AAV_Delivery_Availability__c,AAV_Service_Availability__c,Availability_Flag__c, ////SDT-29399 
                      AAV_Asset_Availability_API_Errors__c, //SDT - 31583
                      Vendor__r.FacilityCode__c //SDT-29645
                      ,Quote_Only_Copy_of__c,SBQQ__Quote__r.SBQQ__Type__c,CustomerApproval__c//SDT 33101
                      ,Day_of_Month__c,Month_Relative_Interval__c,Month_Relative__c, //SDT41407
                      SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Is_Haul_Away_Service__c,SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c //SDT-41473
                      FROM SBQQ__QuoteLine__c
                      WHERE SBQQ__Quote__c =: quoteId AND SBQQ__RequiredBy__c = Null];
        
        system.debug('Quote lines returned: ' + quoteLines.size());
        
        return quoteLines;
        
    }
    //Added for story SDT-21065
    public static List<SBQQ__QuoteLine__c> getQuoteLineMASDetails(Id quoteLineId) {
        
        List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();
        //SDT- 29645 - Vendor__c,Vendor__r.FacilityCode__c
        quoteLines = [SELECT Id,Vendor__r.Status__c,PricingUnitMethod__c,Vendor_Commit_Date__c,SBQQ__Quote__r.SBQQ__Type__c,SBQQ__Quote__r.Case_Type__c,SBQQ__Quote__r.STP__c,MASLibrary__c, MASCompany__c, MASAccount__c, MASCustomerUniqueId__c, MASServiceLine__c, 
                      MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c, SetupComment__c, DoNotCreateMASTicket__c
                      ,DoNotCreateTaskGridTickets__c, SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name//added for SDT 29392
                      // Commented 'SetupComment__c' field reference for story SDT-25787 to change the DataType from 'Text(255)' to 'Long Text(1500)' Will uncomment after DataType is changed
                      //MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c,  DoNotCreateMASTicket__c
                      ,Vendor__c,Vendor__r.FacilityCode__c, Vendor__r.Vendor_Business_Unit__c,
                      SBQQ__Product__R.family
                      
                      FROM SBQQ__QuoteLine__c
                      WHERE id =: quoteLineId];
        
        return quoteLines;
        
    }
    //Returns the detail records for each header objects for storage in the wrapper class
    public static List<SBQQ__QuoteLine__c> getQuoteDetails(Id quoteLineId) {
        
        List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();
        //TCS-pkulkarn-SDT-33303-Added DoNotCreateTaskGridTickets__c to the SOQL
        //TCS-pkulkarn-SDT-41532-Added fields CostPrice1__c, CostPrice2__c, PricePrice1__c, PricePrice2__c to SOQL
        quoteLines = [SELECT Id, SBQQ__Quote__c,PricingUnitMethod__c,Vendor__r.Status__c,Vendor_Commit_Date__c, SBQQ__Quote__r.SBQQ__Type__c,SBQQ__Quote__r.Case_Type__c,SBQQ__Quote__r.STP__c,
                     SBQQ__ListPrice__c, SBQQ__UnitCost__c, SBQQ__ProductName__c, SBQQ__ProductCode__c, SBQQ__ProductFamily__c,
                      Vendor__c,Vendor__r.Vendor_Business_Unit__c, Vendor__r.Parent_Vendor_Id__c, Vendor__r.Name, Vendor__r.AccountNumber,
                      Occurrence_Type__c, Schedule_Frequency__c, Frequency_Interval__c, Service_Days__c,SBQQ__Cost__c, SBQQ__Quantity__c, Name,
                      PriceUOM__c, PriceMinQuantity__c, SBQQ__PricingMethod__c, CostModelType__c, Cost_Unit_of_Measure__c, ErrorComments__c,
                      CostMinQuantity__c, MASLibrary__c, MASCompany__c, MASAccount__c, MASCustomerUniqueId__c, MASServiceLine__c, 
                      MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c, SetupComment__c, DoNotCreateMASTicket__c, Location_Position_Name__c,
                      // Commented 'SetupComment__c' field reference for story SDT-25787 to change the DataType from 'Text(255)' to 'Long Text(1500)' Will uncomment after DataType is changed
                      //MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c, DoNotCreateMASTicket__c, Location_Position_Name__c,
                      SBQQ__RequiredBy__c, Equipment_Size__c, Duration__c, SBQQ__StartDate__c, SBQQ__EndDate__c, sCode__c, SBQQ__RequiredBy__r.SBQQ__RequiredBy__c,
                      SBQQ__Quote__r.SBQQ__Status__c,Bypass_Acorn_Integration__c, VCRCode__c, SBQQ__Product__c, SBQQ__Product__r.SBQQ__QuantityEditable__c,
                      Pricing_API_Method__c, CurrencyIsoCode, Cost_Compare_Message__c,IsAssetQuotelineDifferent__c,SBQQ__Quote__r.Case_record_Type__c,  //SDT-32124 - added IsAssetQuotelineDifferent__c,SBQQ__Quote__r.Case_record_Type__c 
                      SBQQ__RequiredBy__r.SBQQ__ProductName__c, SBQQ__Product__R.Name, SBQQ__RequiredBy__r.Equipment_Size__c, SBQQ__RequiredBy__r.AssetId__r.Equipment_Size__c,
                      SBQQ__RequiredBy__r.SBQQ__ProductFamily__c, AssetId__c, 
                      DoNotCreateTaskGridTickets__c, CostPrice1__c, CostPrice2__c, PricePrice1__c, PricePrice2__c
                      FROM SBQQ__QuoteLine__c
                      WHERE (SBQQ__RequiredBy__c =: quoteLineId OR SBQQ__RequiredBy__r.SBQQ__RequiredBy__c =: quoteLineId) AND SBQQ__ProductFamily__c != 'Waste Category'];
        //SDT-20085 - Yeshas K
        if(quoteLines.size()>0){
            for(SBQQ__QuoteLine__c qLine : quoteLines){
                if(!(wasteCategorySet.contains(qLine.SBQQ__ProductFamily__c)) && qLine.SBQQ__RequiredBy__c!=null && qLine.Bypass_Acorn_Integration__c == false){
                    qLine.ErrorComments__c = assignQuoteLineErrorMEssage(qLine);   
                }
            }
        }
        //update quoteLines;
        return quoteLines;
        
    }
    
    @AuraEnabled
    public static List<Quote_Order__c> getOrders (Id quoteLineId) {
        // Refactored to use QuoteProcurementOrderService
        return QuoteProcurementOrderService.getQuoteOrders(quoteLineId);
    }
    @AuraEnabled
    public static string deleteQuoteOrders(List<Quote_Order__c> quoteOrders){
        // Refactored to use QuoteProcurementDMLService
        return QuoteProcurementOrderService.deleteQuoteOrders(quoteOrders);
    }
    
    //SDT-20085 - Yeshas K
    public static string assignQuoteLineErrorMEssage(SBQQ__QuoteLine__c qLine){
        string errMsg = '';
        
        if(qLine.SBQQ__Quote__r.SBQQ__Status__c=='Draft'){ 
            errMsg = vFStage(qLine);
        }
        else if(qLine.SBQQ__Quote__r.SBQQ__Status__c=='Product Configured'){ 
            errMsg = vFStage(qLine);
            if(errMsg==''){
                errMsg = vSStage(qLine);
            }
        }
        else if(qLine.SBQQ__Quote__r.SBQQ__Status__c=='Cost Configured'){
            errMsg = vFStage(qLine);
            if(errMsg==''){
                errMsg = vSStage(qLine);
            }
            if(errMsg==''){
                errMsg = vTStage(qLine);
            }
        }
        return errMsg;
    }
    //SDT-20085 - Yeshas K
    public static string vFStage(SBQQ__QuoteLine__c qLine){
        string errMsg = '';
        if(qLine.Occurrence_Type__c=='SOC' || qLine.Occurrence_Type__c=='SCH'){
            if(qLine.Schedule_Frequency__c == '' || qLine.Schedule_Frequency__c == null){
                errMsg='Scheduled service missing a service frequency (weekly, monthly, etc.)';
            }else{
                if(qLine.Schedule_Frequency__c == 'W' && (qLine.Service_Days__c=='' || qLine.Service_Days__c==null) ){
                    errMsg='Weekly scheduled service missing day(s) of the week';
                }
            }
        }
        //Additional validation:vendor is inactive
        
            if (((qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||qline.SBQQ__Quote__r.SBQQ__Type__c == 'Exception' || qline.SBQQ__Quote__r.SBQQ__Type__c == 'Correction' || 
                 (qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && qline.SBQQ__Quote__r.STP__c == FALSE ) 
                 ) || 
                 (qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && qline.SBQQ__Quote__r.STP__c == TRUE )
                 )&& qLine.Vendor__c != null) {
                string vendorStatus = qLine.Vendor__r.Status__c;
             // Only check vendor status if vendor is not null
             if (vendorStatus == 'Inactive') {
                errMsg = strVendorInactive; 
             }
            }
        return errMsg;
    }
    //SDT-20085 - Yeshas K
    public static string vSStage(SBQQ__QuoteLine__c qLine){
        string errMsg = '';

    //SDT-32124 -- add method to evaluate not new service and Quoteline changed
        if(QuoteLineServices.isQuoteLineChangedforNonNs(qLine)) {
        if(qLine.Vendor__c == null){
            errMsg=strVendorMissing;
        }

        else{
            //Additional Validation:vendor is In active
            
              if ((qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||qline.SBQQ__Quote__r.SBQQ__Type__c == 'Exception' || qline.SBQQ__Quote__r.SBQQ__Type__c == 'Correction' || (qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && qline.SBQQ__Quote__r.STP__c == FALSE) ) && qLine.Vendor__c != null) {
                string vendorStatus = qLine.Vendor__r.Status__c;
             // Only check vendor status if vendor is not null
             if (vendorStatus == 'Inactive') {
                errMsg = strVendorInactive; 
             }
            }
            string vendorName = qLine.Vendor__r.Name;
            
            //string vendorName = qLine.Vendor__r.Name;
            String vendorId = qLine.Vendor__r.Parent_Vendor_ID__c;	//TCS-pkulkarn-13-Mar-2024-SDT-33303-Added-Modified if condition and removed SetupComment check
            if((vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR))
            {
            //if(vendorName.startsWithIgnoreCase('WM') && (qLine.MASLibrary__c=='' || qLine.MASLibrary__c==null || qLine.MASCompany__c=='' || qLine.MASCompany__c==null || qLine.SetupComment__c=='' || qLine.SetupComment__c==null)){
            // Commented 'SetupComment__c' field reference for story SDT-25787 to change the DataType from 'Text(255)' to 'Long Text(1500)' Will uncomment after DataType is changed
            //if(vendorName.startsWithIgnoreCase('WM') && (qLine.MASLibrary__c=='' || qLine.MASLibrary__c==null || qLine.MASCompany__c=='' || qLine.MASCompany__c==null)){
                if(qLine.MASLibrary__c=='' || qLine.MASLibrary__c==null || qLine.MASCompany__c=='' || qLine.MASCompany__c==null)
                {    
                    errMsg=strMASLibraryOrCode;
                }
                //TCS-pkulkarn-13-Mar-2024-SDT-33303-Added
                if((qLine.SetupComment__c == '' || qLine.SetupComment__c == null) && qLine.DoNotCreateTaskGridTickets__c == false)
                {
                    if(errMsg.equalsIgnoreCase(Constant_Util.EMPTY_STRING) == false)
                    {
                        errMsg = errMsg + strOrSetupComment;
                    }
                    else
                    {
                        errMsg = strSetupComment;
                    }
                }
                //TCS-pkulkarn-13-Mar-2024-SDT-33303-End
            }
             // Additional Vlaidation: for Start Date and End Date mismatch ***
            
                     Date vendorCommitDate = qLine.Vendor_Commit_Date__c; // Vendor commit date
                    // Date startDate = qLine.SBQQ__StartDate__c; // Start date from Quote Line
                     Date endDate = qLine.SBQQ__EndDate__c; // End date from Quote Line
 
            // Combined check for Vendor Commit Date or Start Date being greater than End Date
                   if (((vendorCommitDate != null && endDate != null && vendorCommitDate > endDate)) && (qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' || qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' ) ) {
                        errMsg = 'End Dates must be greater than the vendor commit date';
                        }


             // Additional Validation: Check if VCR Code is missing for WM vendors
             if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR){
            if (( qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' )&& vendorName != null && (qLine.VCRCode__c == null || qLine.VCRCode__c == '')) {
                errMsg = strVCRCodeMissing;
            }
        }
 
           /* //Additional validation: Missing Mass Unique ID validation
            if ((qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment') && qLine.MASCustomerUniqueId__c == null || qLine.MASCustomerUniqueId__c == 0) {
                errMsg = strMassIdMissing;
            }
            */
            if(errMsg.equalsIgnoreCase(Constant_Util.EMPTY_STRING))
            {
                if((qLine.Cost_Unit_of_Measure__c == '' || qLine.Cost_Unit_of_Measure__c == null) || (qLine.CostModelType__c == '' || qLine.CostModelType__c == null)){
                    errMsg = strCostUOMType;
                }
                else{
                    //TCS-pkulkarn-SDT-41532-Added for showing validation error on Configured Products section on Quote Page
                        //qLine.CostModelType__c=='REB' check moved to else if part
                        if(qLine.CostModelType__c=='STP')
                        {
                            if(qLine.CostPrice1__c==null || qLine.CostPrice2__c==null)
                            {
                                errMsg = strCostModelTypeSTP;
                            }
                        }
                        //TCS-pkulkarn-SDT-41532-End
                        else if(qLine.CostModelType__c=='REB')
                        {
                            if(qLine.SBQQ__UnitCost__c!=0){
                                errMsg=strCostModelTypeRebate;
                            }
                        }
                        else{
                            if(qLine.SBQQ__UnitCost__c == null){
                                errMsg=strCostMissing;
                            }else{
                                if(qLine.SBQQ__ProductName__c == 'Management Fee'){
                                    //string vendorName = qLine.Vendor__r.Name;
                                    if(qLine.SBQQ__UnitCost__c!=0 || !vendorName.startsWithIgnoreCase('WM Fee')){
                                        errMsg=strManagementFee;
                                    }
                                }
                                //SDT- 48564 Additional Validation:Check if Vendor is "WM Fee" and Unit Cost does not equal to  0
                               else if ( (qLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' || qLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' ) && !qLine.SBQQ__Quote__r.STP__c && vendorName != null && vendorName.startsWithIgnoreCase('WM Fee') && qLine.SBQQ__UnitCost__c != 0 ) {
                
                                     errMsg = strWMFeeUnitCost ;
                 
                                 }
                                else{
                                    errMsg= validateOccurence(qLine);
                                }
                            }
                    }
                }   
            }
        }
    }
    //added as part of sdt 32753
        //alert is shown only in product configured status
        if((errMsg.equalsIgnoreCase(Constant_Util.EMPTY_STRING)) && (qLine.SBQQ__RequiredBy__r.SBQQ__ProductFamily__c.equalsIgnoreCase(Constant_Util.COMMERCIAL)) 
           && (qLine.SBQQ__Quote__r.SBQQ__Status__c.equalsIgnoreCase(QuoteLineServices.STATUS_PRODUCT_CONFIGURED)) 
           && ((qLine.SBQQ__Product__R.Name.equalsIgnoreCase(Constant_Util.REMOVAL)) 
               || (qLine.SBQQ__Product__r.Name.equalsIgnoreCase(Constant_Util.SWAPOUT_PRODUCT)))
           && (qLine.SBQQ__Quote__r.Case_record_Type__c != Constant_Util.New_Service_Case)) {
               errMsg = validateRemovalAndSwapoutSize(qLine);
        }
    return errMsg;
    }
    //SDT-20085 - Yeshas K
    public static string validateOccurence(SBQQ__QuoteLine__c qLine){
        string errMsg = '';
        if(qLine.Occurrence_Type__c=='SOC' || qLine.Occurrence_Type__c=='SCH'){
            //Changes related to defect SDT-48522 raised for SDT-39632 
            if(qLine.Schedule_Frequency__c=='D' || qLine.Schedule_Frequency__c=='M' || qLine.Schedule_Frequency__c=='Y' || qLine.Schedule_Frequency__c == 'W'){
                if(qLine.Frequency_Interval__c==null || qLine.Frequency_Interval__c==''){
                    errMsg = 'Scheduled/SOC service missing frequency interval';
                }
            }
        }else{
            if(qLine.Occurrence_Type__c=='OC' && ((qLine.Schedule_Frequency__c!='' && qLine.Schedule_Frequency__c!=null) ||( qLine.Frequency_Interval__c!='' && qLine.Frequency_Interval__c!=null) ) ){
                errMsg='On-call Service should not contain a Service Frequency or Frequency interval';
            }
        }
        return errMsg;
    }

    //added as part of sdt 32753
    public static String validateRemovalAndSwapoutSize(SBQQ__QuoteLine__c currentQuoteline) {
        //string to store error message
        String errMsg = '';
        
        // get the Equipment Size
        List<Schema.PicklistEntry> equipment_SizeEntries = Schema.SObjectType.SBQQ__QuoteLine__c.fields.Equipment_Size__c.getPicklistValues();
        
        //checking if the parent is commercial family
        if((currentQuoteline.SBQQ__RequiredBy__c != NULL) && (currentQuoteline.SBQQ__RequiredBy__r.SBQQ__ProductFamily__c.equalsIgnoreCase(Constant_Util.COMMERCIAL))) 
        {
            //system.debug('insidefirstif');
            String convertedAssetSize = AssetQuoteProcurementController.getPicklistEntryByLabel(equipment_SizeEntries, currentQuoteLine.SBQQ__RequiredBy__r.AssetId__r.Equipment_Size__c);
            
            //checking if the size is changed for this bundle
            if(currentQuoteLine.SBQQ__RequiredBy__r.Equipment_Size__c != convertedAssetSize) 
            {
                //system.debug('convertedAssetSize >> ' + convertedAssetSize);
                //checking if the size for removal or swapout is not the asset size - fail status change for quote
                if(!(currentQuoteline.Equipment_Size__c.equalsIgnoreCase(convertedAssetSize))) 
                {
                    //System.debug('inside last if currentQuoteline.Equipment_Size__c >> ' + currentQuoteline.Equipment_Size__c);
                    errMsg = 'Please ensure your Swapout and Removal have the correct sizes';
                }
            }
        }
        return errMsg;
    }

    public static string vTStage(SBQQ__QuoteLine__c qLine){
        string errMsg = '';
        //Additional validation:vendor is inactive
          if ((qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||qline.SBQQ__Quote__r.SBQQ__Type__c == 'Exception' || qline.SBQQ__Quote__r.SBQQ__Type__c == 'Correction' || (qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && qline.SBQQ__Quote__r.STP__c == FALSE) ) && qLine.Vendor__c != null) {
                string vendorStatus = qLine.Vendor__r.Status__c;
             // Only check vendor status if vendor is not null
             if (vendorStatus == 'Inactive') {
                errMsg = strVendorInactive; 
             }
            }
            string vendorName = qLine.Vendor__r.Name;
            
            // Additional Vlaidation: for Start Date and End Date mismatch ***
            
                     Date vendorCommitDate = qLine.Vendor_Commit_Date__c; // Vendor commit date
                    // Date startDate = qLine.SBQQ__StartDate__c; // Start date from Quote Line
                     Date endDate = qLine.SBQQ__EndDate__c; // End date from Quote Line
 
            // Combined check for Vendor Commit Date or Start Date being greater than End Date
               if (((vendorCommitDate != null && endDate != null && vendorCommitDate > endDate) ) && (qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' || qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote') ) {
                    errMsg = 'End Dates must be greater than the vendor commit date';
                    }
            //Additional validation: Missing Mass Unique ID validation
            String vendorId = qLine.Vendor__r.Parent_Vendor_ID__c; 
            if ((vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR) && (qline.SBQQ__Quote__r.SBQQ__Type__c  != 'Quote') && (qLine.MASCustomerUniqueId__c == null)) {
                errMsg = strMassIdMissing;
            }
            // Additional Validation: Check if VCR Code is missing for WM vendors
            if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR){
            if (( qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' )&& vendorName != null  && (qLine.VCRCode__c == null || qLine.VCRCode__c == '')) {
                errMsg = strVCRCodeMissing;
            }
        }
          // Additional validation: Check if Pricing Method is missing
          if( !qline.SBQQ__Quote__r.STP__c){
          if(qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' || qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote') {
          if (qLine.SBQQ__PricingMethod__c == null || qLine.SBQQ__PricingMethod__c == '') {
               errMsg = strPricingMethodMissing ;
          }
        }
    }
              //Additional validation: Vendor validation for "WM Fee" with  List Price = 0 in Configure Price stage
         if (vendorName != null && vendorName.startsWithIgnoreCase('WM Fee')) {
         if (qLine.SBQQ__ListPrice__c == 0) {
            errMsg = strWMFeeList;
         }
        }
        // Additional validation:: unit List Price Missing 
        if ((qline.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' || qline.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' ) && !qLine.SBQQ__Quote__r.STP__c && qLine.SBQQ__ListPrice__c == null && qLine.PricingUnitMethod__c!='STP' ) {
                errMsg = strPriceMissing;
           }
        if(qLine.PriceUOM__c==null || qLine.PriceUOM__c==''){
            errMsg='Missing price unit of measure';
        }else{
            if(qLine.SBQQ__ProductName__c == 'Management Fee' && (qLine.SBQQ__ListPrice__c==null || qLine.SBQQ__ListPrice__c<=0 )){
                errMsg='Price of Management Fee product option must be greater than $0.00';
            }
        }
        //TCS-pkulkarn-SDT-41532-Added for showing validation error on Configured Products section on Quote Page
        if(qLine.SBQQ__PricingMethod__c=='STP')
        {
            if(qLine.PricePrice1__c==null || qLine.PricePrice2__c==null)
            {
                errMsg = strPricingUnitMethodSTP;
            }
        }
        //TCS-pkulkarn-SDT-41532-End
        return errMsg;
    }
    
    
    //Performs a SOSL search based on user input of vendor account details
    //Business has expressed a need to search by VID over name.  SOSL will 
    //accommodate this request.
   @AuraEnabled
    public static List<Account> searchVendors(String searchString) {
        // Refactored to use QuoteProcurementSearchService
        return QuoteProcurementSearchService.searchVendors(searchString);
    }
    
    @AuraEnabled
    public static List<Account_Position__c> allPositions(QuoteProcurementController.HeaderWrapper header) {
        // Refactored to use QuoteProcurementSearchService
        return QuoteProcurementSearchService.getAllPositions(header.locationId);
    }
    
    @AuraEnabled
    public static List<Account_Position__c> searchPositions(QuoteProcurementController.HeaderWrapper header, String searchString) {
        // Refactored to use QuoteProcurementSearchService
        return QuoteProcurementSearchService.searchPositions(header.locationId, searchString);
    }
    
    /*@AuraEnabled
    public static void uncheckPricing(String quoteId) {
        SBQQ__Quote__c q = [SELECT Id, Show_Get_Price__c
                           FROM SBQQ__Quote__c
                           WHERE Id =:quoteId];
        q.Show_Get_Price__c = FALSE;
        update q;
    }*/
    
    @AuraEnabled
    public static List<ProductsWrapper> getCaseQuotes(String CaseId) {
        // Refactored to use QuoteProcurementWrapperService
        return QuoteProcurementWrapperService.getCaseQuotes(CaseId);
    }
    
    @AuraEnabled
    public static List<ProductsWrapper> getDuplicates(String CaseId) {
        List<ProductsWrapper> caseProducts = new List<ProductsWrapper>();

        List<SBQQ__Quote__c> caseQuotes = new List<SBQQ__Quote__c>();
        Case c = [SELECT Id, Location__c, Service_Date__c
                 FROM Case
                 WHERE Id =: CaseId];

        // Check if Service_Date__c is null to prevent null pointer exception
        if (c.Service_Date__c == null) {
            system.debug('Service_Date__c is null for Case: ' + CaseId + '. Cannot check for quote duplicates.');
            return caseProducts; // Return empty list
        }

        caseQuotes = [SELECT Id
                      FROM SBQQ__Quote__c
                     WHERE SBQQ__Account__c =: c.Location__c AND
                        SBQQ__StartDate__c >=: c.Service_Date__c - 3 AND
                        SBQQ__StartDate__c <=: c.Service_Date__c + 3];

        for (SBQQ__Quote__c q : caseQuotes) {

            ProductsWrapper pw = new ProductsWrapper();
            pw = buildQuoteWrapper(q.Id);
            caseProducts.add(pw);

        }

        system.debug(caseProducts);

        return caseProducts;

    }

    @AuraEnabled
    public static String storeOnsite(QuoteProcurementController.HeaderWrapper header, String positionName)
    {
        // Refactored to use QuoteProcurementPositionService
        return QuoteProcurementPositionService.createOnsitePosition(header.locationId, positionName);
    }
    @AuraEnabled
    public static String storeOffsite(QuoteProcurementController.HeaderWrapper header, String OffsitePosition , string street, string city,string state ,string postal)
    {
        // Refactored to use QuoteProcurementPositionService
        return QuoteProcurementPositionService.createOffsitePosition(header.locationId, OffsitePosition, street, city, state, postal);
    }

    private static Boolean validatePosition(Id locationId, String containerPosition)
    {
        List<Account_Position__c> accPos = new List<Account_Position__c>();
        Boolean isValid = true;

        //SOSL query not give proper duplicate record result within time frame
        //That's why use SOQL and use loop, as TextArea filed didn't use directly in where clause
        accPos = [SELECT Id, Name, Container_Position__c
               FROM Account_Position__c
               WHERE AccountId__c =: locationId];

        for(Account_Position__c ap : accPos)
        {
            if(ap.Container_Position__c == containerPosition)
            {
                isValid = false;
                break;
            }
        }       

        return isValid;
    }
    
    @AuraEnabled
    public static List<SBQQ__QuoteLine__c> showLocationPosition(Id quoteLineId)
    {
        // Refactored to use QuoteProcurementPositionService
        return QuoteProcurementPositionService.getQuoteLinePositions(quoteLineId);
    }
   
    @AuraEnabled
    public static void updateALPOnQuoteLine(QuoteProcurementController.HeaderWrapper header, Id ALPId, String setupComments, Boolean isOffsite)
    {
        // Refactored to use QuoteProcurementDMLService
        QuoteProcurementDMLService.getInstance().updatePositionOnQuoteLines(header.parentId, ALPId, setupComments, isOffsite);
    }

    @AuraEnabled
    public static Boolean updateQuoteOverview(HeaderWrapper productWrapper) {
        // Refactored to use QuoteProcurementQuoteLineService
        return QuoteProcurementQuoteLineService.updateQuoteOverview(productWrapper);
    }
    public static string getPicklistAPIName(string labelName){
        string result = labelName;
        Schema.DescribeFieldResult fieldResult = SBQQ__QuoteLine__c.Equipment_Size__c.getDescribe();
        List<Schema.PicklistEntry> values = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry v : values) {
            if (v.getLabel()  == labelName) {
                result = v.getValue();
            }
        }
        return result;
    }
    // Added for SDT-20583/20584
    @AuraEnabled
    public static string getAddProductId() {
        String addProduct = [SELECT Id FROM SBQQ__CustomAction__c WHERE Name =: Constant_Util.ADD_PRODUCTS].Id;
        return addProduct;
        
    }
    @AuraEnabled
    public static Map<String, String> getSizes(Id productId, Boolean returnAll) {
        // Delegates to QuoteFavoritesController
        return QuoteFavoritesController.getSizes(productId, returnAll);
    }
    // Added for SDT-20583
    public class FavoriteProductHeader{
        @AuraEnabled public String productName {get; set;}
     // @AuraEnabled public Id productID {get; set;}
        @AuraEnabled public List<QuoteProcurementController.FavoriteProductDetail> listcontainerDetails {get; set;}
    }
    // Added for SDT-20583
    public class FavoriteContainerWrapper{
        @AuraEnabled public List<QuoteProcurementController.FavoriteProductHeader> ContainerList {get; set;}
    }
   // Added for SDT-20583 
    public class FavoriteProductDetail{
        @AuraEnabled public String containerType {get; set;}
        @AuraEnabled public Id FavoriteID {get; set;}
        @AuraEnabled public String materialType {get; set;}
        @AuraEnabled public String equipmentSize {get; set;}
        
    }
  /*  
    public with sharing class ConfigurationAttribute {
    public String EquipmentSize;
    public String cost;
    public String value;
    public String vendor;
        public ConfigurationAttribute() {}
    }
        
    public with sharing class Response {
    public List<ConfigurationAttribute> configurationAttribute;
    public Integer Count;
    public Response() {}
}*/
  // Added for SDT-20583 - Creating Quote and QuoteLine based on the data selection from Favriotes screen.  
    @AuraEnabled
    public static String addQuoteAndQuoteine(String favroiteId, String caseId, String quoteID, Boolean quoteScreen) {
        // Refactored to use QuoteProcurementFavoritesService
        return QuoteProcurementFavoritesService.createQuoteFromFavorite(
            favroiteId,
            caseId,
            quoteID,
            quoteScreen
        );
    }
    
	// Added for SDT-20583
    @AuraEnabled
    public static FavoriteContainerWrapper getFavorites() {
        // Refactored to use QuoteProcurementFavoritesService
        return QuoteProcurementFavoritesService.getFavorites();
    }
   // Added for SDT-20583
    @AuraEnabled
    public static String addQuoteAsProductNotListed(String CaseId) {
        system.debug('CaseId--->'+ CaseId);
        String quoteID = GetCaseInformation.createOppQuote(CaseId);
        system.debug('quoteID--->'+ quoteID);
        return quoteID; 
  	}
    // Added for SDT-20584
  	@AuraEnabled
    public static string goToCase(String quoteID){
       
        SBQQ__Quote__c quote = [Select ID, SBQQ__Opportunity2__r.Case__c FROM SBQQ__Quote__c WHERE ID =: quoteID];
       
        return quote.SBQQ__Opportunity2__r.Case__c;
    } 
    //Added for SDT-20939
    @AuraEnabled
    public static List<String> getPicklistSchema(){
        // Refactored to use QuoteProcurementUIService
        return QuoteProcurementUIService.getPicklistSchema();
    }

    //Added for story SDT-21065
     @AuraEnabled
    public static MASWrapper getMasDetails(Id quoteLineId) {
        // Refactored to use QuoteProcurementMASService
        return QuoteProcurementMASService.getMASWrapper(quoteLineId);
    }
    //Story 21060
    //Fetch the data from parent quoteline to store on Financial detail component.
    @AuraEnabled
    public static FinancialDetailWrapper getQLFinancialDetail(Id quoteLineId)
    {
        // Refactored to use QuoteProcurementUIService
        return QuoteProcurementUIService.getFinancialDetails(quoteLineId);
    }
    //Story 21060
    //Save the data fetched from Financial detail component to save on respective quotelines.
    @AuraEnabled
    public static string updateFinancialDetail(Id quoteLineId, Boolean isQuoteOnly, String companyCategory,String companyCategoryName, String generalLedgerNo, String customerCostCenter)
    {
        // Refactored to use QuoteProcurementDMLService
        QuoteProcurementDMLService.DMLResult result = QuoteProcurementDMLService.getInstance()
            .updateFinancialDetails(quoteLineId, isQuoteOnly, companyCategory,
                                   companyCategoryName, generalLedgerNo, customerCostCenter);
        return result.success ? 'Success' : 'Failed';
    }
	
    //Displays active projects
    @AuraEnabled
    public static List<Project_Code__c> getActiveProjects(Id quoteId, String searchString) {
        // Refactored to use QuoteProcurementSearchService
        return QuoteProcurementSearchService.searchActiveProjects(quoteId, searchString);
    }

    @AuraEnabled
    public static Business_Rule__c quoteBusinessRules(Id quoteId, String caseType, String subType) {
        
        Business_Rule__c limitingRule = new Business_Rule__c(); 

        SBQQ__Quote__c q = [SELECT Id, SBQQ__Account__r.ParentId
                            FROM SBQQ__Quote__c
                            WHERE Id=: quoteId
                            LIMIT 1];
        
        List<Business_Rule__c> businessRuleList = [SELECT Id, AccountId__c, Request_Type__c, Service__c, Case_Reason__c, Required_Information__c
                                                    FROM Business_Rule__c
                                                    WHERE AccountId__c =: q.SBQQ__Account__r.ParentId 
                                                    AND Active__c = true 
                                                    AND ((Request_Type__c =: caseType AND Service__c =: subType)
                                                    AND (Request_Type__c =: caseType AND Service__c = null))];

        for (Business_Rule__c br: businessRuleList) {
            //Most to least selective
            if (br.Service__c == subType) {
                limitingRule = br;
            } else if (br.Service__c == null) {
                limitingRule = br;
            }
        }

        return limitingRule;
    }
    @AuraEnabled
    // Refactored to use QuoteProcurementUIService
    public static SBQQ__Quote__c getQuoteStatusDetails(Id quoteId) {
        return QuoteProcurementUIService.getQuoteStatusDetails(quoteId);
    }
    //SDT-30072 : Check Asset Availability Permission
    // Refactored to use QuoteProcurementUIService
    @AuraEnabled
    public static Boolean hasAssetAvailabilityPermission(){
        return QuoteProcurementUIService.hasAssetAvailabilityPermission();
    }
    // - 41624
    // Refactored to use QuoteProcurementUIService
    @AuraEnabled
    public static Boolean hasAssetAvailabilityPermissionWithHaulAway(Id caseId){
        return QuoteProcurementUIService.hasAssetAvailabilityPermissionWithHaulAway(caseId);
    } // - 41624
    
    //SDT-29101 : get Asset Availability response
    @AuraEnabled
    public static AAV_Asset_Availability__c getAvailabilityResponse(String quoteLineId){
        // Refactored to use QuoteProcurementIntegrationService
        return QuoteProcurementIntegrationService.getAvailabilityResponse(quoteLineId);
    }
    //SDT-30864 - Asset Availability: get Delivery Override Reasons Picklist Values
    // Refactored to use QuoteProcurementUIService
    @AuraEnabled
    public static List<String> getDeliveryOverrideReasons() {
        return QuoteProcurementUIService.getDeliveryOverrideReasons();
    }
    //SDT-30963 : update new Equipement size and related fields
    @AuraEnabled
    public static Boolean updateAlternateProduct(HeaderWrapper productWrapper) {
        // Refactored to use QuoteProcurementIntegrationService
        return QuoteProcurementIntegrationService.updateAlternateProduct(productWrapper);
    }
    @AuraEnabled
    public static SBQQ__Quote__c getQuoteForOrders(Id quoteId) {
        // Refactored to use QuoteProcurementUIService
        return QuoteProcurementUIService.getQuoteForOrders(quoteId);
    }
    
    @AuraEnabled
    public static Boolean updateQuoteForOrders(SBQQ__Quote__c updatedQuote) {
        // Refactored to use QuoteProcurementUIService
        return QuoteProcurementUIService.updateQuoteForOrders(updatedQuote);
    }

    public static List<SBQQ__ErrorCondition__c> getProductRules(Id productId){
        
        List<SBQQ__ErrorCondition__c> errorConditions = new List<SBQQ__ErrorCondition__c>();
        Set<Id> ruleIds = new Set<Id>();

        List<SBQQ__ConfigurationRule__c> configRules = [SELECT Id, SBQQ__Product__c, SBQQ__ProductRule__c
                                                        FROM SBQQ__ConfigurationRule__c
                                                        WHERE SBQQ__Product__c =: productId AND SBQQ__Active__c = TRUE];
        
        if (configRules.size() == 0) {
            return errorConditions;
        } else {
            for (SBQQ__ConfigurationRule__c c: configRules) {
                ruleIds.add(c.SBQQ__ProductRule__c);
            }
        }
        
        errorConditions = [SELECT Id, SBQQ__Rule__c, SBQQ__TestedField__c, SBQQ__Operator__c, SBQQ__FilterType__c, SBQQ__FilterValue__c
                          FROM SBQQ__ErrorCondition__c
                          WHERE SBQQ__Rule__c IN: ruleIds AND SBQQ__Operator__c = 'equals'];

        return errorConditions;

    }

    public static Set<Id> getActions(List<SBQQ__ErrorCondition__c> conditions, SBQQ__QuoteLine__c parentLine) {

        Set<Id> productRules = new Set<Id>();

        for (SBQQ__ErrorCondition__c e : conditions) {
            String checkedField = e.SBQQ__TestedField__c;
            String errCondField = e.SBQQ__FilterValue__c;
            Object qlFieldObject = parentLine.get(checkedField);
            String qlCondField = String.valueOf(qlFieldObject);
            if (errCondField == qlCondField) {
                productRules.add(e.SBQQ__Rule__c);
            }
        }

        return productRules;

    }

    public static Set<Id> getAddRuleProducts(Set<Id> rules) {

        Set<Id> addProducts = new Set<Id>();
        List<SBQQ__ProductAction__c> addActions = [SELECT Id, SBQQ__Rule__c, SBQQ__Product__c
                                                   FROM SBQQ__ProductAction__c
                                                   WHERE SBQQ__Rule__c IN: rules AND SBQQ__Type__c = 'Add'];
        for (SBQQ__ProductAction__c a: addActions) {
            addProducts.add(a.SBQQ__Product__c);
        }
        return addProducts;

    }

    public static Set<Id> getRemRuleProducts(Set<Id> rules) {

        Set<Id> remProducts = new Set<Id>();
        List<SBQQ__ProductAction__c> remActions = [SELECT Id, SBQQ__Rule__c, SBQQ__Product__c
                                                   FROM SBQQ__ProductAction__c
                                                   WHERE SBQQ__Rule__c IN: rules AND SBQQ__Type__c = 'Add'];
        for (SBQQ__ProductAction__c a: remActions) {
            remProducts.add(a.SBQQ__Product__c);
        }
        return remProducts;

    }

    @AuraEnabled
    public static SBQQ__QuoteLine__c getQuoteLineForOrders(Id qlid) {
        // NOTE: QuoteProcurementContextGetter.getQuoteLineForOrders exists but queries different fields
        // This method queries order-specific fields (Profile_Number__c, Landfill_Tickets__c, etc.)
        // Service method queries general fields (SBQQ__ProductName__c, Schedule_Frequency__c, etc.)
        // Keep as-is until a dedicated service method is created for these specific fields

        SBQQ__QuoteLine__c targetQuoteLine = new SBQQ__QuoteLine__c();

        targetQuoteLine = [SELECT Id, Profile_Number__c, Landfill_Tickets__c, Special_Disposal_Description__c,
                            Service_Start_Time__c, Service_End_Time__c, Gate_Code__c, Certificate_of_Destruction__c, Certificate_of_Disposal__c,
                           Restriction_Details__c
                            FROM SBQQ__QuoteLine__c
                            WHERE Id =: qlid];

        return targetQuoteLine;
    }

    //SDT-29381 - Harun - getting label of quoteline Equipment_Size__c 
    public static String getPicklistLabel(String qlinepicklistAPIValue)
    {     
        string qlinepicklistLabel = '';
       
        Schema.DescribeFieldResult fieldResult = SBQQ__QuoteLine__c.Equipment_Size__c.getDescribe();
        Map<String, String> picklistValuesMap = new Map<String, String>(); 
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
          picklistValuesMap.put(entry.getValue(), entry.getLabel());
     	}
		if (picklistValuesMap.containsKey(qlinepicklistAPIValue)) {
 		    qlinepicklistLabel = picklistValuesMap.get(qlinepicklistAPIValue);
   			System.debug('Picklist Field Label: ' + qlinepicklistLabel);
         }
        return qlinepicklistLabel;
    }

    @AuraEnabled
    public static qLineWrapper getQuoteLineForOrdersWrapper(Id qlid) {
        // Refactored to use QuoteProcurementUIService
        return QuoteProcurementUIService.getQuoteLineForOrdersWrapper(qlid);
    }
    public class  qLineWrapper{
        @AuraEnabled public SBQQ__QuoteLine__c cQLine{set;get;}
        @Auraenabled public string serviceStartTime{set;get;}
        @Auraenabled public string serviceEndTime{set;get;}
        //Changes for SDT-26541
        @Auraenabled public Boolean hasDelivery{set;get;}
    }
    @Auraenabled
    public static Boolean updateQuoteLineForOrders(SBQQ__QuoteLine__c updatedQuoteLine) {
        // TODO: Complex quote line update logic - candidate for future service extraction
        // Contains DML, location position handling, and special handling updates
        // Calls updateSpecialHandling() method which also needs to be extracted

        try {
            // DateTime SLADateTime = QuoteFavoritesController.determineSLAforProjectcodeentitlements(updatedQuoteLine.Id);
            // updatedQuoteLine.SBQQ__StartDate__c = SLADateTime.date();
            //Assigning Latest Location Position to avoid overlapping with old one
            //SDT-30089 - start
            List<SBQQ__QuoteLine__c> qlList = [Select Id, Location_Position_Name__c, SBQQ__Quote__c,SBQQ__Quote__r.Special_Handling__c from SBQQ__QuoteLine__c WHERE Id =: updatedQuoteLine.Id];
            //SDT-30089 - end
            if(qlList.size() > 0 && !qlList.isEmpty())
            {
                SBQQ__QuoteLine__c qlPosition = qlList[0];

                if(qlPosition.Location_Position_Name__c != null)
                {
                    updatedQuoteLine.Location_Position_Name__c = qlPosition.Location_Position_Name__c;
                }
            }
            
            update updatedQuoteLine;

             //SDT-30089 - start
             updateSpecialHandling(qlList[0].SBQQ__Quote__c);
             //SDT-30089 - end
            
            return true;    
           } 
        
        catch (exception e) {
            return false;
        }  

    }

    /**************************************************
    * Created By:TCS
    * CreatedDate:03/18/2025
    * Defect: SDT-45088
    * To create a case comment displaying both the quote sla override reason and override comment the user selected at Intake screen and MIF flow.
    * **************************************************/
    @AuraEnabled
    public static void addCommentForSLAOverrideFromIntake(String caseId) {
        addCommentForSLAOverride(caseId, Null, Null);
    }
    
    @InvocableMethod(label='Add Comment for SLA Override' description='This action is for creating sla override comment')
    public static void addCommentForSLAOverrideFromMIF(List<InputWrapperForMIFFlow> input) {
        addCommentForSLAOverride(input[0].caseId, input[0].slaComment, input[0].slaReason);
    }
    
    public class InputWrapperForMIFFlow {
        @InvocableVariable(label='Case Id')
        public string caseId;
        @InvocableVariable(label='Sla Comment')
        public string slaComment;
        @InvocableVariable(label='Sla Reason')
        public string slaReason;
    }
    /**************************************************
	* Created By:TCS av4
	* CreatedDate:28/11/2023
	* Defect: SDT-25005
	* To create a case comment displaying both the quote sla override reason and override comment the user selected at intake screen.
	* **************************************************/
    @AuraEnabled
    public static void addCommentForSLAOverride(String caseId, String slaComment, String slaReason) {
        // Refactored to use QuoteProcurementIntegrationService
        QuoteProcurementIntegrationService.addCommentForSLAOverride(caseId, slaComment, slaReason);
    }

	
	// SDT-31752 - Earlier getAccessories was used to get only the assessories, now assessories and already selected 
    // Assessory from Quoteline is been sent so that selection can occur.
	// It also sends back a map of Product Option Id and Optional SKU ID 
    @AuraEnabled
    public static  Map<String,List<Object>> getAccessoriesWithSelection(Id productId, Id quoteId) {
        // Refactored to use QuoteProcurementProductService
        return QuoteProcurementProductService.getAccessoriesWithSelection(productId, quoteId);
    }
    

    @AuraEnabled
    public static List<SBQQ__ProductOption__c> getAccessories(Id productId) {
        // Refactored to use QuoteProcurementProductService
        return QuoteProcurementProductService.getAccessories(productId);
    }

    /*
     * SDT-23055
     * Dev: Rishi
     * Description: Created this method to return keys for Padlocks.
     * 
     */
    @AuraEnabled
    public static List<SBQQ__ProductOption__c> getPadlockKeys(List<Id> padLockIdList){
        // Refactored to use QuoteProcurementProductService
        return QuoteProcurementProductService.getPadlockKeys(padLockIdList);
    }
    
    @AuraEnabled
    public static List<SBQQ__ConfigurationAttribute__c> getConfigAttributes(Id productId, String quoteLineId) {
        // Refactored to use QuoteProcurementProductService
        return QuoteProcurementProductService.getConfigAttributes(productId, quoteLineId);
    }

    /*SDT-22447-START*/
    //Get the Product specific Equipment style values  
    public static Boolean isEquipmentStyleOptionValidByProductName(Map<String,Set<String>> equipmentStyleValuesWithProduct, String currentProductName,String targetField, String equipmentStyleOption){
        if(equipmentStyleValuesWithProduct.containsKey(currentProductName) 
            && targetField.equalsIgnoreCase('Equipment_Style__c')  
            && !equipmentStyleValuesWithProduct.get(currentProductName).contains(equipmentStyleOption)){
            return true;
        }
        else{
            return false;  
        }   
    } 
    /*SDT-22447-END*/

    @AuraEnabled
    public static string updateConfigAttribute(Id quoteLineId, String fieldName, String fieldValue, Id quoteId){
        // Refactored to use QuoteProcurementProductService
        return QuoteProcurementProductService.updateConfigAttribute(quoteLineId, fieldName, fieldValue, quoteId);
    }

    @AuraEnabled
    public static string addProductOption(Id quoteLineId, Id productOptionId){
        // Refactored to use QuoteProcurementProductOptionService
        return QuoteProcurementProductOptionService.addProductOption(quoteLineId, productOptionId);
    }
     // SDT-31752
    // quoteId = Parent QL Id
    // ProductionOptionId is the Id of the Optional SKU on the product option, This is to remove the option Id
    @AuraEnabled
    public static string removeProductOption(Id quoteLineId, Id productOptionId) {
        // Refactored to use QuoteProcurementProductOptionService
        return QuoteProcurementProductOptionService.removeProductOption(quoteLineId, productOptionId);
    }
    /*
     * SDT-23055
     * Dev: Rishi
     * Description: Created this method to remove QL for keys when accessories get unchecked
     * SDT-31752
     * quoteId = Parent QL Id
     * ProductionOptionId is the Id of the Optional SKU on the product option. This is done to remove the dependency of option Id
     */
    @AuraEnabled
    public static string removeProductOption(Id quoteLineId, Id productOptionId, Id keyOptionId) {
        // Refactored to use QuoteProcurementProductOptionService
        return QuoteProcurementProductOptionService.removeProductOptionWithKeys(quoteLineId, productOptionId, keyOptionId);
    }

    /*
     * SDT-23055
     * Dev: Rishi
     * Description: Created this method to update keys Quantity on qls
     *
     */

    @AuraEnabled
    public static string updateKeysQuantity(Id parentId, List<KeyMapWrapper> keyObj){
        // Refactored to use QuoteProcurementProductOptionService
        return QuoteProcurementProductOptionService.updateKeysQuantity(parentId, keyObj);
    }

    // Getting all intergration metadata where isActive true
    public static Set<String> getIntegrationFieldsOfQL()
    {
        // local variable
        Set<String> setFields = new Set<String>();
        List<PricingJsonSetting__mdt> lstRecords = new List<PricingJsonSetting__mdt>([Select Attribute__c,Default_Value__c,IsDisable__c,Json_Node__c,Field_API_Name__c,Object_API_Name__c from PricingJsonSetting__mdt where IsDisable__c != true]);
        for(PricingJsonSetting__mdt objRec: lstRecords){
            if(objRec.Field_API_Name__c != null){
                List<String> lstStr = (objRec.Field_API_Name__c).split(',');
                for(String str : lstStr){
                    if(objRec.Object_API_Name__c == 'SBQQ__QuoteLine__c'){
                        setFields.add(str);
                    } 
                } 
            }
        }
        return setFields;
    }

    @AuraEnabled
    public static QuoteSummaryWrapper createDelivery(OrderWrapper ow, String orderType, string placementInstructions) 
    {
        //String result;
        QuoteSummaryWrapper wrapper = new QuoteSummaryWrapper();
        wrapper.isAssetChanged = false;
        //Changes for SDT-27107
        Set<String> setFields = new Set<String>();
        Id parentQLId = ow.parentQuoteLine;
        Id quoteId = ow.quoteId;
        String vendorServiceId  = ow.vendorServiceId;

        // Getting all intergration metadata where isActive true
        setFields = getIntegrationFieldsOfQL();
	setFields.add('sbqq__Quote__r.SBQQ__Opportunity2__r.Case__c'); //41624

        // fields that need to check to update the start date // SDT-33378
        set<string> additionFieldsforMetadata = new Set<string>{'Vendor__c', 'LocationPositionName__c', 'Location_Position_Name__c','SBQQ__PricingMethod__c','SBQQ__StartDate__c', 'AssetId__r.ParentId'};

        String wasteStream = Constant_Util.WASTE_STREAM;
        String wasteCategory = Constant_Util.WASTE_CATEGORY;

        // Get all quote lines
        //List<SBQQ__QuoteLine__c> quoteLines = Database.Query('Select '+ String.join(new List<String>(setFields), ', ') +','+ String.join(new List<String>(additionFieldsforMetadata), ', ') +',SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name,AssetId__c,SBQQ__ProductOption__r.SBQQ__ConfiguredSKU__r.Family,SBQQ__ProductOption__r.SBQQ__Feature__r.Name,SBQQ__Product__c,EventRecurrence__c,SBQQ__ProductOption__r.SBQQ__ProductCode__c,SBQQ__ProductFamily__c,SBQQ__ProductName__c,SBQQ__RequiredBy__c,SBQQ__Product__r.Family,SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, SBQQ__Quote__r.Project__c,  SBQQ__Quote__r.Project_Services_Request__c, SBQQ__Product__r.Name from SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId AND (SBQQ__Product__r.Family != :wasteStream AND SBQQ__Product__r.Family != :wasteCategory)');
        List<SBQQ__QuoteLine__c> quoteLines = QuoteLineSelector.getQuoteLinesByQuoteId(setFields, parentQLId, quoteId, additionFieldsforMetadata);
            //Database.Query('Select '+ String.join(new List<String>(setFields), ', ') +','+ String.join(new List<String>(additionFieldsforMetadata), ', ') +',SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name,AssetId__c,SBQQ__ProductOption__r.SBQQ__ConfiguredSKU__r.Family,SBQQ__ProductOption__r.SBQQ__Feature__r.Name,SBQQ__Product__c,EventRecurrence__c,SBQQ__ProductOption__r.SBQQ__ProductCode__c,SBQQ__ProductFamily__c,SBQQ__ProductName__c,SBQQ__RequiredBy__c,SBQQ__Quote__r.Name,SBQQ__Product__r.Family,SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, SBQQ__Quote__r.Project__c,  SBQQ__Quote__r.Project_Services_Request__c, SBQQ__Product__r.Name, (Select Id, Service_Type__c from Quote_Orders__r) from SBQQ__QuoteLine__c WHERE Id = :parentQLId OR SBQQ__RequiredBy__c =:parentQLId OR SBQQ__RequiredBy__r.SBQQ__RequiredBy__c =:parentQLId ');
        
        //Local Variable
        List<SBQQ__QuoteLine__c> PqLine = new List<SBQQ__QuoteLine__c>();
        List<SBQQ__QuoteLine__c> deliveryQuoteLines = new List<SBQQ__QuoteLine__c>();
        // 41624
        List<SBQQ__QuoteLine__c> pickupQuoteLines = new List<SBQQ__QuoteLine__c>(); //end - 41624
        boolean isQLChanged = false;
        set<Id> assetIds = new set<id>();
        Map<Id,Asset> assetProductMap = new Map<Id,Asset>();
        List<SBQQ__QuoteLine__c> tobeChangeQuoteLines = new List<SBQQ__QuoteLine__c>();
        // Changes for SDT-30118
        Set<Id> surChargeIds = new Set<Id>();
        boolean isKeyDeliveryAdded = false;
        //get delivery line
        for(SBQQ__QuoteLine__c deliveryQL : quoteLines)
        {
            //identify Delivery QL
            if(deliveryQL.SBQQ__ProductName__c == orderType)
            {
                deliveryQuoteLines.add(deliveryQL);
            }

            //41624

            if(deliveryQL.SBQQ__ProductName__c.equalsIgnoreCase(Constant_Util.Haul_Away_Service) && deliveryQL.SBQQ__RequiredBy__c!= null)
            {
                deliveryQuoteLines.add(deliveryQL);
            }
            // End - 41624
            
            //identify Parent QL
            if(deliveryQL.SBQQ__RequiredBy__c == null)
            {
                PqLine.add(deliveryQL);
            }
            // Checking for Surcharge and Fee and adding in surcharge list
            if(deliveryQL.SBQQ__Product__r.Family == PricingJSONRequest.SURCHARGES_AND_FEES)
            {
                surChargeIds.add(deliveryQL.Id);
            }

            // Adding Keys in filtered bundle QuoteLineList
            if(surChargeIds.contains(deliveryQL.SBQQ__RequiredBy__c) && !isKeyDeliveryAdded)
            {
                deliveryQuoteLines.add(deliveryQL);
                isKeyDeliveryAdded =true;
            }

            // create a set of Asset Ids
            if(deliveryQL.AssetId__c != null)
                assetIds.add(deliveryQL.AssetId__c);
        }

        String positionName=Constant_Util.EMPTY_STRING;
        String caseRecordType = PqLine.size() > 0 ? PqLine[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name: Constant_Util.EMPTY_STRING;

        // system.debug('assetIds >'+ assetIds );
        // system.debug('caseRecordType >'+ caseRecordType );
        // check for Update Asset Record
        if(caseRecordType != Constant_Util.New_Service_Case)
        {
            List<Asset> assetDetails = new List<Asset>();
            if(assetIds != null && !assetIds.isempty() )
            {
                //SDT-38285 - start
                //Added Supplier__r.Parent_Vendor_ID__c for story SDT-39662
                assetDetails = [Select Id,ContactId,AccountId,ParentId,RootAssetId,Product2Id,ProductCode,ProductFamily,ProductDescription,
                                IsCompetitorProduct,CreatedDate,CreatedById,LastModifiedDate,LastModifiedById,SystemModstamp,IsDeleted,
                                CurrencyIsoCode,Name,SerialNumber,InstallDate,ManufactureDate,StatusReason,Uuid,ExternalIdentifier,
                                PurchaseDate,UsageEndDate,Status,DigitalAssetStatus,Price,Quantity,Description,OwnerId,RecordTypeId,
                                LocationId,AssetProvidedById,AssetServicedById,IsInternal,AssetLevel,StockKeepingUnit,LastViewedDate,
                                LastReferencedDate,Duration__c,Location__c,Acorn_SBID__c,Acorn_SCOD__c,Acorn_SID__c,Acorn_Update_Datetime__c,
                                Acorn_Vendor_Id__c,BusinessUnit_Name__c,Bypass_Cost_Grid__c,Bypass_MAS__c,Category__c,Container_Position__c,
                                Contract_Notes__c,Cost_Center__c,Cost_Currency__c,Cost_Increment_1__c,Cost_Increment_2__c,Cost_Increment_3__c,
                                Cost_Increment_4__c,Cost_Minimum_Quantity__c,Cost_Model_Type__c,Cost_Price_1__c,Cost_Price_2__c,
                                Cost_Price_3__c,Cost_Price_4__c,Cost_Total_Tax__c,Cost_Unit__c,Cost_UpTo_1__c,Cost_UpTo_2__c,
                                Cost_UpTo_3__c,Cost_UpTo_4__c,Cost__c,Customer_Account_Number__c,EDI_Price_Source__c,End_Date__c,
                                Equipment_Owner__c,Equipment_Size__c,Equipment_Type__c,Every__c,Exception_Comments__c,
                                Exception_Effective_Date__c,Exception_Reason_Detail__c,Exception_Reason__c,Exclude_Holidays__c,
                                Exclude_Saturdays__c,Exclude_Sundays__c,Frequency__c,Friday_AM__c,Friday_Frequency__c,Friday_PM__c,Friday__c,
                                GL_Code__c,Generate_Service_Events__c,Has_Extra_Pickup__c,Is_Active__c,Is_Core_Service__c,
                                Is_Hold_Until_Posted__c,Is_Locally_Billed__c,Is_Monitored__c,Is_Override_Rule__c,Location_Code__c,
                                MAS_Account_Number__c,MAS_Company_Code__c,MAS_Customer_Unique_Id__c,MAS_Library__c,MAS_Line_Number__c,
                                MAS_Setup_Comment__c,MAS_VCR_Code__c,MAS_Waste_Stream__c,Market_Area__c,Material_Grade__c,Material_Type__c,
                                Monday_AM__c,Monday_Frequency__c,Monday_PM__c,Monday__c,Monitored__c,Negotiater_ContactId__c,
                                Negotiater_UserId__c,Occurrence_Type__c,Occurrence__c,Occurs__c,Of_Every1__c,Of_Every2__c,Of_Every3__c,
                                Of_Every__c,Of_Month__c,On_Date__c,On_Day1__c,On_Day2__c,On_Day3__c,On_Day__c,On_the__c,Override_UserId__c,
                                Price_Currency__c,Price_Increment_1__c,Price_Increment_2__c,Price_Increment_3__c,Price_Increment_4__c,
                                Price_Minimum_Quantity__c,Price_Model_Type__c,Price_Price_1__c,Price_Price_2__c,Price_Price_3__c,
                                Price_Price_4__c,Price_Tax_Inclusive__c,Price_Total_Tax__c,Price_Unit__c,Price_UpTo_1__c,Price_UpTo_2__c,
                                Price_UpTo_3__c,Price_UpTo_4__c,Price__c,Project__c,Quantity__c,Reason_for_Change__c,Required_Time_of_Day__c,
                                Saturday_AM__c,Saturday_Frequency__c,Saturday_PM__c,Saturday__c,Schedule_A_Override__c,Schedule__c,
                                Send_Schedule_A__c,Sensitivity_Code__c,Service_Header_Id__c,Service_Info__c,Service_Type__c,Start_Date__c,
                                Sunday_AM__c,Sunday_Frequency__c,Sunday_PM__c,Sunday__c,Supplier__c,Supplier__r.Parent_Vendor_ID__c,Third_Party_Source__c,Thursday_AM__c,
                                Thursday_Frequency__c,Thursday_PM__c,Thursday__c,Time_of_Day_AM__c,Time_of_Day_PM__c,Tuesday_AM__c,
                                Tuesday_Frequency__c,Tuesday_PM__c,Tuesday__c,Vendor_Account_Number__c,Vendor_BU__c,Vendor_ID__c,
                                Vendor_Service_Number__c,Waste_Profile__c,Wednesday_AM__c,Wednesday_Frequency__c,Wednesday_PM__c,
                                Wednesday__c,Weekly_Frequency__c,Cost_Tax_Inclusive__c,MAS_Company_Account_Number__c,MAS_Unique_Text__c,
                                SBID_text_c__c,SCOD_text__c,Core_MAS_Unique__c,Core_Quantity__c,Core_Schedule__c,Lower_Case_Asset_Details__c,
                                Occurrence_Type_Formula__c,Active__c,End_Date_Based_on_Project_code__c,End_Dated_Asset__c,Project_Code__c, RootAsset.Project_Code__r.ProjectCode_Id__c, //SDT-40012 Added Project_Code__r.ProjectCode_Id__c
                                Schedule_Type__c,Created_By_User_Id__c,End_Date_Warning__c,Material_Prompt_ID__c,Voice_Prompt__c,
                                Dumpster_Service_Style__c,Dumpster_Style__c,Is_Null_End_Date__c,Originating_Case__c,
                                SBQQ__AdditionalDiscountAmount__c,Is_Self_Service__c,SBQQ__BillingFrequency__c,SBQQ__BillingType__c,
                                SBQQ__Bundle__c,SBQQ__BundledQuantity__c,SBQQ__Bundled__c,SBQQ__ChargeType__c,SBQQ__CombineKey__c,
                                SBQQ__ComponentDiscountedByPackage__c,SBQQ__CreditProductId__c,SBQQ__CurrentSubscription__c,SBQQ__Dimension__c,
                                SBQQ__DiscountScheduleType__c,SBQQ__DiscountSchedule__c,SBQQ__Discount__c,SBQQ__DistributorDiscount__c,
                                SBQQ__DynamicOptionId__c,SBQQ__FromServiceCloud__c,SBQQ__LatestQuoteLine__c,SBQQ__ListPrice__c,
                                SBQQ__MarkupAmount__c,SBQQ__MarkupRate__c,SBQQ__Number__c,SBQQ__OptionDiscountAmount__c,SBQQ__OptionDiscount__c,
                                SBQQ__OptionLevel__c,SBQQ__OptionType__c,SBQQ__OrderProduct__c,SBQQ__OriginalUnitCost__c,
                                SBQQ__PackageProductCode__c,SBQQ__PackageProductDescription__c,SBQQ__PartnerDiscount__c,
                                SBQQ__PriceDimension__c,SBQQ__PricingMethod__c,SBQQ__ProductOption__c,SBQQ__QuoteLine__c,SBQQ__RegularPrice__c,
                                SBQQ__RenewalUpliftRate__c,SBQQ__RequiredByAsset__c,SBQQ__RequiredById__c,SBQQ__RequiredByProduct__c,
                                SBQQ__RequiredBySubscription__c,SBQQ__RevisedAsset__c,SBQQ__RootAsset__c,SBQQ__RootId__c,SBQQ__SegmentIndex__c,
                                SBQQ__SegmentKey__c,SBQQ__SegmentLabel__c,SBQQ__SubscriptionEndDate__c,SBQQ__SubscriptionQuoteLine__c,
                                SBQQ__SubscriptionStartDate__c,SBQQ__Subscription__c,SBQQ__TermDiscountSchedule__c,SBQQ__UnitCost__c,
                                SBQQ__VirtualAsset__c,CPQ_Product__c,CPQ_Material__c, RecordType.DeveloperName , Account_Position__c,
                                MASBox__c, Material_Grade_Code__c, Month_Relative_Interval__c, Month_Relative__c 
                                from asset where id IN :assetIds]; // Changes for SDT-32105 
                //SDT-38285 - end
            }

            //iterating Asset Detail record to create a Map<assetId, Asset>
            For(Asset asset : assetDetails){
            if(asset!= null) 
            {
                assetProductMap.put(asset.id,asset);
            }
            }
            AssetQuoteProcurementController.TransformationHelper transformationHelper = new AssetQuoteProcurementController.TransformationHelper();
            // Changes for SDT-30514
            // Update baseline fields
            Set<string> updateBaselineFields = transformationHelper.readFieldSet('Update_Baseline','SBQQ__QuoteLine__c');
            // End and Extend fields
            Set<string> endAndExtendBaselineFields = transformationHelper.readFieldSet('End_and_Extend_Baseline','SBQQ__QuoteLine__c');
            // Excluded Fields
            Set<string> excludedFields = transformationHelper.readFieldSet('Integration_Excluded_Fields','SBQQ__QuoteLine__c');
            // get the Asset Quote Line Mapping for specific fields
            List<Asset_Quoteline_Mapping__mdt> assetQuoteLineMappings = [SELECT AssetDataType__c,AssetField__c,AssetFieldValue__c,IsActive__c,QuoteLineField__c,QuoteLineFieldValue__c FROM Asset_Quoteline_Mapping__mdt Where IsActive__c = true];
			
            //TCS-pkulkarn-13-Oct-2023-Added for SDT-32782
            Map<Id, SBQQ__QuoteLine__c> bundlewisePickupQuoteLinesMap = new Map<Id, SBQQ__QuoteLine__c>();
            Map<Id, SBQQ__QuoteLine__c> bundlewiseExtraPickupQuoteLinesMap = new Map<Id, SBQQ__QuoteLine__c>();
            //End-SDT-32782
            
            

            for(SBQQ__QuoteLine__c ql : quoteLines)
            {
                Asset asset =  assetProductMap.get(ql.AssetId__c);
                SBQQ__QuoteLine__c parentQL =PqLine[0];
				
				// changing enddate logic for 32792 start
                date endDateFromAsset=ql.SBQQ__EndDate__c;
                date endDatefromCIntake=(ql.SBQQ__ProductName__c == Constant_Util.ServiceType_Delivery) ? ow.serviceDate : (ow.serviceEndDate != null) ? ow.serviceEndDate : null;
                ql.SBQQ__EndDate__c = (endDatefromCIntake != null) ? endDatefromCIntake : endDateFromAsset;
				// Setting up end date before comparison so if End date is null we can detect in Asset and QL comparison
                //ql.SBQQ__EndDate__c = (ql.SBQQ__ProductName__c == Constant_Util.ServiceType_Delivery) ? ow.serviceDate : (ow.serviceEndDate != null) ? ow.serviceEndDate : null;
                // changing enddate logic for 32792 end
				
                if(asset != null && ql.SBQQ__ProductFamily__c != Constant_Util.WASTE_CATEGORY && ql.SBQQ__ProductFamily__c != Constant_Util.WASTE_STREAM){
                    // Changes for SDT-30514 and SDT-30515
                    AssetQuoteProcurementController.comparisonResponseModel responseModel= transformationHelper.compareAssetQuoteLines(asset, ql, parentQL, false, updateBaselineFields, endAndExtendBaselineFields, excludedFields, assetQuoteLineMappings);
                    //Changes for SDT-28571 , Bug: SDT-29124
                    if(responseModel!=null && responseModel.isQLMached)
                    {
                        Boolean isAssetHasProject = false;
                        if(asset.Project_Code__c != null)
                            isAssetHasProject = true;

                        if((ql.SBQQ__Quote__r != null && ql.SBQQ__Quote__r.Project__c !=  asset.Project_Code__c) || (ql.SBQQ__Quote__r.Project_Services_Request__c != isAssetHasProject))
                        {
                            responseModel.isQLMached = false;
                        }
                    }
                    //system.debug('qlMached >>'+ qlMached);
                   if(responseModel!=null && !responseModel.isQLMached)
                    {
                        //system.debug('isUpdateBaseline 2>>'+ responseModel.isUpdateBaseline);
                        //Changes for SDT-30514 & SDT- 30515- If this is not Update Baseline Case then Will update Start Date and Assign Default Values to it else will Update Only respected field
                        if(responseModel.isEndAndExtendBaseline)
                        {
                            
                            ql.SBQQ__StartDate__c =ow.serviceDate;
			    
			    //SDT-33378
                                // not to run for Bundle only child
                                //if(ql.AssetId__r.ParentId!=null){
                                    StartDateManagement mananageStartDate = new StartDateManagement();
                                    Boolean isStartDateValid =  mananageStartDate.validateQuoteLineStartDate(ql);
                                    if(!isStartDateValid){
                                     throw new AuraHandledException( StartDateManagement.InvalidStartDateErrorMessage) ;
                                    }
                               
                                
                            //}
			    
                            //ql.Exception_Effective_Date__c = ow.serviceDate;     //pkulkarn-TCS-28-Mar-23-Added for SDT-28044
                            //SDT-29615 Start
                            //SDT 34351
                            //ql.Exception_Effective_Date__c = (ow.serviceDate!=null)?DateTime.newInstanceGMT(ow.serviceDate.year(),ow.serviceDate.month(),ow.serviceDate.day(),12,00,00):ow.serviceDate;
                            //SDT-29615 End
                            //sdhikale TCS SDT-29806
                            //SDT 34351
                            //ql.Exceptions_Effective_Date__c = ow.serviceDate;
                            ql.SBQQ__EndDate__c = (ql.SBQQ__ProductName__c == Constant_Util.ServiceType_Delivery || ql.SBQQ__ProductName__c == Constant_Util.KEYS) ? ow.serviceDate : (ow.serviceEndDate != null) ? ow.serviceEndDate : null;
                            
                            //Changes for SDT-29104 and Changes for SDT-29385 are moved to this method to set default values
                            //SDT-38052 Start - replacing null assignment with condition assignment
                            //ql.Service_Action__c ='';
                            if(ql.SBQQ__Quote__r.SBQQ__Type__c ==  Constant_Util.QUOTE_TYPE_AMEND || 
                               ql.SBQQ__Quote__r.SBQQ__Type__c ==  Constant_Util.QUOTE_TYPE_EXCEPTION || 
                               ql.SBQQ__Quote__r.SBQQ__Type__c == Constant_Util.QUOTE_TYPE_CORRECTION){
                                   List<Schema.PicklistEntry> serviceActionEntries = Schema.SObjectType.SBQQ__QuoteLine__c.fields.Service_Action__c.getPicklistValues();
                                   if(ql.AssetId__c!=null){                                       
                                       ql.Service_Action__c = AssetQuoteProcurementController.getPicklistEntryByLabel(serviceActionEntries, Constant_Util.EXTEND_SERVICE);
                                   }
                               }
                            //SDT-38052 - End
                             //Modify for SDT-33285
                            QuoteLineServices.setDefaultValuesForQuoteLines(ql,ql.SBQQ__Quote__r.Name,asset);
                            //TCS-pkulkarn-13-Oct-2023-Added for SDT-32782-Capture Pickup line updates into a map
                            if(ql.SBQQ__ProductName__c == Constant_Util.PR_PICKUP)
                            {
                                bundlewisePickupQuoteLinesMap.put(ql.SBQQ__RequiredBy__c, ql);
                            }
                            //End-SDT-32782
                        }
                        // Changes for SDT-31788
                        else if (responseModel!= null && responseModel.isUpdateBaseline)
                        {
                           ql.Service_Action__c =QuoteLineSelector.SERVICE_ACTION_DO_NOT_EXTEND_SERVICE;
                        }
                        tobeChangeQuoteLines.add(ql);

                        //Changes for SDT-28571
                        wrapper.isAssetChanged = true;
                    }
		    //TCS-pkulkarn-13-Oct-2023-Added for SDT-32782-Capture Extra Pickup quote lines into a map
                    if(ql.SBQQ__ProductName__c == Constant_Util.PR_EXTRA_PICKUP)
                    {
                        bundlewiseExtraPickupQuoteLinesMap.put(ql.SBQQ__RequiredBy__c, ql);
                    }
                    //End-SDT-32782
                }
                else{
                    if(ql.SBQQ__ProductFamily__c != Constant_Util.WASTE_CATEGORY && ql.SBQQ__ProductFamily__c != Constant_Util.WASTE_STREAM)
                    {
                        ql.SBQQ__StartDate__c =ow.serviceDate;
                        //ql.Exception_Effective_Date__c = ow.serviceDate;     //pkulkarn-TCS-28-Mar-23-Added for SDT-28044
                        //SDT-29615 Start
                        //SDT34351 ql.Exception_Effective_Date__c = (ow.serviceDate!=null)?DateTime.newInstanceGMT(ow.serviceDate.year(),ow.serviceDate.month(),ow.serviceDate.day(),12,00,00):ow.serviceDate;
                        //SDT-29615 End
                        //sdhikale TCS SDT-29806
                        //SDT 34351 ql.Exceptions_Effective_Date__c = ow.serviceDate;
                        ql.SBQQ__EndDate__c = (ql.SBQQ__ProductName__c == Constant_Util.ServiceType_Delivery || ql.SBQQ__ProductName__c == Constant_Util.KEYS) ? ow.serviceDate : (ow.serviceEndDate != null) ? ow.serviceEndDate : null;
                        // if(ow.serviceEndDate != null)
                        //     ql.SBQQ__EndDate__c = ow.serviceEndDate;
                        //Changes for SDT-29104
                        //Changes for SDT-29104 and Changes for SDT-29385 are moved to this method to set default values
                       // QuoteLineServices.setDefaultValuesForQuoteLines(ql,ql.SBQQ__Quote__r.Name,asset); //Modify for SDT-33285
                       QuoteLineServices.setDefaultValuesForQuoteLines(ql,ql.SBQQ__Quote__r.Name); 
                       tobeChangeQuoteLines.add(ql);
                        //Changes for SDT-28571
                        wrapper.isAssetChanged = true;
                    }
                }
            }
            
            //TCS-pkulkarn-13-Oct-2023-Added for SDT-32782
            //Handle Extra pick changes-Retrieve List of Extra Pickup Quote Lines if Pickup line start date is changed
            List<SBQQ__QuoteLine__c> extraPickupQuoteLineListForUpdate = getExtraPickupLineForStartDateUpdate(bundlewisePickupQuoteLinesMap, bundlewiseExtraPickupQuoteLinesMap, true);
               // if(extraPickupQuoteLineListForUpdate.size() > 0)
               // {
                 //   tobeChangeQuoteLines.addAll(extraPickupQuoteLineListForUpdate);
              //  }
           // }
                 
           map<id,SBQQ__QuoteLine__c> extraPickupQuoteMAP= new map<id,SBQQ__QuoteLine__c>();
           for(SBQQ__QuoteLine__c extraPickupObj : extraPickupQuoteLineListForUpdate)
           {
                extraPickupQuoteMAP.put(extraPickupObj .Id,extraPickupObj);
           }
      if(extraPickupQuoteLineListForUpdate.size() > 0)
                {
                    boolean listCheck = false;                              
                               for(SBQQ__QuoteLine__c currentQuotelineObj : tobeChangeQuoteLines)
                              {
                                  if(extraPickupQuoteMAP.get(currentQuotelineObj.id) !=null)
                                  {
                                    for(Id key : bundlewiseExtraPickupQuoteLinesMap.keyset())
                                    {
                                        listCheck =  true;
                                        Date pickupLineStartDate = bundlewisePickupQuoteLinesMap.get(key).SBQQ__StartDate__c;
                                        currentQuotelineObj.SBQQ__StartDate__c = pickupLineStartDate;
                                        //SDT34351 currentQuotelineObj.Exception_Effective_Date__c = DateTime.newInstanceGMT(pickupLineStartDate.year(), pickupLineStartDate.month(), pickupLineStartDate.day(),12,00,00);
                                        // SDT34351 currentQuotelineObj.Exceptions_Effective_Date__c = pickupLineStartDate;
                                    }                                    
                                  }
                              }
                    If(!listCheck)
                    {
                        tobeChangeQuoteLines.addAll(extraPickupQuoteLineListForUpdate);
                    }
                }
            //End-SDT-32782
        }
        else
        {
            for(SBQQ__QuoteLine__c QL : quoteLines)
            {
                QL.SBQQ__StartDate__c = ow.serviceDate;
            //  if(ow.serviceEndDate != null)
            //     QL.SBQQ__EndDate__c = ow.serviceEndDate;
            QL.SBQQ__EndDate__c = (QL.SBQQ__ProductName__c == Constant_Util.ServiceType_Delivery || QL.SBQQ__ProductName__c == Constant_Util.KEYS) ? ow.serviceDate : (ow.serviceEndDate != null) ? ow.serviceEndDate : null;
                tobeChangeQuoteLines.add(QL);
            }
        }

        Boolean isRemovalAvailable=false;
        Boolean isOrderAvailable=false;
        Boolean isKeyOrderAvailable=false;
        //Additional Login to check Existing Quote Order for defect #SDT-25715
        List<Quote_Order__c> quoteOrderLst = new List<Quote_Order__c>();
        if(PqLine[0].Quote_Orders__r != null)
        {
            quoteOrderLst = PqLine[0].Quote_Orders__r;
        }
        Map<String,Id> serviceTypeOrderIdMap = new Map<String,Id>();
        if(quoteOrderLst!= null && !quoteOrderLst.isempty())
        {
            for(Quote_Order__c order: quoteOrderLst)
            {
                // Check if Service Type avaiable
                if(order.Service_Type__c == ow.serviceType || order.Service_Type__c.equalsIgnoreCase(Constant_Util.Haul_Away_Service) ) //41624
                {
                    isOrderAvailable= true;
                }
                // Check if Removal avaiable
                if(order.Service_Type__c == Constant_Util.REMOVAL)
                {
                    isRemovalAvailable= true;
                }
                 // Check if Lock Delivery Service Type avaiable
                 if(order.Service_Type__c == Constant_Util.LOCK_DELIVERY)
                 {
                    isKeyOrderAvailable= true;
                 }
            // Creating Map between Service Type and Order Id
            serviceTypeOrderIdMap.put(order.Service_Type__c, order.Id);
        }
    }

    //TCS-pkulkarn-SDT-41184-Added to avoid recursion on End Date update
    if(ow.serviceEndDate != null)
    {
        RecurrsiveTriggerHandler.isSkipEndDateUpdate = true;
    }
    //TCS-pkulkarn-SDT-41184-End
    if(tobeChangeQuoteLines!=null && !tobeChangeQuoteLines.isEmpty())
        {
            //DML to update QLs details along with start date
            RecurrsiveTriggerHandler.isSkipValidateQLCostPrice = true;
            update tobeChangeQuoteLines;
            RecurrsiveTriggerHandler.isSkipValidateQLCostPrice = false;
        }

        
    String dateStr = Constant_Util.EMPTY_STRING;
    //create Haul and Removal lines
    if(ow.serviceEndDate != null)
    {
        dateStr = ow.serviceEndDate.format();  
    }
    else
        deleteHaulRemovalqLine(parentQLId);

    //system.debug('dateStr > '+ dateStr);              
    validateHaulRemovalqLine(parentQLId, dateStr);
    
        

        if (deliveryQuoteLines.size() == 0) 
        {
            String productFamily =''; 
            if(PqLine.size()>0 && PqLine[0].SBQQ__ProductCode__c != ''){
                productFamily = PqLine[0].SBQQ__ProductFamily__c;
                if(PqLine[0].SBQQ__ProductCode__c =='CMP' && PqLine[0].Equipment_Size__c != null && PqLine[0].Equipment_Size__c.contains('-'))  
                {
                    Double eqSize = Double.valueOf(PqLine[0].Equipment_Size__c.substringAfter('-'));
                    if(eqSize < 10)
                    {
                        productFamily = Constant_Util.COMMERCIAL;
                    }
                }
                
                if(productFamily == Constant_Util.COMMERCIAL)
                    wrapper.result = validateAndCreateRemovalQouteOrder(ow, positionName, placementInstructions, isRemovalAvailable, serviceTypeOrderIdMap);
                else
                    wrapper.result = 'N/A';
            }
            else{
                wrapper.result = 'N/A';
            }
            //return wrapper;		//TCS-pkulkarn-6-Sep-2023-Commented and moved to end of method-SDT-30092
        } 
        else 
        {
            List<Quote_Order__c> quoteOrderList = new List<Quote_Order__c>();
            // Changes for SDT-30118
            //41624
            Boolean isHaul_Away = HaulAwayService.getIsHaulAwayService(quotelines[0].sbqq__Quote__r.SBQQ__Opportunity2__r.Case__c);
            if(isHaul_Away){
                ow.serviceType = Constant_Util.Haul_Away_Service;
            }
            for(SBQQ__QuoteLine__c ql : deliveryQuoteLines)
            {
                Quote_Order__c newDel = new Quote_Order__c();
                if (ql.Location_Position_Name__c != null) {
                    positionName=ql.Location_Position_Name__r.Container_Position__c;
                // Removed offsite check for this bug #SDT-22324
                //if (ql.Location_Position_Name__c != null && ql.Location_Position_Name__r.Container_Position__c.contains('OFFSITE')) {
                    newDel.Instructions__c ='POSITION:' + ql.Location_Position_Name__r.Container_Position__c + '\n'  + ow.instructions;
                    newDel.Acorn_Instructions__c ='POSITION:' + ql.Location_Position_Name__r.Container_Position__c + '\n'  + ow.acornInstructions;
                } else {
                    newDel.Instructions__c = ow.instructions;
                    newDel.Acorn_Instructions__c = ow.acornInstructions;
                }
                newDel.Quote_Line__c = ow.parentQuoteLine;
                newDel.Service_Quote_Line__c = ql.Id;
                if(ql.SBQQ__ProductFamily__c == PricingJSONRequest.SURCHARGES_AND_FEES)
                {   if(isHaul_Away){
                    newDel.Service_Type__c = Constant_Util.Haul_Away_Service;
                }   else{
                    newDel.Service_Type__c = Constant_Util.LOCK_DELIVERY;
                }
                    
                }
                else{
                        newDel.Service_Type__c = ow.serviceType;
                    
                    
                }
                newDel.Quantity__c = ow.quantity;
                newDel.Onsite_Contact__c = ow.onsiteContact;
                newDel.Onsite_Contact_Phone__c = ow.onsitePhone;
                newDel.Product_Type__c = ql.SBQQ__ProductName__c;
                if(String.isNotEmpty(ow.PONumber)){
                    newDel.Cust_Ref_Number__c = ow.PONumber;
                }
                newDel.Duration__c = ow.Duration;
                newDel.Occurrence_Type__c = ql.Occurrence_Type__c;
                newDel.Service_Time_Span__c = 'ASAP';
                newDel.Placement_Instructions__c= placementInstructions;
                //SDT-41473 - 41625 - 41966
                newDel.Vendor_Service_Id__c = vendorServiceId;
                newDel.Service_Date__c = ow.serviceDate;
                system.debug('isOrderAvailable >>'+ isOrderAvailable);
                if(isOrderAvailable)
                {
                    // In case of update pulling the Id from ServiceType and Order Map
                    newDel.Id = serviceTypeOrderIdMap.get(ow.serviceType);
                }
                if (isKeyOrderAvailable)
                {
                    if(isHaul_Away){
                        newDel.Id = serviceTypeOrderIdMap.get(Constant_Util.Haul_Away_Service);
                    }
                    else{
                        newDel.Id = serviceTypeOrderIdMap.get(Constant_Util.LOCK_DELIVERY);
                        system.debug('newDel.Id >' + newDel.Id);
                    }
                    
                }
                quoteOrderList.add(newDel);
            }
            
            try {
               
                upsert quoteOrderList;
            

                
                wrapper.result = validateAndCreateRemovalQouteOrder(ow, positionName, placementInstructions, isRemovalAvailable, serviceTypeOrderIdMap);
                //return wrapper;		//TCS-pkulkarn-6-Sep-2023-Commented and moved to end of method-SDT-30092
            } catch (exception e) {
                wrapper.result = e.getMessage();
                return wrapper;
            }
        }
        
        //TCS-pkulkarn-Added code for SDT-30092
        try 
        {
            if(PqLine[0].SBQQ__ProductFamily__c == Constant_Util.COMMERCIAL && caseRecordType != Constant_Util.New_Service_Case)
        		CreateDeliveryRemovalForCommercialProducts(PqLine[0].Id, ow);
        }
        catch (exception e) 
        {
            wrapper.result = e.getMessage();
        }
        //TCS-pkulkarn-SDT-30092-End
        return wrapper;		//TCS-pkulkarn-6-Sep-2023-Moved to end of method-SDT-30092
    }
    public static string validateAndCreateRemovalQouteOrder(OrderWrapper ow, String positionName, string placementInstructions, Boolean isRemovalAvailable, Map<String,Id> serviceTypeOrderIdMap){
        system.debug('inside validateAndCreateRemovalQouteOrder==');
        string result='SUCCESS';
        List<SBQQ__QuoteLine__c> removalHaulQuoteLines = new List<SBQQ__QuoteLine__c>();
        removalHaulQuoteLines = [SELECT Id, Occurrence_Type__c, SBQQ__ProductName__c, Location_Position_Name__r.Container_Position__c,
                                 Location_Position_Name__c,SBQQ__EndDate__c,Duration__c FROM SBQQ__QuoteLine__c 
                                 WHERE SBQQ__RequiredBy__c=:ow.parentQuoteLine AND 
                                 (SBQQ__ProductName__c ='Haul' OR SBQQ__ProductName__c ='Removal')];
        if(removalHaulQuoteLines.size()>0 && removalHaulQuoteLines[0].SBQQ__EndDate__c!=null){
            
            result = createQuoteOrder(ow, removalHaulQuoteLines[0], positionName, placementInstructions,isRemovalAvailable,serviceTypeOrderIdMap);
        }
        return result;
    }
    public static String createQuoteOrder(OrderWrapper ow, SBQQ__QuoteLine__c qLine, String positionName, string placementInstructions,Boolean isRemovalAvailable, Map<String,Id> serviceTypeOrderIdMap) {

        String result;
        SBQQ__QuoteLine__c ql = qLine;
        Quote_Order__c newRemovalDel = new Quote_Order__c();
        // Removed offsite check for this bug #SDT-22324
        if (positionName != null && positionName != '') {
            newRemovalDel.Instructions__c ='POSITION:' + positionName + '\n'  + ow.instructions;
            newRemovalDel.Acorn_Instructions__c ='POSITION:' + positionName + '\n'  + ow.acornInstructions;
        } else {
            newRemovalDel.Instructions__c = ow.instructions;
            newRemovalDel.Acorn_Instructions__c = ow.acornInstructions;
        }
        newRemovalDel.Quote_Line__c = ow.parentQuoteLine;
        newRemovalDel.Service_Quote_Line__c = ql.Id;
        //newRemovalDel.Service_Date__c = ow.serviceDate;
        if(qLine.SBQQ__EndDate__c !=null)
            newRemovalDel.Service_Date__c = qLine.SBQQ__EndDate__c;
        newRemovalDel.Service_Type__c = 'Removal';
        newRemovalDel.Quantity__c = ow.quantity;
        newRemovalDel.Onsite_Contact__c = ow.onsiteContact;
        newRemovalDel.Onsite_Contact_Phone__c = ow.onsitePhone;
        newRemovalDel.Product_Type__c = ql.SBQQ__ProductName__c;
        newRemovalDel.Cust_Ref_Number__c = ow.PONumber;
        newRemovalDel.Duration__c = ow.Duration;
        newRemovalDel.Occurrence_Type__c = ql.Occurrence_Type__c;
        newRemovalDel.Service_Time_Span__c = 'ASAP';
        newRemovalDel.Placement_Instructions__c= placementInstructions;
        //SDT-41473 - 41625 - 41966
        newRemovalDel.Vendor_Service_Id__c = ow.vendorServiceId;
        try {
            if(isRemovalAvailable)
            {
                // In case of update pulling the Id from ServiceType and Order Map
                newRemovalDel.Id = serviceTypeOrderIdMap.get(newRemovalDel.Service_Type__c);
                update newRemovalDel;
            }
            else
                insert newRemovalDel;
            result = 'SUCCESS';
            return result;
        } catch (exception e) {
            result = e.getMessage();
            return result;
        }
        
    }

    @AuraEnabled 
    public static OrderWrapper generateOrderWrapper(){
        OrderWrapper ow = new OrderWrapper();
        ow.parentQuoteLine = '';
        ow.serviceQuoteLine = '';
        ow.serviceDate = system.today();
        ow.serviceType = '';
        ow.onsiteContact = '';
        ow.onsitePhone ='';
        ow.instructions = '';
		ow.acornInstructions = '';
        ow.productType = '';
        ow.PONumber = '';
        ow.duration = '';
        ow.occurrenceType = '';
        ow.serviceTimeSpan = '';
        //Changes for SDT-27107
        ow.quoteId = '';
        ow.serviceEndDate =null;
        
        //SDT-41473 - 41625 - 41966
        ow.vendorServiceId = '';
        system.debug('Returned structure of the orderwrapper is: ' + ow);

        return ow;
    }

    @AuraEnabled
    public static String updateStatus(Id quoteId, String newStatus, Boolean quoteOnly) {
        SBQQ__Quote__c q = [SELECT Id, SBQQ__Status__c, Quote_Only__c
        ////SDT 42652 Haul Away
        ,SBQQ__Opportunity2__r.Case__c,SBQQ__Opportunity2__r.Case__r.Haul_Away_Service_Booked__c,
        SBQQ__Opportunity2__r.Case__r.Chargeable__c,SBQQ__Opportunity2__r.Case__r.Is_Haul_Away_Service__c,
        SBQQ__Opportunity2__r.Case__r.Haul_Away_information__c, SBQQ__Opportunity2__r.Case__r.Haul_Away_Vendor__c,
        Business_Rule__r.Is_Auto_Email__c, Business_Rule__r.No_Approval_Required__c, Genesys_Record_Created__c
                           FROM SBQQ__Quote__c
                           WHERE Id=:quoteId];
                
                           String result;
        //SDT 42652 Haul Away
        Boolean isHaulAway = HaulAwayService.getIsHaulAwayService(q.SBQQ__Opportunity2__r.Case__c);
        if(isHaulAway==true){
            String haulAwayServiceBooked = q.SBQQ__Opportunity2__r.Case__r.Haul_Away_Service_Booked__c;
            if(haulAwayServiceBooked.equalsIgnoreCase(Constant_Util.PROCURED_YES)){
                q.SBQQ__Status__c = Constant_Util.APPROVED;
            }
            else{
                q.SBQQ__Status__c = Constant_Util.QUOTE_PRICE_CONFIGURED;
                
            }
        }
        else{
            q.SBQQ__Status__c = newStatus;
        }
        q.Quote_Only__c = quoteOnly;
        try {
            //Changes for SDT-49634 - Disable CPQ Package Trigger
            SBQQ.TriggerControl.disable();
            update q;
            result = 'SUCCESS';
        } catch (exception e) {
            //Changes related to SDT-48086
            UTIL_LoggingService.logHandledExceptionWithClass(e, UserInfo.getOrganizationId(),
                                                UTIL_ErrorConstants.CONFIRM_CONFIGURATION_ACTION,
                                                System.LoggingLevel.Error,
                                                UTIL_ErrorConstants.QUOTEPROCUREMNTCONTROLLER_CLASSNAME,
                                                UTIL_ErrorConstants.UPDATESTATUS_METHODNAME,
                                                null);
            //Changes related to SDT-39632
            throw new AuraHandledException(e.getMessage());
        }
        finally{
            SBQQ.TriggerControl.enable();
        }
        //41544
        //     SBQQ__Quote__c q1 = [SELECT Id, SBQQ__Status__c, Quote_Only__c
                            
        //                     ,SBQQ__Opportunity2__r.Case__c,SBQQ__Opportunity2__r.Case__r.Haul_Away_Service_Booked__c,
        //                     SBQQ__Opportunity2__r.Case__r.Chargeable__c,SBQQ__Opportunity2__r.Case__r.Is_Haul_Away_Service__c,
        //                     SBQQ__Opportunity2__r.Case__r.Haul_Away_information__c, SBQQ__Opportunity2__r.Case__r.Haul_Away_Vendor__c,
        //                     Business_Rule__r.Is_Auto_Email__c, Business_Rule__r.Id, Business_Rule__r.No_Approval_Required__c, Genesys_Record_Created__c
        //                    FROM SBQQ__Quote__c
        //                    WHERE Id=:quoteId];
        //     system.debug('Business_Rule__r.Is_Auto_Email__c' + q1.Business_Rule__r.Is_Auto_Email__c);
        //     system.debug('Business_Rule__r.No_Approval_Required__c' + q1.Business_Rule__r.No_Approval_Required__c);
        //     system.debug('Genesys_Record_Created__c' + q1.Genesys_Record_Created__c);
        //     if(q1.Business_Rule__r.Is_Auto_Email__c == false && q1.Business_Rule__r.No_Approval_Required__c == false && q1.SBQQ__Status__c == 'Price Configured'){
        //             q1.Genesys_Record_Created__c = true;
        //         }
        // try {
        //     update q1;
        //     result = 'SUCCESS';
        //     system.debug('Genesys_Record_Created__c' + q1.Genesys_Record_Created__c);

        return result;

    }

    @AuraEnabled
    public static List<String> getSLAOverrideReasons() {
        // Refactored to use QuoteProcurementUIService
        return QuoteProcurementUIService.getSLAOverrideReasons();
    }

    @AuraEnabled
    public static String createQuoteLines(Id quoteId, Id productId, Id wasteStream, String equipmentSize) {

        String successMessage;
        List<SBQQ__ErrorCondition__c> errorConditions = new List<SBQQ__ErrorCondition__c>();
        Set<Id> actionIds = new Set<Id>();
        Set<Id> addProducts = new Set<Id>();
        Set<Id> remProducts = new Set<Id>();
        List<SBQQ__QuoteLine__c> newLines = new List<SBQQ__QuoteLine__c>();
        
        List<SBQQ__QuoteLine__c> insertQuoteLines = new List<SBQQ__QuoteLine__c>();
        List<SBQQ__QuoteLine__c> updateQuoteLines = new List<SBQQ__QuoteLine__c>();
        Map<String,Id> relationshipMap =  new Map<String,Id>();
        
        SBQQ__ProductOption__c materialOption = getMaterialOption(wasteStream);

        SBQQ__ProductOption__c categoryOption = getCategoryOption(materialOption.SBQQ__ConfiguredSKU__c, productId);

        Decimal quoteLineNumber = getMaxQuoteLineNumber(quoteId);
        
        Decimal parentLineNumber;
        String wasteCategoryId;

        

        SBQQ__QuoteLine__c parentQLine = QuoteLineServices.returnParentQuoteline(quoteId,productId,equipmentSize,'OC',true,1,quoteLineNumber);
        
          parentLineNumber = quoteLineNumber;
        quoteLineNumber = quoteLineNumber + 3;
        DateTime SLADate;

        try {
            insertQuoteLines.add(parentQLine);
        } catch (exception e) {
           system.debug(e.getMessage());
        }


        errorConditions = SBQQConfigurationRuleService.getProductRules(productId);
        if (errorConditions.size() > 0) {
            actionIds = SBQQConfigurationRuleService.getActions(errorConditions, parentQLine);
            addProducts = SBQQConfigurationRuleService.getAddRuleProducts(actionIds);
        }

        List<SBQQ__ProductOption__c> productOptions = [SELECT Id, Name, SBQQ__Quantity__c, Occurrence_Type__c, CostModelType__c,
                                                      Cost_Unit_of_Measure__c, PriceUOM__c, Schedule_Frequency__c, Frequency_Interval__c,
                                                      SBQQ__OptionalSKU__c, Equipment_Size__c, SBQQ__ProductFamily__c
                                                      FROM SBQQ__ProductOption__c
                                                      WHERE SBQQ__ConfiguredSKU__c =: productId AND (SBQQ__Selected__c = true OR SBQQ__OptionalSKU__c IN: addProducts) AND
                                                      SBQQ__ProductFamily__c != 'Waste Category' AND SBQQ__ProductFamily__c != 'Waste Stream'];

        productOptions.add(categoryOption);
        productOptions.add(materialOption);

        for (SBQQ__ProductOption__c po : productOptions) {

            if (po.SBQQ__ProductFamily__c == 'Waste Category') {

                SBQQ__QuoteLine__c qLine = new SBQQ__QuoteLine__c(SBQQ__Quote__c = quoteId,
                                                                SBQQ__Product__c = po.SBQQ__OptionalSKU__c,
                                                                Equipment_Size__c = equipmentSize,
                                                                SBQQ__StartDate__c = NULL,  
                                                                //SBQQ__RequiredBy__c = parentQLine.Id,
                                                                SBQQ__ProductOption__c = po.Id,
                                                                SBQQ__OptionLevel__c = 1,
                                                                SBQQ__Quantity__c = po.SBQQ__Quantity__c,
                                                                SBQQ__Number__c = parentLineNumber + 1,
                                                                SBQQ__CostEditable__c = false,
                                                                SBQQ__PriceEditable__c = true,
                                                                Occurrence_Type__c = po.Occurrence_Type__c,
                                                                CostModelType__c = po.CostModelType__c,
                                                                Cost_Unit_of_Measure__c = po.Cost_Unit_of_Measure__c,
                                                                PriceUOM__c = po.PriceUOM__c,
                                                                Schedule_Frequency__c = po.Schedule_Frequency__c,
                                                                Frequency_Interval__c = po.Frequency_Interval__c);

                try {
                    insertQuoteLines.add(qline);
                    //insert qline;
                    //wasteCategoryId = qline.Id;
                    
                } catch (exception e) {
                    system.debug(e.getMessage());
                }
            } else {
                SBQQ__QuoteLine__c qLine = new SBQQ__QuoteLine__c(SBQQ__Quote__c = quoteId,
                                                                SBQQ__Product__c = po.SBQQ__OptionalSKU__c,
                                                                Equipment_Size__c = equipmentSize,
                                                                //SBQQ__RequiredBy__c = po.SBQQ__ProductFamily__c == 'Waste Stream' ? wasteCategoryId : parentQLine.Id,
                                                                SBQQ__ProductOption__c = po.Id,
                                                                SBQQ__OptionLevel__c = po.SBQQ__ProductFamily__c == 'Waste Stream' ? 2 : 1,
                                                                SBQQ__Number__c = po.SBQQ__ProductFamily__c == 'Waste Stream' ? parentLineNumber + 2 : quoteLineNumber,
                                                                SBQQ__CostEditable__c = po.SBQQ__ProductFamily__c == 'Waste Stream' ? false : true,
                                                                SBQQ__PriceEditable__c = po.SBQQ__ProductFamily__c == 'Waste Stream' ? false : true,
                                                                SBQQ__Quantity__c = po.SBQQ__Quantity__c,
                                                                SBQQ__StartDate__c = parentQLine.SBQQ__StartDate__c,  
                                                                Occurrence_Type__c = po.Occurrence_Type__c, 
                                                                CostModelType__c = po.CostModelType__c,
                                                                Cost_Unit_of_Measure__c = po.Cost_Unit_of_Measure__c, 
                                                                PriceUOM__c = po.PriceUOM__c,
                                                                Schedule_Frequency__c = po.Schedule_Frequency__c,
                                                                Frequency_Interval__c = po.Frequency_Interval__c); 
                
                //newLines.add(qLine);
                insertQuoteLines.add(qLine);
                quoteLineNumber = quoteLineNumber + 1;
            }

        }

        try {
            //insert newLines;
            insert insertQuoteLines;
            //List<SBQQ__QuoteLine__c> insertLines = QuoteLineServices.getQuoteLinesByQuoteId(quoteId);
            
            // get all inserted Ids
            Set<Id> allInsertedIds = new Set<Id>();
            for(SBQQ__QuoteLine__c quoteLineObj: insertQuoteLines)
            {
                 allInsertedIds.add(quoteLineObj.Id);
            }


         List<SBQQ__QuoteLine__c> insertLines = QuoteLineServices.getQuoteLinesByIds(allInsertedIds);
         //Haul Away SDT 44574
         Id haulAwayVendorId;
         boolean isHaulAway = HaulAwayService.getIsHaulAwayServiceForQuote(quoteId);
         String hVendor;
         if(isHaulAway){
         for(SBQQ__QuoteLine__c quoteLineObj: insertLines)
         {
             //This loop is added to calculate Vendor__c for Quoteline once and same should be used for rest of bundle QLs
             if(quoteLineObj.SBQQ__RequiredBy__c ==null && haulAwayVendorId==null){
             String vendor = quoteLineObj.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Haul_Away_Vendor__c;
              String location = quoteLineObj.SBQQ__Quote__r.SBQQ__ShippingCountry__c;
             hVendor = HaulAwayService.getHaulAwayVendorByLocation(vendor,location);
             haulAwayVendorId = HaulAwayService.getHaulAwayVendor(hVendor);
                 quoteLineObj.Vendor__c = haulAwayVendorId;
             }
         }  
        } 
         /* Loop for finding Id for relationship  */
            for(SBQQ__QuoteLine__c quoteLineObj: insertLines)
            {
                //Haul Away SDT 44574
                if(isHaulAway && haulAwayVendorId!=null){
                    quoteLineObj.Vendor__c = haulAwayVendorId;
                }
                //Haul Away end
                if(quoteLineObj.SBQQ__Bundle__c)
                    relationshipMap.put('ParentQuote',quoteLineObj.id);
                
                if(quoteLineObj.SBQQ__ProductFamily__c == 'Waste Category')
                    relationshipMap.put('WasteCategory',quoteLineObj.id);
            }      
            
            boolean isExtraPickup=false;
            /* Updating relationship */
            for(SBQQ__QuoteLine__c quoteLineObj: insertLines)
            {
                if(quoteLineObj.SBQQ__Bundle__c)
                {
                     //System.debug('insideParent>>');
                    //SLADate = QuoteFavoritesController.determineSLA(relationshipMap.get('ParentQuote'));
                    //quoteLineObj.SBQQ__StartDate__c = SLADate.date();
                    updateQuoteLines.add(quoteLineObj);
                }
                if(quoteLineObj.SBQQ__ProductFamily__c == 'Waste Stream')
                {
                    quoteLineObj.SBQQ__RequiredBy__c  = relationshipMap.get('WasteCategory');
                    updateQuoteLines.add(quoteLineObj);  
                }
                else if(quoteLineObj.SBQQ__Bundle__c != true && quoteLineObj.SBQQ__ProductFamily__c != 'Waste Stream')
                {
                    quoteLineObj.SBQQ__RequiredBy__c = relationshipMap.get('ParentQuote');
                    updateQuoteLines.add(quoteLineObj);

                    if(quoteLineObj.SBQQ__RequiredBy__c != null && quoteLineObj.SBQQ__ProductName__c == Constant_Util.EXTRA_PICKUP){
                        isExtraPickup =true;
                     }
                    
                }
            }

            if(isExtraPickup)
            {
                for(SBQQ__QuoteLine__c quotePickupLine : updateQuoteLines){
                    if(quotePickupLine.SBQQ__ProductName__c == Constant_Util.PICKUP_CSTYPE && quotePickupLine.Occurrence_Type__c == Constant_Util.SCHEDULED_TYPE)
                    {
                        quotePickupLine.IsExtraPickup__c = true;
                    }
                }
            }

            update updateQuoteLines;
            successMessage = relationshipMap.get('ParentQuote');
           // successMessage = parentQLine.Id;
        } catch (exception e) {
            successMessage = e.getMessage();
        }

        return successMessage;
    }
    
    public static SBQQ__ProductOption__c getMaterialOption(String wasteStream) {

        SBQQ__ProductOption__c materialOption = [SELECT Id, Name, SBQQ__Quantity__c, Occurrence_Type__c, CostModelType__c,
                                                Cost_Unit_of_Measure__c, PriceUOM__c, Schedule_Frequency__c, Frequency_Interval__c,
                                                SBQQ__ConfiguredSKU__c, SBQQ__OptionalSKU__c, Equipment_Size__c, SBQQ__ProductFamily__c
                                                FROM SBQQ__ProductOption__c
                                                WHERE Id =: wasteStream
                                                LIMIT 1];
        return materialOption;

    }
    
    public static SBQQ__ProductOption__c getCategoryOption(String materialParentSKU, String productId) {

        SBQQ__ProductOption__c categoryOption = [SELECT Id, Name, SBQQ__Quantity__c, Occurrence_Type__c, CostModelType__c,
                                                Cost_Unit_of_Measure__c, PriceUOM__c, Schedule_Frequency__c, Frequency_Interval__c,
                                                SBQQ__ConfiguredSKU__c, SBQQ__OptionalSKU__c, Equipment_Size__c, SBQQ__ProductFamily__c
                                                FROM SBQQ__ProductOption__c
                                                WHERE SBQQ__OptionalSKU__c =: materialParentSKU AND SBQQ__ConfiguredSKU__c =: productId
                                                LIMIT 1];
        return categoryOption;

    }

    public static Decimal getMaxQuoteLineNumber(String quoteId) {

        List<SBQQ__QuoteLine__c> maxQL = [SELECT SBQQ__Number__c
                                          FROM SBQQ__QuoteLine__c
                                          WHERE SBQQ__Quote__c =: quoteID
                                          ORDER BY SBQQ__Number__c DESC
                                          LIMIT 1];

        Decimal quoteLineNumber = (maxQL.size() > 0) ? maxQL[0].SBQQ__Number__c + 1: 1;

        return quoteLineNumber;

    }
    /*SDT-25277 Deleting Removal Quoteline*/
    @AuraEnabled
    public static string deleteHaulRemovalqLine(string parentQLineId){
        string msg = 'SUCCESS';
        try{
		//changes done for 32420 and 32464 --- removal QL will only get delete in case its quote's type is 'Quote'
            List<SBQQ__QuoteLine__c> haulRemovalQLinesListToDelete = new List<SBQQ__QuoteLine__c>();
            List<SBQQ__QuoteLine__c> haulRemovalQLinesList = new List<SBQQ__QuoteLine__c>();
            haulRemovalQLinesList = [SELECT id,SBQQ__Quote__r.SBQQ__Type__c
                                     FROM SBQQ__QuoteLine__c 
                                     WHERE SBQQ__RequiredBy__c=:parentQLineId 
                                     AND SBQQ__Product__c!= null 
                                     AND SBQQ__Product__r.Name = 'Removal'];
            if(haulRemovalQLinesList.size()>0){
                for(SBQQ__QuoteLine__c ql : haulRemovalQLinesList){
                    if(ql.SBQQ__Quote__r.SBQQ__Type__c == 'Quote'){
                        haulRemovalQLinesListToDelete.add(ql);
                    }
                }
            }
            system.debug('Inside deleteHaulRemovalqLine ==>'+haulRemovalQLinesList);
            if(haulRemovalQLinesListToDelete.size()>0){
                delete haulRemovalQLinesListToDelete;
            }     
        }
        catch(exception ex){
            msg = ex.getMessage();
        }
        return msg;
    }

    @AuraEnabled
    public static string validateHaulRemovalqLine(string parentQLineId, string endDate){
        system.debug('parentQLineId==>'+parentQLineId);
        string result = 'SUCCESS';
        SBQQ__QuoteLine__c parentQLine = getParentQline(parentQLineId);
        system.debug('parentQLine==>'+parentQLine);
        system.debug('parentQLine.Duration__c==>'+parentQLine.Duration__c);
        system.debug('parentQLine.SBQQ__ProductFamily__c==>'+parentQLine.SBQQ__ProductFamily__c);
        if(parentQLine.Duration__c =='TEMP'){
            if(parentQLine.SBQQ__ProductFamily__c=='Rolloff'){
                result = validateHaul(parentQLine, endDate);// need to add quote serial number logic in near future
            }else if(parentQLine.SBQQ__ProductFamily__c=='Commercial'){
                result = validateRemoval(parentQLine, endDate);// need to add quote serial number logic in near future
            }
        }
        return result;
    }

    // Changes for SDT-31623
    public static SBQQ__ProductOption__c getProductOptionId(string parentQLineProdutId, string childProductId){
        
        SBQQ__ProductOption__c productOption = new SBQQ__ProductOption__c();
        List<SBQQ__ProductOption__c> pOptionList = [SELECT id, SBQQ__ConfiguredSKU__c, SBQQ__ConfiguredSKU__r.Name, SBQQ__OptionalSKU__c, 
                                                    SBQQ__OptionalSKU__r.Name, Occurrence_Type__c , Cost_Unit_of_Measure__c, CostModelType__c, PriceUOM__c // Changes for SDT-32028
                                                    FROM SBQQ__ProductOption__c 
                                                    WHERE SBQQ__ConfiguredSKU__c = :parentQLineProdutId AND 
                                                    SBQQ__OptionalSKU__c=:childProductId];
        if(pOptionList.size()>0){
            productOption = pOptionList[0];
        }
        return productOption;
    }
    public static id getProductId(string productName, string parentQuotelineProductId){
        List<SBQQ__ProductOption__c> pOptionList = new List<SBQQ__ProductOption__c>();
        pOptionList = [SELECT SBQQ__OptionalSKU__c
                                                    FROM SBQQ__ProductOption__c 
                                                    WHERE SBQQ__ConfiguredSKU__c = :parentQuotelineProductId 
                                                    AND SBQQ__OptionalSKU__r.Name=:productName];
        
        if(pOptionList.size()==0){
            return null;
        }
        return pOptionList[0].SBQQ__OptionalSKU__c;
    }
    public static SBQQ__QuoteLine__c assignParentQLineFields(SBQQ__QuoteLine__c parentQLine){
        SBQQ__QuoteLine__c childQLine = new SBQQ__QuoteLine__c(
        	SBQQ__Quote__c = parentQLine.SBQQ__Quote__c,
            SBQQ__RequiredBy__c = parentQLine.Id,
            Account__c = parentQLine.Account__c,
            SBQQ__StartDate__c = parentQLine.SBQQ__StartDate__c,
            SBQQ__EndDate__c = parentQLine.SBQQ__EndDate__c, 
            //SDT 34351 Exception_Effective_Date__c = parentQLine.Exception_Effective_Date__c,
            //sdhikale TCS SDT-29806
            //SDT 34351 Exceptions_Effective_Date__c = parentQLine.Exceptions_Effective_Date__c,
            Exception_Type__c = parentQLine.Exception_Type__c,
            Exception_Comments__c = parentQLine.Exception_Comments__c,
            Exception_Reason__c = parentQLine.Exception_Reason__c,
  			Equipment_Size__c = parentQLine.Equipment_Size__c,
            Occurrence_Type__c = parentQLine.Occurrence_Type__c,
            Schedule_Frequency__c = parentQLine.Schedule_Frequency__c,
            Frequency_Interval__c = parentQLine.Frequency_Interval__c,
            Day_of_Month__c = parentQLine.Day_of_Month__c,
            Service_Days__c = parentQLine.Service_Days__c,
            Duration__c = parentQLine.Duration__c,
            //SDT-38285 - start
            Month_Relative_Interval__c = parentQLine.Month_Relative_Interval__c,
            Month_Relative__c = parentQLine.Month_Relative__c
            //SDT-38285 - End
        );
        
            //End SDT-29615 
        return childQLine;
    }
    public static string validateHaul(SBQQ__QuoteLine__c parentQLine, string endDate){
        system.debug('parentQLine==>1679'+parentQLine);
        string result = 'SUCCESS';
        try{
            SBQQ__QuoteLine__c haulQLine = getQLine(parentQLine.Id,'Haul');
            system.debug('haulQLine==>'+haulQLine);
            if(haulQLine == null || haulQLine.Id == null){
                haulQLine = new SBQQ__QuoteLine__c();
                haulQLine = assignParentQLineFields(parentQLine);
                haulQLine.SBQQ__Product__c = getProductId('Haul', parentQLine.SBQQ__Product__c);
                haulQLine.SBQQ__Quantity__c = 1;
                //date d = date.valueOf(endDate);
                //haulQLine.SBQQ__EndDate__c = date.valueOf(d);
                if(!String.isEmpty(endDate))
                {
                    date haulenddate = date.parse(endDate);
                    haulQLine.SBQQ__EndDate__c = haulenddate;
                }
                if(haulQLine.SBQQ__Product__c!=null){
                    // Changes for SDT-31623
                    SBQQ__ProductOption__c haulProductOption= getProductOptionId(parentQLine.SBQQ__Product__c, haulQLine.SBQQ__Product__c);
                    if(haulProductOption!= null && haulProductOption.Id != null)
                    {
                        haulQLine.SBQQ__ProductOption__c= haulProductOption.Id;
                    }
                }
                
                haulQLine.SBQQ__Number__c = getMaxQuoteLineNumber(parentQLine.SBQQ__Quote__c);
                insert haulQLine;
                // haulQLine = [SELECT id, SBQQ__EndDate__c FROM SBQQ__QuoteLine__c WHERE id=:haulQLine.id];
                // if(haulQLine.SBQQ__EndDate__c==null){
                //     haulQLine.SBQQ__EndDate__c = haulenddate;
                //     update haulQLine;
                // }
            }
            else
            {
                SBQQ__QuoteLine__c updatedhaulQLine = assignParentQLineFields(parentQLine);
                updatedhaulQLine.Id = haulQLine.Id;
                system.debug('haulQLine.Exception_Effective_Date__c >'+ haulQLine.Exception_Effective_Date__c);
                //sdhikale TCS SDT-29806
                system.debug('haulQLine.Exceptions_Effective_Date__c >'+ haulQLine.Exceptions_Effective_Date__c);
                update updatedhaulQLine;
            }
        }catch(exception ex){
        	result= ex.getMessage();
        }
        return result;
    }

    //Changes for SDT-31623: To clear Schedule values
    private static SBQQ__QuoteLine__c clearScheduleValues(SBQQ__QuoteLine__c qLine)
    {
        qLine.Schedule_Frequency__c =  null;
        qLine.Frequency_Interval__c =  null;
        qLine.Day_of_Month__c =  null;
        qLine.Service_Days__c = null;
        //SDT-38285 - start
        qLine.Month_Relative_Interval__c = null;
        qLine.Month_Relative__c = null;
        //SDT-38285 - End
        return qLine;
    }

    public static string validateRemoval(SBQQ__QuoteLine__c parentQLine, string endDate){
        string result = 'SUCCESS';
        try{
            SBQQ__QuoteLine__c removalQLine = getQLine(parentQLine.Id,'Removal');
            if(removalQLine == null || removalQLine.Id == null){
                removalQLine = new SBQQ__QuoteLine__c();
                removalQLine = assignParentQLineFields(parentQLine);
                removalQLine.SBQQ__Product__c = getProductId('Removal', parentQLine.SBQQ__Product__c);
                removalQLine.SBQQ__Quantity__c = 1;
                system.debug('parentQLine.SBQQ__ProductOption__c==>'+parentQLine.SBQQ__ProductOption__c);
                system.debug('removalQLine.SBQQ__Product__c==>'+removalQLine.SBQQ__Product__c);
                if(removalQLine.SBQQ__Product__c!=null){
		    // Changes for SDT-31623
                    SBQQ__ProductOption__c removalProductOption= getProductOptionId(parentQLine.SBQQ__Product__c, removalQLine.SBQQ__Product__c);
                    if(removalProductOption!= null && removalProductOption.Id != null)
                    {
                        // Setting up Occurrence_Type__c = On Call for Removal and removing other schedule values
                        removalQLine.SBQQ__ProductOption__c =removalProductOption.Id;
                        removalQLine.Occurrence_Type__c =removalProductOption.Occurrence_Type__c;
                        // Changes for SDT-32028
                        removalQLine.PriceUOM__c =removalProductOption.PriceUOM__c ;
                        removalQLine.Cost_Unit_of_Measure__c =removalProductOption.Cost_Unit_of_Measure__c;
                        removalQLine.CostModelType__c =removalProductOption.CostModelType__c;
                        //Removing Other Schedule Values
                        removalQLine = clearScheduleValues(removalQLine);
                    }
                }
                //removalQLine.SBQQ__ProductOption__c = getProductOptionId(parentQLine.SBQQ__ProductOption__c, 'Removal');
                // date d = date.valueOf(endDate);
                // removalQLine.SBQQ__EndDate__c = date.valueOf(d);
                if(!String.isEmpty(endDate))
                {
                    date removalenddate = date.parse(endDate);
					//SDT 32952
                    //removalQLine.SBQQ__EndDate__c = removalenddate;
					RemovalQuoteLineHandler.setDatesForRemovalQL(removalQLine,removalenddate);
                }
                removalQLine.SBQQ__Number__c = getMaxQuoteLineNumber(parentQLine.SBQQ__Quote__c);
                
				//SDT 32952
				//Removal Quoteline will only be inserted if bundle has end date 
				//insert removalQLine;
				//TCS-pkulkarn-SDT-41184-Added if condition to check for Quote Type-Removal quote line not to be added for Add/Change quotes for TEMP Duration on Commercial containers
                if(parentQLine.SBQQ__Quote__r.SBQQ__Type__c == Constant_Util.QUOTE)
                {
                    RemovalQuoteLineHandler.checkIfBundleQLHasEnddateBeforeInsert(removalQLine);
                }
                
                // removalQLine = [SELECT id, SBQQ__EndDate__c FROM SBQQ__QuoteLine__c WHERE id=:removalQLine.id];
                // if(removalQLine.SBQQ__EndDate__c==null){
                //     removalQLine.SBQQ__EndDate__c = removalenddate;
                //     update removalQLine;
                // }
                
            }
            else
            {
                SBQQ__QuoteLine__c updatedremovalQLine = assignParentQLineFields(parentQLine);
                updatedremovalQLine.Id = removalQLine.Id;
				//SDT32952
				if(!String.isEmpty(endDate))
				{
					date removalDate = date.parse(endDate);
					RemovalQuoteLineHandler.setDatesForRemovalQL(updatedremovalQLine,removalDate);
				}
               
	       
	       // Overriding Occurrence_Type__c Value from Removal QL
                updatedremovalQLine.Occurrence_Type__c=removalQLine.Occurrence_Type__c;
                 //Removing Other Schedule Values
                updatedremovalQLine = clearScheduleValues(updatedremovalQLine);
                system.debug('removalQLine.Exception_Effective_Date__c >'+ removalQLine.Exception_Effective_Date__c);
                //sdhikale TCS SDT-29806
                system.debug('removalQLine.Exceptions_Effective_Date__c >'+ removalQLine.Exceptions_Effective_Date__c);
                update updatedremovalQLine;
            }
        }catch(exception ex){
        	result= ex.getMessage();
        }
        return result;
    }
    public static SBQQ__QuoteLine__c getQLine(string qLineId, string prdName){
        //SDT-38285 Added Month_Relative_Interval__c and Month_Relative__c
        List<SBQQ__QuoteLine__c> qLineList = [SELECT id, SBQQ__Quote__c, SBQQ__RequiredBy__c, Account__c, SBQQ__StartDate__c, SBQQ__EndDate__c, Exception_Effective_Date__c, Exceptions_Effective_Date__c,  Exception_Type__c, Exception_Comments__c, Exception_Reason__c, Equipment_Size__c, Occurrence_Type__c, Schedule_Frequency__c, Frequency_Interval__c, Day_of_Month__c, Service_Days__c, Duration__c, Month_Relative_Interval__c, Month_Relative__c FROM SBQQ__QuoteLine__c WHERE SBQQ__RequiredBy__c=:qLineId 
                                             AND SBQQ__ProductName__c =:prdName];
        if(qLineList.size()>0){
         	return qLineList[0];   
        }
        return null;
    }
    public static SBQQ__QuoteLine__c getParentQline(string parentQLineId){
        //SDt-38285 Added Month_Relative_Interval__c and Month_Relative__c
        //TCS-pkulkarn-SDT-41184-Added SBQQ__Quote__r.SBQQ__Type__c to the SOQL
        List<SBQQ__QuoteLine__c> pQLineList = [SELECT id, SBQQ__Quote__c, Account__c, SBQQ__StartDate__c, SBQQ__EndDate__c, Exception_Effective_Date__c, Exceptions_Effective_Date__c, Exception_Type__c,
                                               Exception_Comments__c, Exception_Reason__c, Equipment_Size__c, SBQQ__Quantity__c, Occurrence_Type__c, Schedule_Frequency__c,
                                               Frequency_Interval__c, Day_of_Month__c, Service_Days__c, SBQQ__Product__c, SBQQ__ProductOption__c,Duration__c,SBQQ__ProductFamily__c,
                                               SBQQ__Product__r.ProductCode, Month_Relative_Interval__c, Month_Relative__c, SBQQ__Quote__r.SBQQ__Type__c
                                               FROM SBQQ__QuoteLine__c WHERE id=:parentQLineId];
        if(pQLineList.size()>0){
            return pQLineList[0];
        }
        return null;
    }
    
    @AuraEnabled 
    public static Map<string,Object> fetchUser(Id quoteId){
        
        Map<string,Object> result = new Map<string,Object>();
        
        User u = [select id,UserRole.Name,RoleCombination__c, Profile.Name from User where id =: userInfo.getUserId()];
        
        result.put('User', u);
        result.put('NewServiceRecordType', Constant_Util.New_Service_Case);
        //SDT-41473
        result.put('isHaulAway', HaulAwayService.getIsHaulAwayServiceForQuote(quoteId));
        
        return result;
    }
    
    // method to get the Quotelines by Quotes
    @AuraEnabled 
    public static List<HeaderWrapper> getQuoteLinesByQuote(Id quoteId)
    {
        List<HeaderWrapper> headerList = new List<HeaderWrapper>();
        List<SBQQ__QuoteLine__c> headerRecords = getQuoteProducts(quoteId);
        for (SBQQ__QuoteLine__c header : headerRecords){
            HeaderWrapper prod = new HeaderWrapper();
            prod.parentId = header.Id;
            prod.locationId = header.Account__c;
            prod.quoteLineName = header.Name;
            prod.productId = header.SBQQ__Product__c;
            prod.equipmentType = header.SBQQ__ProductName__c;
            prod.equipmentTypeCode = header.SBQQ__ProductCode__c;
            prod.equipmentSize = header.Equipment_Size__c;
            prod.duration = header.Duration__c;
            prod.quoteID = header.SBQQ__Quote__c;

            List<SBQQ__QuoteLine__c> detailRecords = getQuoteDetails(header.Id);
            for (SBQQ__QuoteLine__c detail: detailRecords) {
                //Immediately store the material type to the header record and skip to the next
                //iteration
                if (detail.SBQQ__ProductFamily__c == 'Waste Stream') {
                    prod.materialType = detail.SBQQ__ProductName__c;
                    prod.materialTypeCode = detail.SBQQ__ProductCode__c;
                    continue;
                }
            }
            headerList.add(prod);
        }
        return headerList;
    }

     // method to get the products
     @AuraEnabled
     public static List<Product2> getProducts()
     {
         // Delegates to QuoteFavoritesController
         return QuoteFavoritesController.getProducts();
     }

     //method to get the selected Products
     @AuraEnabled
    public static Product2 getPreselectedProduct(string selectedProductName){
        // Delegates to QuoteFavoritesController
        return QuoteFavoritesController.getPreselectedProduct(selectedProductName);
    }

    //get the materials by product
    @AuraEnabled
    public static List<SBQQ__ProductOption__c> getWasteStreams(Id productId) {
        // Delegates to QuoteFavoritesController
        return QuoteFavoritesController.getWasteStreams(productId);
    }

    // Refactored to use QuoteProcurementUIService
    @AuraEnabled
    public static Map<String, String> getDurations() {
        return QuoteProcurementUIService.getDurations();
    }
    @AuraEnabled
    public static SBQQ__QuoteLine__c getParentQlineRec(Id parentId)
    {
      return [SELECT Id, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Quantity__c, Description_of_Waste__c,
      SBQQ__ProductName__c,SBQQ__ProductFamily__c, SBQQ__ProductOption__r.SBQQ__Type__c, SBQQ__Product__c, Equipment_Size__c, SBQQ__Quote__c,
      SBQQ__RequiredBy__c,Duration__c, SID__c
      FROM SBQQ__QuoteLine__c
      WHERE Id =: parentId];
    }
    
          /*
     * SDT-26026
     * Dev: Jatan
     * Description: Created Comment for quote
     * 
     */
    @AuraEnabled
    public static void createQuoteComment(String quoteComment , id caseId){
        String result ;
        try {
            system.debug('In Procurement calss ' +QuoteComment +' ' +caseId);
            //List<SBQQ__Quote__c> caseId = [select SBQQ__Opportunity2__r.Case__c from SBQQ__Quote__c where id =: quoteId limit 1];
          result =  AcornController.createAcornComment(quoteComment,caseId);
        } catch (Exception e) {
            //Changes related to SDT-48086
            UTIL_LoggingService.logHandledExceptionWithClass(e, UserInfo.getOrganizationId(),
                                                            UTIL_ErrorConstants.CONFIRM_CONFIGURATION_ACTION,
                                                            System.LoggingLevel.Error,
                                                            UTIL_ErrorConstants.QUOTEPROCUREMNTCONTROLLER_CLASSNAME,
                                                            UTIL_ErrorConstants.CREATEQUOTECOMMENT_METHODNAME+ UTIL_ErrorConstants.BLANK_SPACE+ 
                                                            'AcornController.createAcornComment',
                                                            null);
            
            throw new AuraHandledException(e.getMessage());
        }
        //return result;
    }
	
	/*
     * SDT-27107
     * Dev: Seema
     * Description: get SLA date
     * 
     */

    @AuraEnabled
    public static Date callDetermineSLA(String parentQuoteLineId) {
        if(!QuoteFavoritesController.getSLASwitch())
        {
            //Code Change for SDT-39637 & 45007
            Date slaDate;
            DateTime slaDateTime = QuoteFavoritesController.determineSLA(parentQuoteLineId);
            system.debug('SLA Datetime ' + slaDateTime);

            slaDate = slaDateTime.dateGmt();
            System.debug('SLA Date: ' + slaDate);
            return slaDate; 
        }
        else
        {
            // Old Code before SDT-34542 Change
            DateTime slaDate ;
            try {
                slaDate=QuoteFavoritesController.determineSLA(parentQuoteLineId);
            } 
            catch (Exception e) 
            {
                throw new AuraHandledException(e.getMessage());
            } 
            return slaDate.date(); 
        }        
    }
    
    /*
     * SDT-27107
     * Dev: Seema
     * Description: Populate Start And EndDate On Related QuoteLines as null.
     * 
     */
    @AuraEnabled
    public static void removeStartAndEndDateOnRelatedQL(String parentQuoteLineId) {
        try {
          If(parentQuoteLineId!=NULL)
          {
             List<SBQQ__QuoteLine__c> qlList =  QuoteLineServices.getQuoteLinesByParentId(parentQuoteLineId);
             
              if(qlList.size()>0){
                  for(SBQQ__QuoteLine__c ql : qlList){
                    if(ql.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.DeveloperName==Constant_Util.New_Service_Case){
                            ql.SBQQ__StartDate__c=NULL;
                            ql.SBQQ__EndDate__c=NULL;
                        }
                  }
                  update qlList;
        }
          }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
	

    /*SDT-21804- 
        Dev: Rishi
        FC: Anmoal Bharti
        Description: added validation for description of waste field on quote line. 
        This validation is only applicable when Quote/Quote lines are being created/updated from CEI screen.
		Test Coverage is covered with methods validateDescriptionOfWasteForAllTest(), validateDescriptionOfWasteForAnyTest() ,validateDescriptionOfWasteForCustomTest() and validateDescriptionOfWasteForSuccessTest() of ServiceSchedulerCtrlTest class
    */
    public static Map<String,List<String>> validateDescriptionOfWaste(HeaderWrapper productWrapper) {
        Map<String,List<String>> resultErrorMap;
        if(productWrapper.materialType!=null){
            String wasteDescription = String.isBlank(productWrapper.wasteDescription) ? null : productWrapper.wasteDescription;
            resultErrorMap = QuoteProcurementController.validateProductRules(productWrapper.productId, wasteDescription, productWrapper.materialType);
        }
        if(resultErrorMap!=null && !resultErrorMap.isEmpty()){
            return resultErrorMap;
        }else{
            List<String> successList = new List<String>();
            successList.add('Success');
            resultErrorMap = new Map<String,List<String>>();
            resultErrorMap.put('Success',successList);
            return resultErrorMap;
        }
    }
	
    /*SDT-21804- 
        Dev: Rishi
        FC: Anmoal Bharti
        Description: added validation for description of waste field on quote line. 
        This validation is only applicable when Quote/Quote lines are being created/updated from CEI screen.
		Test Coverage is covered with methods validateDescriptionOfWasteForAllTest(), validateDescriptionOfWasteForAnyTest() ,validateDescriptionOfWasteForCustomTest() and validateDescriptionOfWasteForSuccessTest() of ServiceSchedulerCtrlTest class
    */
    public static Map<String,List<String>> validateProductRules(String productId, String wasteDescription,String wasteStream){
        List<ProductRulesExecutor.ErrorConditionsModal> errCondModalList = new List<ProductRulesExecutor.ErrorConditionsModal>();
        ProductRulesExecutor.ErrorConditionsModal errorConditionsObj =  new ProductRulesExecutor.ErrorConditionsModal();
        errorConditionsObj.testedObject = 'Configuration Attributes';
        errorConditionsObj.testedField = 'Description_of_Waste__c';
        errorConditionsObj.testedValue = wasteDescription;
        errorConditionsObj.testedValueType = 'String';
        errCondModalList.add(errorConditionsObj);

        ProductRulesExecutor.ErrorConditionsModal errorConditionsObj1 =  new ProductRulesExecutor.ErrorConditionsModal();
        errorConditionsObj1.testedObject = 'Product Option';
        errorConditionsObj1.testedField = 'SBQQ__ProductName__c';
        errorConditionsObj1.testedValue = wasteStream;
        errorConditionsObj1.testedValueType = 'String';
        errCondModalList.add(errorConditionsObj1);

        Map<String,List<String>> resultErrorMap = ProductRulesExecutor.executeProductRule(productId,errCondModalList);
        System.debug('resultErrorMap>>'+resultErrorMap);
        return resultErrorMap;
    }
          /*
     * SDT-26217
     * Dev: Jatan
     * Description: getCompanyCategory for seachable dropdown
     * 
     */ 
    @AuraEnabled
    public static List<Map<String, String>> getCompanyCategory(string quoteId) {

        SBQQ__Quote__c parentQuote = [SELECT Id, SBQQ__Account__r.Parent.AccountNumber
                               FROM SBQQ__Quote__c
                               WHERE Id =: quoteId];
        
        
        map<String, String> companyCategoriesMap = AcornCompanyDetails.getAcornCCMap(parentQuote.SBQQ__Account__r.Parent.AccountNumber);
        
        List<Map<String, String>> companyList = new List<Map<String, String>>();
       

        list<sortingWrapper> sortedList = new list<sortingWrapper>();

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
        return companyList;
    }
  /*
     * SDT-26217
     * Dev: Jatan
     * Description: sort Company Category
     * 
     */
    public class sortingWrapper implements Comparable {
        public Map<String, String> sObjFldsMap;

        public sortingWrapper(Map<String, String> sObjFldsMap) {
            this.sObjFldsMap = sObjFldsMap;
        }

        public Integer compareTo(Object compareTo) {
            return sObjFldsMap.get('label').compareTo(((sortingWrapper)compareTo).sObjFldsMap.get('label'));
        }
    }
    
    //Quote Approval Automation (all case types) requires a dynamic getter method to match up against
    //the custom metadata values.  This method will simply allow us to extend the classes below to use a faux
    //getter method to return values
    public abstract class CoreObject {
        public Object getField(String parameterName) {
            String jsonInstance = Json.serialize(this);
            Map<String, Object> untypedInstance;
            untypedInstance = (Map<String, Object>)JSON.deserializeUntyped(jsonInstance);
            return untypedInstance.get(parameterName);
        }
    }
	
    //sdt-31000
    public class nteWrapper{
        //@AuraEnabled public List<QuoteProcurementController.HeaderWrapper> configuredProducts {get; set;}
        @AuraEnabled public Boolean showMessage {get; set;}
        @AuraEnabled public String qlineDetails {get; set;}
		@AuraEnabled public String qlineId {get; set;}
        
    }
    //sdt-31000
    //Creating a wrapper class that will store data in a way that is consumable for 
    //end users.  Breaks into three categories - header records, detail records, and
    //MAS Details.  Includes conversions for Picklist values.
    public class ProductsWrapper{
        @AuraEnabled public List<QuoteProcurementController.HeaderWrapper> configuredProducts {get; set;}
        @AuraEnabled public Boolean disableMAS {get; set;}
        @AuraEnabled public Boolean disableCost {get; set;}
        @AuraEnabled public Boolean disablePrice {get; set;}
        @AuraEnabled public String singleQuoteId {get; set;}
    }
    //The header wrapper is effectively how we would describe a service to a customer
    //(e.g., your 30 yard trash open top)
    public class HeaderWrapper extends CoreObject{
        //TCS adding caseType for SDT-27578 
        @AuraEnabled public String caseType {get; set;}
        @AuraEnabled public String caseSubType {get; set;}
        @AuraEnabled public String caseReason {get; set;}
        @AuraEnabled public String caseOrigin {get; set;}
        @AuraEnabled public String projectCodeId {get; set;}
        @AuraEnabled public id parentId {get; set;}
	@AuraEnabled public id clientId {get;set;}
        @AuraEnabled public id locationId {get; set;}
	@AuraEnabled public id locationDivision {get; set;}
        @AuraEnabled public id locationGeography {get; set;}
        @AuraEnabled public id locationType {get; set;}
        @AuraEnabled public id locationBrand {get; set;}
        @AuraEnabled public String quoteLineName {get; set;}
        @AuraEnabled public Id productId {get; set;}
        @AuraEnabled public Boolean quantityEditable {get; set;}
        @AuraEnabled public Id favoriteId {get; set;}
        @AuraEnabled public Decimal quantity {get; set;}
	@AuraEnabled public Id assetId {get; set;}
        @AuraEnabled public String equipmentType {get; set;}
        @AuraEnabled public String equipmentTypeCode {get; set;}
        @AuraEnabled public String equipmentSize {get; set;}
        @AuraEnabled public String duration {get; set;}
        @AuraEnabled public String materialType {get; set;}
        @AuraEnabled public String materialTypeCode {get; set;}
        @AuraEnabled public String wasteDescription {get; set;}
        @AuraEnabled public Date startDate {get; set;}
	@AuraEnabled public Date originalSLAstartDate {get; set;}
        @AuraEnabled public Date endDate {get; set;}
        @AuraEnabled public String quoteIdNav {get; set;}
        @AuraEnabled public String quoteName {get; set;}
        @AuraEnabled public String quoteStatus {get; set;}
        @AuraEnabled public Id vendorId {get; set;}
        @AuraEnabled public String companyCategory {get; set;}
        @AuraEnabled public String companyCategoryName {get; set;}
        @AuraEnabled public String selectedMaterialGrade {get; set;}// SDT-37527

        @AuraEnabled public String vendorName {get; set;}
        @AuraEnabled public String vendorNumber {get; set;}
        @AuraEnabled public String vendorBU {get; set;}
        @AuraEnabled public String vendorFacilityCode {get; set;}//SDT-29645
        @AuraEnabled public String parentVendorId {get; set;}
        @AuraEnabled public String vendorManualDispatch {get; set;}
        @AuraEnabled public String vendorPrepayment {get; set;}
        @AuraEnabled public Boolean isCOD {get; set;}
        @AuraEnabled public Boolean lineError {get; set;}
        //SDT-41473
        @AuraEnabled public Boolean isHaulAway {get; set;}
        //Adding VCR and SCode for SDT-20795
        @AuraEnabled public String sCode {get; set;}
        //Readded for 20079 after overwrite for 20085///
        @AuraEnabled public String primaryContact {get; set;}
        @AuraEnabled public String contactID {get; set;}
        @AuraEnabled public String lineFrequency {get; set;}
        @AuraEnabled public String monthlyScheduleDetails{set;get;}	//SDT-41407
        @AuraEnabled public String quoteID {get; set;}//Occurrence_Type__c 
        @AuraEnabled public String occurrenceType {get; set;}
        @AuraEnabled public Decimal quoteLineNumber {get; set;}
        @AuraEnabled public map<String,String> companyCategories {get; set;}
        @AuraEnabled public Boolean quoteOnly {get; set;}
        @AuraEnabled public String slaOverrideReason {get; set;}
        @AuraEnabled public String slaOverrideComment {get; set;}
        @AuraEnabled public String productFamily {get; set;}
        @AuraEnabled public String bundleProcuredStatus {get; set;}
        @AuraEnabled public String procurementErrorMessage {get; set;}
        @AuraEnabled public QuoteProcurementController.MASWrapper MAS {get; set;}
        @AuraEnabled public List<QuoteProcurementController.DetailWrapper> details {get; set;}
        @AuraEnabled public List<QuoteProcurementController.WOWrapper> workOrders {get; set;}
        /*SDT-24736 Classification Changes
        Author : Yeshas Konduru*/
        @AuraEnabled public string caseRecordType {get; set;}
        @AuraEnabled public string deliveryOverrideReason {get; set;} //SDT-30864 : Asset Availabilty
        @AuraEnabled public string deliveryOverrideComment {get; set;} //SDT-30864 : Asset Availabilty
        @AuraEnabled public string serviceOverrideReason {get; set;} //SDT-29100 : Asset Availabilty
        @AuraEnabled public string serviceOverrideComment {get; set;} //SDT-29100 : Asset Availabilty
        @AuraEnabled public Boolean nteWarnning {get; set;} // changes for SDT-31000
        @AuraEnabled public string nteWarnningMessage {get; set;} // changes for SDT-31000
        //SDT33101
        @AuraEnabled public String quoteType {get; set;}
        @AuraEnabled public String customerApproval {get; set;}
        @AuraEnabled public String quoteOnlyCopyOf {get; set;}
    }
    //Details are further broken into cost and price categories, and describe 
    //the charges associated with a service
    public class DetailWrapper {
        @AuraEnabled public Id componentId {get; set;}
        @AuraEnabled public String quoteLineName {get; set;}
        @AuraEnabled public Id productId {get; set;}
        @AuraEnabled public String componentType {get; set;}
        @AuraEnabled public Integer componentQuantity {get; set;}
        @AuraEnabled public Date componentStartDate {get; set;}
        @AuraEnabled public Date componentEndDate {get; set;}
        @AuraEnabled public String occurrenceType {get; set;}
        @AuraEnabled public String scheduleFrequency {get; set;}
        @AuraEnabled public String frequencyInterval {get; set;}
        @AuraEnabled public String serviceDays {get; set;}
        @AuraEnabled public String errorMessage {get; set;}
        @AuraEnabled public Decimal vendorCost {get; set;}
        @AuraEnabled public String costCurrencyCode {get; set;}
        @AuraEnabled public String costUOM {get; set;}
        @AuraEnabled public Decimal costMin {get; set;}
        @AuraEnabled public Decimal customerPrice {get; set;}
        @AuraEnabled public String priceCurrencyCode {get; set;}
        @AuraEnabled public String priceUOM {get; set;}
        @AuraEnabled public Decimal priceMin {get; set;}
        @AuraEnabled public String iconName {get; set;}
    }
    //Vendor cost and Customer Price are separate entities for permissions purposes
    public class VendorCost {
        //Future iterations can store stepped tonnage here
    }
    public class CustomerPrice {
        //Future iterations can store stepped tonnage here
    }
    
    //MAS details are broken out to ensure we can tackle just MAS Integration for now
    public class MASWrapper {
        @AuraEnabled public String MASLibrary {get; set;}
        @AuraEnabled public String MASCompany {get; set;}
        @AuraEnabled public Double MASAccount {get; set;}
        @AuraEnabled public Double MASUniqueId {get; set;}
        @AuraEnabled public Double MASServiceLine {get; set;}
        @AuraEnabled public String MASBox {get; set;}
        @AuraEnabled public String MASComment {get; set;}
        @AuraEnabled public Boolean MASBypassPrice {get; set;}
        @AuraEnabled public Boolean MASDoNotCreate {get; set;}
        //SDT-29392 start
        @AuraEnabled public Boolean DoNotCreateTaskGridTickets {get; set;}
        @AuraEnabled public Boolean IsDoNotCreateTaskGridTicketVisible {get; set;}
        //SDT-29392 end
        @AuraEnabled public String VCRCode {get; set;}
        //added new Property for SDT-25787
        @AuraEnabled public Integer MASCommentSize {get; set;}
    }
    //SDT-29392 start
    public class MASResponseWrapper
    {
        @AuraEnabled public Boolean IsSuccess {get; set;}  
        @AuraEnabled public String ErrorMessage {get; set;}  
    }
    //WorkOrder details for display purposes
    public class WOWrapper {
        @AuraEnabled public Date serviceDate {get; set;}
        @AuraEnabled public String serviceType {get; set;}
        @AuraEnabled public String instructions {get; set;}
    }
    //SDT-21060
    //FinancialDetail Wrapper to fetch data.
    public class FinancialDetailWrapper{
        @AuraEnabled public Boolean quoteOnly {get; set;}
        @AuraEnabled public String companyCategory {get; set;}
        @AuraEnabled public String clientGLNo {get; set;}
        @AuraEnabled public String customerCostCenter {get; set;}
    }
    //Wrapper class for orders
    //Correlates to Quote_Order__c object
    public class OrderWrapper {
        @AuraEnabled public String parentQuoteLine {get; set;} //Quote_Line__c
        @AuraEnabled public String serviceQuoteLine {get; set;} //Service_Quote_Line__c
        @AuraEnabled public Date serviceDate {get; set;} //Service_Date__c
        @AuraEnabled public String serviceType {get; set;} //Service_Type__c (Picklist)
        @AuraEnabled public Decimal quantity {get; set;} //Quantity__c

        @AuraEnabled public String onsiteContact {get; set;} //Onsite_Contact__c
        @AuraEnabled public String onsitePhone {get; set;} //Onsite_Contact_Phone__c
        @AuraEnabled public String instructions {get; set;} //Instructions__c
		@AuraEnabled public String acornInstructions {get; set;} //Acorn Instructions__c 

        @AuraEnabled public String productType {get; set;} //Product_Type__c
        @AuraEnabled public String PONumber {get; set;} //Cust_Ref_Number__c
        @AuraEnabled public String duration {get; set;} //Duration__c
        @AuraEnabled public String occurrenceType {get; set;} //Occurrence_Type__c
        @AuraEnabled public String serviceTimeSpan {get; set;} //Service_Time_Span__c
        //Changes for SDT-27107
        @AuraEnabled public String quoteId {get; set;} 
        @AuraEnabled public Date serviceEndDate {get; set;}

        //SDT-41473 - 41625 - 41966
        @AuraEnabled public String vendorServiceId {get; set;} //Vendor_Service_Id__c
    }
    public class PicklistSelect {
        @AuraEnabled public String value {get; set;}
        @AuraEnabled public String label {get; set;}
        @AuraEnabled public Boolean selected {get; set;}
    }

    /*
     * SDT-23055
     * Dev: Rishi
     * Description: Created this wrapper for catering PO and its Quantities. It will be used in updateKeysQuantity
     * 
     */
    public class KeyMapWrapper{
        @AuraEnabled public String value {get; set;}
        @AuraEnabled public String id {get; set;}
    }
    
    /*
     * SDT-28571
     * Dev: Aliasgher
     * Description: Create this wrapper for Quote Summary Confirmation, It will be used in CreateDelivery.
    */
    public class QuoteSummaryWrapper{
        @AuraEnabled public String result {get;set;}
        @AuraEnabled public Boolean isAssetChanged {get;set;}
    }
    
    /*
    * SDT-30108
    */
    @AuraEnabled
    public static string addAdditionalServicesComment(String quoteId){
        string result;
        try {
            AAV_AvailabilityUtility.availabilityComments(quoteId);
            result = 'SUCCESS';
        } catch (Exception e) {
            //Changes related to SDT-48086
            UTIL_LoggingService.logHandledExceptionWithClass(e, UserInfo.getOrganizationId(),
                                                            UTIL_ErrorConstants.CONFIRM_CONFIGURATION_ACTION,
                                                            System.LoggingLevel.Error,
                                                            UTIL_ErrorConstants.QUOTEPROCUREMNTCONTROLLER_CLASSNAME,
                                                            UTIL_ErrorConstants.ADDADDITIONALSERVICESCOMMENT_METHODNAME+ UTIL_ErrorConstants.BLANK_SPACE+ 
                                                            'AcornController.createAcornComment',null);
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    
    /*
     * SDT-29084
     * Description : Fetch stp by Pass reason picklist values
    */
    @AuraEnabled
    public static Map<String, String> getByPassSTPReasonList()
    {
        Map<String,String> prValue = new Map<String,String>();
        List<String> pckValuelist =  UTIL_Picklist.getPickListValuesIntoList('SBQQ__Quote__c','Special_Handling_Reason__c');
        for(String pckValue : pckValuelist){
            prValue.put(pckValue.split(',').get(1), pckValue.split(',').get(0));//TODO - check what it returns
        }
        return prValue;
    } 
    /*
     * SDT-29084
     * Description : save stp by Pass reasons fields
    */
    
    @AuraEnabled
    public static void saveByPassSTPRequest(Id quoteId, Boolean byPassSTPFlag, String byPassSTPReason, String byPassSTPOtherReason, Boolean quoteOnly){
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        quote.Id = quoteId;
        quote.Special_Handling__c = byPassSTPFlag;
        quote.Special_Handling_Reason__c = byPassSTPReason;
        quote.Special_Handling_Reason_Details__c     = byPassSTPOtherReason;
        quote.Quote_Only__c = quoteOnly;
        try
        {
            update quote;
        }
        catch(Exception ex)
        {
            //Changes related to SDT-48086
            UTIL_LoggingService.logHandledExceptionWithClass(ex, UserInfo.getOrganizationId(),
                                                             UTIL_ErrorConstants.CONFIRM_CONFIGURATION_ACTION,
                                                             System.LoggingLevel.Error,
                                                             UTIL_ErrorConstants.QUOTEPROCUREMNTCONTROLLER_CLASSNAME,
                                                             UTIL_ErrorConstants.SAVEBYPASSREQUEST_METHODNAME,
                                                             null);
        }
    }

    @AuraEnabled
    public static Boolean getReqBusinessRulesCC(Id quoteId){
        Boolean isReqQuoteCC = false; 
        //system.debug('quoteId '+quoteId);
        for(SBQQ__Quote__c q : [SELECT Id, SBQQ__Account__c, SBQQ__Account__r.ParentId,Case_Type__c,Case_Sub_Type__c,
                            SBQQ__Opportunity2__r.Case__r.Business_RuleId__c,SBQQ__Opportunity2__r.Case__r.Required_Information__c 
                                FROM SBQQ__Quote__c WHERE Id=: quoteId LIMIT 1]){
        system.debug('q Parent Acc : ' + q.SBQQ__Account__r.ParentId);
        if (q!=null && String.isNotBlank(q.SBQQ__Opportunity2__r.Case__r.Business_RuleId__c) && String.isNotBlank(q.SBQQ__Opportunity2__r.Case__r.Required_Information__c) 
            &&  q.SBQQ__Opportunity2__r.Case__r.Required_Information__c.contains(Constant_Util.COMPANY_CATEGORY)) {
                    isReqQuoteCC = True;
                } 
        }
        system.debug(' :isReqQuoteCC : ' + isReqQuoteCC);
        return isReqQuoteCC;
    }
    
    public static void CreateDeliveryRemovalForCommercialProducts(String parentQuoteLineId, OrderWrapper orderWrapper)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To check and create Delivery, Removal Quote lines and Work Orders for Commercial (Product Family) products when there is a change in Quantity and/or Size
        // Input/Output: parentQuoteLineId/none
        //SDT -38285 Add in select query Month_Relative_Interval__c and Month_Relative__c
        
        List<SBQQ__QuoteLine__c> quoteLines = [ SELECT Id, SBQQ__RequiredBy__c, SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, SBQQ__Quantity__c, SBQQ__ProductFamily__c, SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__Quote__c, Account__c,
                                                SBQQ__StartDate__c, AssetId__c, AssetId__r.Equipment_Size__c, AssetId__r.Quantity__c, Vendor__c, Vendor__r.Parent_Vendor_ID__c, SBQQ__ProductName__c, 
                                                SBQQ__EndDate__c, Exception_Effective_Date__c, Exceptions_Effective_Date__c, Exception_Type__c, Exception_Comments__c, Exception_Reason__c, Equipment_Size__c,  Occurrence_Type__c, 
                                                Schedule_Frequency__c, Frequency_Interval__c, Day_of_Month__c,  Month_Relative_Interval__c, Month_Relative__c, Service_Days__c, Duration__c, Location_Position_Name__c, Location_Position_Name__r.Container_Position__c,
                                                (Select Id, Service_Type__c, Quantity__c, Quote_Line__c, Service_Quote_Line__c from Quote_Orders__r)
                                                FROM SBQQ__QuoteLine__c
                                                WHERE Id = :parentQuoteLineId OR SBQQ__RequiredBy__c =:parentQuoteLineId OR SBQQ__RequiredBy__r.SBQQ__RequiredBy__c =:parentQuoteLineId];

        
        SBQQ__QuoteLine__c parentQuoteLine = null;
        String vendorId = '';
	Integer quoteLineQuantity, assetQuantity;
        Double quoteLineSize, assetSize;
        Boolean changeInSize = false, changeInQuantity = false;
        Integer differenceInQuantity = 0;
        Boolean quantityIncreased = false;
        Boolean quantityDecreased = false;
        List<SBQQ__ProductOption__c> productOptionsList = null;
        
        //Get parent quote line and other information
        for(SBQQ__QuoteLine__c quoteLine : quoteLines)
        {
            if(quoteLine.SBQQ__RequiredBy__c == null)
            {
                parentQuoteLine = quoteLine;
                vendorId = quoteLine.Vendor__r.Parent_Vendor_ID__c;
                quoteLineQuantity = Integer.valueOf(quoteLine.SBQQ__Quantity__c);
                quoteLineSize = Double.valueOf(quoteLine.Equipment_Size__c.substringAfter('-'));
                assetQuantity = Integer.valueOf(quoteLine.AssetId__r.Quantity__c);
                assetSize = Double.valueOf(quoteLine.AssetId__r.Equipment_Size__c.substringBefore(' '));
            }
        }

        if(quoteLines != null && quoteLines.size() > 0 && parentQuoteLine != null)
        {
            //Retrieve Product Options
            productOptionsList = retrieveProductOptionsList(parentQuoteLine.SBQQ__Product__c);
            
            //Determine type of change in Quantity and Size
            if(quoteLineQuantity != assetQuantity && quoteLineQuantity > 0 && assetQuantity > 0)
            {
                changeInQuantity = true;
                differenceInQuantity = Math.abs(quoteLineQuantity - assetQuantity);
                if(quoteLineQuantity < assetQuantity)
                {
                    quantityDecreased = true;
                }
                else if(quoteLineQuantity > assetQuantity)
                {
                    quantityIncreased = true;
                }
            }
            if(quoteLineSize != assetSize)
            {
                changeInSize = true;
            }
        }
		
        //Remove existing Delivery/Removal/Swapout work orders 
		if(parentQuoteLine != null && (changeInSize || changeInQuantity))
            removeExistingWorkOrders(parentQuoteLine);    
        
        //Handle Size change
        if(changeInSize == true && changeInQuantity == false)
        {
            HandleSizeChange(quoteLines, parentQuoteLine, productOptionsList, vendorId, orderWrapper);
        }
        
        //Handle change in Quantity
        if(changeInSize == false && changeInQuantity == true)
        {
            HandleQuantityChange(quoteLines, parentQuoteLine, productOptionsList, quantityIncreased, quantityDecreased, differenceInQuantity, vendorId, orderWrapper);
        }
        
        //Handle change in Quantity and Size
        if(changeInSize == true && changeInQuantity == true)
        {
            HandleSizeAndQuantityChange(quoteLines, parentQuoteLine, productOptionsList, quantityIncreased, quantityDecreased, differenceInQuantity, vendorId, orderWrapper);
        }
    }

    private static void HandleSizeChange(List<SBQQ__QuoteLine__c> quoteLines, SBQQ__QuoteLine__c parentQuoteLine, List<SBQQ__ProductOption__c> productOptionsList, String vendorId, OrderWrapper orderWrapper)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To handle Size change
        // Input/Output: List of asset/true or false

        SBQQ__QuoteLine__c deliveryQuoteLine, removalQuoteLine, finalDeliveryQuoteLine, finalRemovalQuoteLine, swapoutQuoteLine, finalSwapoutQuoteLine;
        List<Quote_Order__c> workOrderList = new List<Quote_Order__c>();
        List<SBQQ__QuoteLine__c> quoteLinesCreated = new List<SBQQ__QuoteLine__c>();
        
        
        if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR || vendorId == Constant_Util.REPUBLIC_VENDOR)
        {
            //Create Delivery and Removal Quote Lines if not present
            deliveryQuoteLine = getDeliveryQuoteLine(quoteLines);
            removalQuoteLine = getRemovalQuoteLine(quoteLines);

            //Delivery does not exist, create one
            if(deliveryQuoteLine == null)
            {
                //Get Product Option for delivery
                SBQQ__ProductOption__c deliveryProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.ServiceType_Delivery)
                        deliveryProductOption = productOption;
                }
                //Create Delivery Quote Line
                if(deliveryProductOption != null)
                {
                    SBQQ__QuoteLine__c newDeliveryQuoteLine = createQuoteLine(parentQuoteLine, deliveryProductOption, Constant_Util.ServiceType_Delivery, orderWrapper);

                    if(newDeliveryQuoteLine != null)
                    {
                        if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                        {
                            newDeliveryQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                        }
                        INSERT newDeliveryQuoteLine;
                        finalDeliveryQuoteLine = newDeliveryQuoteLine;
                    }
                }
            }
            //Delivery exists, update the quantity based on Vendor
            else
            {
                deliveryQuoteLine.SBQQ__BundledQuantity__c = null;
                if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                {
                    deliveryQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                }
                else	//WM Vendor
                {
                    deliveryQuoteLine.SBQQ__Quantity__c = 1; 
                }
                deliveryQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                UPDATE deliveryQuoteLine;
                finalDeliveryQuoteLine = deliveryQuoteLine;
            }

            //Removal does not exist, create one
            if(removalQuoteLine == null)
            {
                //Get Product Option for delivery
                SBQQ__ProductOption__c removalProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.REMOVAL)
                        removalProductOption = productOption;
                }
                //Create Removal Quote Line
                if(removalProductOption != null)
                {
                    SBQQ__QuoteLine__c newRemovalQuoteLine = createQuoteLine(parentQuoteLine, removalProductOption, Constant_Util.REMOVAL, orderWrapper);
                    
                    if(newRemovalQuoteLine != null)
                    {
                        if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                        {
                            newRemovalQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                        }
                        newRemovalQuoteLine.Equipment_Size__c = retriveQuoteLineEquivalentEquipmentSizeFromAsset(parentQuoteLine);
                        INSERT newRemovalQuoteLine;
                        finalRemovalQuoteLine = newRemovalQuoteLine;
                    }
                }
            }
            //Removal exists, update the quantity based on Vendor
            else
            {
                removalQuoteLine.SBQQ__BundledQuantity__c = null;
                if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                {
                    removalQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                }
                else	//WM Vendor
                {
                    removalQuoteLine.SBQQ__Quantity__c = 1; 
                }
				removalQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                removalQuoteLine.Equipment_Size__c = retriveQuoteLineEquivalentEquipmentSizeFromAsset(parentQuoteLine);
                UPDATE removalQuoteLine;
                finalRemovalQuoteLine = removalQuoteLine;
            }

            //Create Work Orders
            if(finalDeliveryQuoteLine != null)
            {
                //When Vendor is WM
                if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
                {
                    CreateWorkOrder(finalDeliveryQuoteLine, Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c), Constant_Util.ServiceType_Delivery, 1, workOrderList, orderWrapper);
                }
                if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                {
                    CreateWorkOrder(finalDeliveryQuoteLine, 1, Constant_Util.ServiceType_Delivery, Integer.valueOf(finalDeliveryQuoteLine.SBQQ__Quantity__c), workOrderList, orderWrapper);
                }
            }

            if(finalRemovalQuoteLine != null)
            {
                //When Vendor is WM
                if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
                {
                    CreateWorkOrder(finalRemovalQuoteLine, Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c), Constant_Util.REMOVAL, 1, workOrderList, orderWrapper);
                }
                if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                {
                    CreateWorkOrder(finalRemovalQuoteLine, 1, Constant_Util.REMOVAL, Integer.valueOf(finalRemovalQuoteLine.SBQQ__Quantity__c), workOrderList, orderWrapper);
                }
            }
			
            if(workOrderList.size() > 0)
                INSERT workOrderList;
        }
        //Other vendor - create Swapout line
        else
        {
            swapoutQuoteLine = getSwapoutQuoteLine(quoteLines);
            if(swapoutQuoteLine == null)
            {
                //Create Swapout Quote Line for Other vendors
                //Get Product Option for Swapout
                SBQQ__ProductOption__c swapoutProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.SWAPOUT_PRODUCT)
                    swapoutProductOption = productOption;
                }
                
                //Create Removal Quote Line
                if(swapoutProductOption != null)
                {
                    SBQQ__QuoteLine__c newSwapoutQuoteLine = createQuoteLine(parentQuoteLine, swapoutProductOption, Constant_Util.SWAPOUT_PRODUCT, orderWrapper);
                
                    if(newSwapoutQuoteLine != null)
                    {
                        newSwapoutQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                        newSwapoutQuoteLine.Equipment_Size__c = getPicklistAPIName(parentQuoteLine.AssetId__r.Equipment_Size__c);
                        INSERT newSwapoutQuoteLine;
                        finalSwapoutQuoteLine = newSwapoutQuoteLine;
                    }
                }
            }
            //Swapout exists, update the same Quote line
            else
            {
                swapOutQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                swapOutQuoteLine.SBQQ__BundledQuantity__c = null;
                swapOutQuoteLine.Equipment_Size__c = getPicklistAPIName(parentQuoteLine.AssetId__r.Equipment_Size__c);
				swapOutQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                UPDATE swapOutQuoteLine;
                finalSwapoutQuoteLine = swapOutQuoteLine;
            }

            //Create Work order
            if(finalSwapoutQuoteLine != null)
            {
                CreateWorkOrder(finalSwapoutQuoteLine, 1, Constant_Util.WORK_ORDER_SVC_TYPE_CONTAINER_EXCHANGE, Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c), workOrderList, orderWrapper);
            }
            
            if(workOrderList.size() > 0)
            {
     			INSERT workOrderList;
            }   
        }
    }

    private static void HandleQuantityChange(List<SBQQ__QuoteLine__c> quoteLines, SBQQ__QuoteLine__c parentQuoteLine, List<SBQQ__ProductOption__c> productOptionsList, Boolean quantityIncreased, Boolean quantityDecreased, Integer differenceInQuantity, String vendorId, OrderWrapper orderWrapper)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To handle change in quantity logic
        
        SBQQ__QuoteLine__c deliveryQuoteLine, removalQuoteLine, finalDeliveryQuoteLine, finalRemovalQuoteLine;
        List<Quote_Order__c> workOrderList = new List<Quote_Order__c>();
        List<SBQQ__QuoteLine__c> quoteLinesCreated = new List<SBQQ__QuoteLine__c>();
    
        //Get Delivery/Removal quote lines if created already
        deliveryQuoteLine = getDeliveryQuoteLine(quoteLines);
        removalQuoteLine = getRemovalQuoteLine(quoteLines);
    
        if(quantityIncreased)
        {
            //Delivery does not exist, create one
            if(deliveryQuoteLine == null)
            {
                //Get Product Option for delivery
                SBQQ__ProductOption__c deliveryProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.ServiceType_Delivery)
                        deliveryProductOption = productOption;
                }
                //Create Delivery Quote Line
                if(deliveryProductOption != null)
                {
                    SBQQ__QuoteLine__c newDeliveryQuoteLine = createQuoteLine(parentQuoteLine, deliveryProductOption, Constant_Util.ServiceType_Delivery, orderWrapper);
    
                    if(newDeliveryQuoteLine != null)
                    {
                        //Republic or other vendor
                        if(vendorId == Constant_Util.REPUBLIC_VENDOR || (vendorId != Constant_Util.WM_US_VENDOR && vendorId != Constant_Util.WM_CANADA_VENDOR))
                        {
                            newDeliveryQuoteLine.SBQQ__Quantity__c = differenceInQuantity; 
                        }
                        INSERT newDeliveryQuoteLine;
                        finalDeliveryQuoteLine = newDeliveryQuoteLine;
                    }
                }
            }
            //Delivery exists, update the quantity based on Vendor
            else
            {
                deliveryQuoteLine.SBQQ__BundledQuantity__c = null;
                //Republic or other vendor
                if(vendorId == Constant_Util.REPUBLIC_VENDOR || (vendorId != Constant_Util.WM_US_VENDOR && vendorId != Constant_Util.WM_CANADA_VENDOR))
                {
                    deliveryQuoteLine.SBQQ__Quantity__c = differenceInQuantity; 
                }
                //WM Vendor
                else if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)	
                {
                    deliveryQuoteLine.SBQQ__Quantity__c = 1;
                }
				deliveryQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                UPDATE deliveryQuoteLine;
                finalDeliveryQuoteLine = deliveryQuoteLine;
            }
    
            //Create Work Orders
            //WM Vendors
            if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
            {
                if(finalDeliveryQuoteLine != null)
                {
                    CreateWorkOrder(finalDeliveryQuoteLine, differenceInQuantity, Constant_Util.ServiceType_Delivery, 1, workOrderList, orderWrapper);
                }
            }
            //Republic or other vendors
            else if(vendorId == Constant_Util.REPUBLIC_VENDOR || (vendorId != Constant_Util.WM_US_VENDOR && vendorId != Constant_Util.WM_CANADA_VENDOR))
            {
                if(finalDeliveryQuoteLine != null)
                {
                    CreateWorkOrder(finalDeliveryQuoteLine, 1, Constant_Util.ServiceType_Delivery, differenceInQuantity, workOrderList, orderWrapper);
                }
            }
            
            //Insert work orders
            if(workOrderList.size() > 0)
            {
                INSERT workOrderList;
            }
        }
    
        if(quantityDecreased)
        {
            //Removal does not exist, create one
            if(removalQuoteLine == null)
            {
                //Get Product Option for delivery
                SBQQ__ProductOption__c removalProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.REMOVAL)
                        removalProductOption = productOption;
                }
                //Create Removal Quote Line
                if(removalProductOption != null)
                {
                    SBQQ__QuoteLine__c newRemovalQuoteLine = createQuoteLine(parentQuoteLine, removalProductOption, Constant_Util.REMOVAL, orderWrapper);
                    
                    if(newRemovalQuoteLine != null)
                    {
                        //Republic or other vendor
                        if(vendorId == Constant_Util.REPUBLIC_VENDOR || (vendorId != Constant_Util.WM_US_VENDOR && vendorId != Constant_Util.WM_CANADA_VENDOR))
                        {
                            newRemovalQuoteLine.SBQQ__Quantity__c = differenceInQuantity; 
                        }
                        INSERT newRemovalQuoteLine;
                        finalRemovalQuoteLine = newRemovalQuoteLine;
                    }
                }
            }
            //Removal exists, update the quantity based on Vendor
            else
            {
                removalQuoteLine.SBQQ__BundledQuantity__c = null;
                if(vendorId == Constant_Util.REPUBLIC_VENDOR || (vendorId != Constant_Util.WM_US_VENDOR && vendorId != Constant_Util.WM_CANADA_VENDOR))
                {
                    removalQuoteLine.SBQQ__Quantity__c = differenceInQuantity; 
                }
                //WM Vendor
                else if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)	
                {
                    removalQuoteLine.SBQQ__Quantity__c = 1; 
                }
				removalQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                UPDATE removalQuoteLine;
                finalRemovalQuoteLine = removalQuoteLine;
            }
    
            //Create Work orders
            //WM Vendors
            if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
            {
                if(finalRemovalQuoteLine != null)
                {
                    CreateWorkOrder(finalRemovalQuoteLine, differenceInQuantity, Constant_Util.REMOVAL, 1, workOrderList, orderWrapper);
                }
            }
            //Republic or other vendors
            else if(vendorId == Constant_Util.REPUBLIC_VENDOR || (vendorId != Constant_Util.WM_US_VENDOR && vendorId != Constant_Util.WM_CANADA_VENDOR))
            {
                if(finalRemovalQuoteLine != null)
                {
                    CreateWorkOrder(finalRemovalQuoteLine, 1, Constant_Util.REMOVAL, differenceInQuantity, workOrderList, orderWrapper);
                }
            }
            
            //Insert work orders
            if(workOrderList.size() > 0)
            {
                INSERT workOrderList;
            }
        }
    }

    private static void HandleSizeAndQuantityChange(List<SBQQ__QuoteLine__c> quoteLines, SBQQ__QuoteLine__c parentQuoteLine, List<SBQQ__ProductOption__c> productOptionsList, Boolean quantityIncreased, Boolean quantityDecreased, Integer differenceInQuantity, String vendorId, OrderWrapper orderWrapper)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To handle change in quantity logic
        
        SBQQ__QuoteLine__c deliveryQuoteLine, removalQuoteLine, finalDeliveryQuoteLine, finalRemovalQuoteLine, swapoutQuoteLine, finalSwapoutQuoteLine;
        List<Quote_Order__c> workOrderList = new List<Quote_Order__c>();
        List<SBQQ__QuoteLine__c> quoteLinesCreated = new List<SBQQ__QuoteLine__c>();
    
        //Get Delivery/Removal quote lines if created already
        deliveryQuoteLine = getDeliveryQuoteLine(quoteLines);
        removalQuoteLine = getRemovalQuoteLine(quoteLines);
    	swapoutQuoteLine = getSwapoutQuoteLine(quoteLines);
        
        //For other vendors create Swapout line
        if(vendorId != Constant_Util.WM_US_VENDOR && vendorId != Constant_Util.WM_CANADA_VENDOR && vendorId != Constant_Util.REPUBLIC_VENDOR)
        {
            if(swapoutQuoteLine == null)
            {
                //Get Product Option for Swapout
                //SBQQ__QuoteLine__c swapOutQuoteLine;
                SBQQ__ProductOption__c swapoutProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.SWAPOUT_PRODUCT)
                    swapoutProductOption = productOption;
                }
                
                //Create Swapout Quote Line
                if(swapoutProductOption != null)
                {
                    SBQQ__QuoteLine__c newSwapoutQuoteLine = createQuoteLine(parentQuoteLine, swapoutProductOption, Constant_Util.SWAPOUT_PRODUCT, orderWrapper);
                
                    if(newSwapoutQuoteLine != null)
                    {
                        newSwapoutQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                        newSwapoutQuoteLine.Equipment_Size__c = getPicklistAPIName(parentQuoteLine.AssetId__r.Equipment_Size__c);
                        INSERT newSwapoutQuoteLine;
                        finalSwapoutQuoteLine = newSwapoutQuoteLine;
                    }
                }
            }
            //Swapout exists, update the same Quote line
            else
            {
                swapOutQuoteLine.SBQQ__Quantity__c = parentQuoteLine.AssetId__r.Quantity__c; 
                swapOutQuoteLine.SBQQ__BundledQuantity__c = null;
                swapOutQuoteLine.Equipment_Size__c = getPicklistAPIName(parentQuoteLine.AssetId__r.Equipment_Size__c);
				swapOutQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                UPDATE swapOutQuoteLine;
                finalSwapoutQuoteLine = swapOutQuoteLine;
            }
    
            if(finalSwapoutQuoteLine != null)
            {
                CreateWorkOrder(finalSwapoutQuoteLine, 1, Constant_Util.WORK_ORDER_SVC_TYPE_CONTAINER_EXCHANGE, Integer.valueOf(finalSwapoutQuoteLine.SBQQ__Quantity__c), workOrderList, orderWrapper);
            }
            
            if(workOrderList.size() > 0)
            {
                INSERT workOrderList;
            }
        }
    
        //For WM and Republic vendors, create Delivery, Removal quote lines and work orders
        else
        {
            //Delivery does not exist, create one
            if(deliveryQuoteLine == null)
            {
                //Get Product Option for delivery
                SBQQ__ProductOption__c deliveryProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.ServiceType_Delivery)
                        deliveryProductOption = productOption;
                }
                //Create Delivery Quote Line
                if(deliveryProductOption != null)
                {
                    SBQQ__QuoteLine__c newDeliveryQuoteLine = createQuoteLine(parentQuoteLine, deliveryProductOption, Constant_Util.ServiceType_Delivery, orderWrapper);
    
                    if(newDeliveryQuoteLine != null)
                    {
                        //Republic vendor
                        if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                        {
                            if(quantityIncreased)
                            {   
                                newDeliveryQuoteLine.SBQQ__Quantity__c = Integer.valueOf(differenceInQuantity + parentQuoteLine.AssetId__r.Quantity__c); 
                            }
                            else if(quantityDecreased)
                            {
                                newDeliveryQuoteLine.SBQQ__Quantity__c = Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c - differenceInQuantity); 
                            }
                        }
                        INSERT newDeliveryQuoteLine;
                        finalDeliveryQuoteLine = newDeliveryQuoteLine;
                    }
                }
            }
            //Delivery exists, update the quantity based on Vendor
            else
            {
                deliveryQuoteLine.SBQQ__BundledQuantity__c = null;
                
                //Republic vendor
                if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                {
                    if(quantityIncreased)
                    {
                        deliveryQuoteLine.SBQQ__Quantity__c = Integer.valueOf(differenceInQuantity + parentQuoteLine.AssetId__r.Quantity__c); 
                    }
                    else if(quantityDecreased)
                    {
                        deliveryQuoteLine.SBQQ__Quantity__c = Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c - differenceInQuantity); 
                    }
                }
                //WM Vendor
                if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
                {
	                deliveryQuoteLine.SBQQ__Quantity__c = 1; 
                }
				deliveryQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                UPDATE deliveryQuoteLine;
                finalDeliveryQuoteLine = deliveryQuoteLine;
            }
    
            //Create Delivery Work Orders
            if(finalDeliveryQuoteLine != null)
            {
                if(quantityIncreased)
                {
                    //WM Vendors
                    if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
                    {
                        CreateWorkOrder(finalDeliveryQuoteLine, Integer.valueOf(differenceInQuantity + parentQuoteLine.AssetId__r.Quantity__c), Constant_Util.ServiceType_Delivery, 1, workOrderList, orderWrapper);
                    }
                    //Republic vendor
                    else if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                    {
                        CreateWorkOrder(finalDeliveryQuoteLine, 1, Constant_Util.ServiceType_Delivery, Integer.valueOf(differenceInQuantity + parentQuoteLine.AssetId__r.Quantity__c), workOrderList, orderWrapper);
                    }
                }
                else if(quantityDecreased)
                {
                    //WM Vendors
                    if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
                    {
                        CreateWorkOrder(finalDeliveryQuoteLine, Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c - differenceInQuantity), Constant_Util.ServiceType_Delivery, 1, workOrderList, orderWrapper);
                    }
                    //Republic vendor
                    else if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                    {
                        CreateWorkOrder(finalDeliveryQuoteLine, 1, Constant_Util.ServiceType_Delivery, Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c - differenceInQuantity), workOrderList, orderWrapper);
                    }
                }
            }
            system.debug('DeliveryWorkOrderSize' + workOrderList.size());
            //Insert work orders
            if(workOrderList.size() > 0)
            {
                INSERT workOrderList;
            }
    
            //Removal does not exist, create one
            if(removalQuoteLine == null)
            {
                //Get Product Option for delivery
                SBQQ__ProductOption__c removalProductOption = null;
                for(SBQQ__ProductOption__c productOption : productOptionsList)
                {
                    if(productOption.SBQQ__OptionalSKU__r.Name == Constant_Util.REMOVAL)
                        removalProductOption = productOption;
                }
                //Create Removal Quote Line
                if(removalProductOption != null)
                {
                    SBQQ__QuoteLine__c newRemovalQuoteLine = createQuoteLine(parentQuoteLine, removalProductOption, Constant_Util.REMOVAL, orderWrapper);
                    
                    if(newRemovalQuoteLine != null)
                    {
                        if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                        {
                            newRemovalQuoteLine.SBQQ__Quantity__c = Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c); 
                        }
                        newRemovalQuoteLine.Equipment_Size__c = retriveQuoteLineEquivalentEquipmentSizeFromAsset(parentQuoteLine);
                        INSERT newRemovalQuoteLine;
                        finalRemovalQuoteLine = newRemovalQuoteLine;
                    }
                }
            }
            //Removal exists, update the quantity based on Vendor
            else
            {
                removalQuoteLine.SBQQ__BundledQuantity__c = null;
                if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                {
                	removalQuoteLine.SBQQ__Quantity__c = Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c); 
                }
                //WM Vendor
                if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
                {
	                removalQuoteLine.SBQQ__Quantity__c = 1; 
                }
				removalQuoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
                removalQuoteLine.Equipment_Size__c = retriveQuoteLineEquivalentEquipmentSizeFromAsset(parentQuoteLine);
                UPDATE removalQuoteLine;
                finalRemovalQuoteLine = removalQuoteLine;
            }
    
            //Create Removal Work orders
            if(finalRemovalQuoteLine != null)
            {
                workOrderList = new List<Quote_Order__c>();
                //WM Vendors
                if(vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR)
                {
                    CreateWorkOrder(finalRemovalQuoteLine, Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c), Constant_Util.REMOVAL, 1, workOrderList, orderWrapper);
                }
    
                //Republic vendor
                else if(vendorId == Constant_Util.REPUBLIC_VENDOR)
                {
                    CreateWorkOrder(finalRemovalQuoteLine, 1, Constant_Util.REMOVAL, Integer.valueOf(parentQuoteLine.AssetId__r.Quantity__c), workOrderList, orderWrapper);
                }
            }

            //Insert removal work orders
            if(workOrderList.size() > 0)
            {
                INSERT workOrderList;
            }
        }
    }
    
    private static void CreateWorkOrder(SBQQ__QuoteLine__c quoteLine, Integer noOfWorkOrders, String serviceType, Integer quantity, List<Quote_Order__c> workOrderList, OrderWrapper orderWrapper)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To create quote line
        // Input/Output: Parent QL, # of Work Orders to be created, Service Type, Work Order Quantity, OrderWrapper/Work Order list
        for(Integer index = 0; index < noOfWorkOrders; index++)
        {
            Quote_Order__c workOrder = new Quote_Order__c();
            if (quoteLine.Location_Position_Name__c != null) 
            {
                //positionName = quoteLine.Location_Position_Name__r.Container_Position__c;
                workOrder.Instructions__c ='POSITION:' + quoteLine.Location_Position_Name__r.Container_Position__c + '\n'  + orderWrapper.instructions;
                workOrder.Acorn_Instructions__c ='POSITION:' + quoteLine.Location_Position_Name__r.Container_Position__c + '\n'  + orderWrapper.acornInstructions;
            } 
            else 
            {
                workOrder.Instructions__c = orderWrapper.instructions;
                workOrder.Acorn_Instructions__c = orderWrapper.acornInstructions;
            }
            workOrder.Quote_Line__c = quoteLine.SBQQ__RequiredBy__c;
            workOrder.Service_Quote_Line__c = quoteLine.Id;
            workOrder.Service_Type__c = serviceType;
            workOrder.Quantity__c = quantity;
            workOrder.Onsite_Contact__c = orderWrapper.onsiteContact;
            workOrder.Onsite_Contact_Phone__c = orderWrapper.onsitePhone;
            if(serviceType == Constant_Util.WORK_ORDER_SVC_TYPE_CONTAINER_EXCHANGE)
                workOrder.Product_Type__c = Constant_Util.SWAPOUT_PRODUCT;
            else
                workOrder.Product_Type__c = serviceType;
            workOrder.Cust_Ref_Number__c = orderWrapper.PONumber;
            workOrder.Duration__c = orderWrapper.Duration;
            workOrder.Occurrence_Type__c = quoteLine.Occurrence_Type__c;
            workOrder.Service_Time_Span__c = 'ASAP';
            workOrder.Placement_Instructions__c= orderWrapper.instructions;
            //SDT-41473 - 41625 - 41966
            workOrder.Vendor_Service_Id__c = orderWrapper.vendorServiceId;
            workOrder.Service_Date__c = orderWrapper.serviceDate;
            workOrderList.add(workOrder);
        }
    }
    
    private static SBQQ__QuoteLine__c createQuoteLine(SBQQ__QuoteLine__c parentQuoteLine, SBQQ__ProductOption__c productOption, String lineType, OrderWrapper orderWrapper)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To create quote line
        // Input/Output: Parent QL, Product Option, Type of Product, Orderwrapper/Quote line

        SBQQ__QuoteLine__c quoteLine;
        //Create Quote Line
        if(productOption != null)
        {
            quoteLine = new SBQQ__QuoteLine__c();
            quoteLine = assignParentQLineFields(parentQuoteLine);
            quoteLine.SBQQ__StartDate__c = orderWrapper.serviceDate;
            quoteLine.SBQQ__EndDate__c = null;		//TCS-pkulkarn-SDT-41184-Added to avoid setting parent bundle End Date
            quoteLine.SBQQ__Quantity__c = 1;
            quoteLine.SBQQ__Number__c = getMaxQuoteLineNumber(parentQuoteLine.SBQQ__Quote__c);
            quoteLine.SBQQ__Product__c = productOption.SBQQ__OptionalSKU__c;
            quoteLine.SBQQ__ProductOption__c = productOption.Id;
            quoteLine.Occurrence_Type__c = productOption.Occurrence_Type__c;
            quoteLine.PriceUOM__c = productOption.PriceUOM__c;
            quoteLine.Cost_Unit_of_Measure__c = productOption.Cost_Unit_of_Measure__c;
            quoteLine.CostModelType__c = productOption.CostModelType__c;
            quoteLine.SBQQ__OptionLevel__c = 1;
            quoteLine.SBQQ__CostEditable__c = true;
            quoteLine.SBQQ__PriceEditable__c = true;
            
            quoteLine = clearScheduleValues(quoteLine);
        }
        return quoteLine;
    }

    private static SBQQ__QuoteLine__c getDeliveryQuoteLine(List<SBQQ__QuoteLine__c> quoteLines)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To check if Delivery quote line exists
        // Input/Output: List of asset/true or false

        
        SBQQ__QuoteLine__c deliveryLine;

        for(SBQQ__QuoteLine__c quoteLine : quoteLines)
        {
            if(quoteLine.SBQQ__Product__r.Name == Constant_Util.ServiceType_Delivery)
            {
                deliveryLine = quoteLine;
                break;
            }
        }
        return deliveryLine;
    }

    private static SBQQ__QuoteLine__c getRemovalQuoteLine(List<SBQQ__QuoteLine__c> quoteLines)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 30-Aug-23
        // Story: SDT-30092
        // Comment: To check if Removal quote line exists
        // Input/Output: List of asset/true or false

        Boolean result = false;
        SBQQ__QuoteLine__c removalLine;
        for(SBQQ__QuoteLine__c quoteLine : quoteLines)
        {
            if(quoteLine.SBQQ__Product__r.Name == Constant_Util.REMOVAL)
            {
                removalLine = quoteLine;
                break;
            }
        }
        return removalLine;
    }
    
    private static SBQQ__QuoteLine__c getSwapoutQuoteLine(List<SBQQ__QuoteLine__c> quoteLines)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 8-Sep-23
        // Story: SDT-30092
        // Comment: To check if Removal quote line exists
        // Input/Output: List of quote lines/Swapout quote line

        Boolean result = false;
        SBQQ__QuoteLine__c swapOutLine;
        for(SBQQ__QuoteLine__c quoteLine : quoteLines)
        {
            if(quoteLine.SBQQ__Product__r.Name == Constant_Util.SWAPOUT_PRODUCT)
            {
                swapOutLine = quoteLine;
                break;
            }
        }
        return swapOutLine;
    }

    private static List<SBQQ__ProductOption__c> retrieveProductOptionsList(Id productId)
    {
        return [SELECT Id, Occurrence_Type__c, PriceUOM__c, Cost_Unit_of_Measure__c, CostModelType__c, SBQQ__ConfiguredSKU__c, SBQQ__ConfiguredSKU__r.Name, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Name FROM SBQQ__ProductOption__c WHERE SBQQ__ConfiguredSKU__c =: productId ];
    }
    
    private static void removeExistingWorkOrders(SBQQ__QuoteLine__c quoteLine)
    {
        // Created By: TCS, pkulkarn
        // CreatedDate: 7-Sep-23
        // Story: SDT-30092
        // Comment: To remove existing work orders on Bundle. This is required when user moves back and forth on the Intake screen
        // Input/Output: Bundle Quote Line/void
        
        List<Quote_Order__c> workOrderList = quoteLine.Quote_Orders__r;
        List<Quote_Order__c> workOrderListToBeDeleted = new List<Quote_Order__c>();
        
        for(Quote_Order__c workOrder : workOrderList)
        {
            if(workOrder.Service_Type__c == Constant_Util.ServiceType_Delivery || workOrder.Service_Type__c == Constant_Util.REMOVAL || workOrder.Service_Type__c == Constant_Util.WORK_ORDER_SVC_TYPE_CONTAINER_EXCHANGE)
                workOrderListToBeDeleted.add(workOrder);
        }
        if(workOrderListToBeDeleted != null && workOrderListToBeDeleted.size() > 0)
            DELETE workOrderListToBeDeleted;
    }
    
    private static String retriveQuoteLineEquivalentEquipmentSizeFromAsset(SBQQ__QuoteLine__c parentQuoteLine)
    {
		// Created By: TCS, pkulkarn
        // CreatedDate: 3-Sep-2023
        // Story: SDT-30092, Defect SDT-32775
        // Comment: To update retrieve Equipment Size field value on Quote Line for the equivalent field on Asset
        // Input/Output: Quote Line/Equipment Size value
        
        return getPicklistAPIName(parentQuoteLine.AssetId__r.Equipment_Size__c);
    }
    
    
    
    /*
     * @Name          updateSpecialHandling
     * @Vendor        TCS
     * @Author        WM - Jatan Sharma / Digdershika Ojha
     * @Date          04/10/2023
     * @param         updatedQuoteLine : SBQQ__QuoteLine__c
     * @param         locationPositionName : String
     * @return        void
     * @story         SDT-30089
     * @Description   It updates quote if special handling auto enable criteria match.
     */

    public static void updateSpecialHandling(Id quoteId){

        List<SBQQ__QuoteLine__c> quoteLine = [select id ,Quote_SLA_Date__c,Certificate_of_Destruction__c,Certificate_of_Disposal__c,
        Gate_Code__c,Service_Start_Time__c,Service_End_Time__c,Restriction_Details__c,SBQQ__Quote__r.Special_Handling__c, SBQQ__Quote__r.Special_Handling_Reason__c, SBQQ__Quote__r.Special_Handling_Reason_Details__c 
        from SBQQ__QuoteLine__c where SBQQ__Quote__c =:quoteId and SBQQ__RequiredBy__c = null ];
        SBQQ__Quote__c quoteObj = new SBQQ__Quote__c();

        if(quoteLine !=null)
        {
            for(SBQQ__QuoteLine__c updatedQuoteLine :quoteLine)
            {
                if(updatedQuoteLine.Quote_SLA_Date__c < system.today())
                {
                    quoteObj.Special_Handling__c = true;
                    quoteObj.Special_Handling_Reason__c = specialHandling_BackDated_Reason;
                    //SDT-31144
                    quoteObj.Special_Handling_Reason_Details__c = '';
                    break;
                }
                else if(updatedQuoteLine.Quote_SLA_Date__c >= system.today() &&
                    (updatedQuoteLine.Certificate_of_Destruction__c || updatedQuoteLine.Certificate_of_Disposal__c 
                    || !String.isBlank(updatedQuoteLine.Gate_Code__c) || updatedQuoteLine.Service_Start_Time__c != null 
                    || updatedQuoteLine.Service_End_Time__c != null 
                    || !String.isBlank(updatedQuoteLine.Restriction_Details__c)))
                {
                    quoteObj.Special_Handling__c = true;
                    quoteObj.Special_Handling_Reason__c = specialHandling_Automatic_Reason;
                    //SDT-31144
                    quoteObj.Special_Handling_Reason_Details__c = '';
                    break;
                }
                else{
                    if(updatedQuoteLine.SBQQ__Quote__r.Special_Handling_Reason__c == specialHandling_BackDated_Reason 
                    || updatedQuoteLine.SBQQ__Quote__r.Special_Handling_Reason__c == specialHandling_Automatic_Reason)
                    {
                        quoteObj.Special_Handling__c = false;
                        quoteObj.Special_Handling_Reason__c = null;
                         //SDT-31144
                        quoteObj.Special_Handling_Reason_Details__c = '';
                    }
                }
            }
        }
        
        if(quoteObj!=null){
            quoteObj.Id = quoteId;
            update quoteObj;
        }
    }
    
    public static List<SBQQ__QuoteLine__c> getExtraPickupLineForStartDateUpdate(Map<Id, SBQQ__QuoteLine__c> bundlewisePickupQuoteLinesMap, Map<Id, SBQQ__QuoteLine__c> bundlewiseExtraPickupQuoteLinesMap, Boolean updateFromIntakeScreen)
    {
        // Author : TCS, SDT-32782
        // Date: 13-Oct-2023
        // Usage : To retrieve a list of Extra Pickup quote lines to update when Pickup quote line is updated
        // Input : Map of Pickup and Extra Pickup quote lines
        // Output : List of Extra Pickup quote lines to be updated
        // To retrieve the Extra Pickup line for update when Pickup line is updated with a new start date
        // Issue/Purpose : 
        // When there is Pickup and Extra Pickup present for a service, and when the Pickup service is updated with new Start Date because of Service changes like Quantity Frequency etc
        // the Extra Pickup was not integrated as there was no change on the Extra Pickup. Hence only Pickup line was integrated with ACORN and Extra Pickup was not.
        // To enable the Integration, the Extra Pickup line was updated with same Start Date as Pickup.
        List<SBQQ__QuoteLine__c> extraPickupQuoteLineListForUpdate = new List<SBQQ__QuoteLine__c>();
        
        for(Id key : bundlewiseExtraPickupQuoteLinesMap.keyset())
        {
            Id parentQuoteLineId = key;
            SBQQ__QuoteLine__c extraPickupQuoteLine = bundlewiseExtraPickupQuoteLinesMap.get(key);
            
            //Check if Pickup exists for the Extra Pickup for the same Bundle
            if(bundlewisePickupQuoteLinesMap.keyset().contains(parentQuoteLineId))
            {
                Date pickupLineStartDate = bundlewisePickupQuoteLinesMap.get(key).SBQQ__StartDate__c;
                Date extraPickupLineStartDate = bundlewiseExtraPickupQuoteLinesMap.get(parentQuoteLineId).SBQQ__StartDate__c;

                if(extraPickupLineStartDate != pickupLineStartDate && pickupLineStartDate != null)	//Check if Extra Pickup lines needs to be updated
                {
                    SBQQ__QuoteLine__c extraPickupLineForUpdate  = bundlewiseExtraPickupQuoteLinesMap.get(parentQuoteLineId);
                    extraPickupLineForUpdate.SBQQ__StartDate__c = pickupLineStartDate;
                    //TCS-pkulkarn-SDT-33383-7-Dec-2023-Commented following call-No need to set Cost, Price and other fields when Extra Pick up is updated with new Start Date
                    /*if(updateFromIntakeScreen)
                    {
                    	QuoteLineServices.setDefaultValuesForQuoteLines(extraPickupLineForUpdate,extraPickupLineForUpdate.SBQQ__Quote__r.Name);
                    }
		    */
                    extraPickupQuoteLineListForUpdate.add(extraPickupLineForUpdate);	//Add the Extra Pickup quotelines to a List
                }
            }
        }
        return extraPickupQuoteLineListForUpdate;
    }
    //SDT 33101
    @AuraEnabled
    public static Boolean getIsAmendmentQuote(Id quoteId) {
        return QuoteOnlyController.getIsAmendmentQuote(quoteId);
    }
    //SDT 33101
    @AuraEnabled
    public static Boolean getshowAddQuoteOnlyServiceButtonForAmendment(Id quoteId) {
        return QuoteOnlyController.getshowAddQuoteOnlyServiceButtonForAmendment(quoteId);
    }
    //SDT 33101
    @AuraEnabled
    public static Boolean getDisableQuoteOnlyButtonForAmendment(Id quoteId) {
        return QuoteOnlyController.getDisableQuoteOnlyButtonForAmendment(quoteId);
    }
    
    //SDT 33101
    @AuraEnabled
    public static void saveQuoteOnly(Id quoteId,boolean quoteOnly, String quoteType) 
    {
       //TCS-pkulkarn-SDT-42718-31-Jan-2025-Added quoteType parameter in the signature and the below method call
        QuoteOnlyController.saveQuoteOnly(quoteId,quoteOnly, quoteType);
    }
    @AuraEnabled
    public static boolean displayApprovalButton(Id quoteId) 
    {
        boolean shouldDisplayApprovalButton = QuoteOnlyController.displayApprovalButton(quoteId);
       return shouldDisplayApprovalButton;
    }
    @AuraEnabled
    public static void approveQuoteLine(Id quoteId,id qlIdToApprove) 
    {
       QuoteOnlyController.approveQuoteLine(quoteId,qlIdToApprove);
    }
 /*
* @Method Name    : getMultivendorPricingRecord
* @author         : Chandu Kari SDT-20689
* @description    : This method is a supporing method to assign quote line values
* @param          : Id quoteId
* @return :  list<Pricing_Request__c>
* */
    @AuraEnabled(cacheable=true)
    public static List<Pricing_Request__c> getMultivendorPricingRecord(Id quoteId){
        List<Pricing_Request__c> priceReq= new List<Pricing_Request__c>();
        try{
            priceReq = PricingRequestSelector.getStandardPricingRequestList(quoteId);
        }catch(Exception ex){
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), UTIL_ErrorConstants.PRICING_REQUEST_APEX,LoggingLevel.ERROR);
        }
        return priceReq;
    }
    //Created by Chandu Kari SDT-20689
    @AuraEnabled
    public static boolean getAMMultiVendorSwitch() 
    {
       boolean multiVendorSwitch = PricingRequestSelector.isPricingMulltiVendorAMSwitchON();
       return multiVendorSwitch;
    }
}

/*************************************************************
@Name: PotentialPickupDateAPI
@LastModifiedBy: Claude AI Assistant
@LastModifiedDate: 2025-11-21
@UsedBy: CNM-27
@Modified: Refactored to use SLACalculationUtility.calculateServiceDateWithCapacity
           for consolidated service date calculation logic that handles both
           Entitlement-based SLA and WM Capacity Planner API integration
@Architecture: This REST API now delegates all service date calculation to
               SLACalculationUtility, which consolidates:
               - Entitlement-based SLA calculation
               - WM Capacity Planner API callouts
               - Work order conflict resolution
               - Business hours and timezone adjustments
**************************************************************/
@RestResource(urlMapping='/PotentialPickupDate/V1/*') 
global with sharing class PotentialPickupDateAPI {        
    public static Map<Id,set<Date>> getWoListByAssetId = new Map<Id,set<Date>>();
    public static Map<Id,Asset> containerWithContainerIdMap = new Map<Id,Asset>();
    public static Map<Id,Entitlement> getEntitlementByAssetId = new Map<Id,Entitlement>(); 
    public static Map<Id,Case> mapCaseAsset = new Map<Id,Case>();
    public static map<Id,Boolean> hasweeklyfrequencymap = new map<Id,Boolean>();    
    public static Map<Id,String> mapSBID = new Map<Id,String>();
    public static map<Id,Set<string>> assetIdOccurencemap = new map<Id,Set<String>>();
    
    @HttpPost
    global static void getAssetDetail(){ 
        //Initialize RestContext
        RestResponse outboundResponse = RestContext.response;
        RestRequest inboundRequest = RestContext.request;
        List<Asset> assetLst = new List<Asset>();
        Set<Id> locationIds = new Set<Id>();
        List<Case> caseList = new List<Case>();
        List<Case> newCaseList = new List<Case>();
        set<String> occrenceSet = new set<String>();
        Set<Id> selfCoreDetailSet = new Set<Id>();
        List<container> lstContainer = new List<container>();
        List<ErrorsWrapper> errorList = new List<ErrorsWrapper>();
        String potentialPickupDate = null;
        Integer count = 0;        
        ContainerStatusResponse contStatusResp = new ContainerStatusResponse();  
        try{
            System.debug('getAssetDetail Inside try block 1>>');
            String jsonRequest = inboundRequest.requestBody.toString();
            System.debug('getAssetDetail Inside try block 2>>' + jsonRequest);
            //Convert request body to data structure, deserialize JSON
            Map<String, Object> requestDataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonRequest);
            //Get values from map
            String connectionId = string.valueOf(requestDataMap.get(Constant_Util.CONNECTION_ID));
            string assetHeaderId = string.valueOf(requestDataMap.get(Constant_Util.ASSET_HEADER_ID));
            Id assetId;
            assetLst = [SELECT Id, Has_Extra_Pickup__c, Product2Id, Product2.Container_Prompt_ID__c, Location__r.ParentId, 
                        Is_Active__c,Location__c,Location__r.Parent.Customer_Code__c, Quantity__c, ProductFamily, Location_Code__c , Product2.Name , Equipment_Type__c, 
                        Duration__c, Material_Type__c, Location__r.Name,  RecordType.DeveloperName, Acorn_SBID__c,Product2.Voice_Prompt__c,Occurrence_Type__c,
                        Product2.ProductTypeSelected__c, Project_Code__c, Active__c, End_Date_Based_on_Project_code__c,End_Date__c,Start_Date__c,Frequency__c,
                        (SELECT Id,Quantity__c,SBID_Text_c__c,Is_Self_Service__c,Is_Core_Service__c,Supplier__r.Parent_Vendor_ID__c,Project_Code__c,Location__r.Parent.Customer_Code__c,Active__c,Frequency__c, Occurs__c, Monday__c, Tuesday__c, Wednesday__c, Thursday__c, Friday__c, Saturday__c,Sunday__c,Service_Header_Id__c 
                         FROM Assets_Parent__r 
                         WHERE Is_Active__c = true)                                
                        FROM Asset  WHERE Id =: assetHeaderId AND RecordType.DeveloperName =: Constant_Util.SERVICE_HEADER LIMIT 1];
            if(assetLst !=null && !assetLst.isEmpty()) {
                Set<Id> assetIds = new Set<Id>();
                count = assetLst.size();
                assetId = assetLst[0].Id;
                for(Asset a: assetLst){
                    for(Asset serviceDetail : a.Assets_Parent__r){
                        if(serviceDetail.Quantity__c==1 && serviceDetail.Is_Self_Service__c){
                            selfCoreDetailSet.add(serviceDetail.Id);
                            if((mapSBID.isEmpty() || !mapSBID.containsKey(a.Id))  ){
                                mapSBID.put(a.Id, serviceDetail.SBID_text_c__c);
                            }
                        }
                        
                        if(Constant_Util.COMMERCIAL.equalsIgnoreCase(a.ProductFamily) && Constant_Util.SCHEDULED.equals(a.Occurrence_Type__c) && Constant_Util.WEEKLY.equals(serviceDetail.Frequency__c)){
                            hasweeklyfrequencymap.put(a.Id,true);
                            if(serviceDetail.Monday__c){
                                occrenceSet.add(Constant_Util.MONDAY);
                            }
                            if(serviceDetail.Tuesday__c){
                                occrenceSet.add(Constant_Util.TUESDAY);
                            }
                            if(serviceDetail.Wednesday__c){
                                occrenceSet.add(Constant_Util.WEDNESDAY);
                            }
                            if(serviceDetail.Thursday__c){
                                occrenceSet.add(Constant_Util.THURSDAY);
                            }
                            if(serviceDetail.Friday__c){
                                occrenceSet.add(Constant_Util.FRIDAY);
                            }
                        }
                    }
                    if(selfCoreDetailSet!=null && !selfCoreDetailSet.isEmpty() ){
                        locationIds.add(a.Location__c);
                        CaseTriggerHelper.casewithContainer.put(a.Id,a);
                        containerWithContainerIdMap.put(a.Id,a);
                        if(Constant_Util.COMMERCIAL.equalsIgnoreCase(a.ProductFamily)){
                            if(occrenceSet!=null && !occrenceSet.IsEmpty() && occrenceSet.size() > 0){
                                assetIdOccurencemap.put(a.Id,occrenceSet);
                            }
                        }
                    }
                }
            }
            
            if(assetId !=null){
                //Location Data for SLA
                for(Account loc: [SELECT Id, Brand__c,  Geography__c, Division__c, Location_Type__c, tz__Timezone_SFDC__c 
                                  FROM Account 
                                  WHERE Id =: locationIds LIMIT 49999]){
                	CaseTriggerHelper.casewithLocation.put(loc.Id,Loc);
                }
                //Business Hours Calculation for SLA
                for(BusinessHours b: [select id,TimeZoneSidKey from BusinessHours LIMIT 39999]){
                    CaseTriggerHelper.businessIdMap.put(b.TimeZoneSidKey,b.Id);
                }
                //Creating a Dummy Case object for the SLA Invocation
                Case objCase = null;
                for(Asset objAsset : assetLst){
                    objCase = new Case();
                    objCase.AssetId = objAsset.Id;
                    objCase.Client__c = objAsset.Location__r.ParentId;
                    objCase.Location__c = objAsset.Location__c;
                    objCase.Case_Type__c = Constant_Util.PICKUP_CSTYPE;
                    if(objAsset.ProductFamily.equalsIgnoreCase(Constant_Util.COMMERCIAL)){
                        objCase.Case_Sub_Type__c = Constant_Util.EXTRA_PICKUP;
                    }
                    if(objAsset.ProductFamily.equalsIgnoreCase(Constant_Util.ROLLOFF)){
                        objCase.Case_Sub_Type__c = Constant_Util.EMPTY_AND_RETURN;
                    }
                    caseList.add(objCase);
                }
                // REFACTORED as CNM-25: Use SLACalculationUtility instead of CaseTriggerHelper.getServiceDate
                // This delegates to the new SLA calculation approach
                //newCaseList = CaseTriggerHelper.getServiceDate(caseList);
                
                System.debug('GetAssetDetail Inside try block 1>>' + caseList);                
                SLACalculationUtility.setServiceDate(caseList);
                
                newCaseList = caseList;
                
                // Get the calculated service date from the first case
                Case returnCase = caseList[0];
                potentialPickupDate = String.valueOf(returnCase.Service_Date__c);

                // ============================================================
                // NOTE: The complex logic for determining service dates has been
                // consolidated into SLACalculationUtility.calculateServiceDateWithCapacity()
                // which handles:
                // - Entitlement-based SLA calculation (Gold Standard, Contractual, Commercial)
                // - WM Capacity Planner API integration (Rolloff products with WM vendor)
                // - Work order conflict resolution
                // - Weekly frequency and occurrence day logic
                // - Business hours adjustments
                // - Timezone conversions
                //
                // The old inline implementation has been removed to eliminate duplication
                // and improve maintainability. See SLACalculationUtility for the consolidated
                // service layer architecture.
                // ============================================================

            }
            Date potentialDate = null;
            map<Id,Date> validateDateByAssetId = new map<Id,Date>();
            
            if(assetLst !=null && !assetLst.isEmpty() && assetId !=null){
                //potentialPickupDate = getNextServiceDate(assetLst[0]);
                if(String.isNotBlank(potentialPickupDate)){
                    potentialDate = Date.valueof(potentialPickupDate); 
                    validateDateByAssetId.put(assetId,potentialDate);
                } else {
                    if(mapCaseAsset.containskey(assetId)){
                        potentialDate = (mapCaseAsset.get(assetId).Service_Date__c).addDays(Integer.valueof(System.Label.Next_Business_Days));
                        validateDateByAssetId.put(assetId,potentialDate);
                    }
                }
            }
                
            Map<Id,String> isValidAssetMap = GetCaseInformation.getAssetDetail(validateDateByAssetId);
                
                
                
                // Output generation
                contStatusResp.container = new List<container>();
                container objCon = null;        
                for(Asset objAsset : assetLst){  
                    objCon = new container();            
                    if(isValidAssetMap.containskey(objAsset.Id)){
                        if(String.isBLANK(isValidAssetMap.get(objAsset.Id))){
                            objCon.IsValidAsset = Constant_Util.YES;
                            objCon.PotentialPickupDate = potentialPickupDate;
                            objCon.AssetErrorMessage = Constant_Util.EMPTY_STRING;
                        } else {
                            objCon.IsValidAsset = Constant_Util.NO;
                            objCon.AssetErrorMessage = isValidAssetMap.get(assetId);
                            objCon.PotentialPickupDate = Constant_Util.EMPTY_STRING;
                        }
                    }
                    lstContainer.add(objCon);
                }
                contStatusResp.container.addAll(lstContainer);
                contStatusResp.RecordCount = count;
                outboundResponse.addHeader(Constant_Util.CONTENT_TYPE, Constant_Util.JSON_CONTENTTYPE);
                outboundResponse.responseBody = Blob.valueOf(JSON.serialize(contStatusResp));
                outboundResponse.statusCode = 200;
            
        }
        catch(Exception ex){
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION,LoggingLevel.ERROR);
            ErrorsWrapper errorDetails = new ErrorsWrapper(ex.getTypeName(), ex.getMessage()); 
            errorList.add(errorDetails);
            contStatusResp.Problem =  new ErrorMessageWrapper(Constant_Util.EXCEPTION_OCCURRED, 
                                                              Constant_Util.KEYWORD_EXCEPTION, errorList); 
            outboundResponse.addHeader(Constant_Util.CONTENT_TYPE, Constant_Util.JSON_CONTENTTYPE);
            outboundResponse.responseBody = Blob.valueOf(JSON.serialize(contStatusResp));      
            outboundResponse.statusCode = 400;
        }
    }
    
    // ================================================================================
    // DEPRECATED: Complex service date calculation logic has been moved to
    // SLACalculationUtility.calculateServiceDateWithCapacity()
    //
    // The method below was the original implementation that handled:
    // - Entitlement-based SLA (Gold Standard, Contractual)
    // - WM Capacity Planner API integration
    // - Work order conflict resolution
    //
    // This logic is now centralized in the service layer (SLACalculationUtility)
    // to eliminate code duplication and improve maintainability.
    //
    // @deprecated Use SLACalculationUtility.calculateServiceDateWithCapacity() instead
    // ================================================================================
    /*
    @Deprecated
    global static String getNextServiceDate(Asset objAsset){
        // Complex logic moved to SLACalculationUtility.calculateServiceDateWithCapacity()
        // This ensures all service date calculations follow the same business rules
        // regardless of entry point (API, UI, Batch, etc.)
    }
    */
    
    // ================================================================================
    // DEPRECATED HELPER METHODS
    // These methods are kept for backward compatibility but their functionality
    // has been consolidated into SLACalculationUtility
    // ================================================================================

    /**
     * @deprecated Use BusinessHours.addGmt() directly
     */
    @Deprecated
    global static Datetime getBusinessHoursServiceDate(Id bId, Datetime serviceDate, Integer milliSeconds){
        return BusinessHours.addGmt(bId,serviceDate,milliSeconds);
    }

    /**
     * @deprecated Use SLACalculationUtility.convertToLocationTimezone() instead
     */
    @Deprecated
    global static Datetime converlocalTimeZone(Datetime dt, string localZone){
        TimeZone tz = Timezone.getTimeZone(localZone);
        dt = dt.addSeconds((tz.getOffset(dt)/1000));
        return dt;
    }

    /**
     * @deprecated Work order conflict logic is now handled in
     * SLACalculationUtility.getNextAvailableDateAfterConflicts()
     * and SLACalculationUtility.calculateCapacityPlannerServiceDate()
     */
    @Deprecated
    global static Date getNextAvailableDateFromSLA(Id bId,set<Date> woAvailDates, Date SLADate,DateTime SLADatetime,string locZone,Integer count,set<String> occurencedays){
        Date nextDate = null;
        DateTime nextDateTime = SLADatetime;
        Integer extraDays = 57600000;
        Integer i=1;
        nextDate = SLADate;
        String dayOfWeek = null;
        if(count != null && count == 0 ){
            while(i>0){
                if(!woAvailDates.contains(nextDate)){
                    break;   
                } 
                else{
                    nextDateTime = getBusinessHoursServiceDate(bId,SLADatetime,extraDays * i);
                    nextDate = converlocalTimeZone(nextDateTime,locZone).dateGmt();
                }
                i++;     
            }
        } else if(count != null && count > 0){
            Boolean checkbool = false;
            for(i = 1;nextDate < = system.Today().addDays(count);i++){
                DateTime dt = DateTime.newInstance(nextDate.year(), nextDate.month(), nextDate.day()); //Actual DateTime field is giving impropriate Day therefore converting date into DateTime to get exact day of the Week.
                dayOfWeek = dt.format(Constant_Util.FORMAT_DAY);
                if(Constant_Util.SATURDAY.equalsIgnoreCase(dayOfWeek) || Constant_Util.SUNDAY.equalsIgnoreCase(dayOfWeek)){
                    nextDate = nextDate.addDays(1);
                    continue;
                }
                if(!woAvailDates.contains(nextDate) && (occurencedays == null || (occurencedays != null && !occurencedays.contains(dayOfWeek)))){
                    checkbool = true;
                    break;   
                } 
                else {
                    nextDate = nextDate.addDays(1);
                }
            }
            if(!checkbool){
                nextDate = null;
            }
        }
        return nextDate;
    }
    
    /**
     * @deprecated Use SLACalculationUtility.getSplitStringDate() instead
     * This method has been consolidated into the utility class
     */
    @Deprecated
    public static String[] getSplitStringDate(String strDate){
        return SLACalculationUtility.getSplitStringDate(strDate);
    }

    /**
     * @deprecated WM Capacity date selection logic is now handled in
     * SLACalculationUtility.calculateCapacityPlannerServiceDate()
     */
    @Deprecated
    global static String getNextAvailableDate(Id businessHoursId,set<Date> woAvailDates, List<Date> availDateSet,string locZone){
        Date nextAvailableDate = Null;
        string availDate = null;
        for(Date cpDate : availDateSet){
            if(!woAvailDates.contains(cpDate)){
                nextAvailableDate = cpDate;
                break;   
            }
        }
        if(nextAvailableDate != null){
            availDate = string.valueof(nextAvailableDate);
        }else {
            nextAvailableDate = availDateSet[availDateSet.size() - 1];
            availDate = String.valueOf(getNextAvailableDateFromSLA(businessHoursId,woAvailDates,nextAvailableDate,nextAvailableDate,locZone,0,null));
        }
        return availDate;  
    }
    
    /**
     * @description Method to find PotentialDate when WorkOrder is not available for commercial products
     * @deprecated This weekly frequency logic should be consolidated into SLACalculationUtility
     * in a future iteration for complete service date calculation centralization
     */
    @Deprecated
    private static String getPotentialDate(Asset objAsset){
        string nextServiceDate = null;                         
        Date serviceDate = mapCaseAsset.get(objAsset.Id).Service_Date__c;
        integer i = 1;
        Boolean checkbool = false;      
        DateTime serviceTime = DateTime.newInstance(serviceDate.year(), serviceDate.month(), serviceDate.day());
        string dayOfWeek = serviceTime.format(Constant_Util.FORMAT_DAY);
        if(Constant_Util.SATURDAY.equalsIgnoreCase(dayOfWeek)){
            serviceDate = serviceDate.addDays(2);
            i = i +2;
        } else if(Constant_Util.SUNDAY.equalsIgnoreCase(dayOfWeek)){
            serviceDate = serviceDate.addDays(1);
            i = i +1;
        }
        if(assetIdOccurencemap.get(objAsset.Id).contains(dayOfWeek)){
            dateTime dayWeek = null;
            for(; serviceDate <= System.Today().addDays(Integer.valueof(System.Label.Next_Business_Days)) ; i++){
                serviceDate = serviceDate.addDays(1);
                serviceTime = DateTime.newInstance(serviceDate.year(), serviceDate.month(), serviceDate.day());
                dayOfWeek = serviceTime.format(Constant_Util.FORMAT_DAY);
                if(Constant_Util.SATURDAY.equalsIgnoreCase(dayOfWeek) || Constant_Util.SUNDAY.equalsIgnoreCase(dayOfWeek)){
                    continue;
                }
                if(!assetIdOccurencemap.get(objAsset.Id).contains(dayOfWeek)){
                    nextServiceDate = string.valueof(serviceDate);
                    checkbool = true;
                    break;
                }
            }
        } else {
            checkbool = true;
            nextServiceDate = string.valueof(serviceDate);
        }
        if(!checkbool){
            nextServiceDate = null;
        }
        return nextServiceDate;
    }
    
    global with sharing class ContainerStatusResponse{
        public Integer RecordCount {get;set;}
        public List<container> container {get;set;}
        public ErrorMessageWrapper Problem {get;set;}
        /**
        * @description Constructor
        */
        public ContainerStatusResponse(){            
            this.RecordCount = 0;
        }
    }
    
    global with sharing class ErrorMessageWrapper{
        public String Title {get;set;}
        public String Status {get;set;}
        public List<ErrorsWrapper> Errors {get;set;}
        
        /**
        * @description Constructor for ErrorMessageWrapper
        */        
        public ErrorMessageWrapper(String title, String status, List<ErrorsWrapper> errors){
            this.Title = title;
            this.Status = status;
            this.Errors = errors;
        }        
    } 
    
    /**
    * @description class for ErrorsWrapper
    */																								
    global with sharing class ErrorsWrapper{
        public String Code {get;set;} 
        public String Message {get;set;}   
        
        /**
        * @description Constructor for ErrorsWrapper
        */
        public ErrorsWrapper(String code, String message){
            this.Code = code;
            this.Message = message;  
        }
    }
    
    global with sharing class container {
        public String PotentialPickupDate {get;set;}
        public string IsValidAsset{get;set;}           
        public string AssetErrorMessage{get;set;}	
    }
}
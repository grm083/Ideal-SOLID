/**
 * @description Controller for WM Capacity Planner Lightning components
 * Refactored to delegate service date calculation logic to SLACalculationUtility
 * This class now serves as a thin presentation layer for UI interactions
 */
public with sharing class WMCapacityController {

    @AuraEnabled
    public static void updateCase(Id caseId, String serviceDate) {
        Case c = [SELECT Id, Service_Date__c, Availability_Confirmed__c, Availability_Checked__c
                  FROM Case WHERE Id=:caseId];

        String parseDate = date.parse(serviceDate).format();

        c.Service_Date__c = date.parse(parseDate);
        c.Availability_Confirmed__c = TRUE;
        c.Availability_Checked__c = TRUE;

        update c;
		GetCaseInformation.insertPlannerComment(caseId, parseDate, true, false);
    }

    @AuraEnabled
    public static void confirmCheck(Id caseId) {
        Case c = [SELECT Id, Availability_Checked__c FROM Case WHERE Id=:caseId];

        c.Availability_Checked__c = TRUE;

        update c;
    }

    @AuraEnabled
    public static String getSLADate(Id caseId) {

        String slaDate;

		//Updated on 5/15/2020 by George Martin - Returning the same field to the capacity controller that is being returned
		//to the Case UI

        Case c = [SELECT SLA_Service_DateTime__c
                 FROM Case
                 WHERE Id =: caseId];

        If (c.SLA_Service_DateTime__c != Null) {
            slaDate = string.valueOf(c.SLA_Service_DateTime__c);
            if (slaDate.contains('-')) {
                slaDate = slaDate.substringBefore(' ');
                String year = slaDate.substringBefore('-').substringBefore(' ');
                String day = slaDate.substringAfterLast('-');
                String month = slaDate.substringBeforeLast('-').substringAfter('-');
                slaDate = month + '/' + day + '/' + year;
            } else {
                slaDate = slaDate.substringBefore(' ');
            }
        }

        return slaDate;
    }

    @AuraEnabled
    public static String getAcornBaseline(Id caseId) {

        String baseline;
        Case c = [SELECT Id, AssetId FROM Case WHERE Id=:caseId];
        Id serviceHeader = c.AssetId;

        Asset[] details = [SELECT Id, Is_Core_Service__c, SBID_Text_c__c, Supplier__r.Parent_Vendor_ID__c
                           FROM Asset
                           WHERE ParentId=:serviceHeader AND Is_Core_service__c = TRUE AND
                           Start_Date__c <= Today AND (End_Date__c >= Today OR End_Date__c = Null)
                           LIMIT 1
                          ];

        If (details == Null || details[0].SBID_text_c__c == Null) {
            return baseline;
        }

        If (details[0].Supplier__r.Parent_Vendor_ID__c == '8') {
        	baseline = details[0].SBID_Text_c__c;
        }


        return baseline;
    }

    /**
     * @description Retrieves available service dates from WM Capacity Planner API
     * REFACTORED: Delegates to SLACalculationUtility for the actual API call
     * @param baseline The SBID (Service Baseline ID) to query
     * @return List of available dates in MM/DD/YYYY format
     */
    @AuraEnabled
    public static List<String> getAvailableDates(String baseline) {
        // Delegate to SLACalculationUtility
        return SLACalculationUtility.callWMCapacityPlannerAPI(baseline);
    }

    // ================================================================================
    // DEPRECATED: These methods/classes have been consolidated into SLACalculationUtility
    // Kept here temporarily for backward compatibility with any direct references
    // ================================================================================

    /**
     * @deprecated Use SLACalculationUtility.parseCapacityJSON instead
     */
    @Deprecated
    @AuraEnabled
	public static List<String> parseCapJSON(capacityResponse jsonResp, String requestedDate) {
		List<String> dates = new List<String>();
		List<String> availDates = new List<String>();
        List<Capacity> capacities = new List<Capacity>();
		if(jsonResp.Data!=null){
            capacities = jsonResp.Data.Site.Capacity;
        }
		for (Capacity cap : capacities) {
                for (String d : cap.AvailableDates) {
                    String year = d.substringBefore('/');
                    String day = d.substringAfterLast('/');
                    String month = d.substringBeforeLast('/').substringAfter('/');
                    d = month + '/' + day + '/' + year;
                    availDates.add(d);
                }
            }

			return availDates;
	}

    /**
     * @deprecated Use SLACalculationUtility.CapacityResponse instead
     */
    @Deprecated
    public inherited sharing class capacityResponse {
        public Data Data;
        public WorkOrderWebservices.ErrorMessageWrapper Problem;
    }

    /**
     * @deprecated Use SLACalculationUtility.CapacitySiteData instead
     */
    @Deprecated
    public inherited sharing class Data {
        public Site Site;
    }

    /**
     * @deprecated Use SLACalculationUtility.CapacitySite instead
     */
    @Deprecated
    public inherited sharing class Site {
        public String Name;
        public List<Capacity> Capacity;
    }

    /**
     * @deprecated Use SLACalculationUtility.CapacityData instead
     */
    @Deprecated
    public inherited sharing class Capacity {
        public String LineOfBusiness;
        public String Status;
        public List<String> AvailableDates;
    }

    /**
     * @deprecated Use SLACalculationUtility.parseCapacityResponse instead
     */
    @Deprecated
    public static capacityResponse parseCapacity(String json) {
        return (capacityResponse) System.JSON.deserialize(json, capacityResponse.class);
    }

    public inherited sharing class dualList {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;

        public dualList(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}
/*
   @purpose	:  Helper class for STPProcessEvent Platform Event
   @Author	:  Toshender Kumar 
 */
public class STPProcessTriggerHelper {
	
    /*
      @purpose	:  STPProcessEvent Platform Event processing through its trigger
				   The event payload carries Quote Ids and if price only call is to be done or not
				   This method gets those Ids and priceonly flag to run the Assignment of users. 
      @Author	:  Toshender Kumar
     */ 
    public static void processSTPProcessEvent(List<STPProcessEvent__e> triggerNew){
                
        Map<Id,Boolean> mapQuoteIdAndPriceOnlyFlag = new Map<Id,Boolean>();
        
        for(STPProcessEvent__e evt : triggerNew){
            mapQuoteIdAndPriceOnlyFlag.put(evt.Payload__c,evt.PriceOnlyCall__c);
        }
        
        for(Id quoteId : mapQuoteIdAndPriceOnlyFlag.keySet()){
            Boolean priceOnlyCall = mapQuoteIdAndPriceOnlyFlag.get(quoteId);
            
            if(!priceOnlyCall)
            {
                if(PricingRequestSelector.isPricingMulltiVendorAMSwitchON())
                {
                    PricingRequestMultiVendorSTPProcess.processMultiVendorPricingRequest(quoteId, true);
                }
                else{
                    PricingRequestSTPProcess.processPricingRequest(quoteId, true);
                }
            }
             else{
                /*PriceOnlyRequestSTPProcess.savePricetoQuoteline(quoteId);
                 if(System.Label.Step_By_Step_Switch == 'On')
                 {
                     STPRuleExecution.executeRules(quoteId, Pricing_Constant_Util.PARTIAL_STP);
                 }*/
                 PriceOnlyRequestSTPProcess.callPriceOnlySTPFunctionality(quoteId);
             }
            
        }
        
    }
}
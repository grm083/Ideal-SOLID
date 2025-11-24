/*************************************************************************************************************************************************************
@ Class:          WorkOrderTriggerHelper 
@ Version:        1.0
@ Author:         DineshKumar 
@ Purpose:        Handler Class to Perform operations on WorkOrder & Case
--------------------------------------------------------------------------------------------------------------------------------------------------------------
@ Change history: 09.27.2019 / Nandhini/ Created the class
**************************************************************************************************************************************************************/
/*@Class Name- WorkOrderTriggerHelper
*@description- This class is used to Perform operations on WorkOrder & related case
*/
public without sharing class WorkOrderTriggerHelper{
    public static Boolean isCancelGenesys = false;
    /*@methodName- updateCaseDetail
*@description- Method to do updates Case details using workorder
*@param-Map<id,WorkOrder> woMap,Map<id,WorkOrder> oldWoMap,Map<id,Case> caseWOMap
*@return- null
*/   
    /*@methodName- updateCaseDetail
    *@description- REFACTORED: Delegates to CaseWorkOrderService.updateCasesFromWorkOrderChanges()
    *  This method now calls the service layer for all Case DML operations
    *@param-Map<id,WorkOrder> woMap,Map<id,WorkOrder> oldWoMap,Map<id,Case> caseWOMap
    *@return- null
    */
    public static void updateCaseDetail(Map<id,WorkOrder> woMap,Map<id,WorkOrder> oldWoMap,Map<id,Case> caseWOMap ){
        // REFACTORED: Delegate to service layer for Case DML operations
        CaseWorkOrderService.updateCasesFromWorkOrderChanges(woMap, oldWoMap, caseWOMap);
    }
    /**@MethodName ServiceDateChanges
    * Method to update task or close case when service date is changed for SDT-7434.
    **/
    Public Static void ServiceDateChanges(List<WorkOrder> woLst, Map<Id,WorkOrder> oldWoMap){
        Set<Id> caseIdSet = new Set<Id>();
        Map<Id, Date> caseWoMap = New Map<Id, Date>();
        Map<Id, String> caseMap = New Map<Id, String>();
        List<Task> updateTaskLst = new List<Task>();
        List<case> updateCaseLst = new List<case>();
        Id businessHoursId = [SELECT Id, FridayEndTime FROM BusinessHours WHERE Name =: Constant_Util.BUSINESSNAME AND
                                     IsActive = true LIMIT 1].Id;
        Long intervalMilliseconds = Long.valueof(string.valueof((decimal.valueOf(0)*3600000).round(System.RoundingMode.HALF_UP))); 
        DateTime closingBusinessTime = BusinessHours.addGmt(businessHoursId,system.now(),intervalMilliseconds);
        try {
            for(WorkOrder wo : woLst) {
                if(oldWoMap != null && oldWoMap.get(wo.Id).Service_Date__c != null && wo.Service_Date__c != null
                            && wo.Service_Date__c != oldWoMap.get(wo.Id).Service_Date__c && wo.CaseId != null) {          
                    //Obtain Schedule Confirmation Task
                    if(wo.Service_Date__c > system.today().adddays(14) ) {
                        caseMap.put(wo.CaseId, 'OSC');
                        caseIdSet.add(wo.CaseId);
                    }
                    if(wo.Service_Date__c < oldWoMap.get(wo.Id).Service_Date__c && wo.Service_Date__c >= system.today()){
                        if(closingBusinessTime <= system.now()) {
                            if(!caseWoMap.containsKey(wo.CaseId)) {
                                //To update dueDateTime on task
                                caseWoMap.put(wo.CaseId, wo.Service_Date__c);
                            }
                            caseIdSet.add(wo.CaseId);
                        } else {
                            caseIdSet.add(wo.CaseId);
                            //Send cancel genesys
                            isCancelGenesys = true;
                        }   
                    }   
                    if(wo.Service_Date__c < system.today()){
                        caseIdSet.add(wo.CaseId);
                        //Send cancel genesys
                        isCancelGenesys = true;
                    }
                    //All Confirm service Completion related task
                    if(wo.Service_Date__c >= system.today()) {            
                        if(!caseMap.containsKey(wo.CaseId)) {
                            caseMap.put(wo.CaseId, 'CSC');
                        }
                        caseIdSet.add(wo.CaseId);
                    }
                }
            }
            if(caseIdSet.size()>0) {
                String containsProcess = Constant_Util.PERCENTAGE + Constant_Util.CONFIRM_SERVICE_COMPLETION + Constant_Util.PERCENTAGE;
                for(Task tsk : [SELECT Id, WhatId, Process__c, status, Is_Attempt_Created__c FROM Task WHERE WhatId IN: caseIdSet
                                AND status =: Constant_Util.OPEN AND (Process__c =: Constant_Util.Obtain_Schedule_Confirmation
                                OR Process__c LIKE: containsProcess)]) {
                    if(caseWoMap.containsKey(tsk.WhatId)) {
                        tsk.Due_Date_Time__c = system.now().addhours(4);
                    } else {
                        tsk.status = Constant_Util.COMPLETED;
                        tsk.Is_Attempt_Created__c = true;
                        tsk.Description__c = 'This task has been automatically closed as workorder service date is changed';
                    }
                    updateTaskLst.add(tsk);                
                }
            }
            if(updateTaskLst != null && !updateTaskLst.isEmpty()){
                Database.saveResult[] dbsrLst = database.update(updateTaskLst,false);                
                UTIL_LoggingService.logDmlResults(dbsrLst,null,updateTaskLst,UTIL_ErrorConstants.ERROR_APPLICATION,UTIL_ErrorConstants.WORKORDER_TRIGGER_HELPER,UTIL_ErrorConstants.WORKORDER_UPDATE_CASE_DETAILS,UTIL_ErrorConstants.WORKORDER_TRIGGER,LoggingLevel.ERROR);
            }
            // REFACTORED: Delegate Case DML to service layer
            if(!caseMap.isEmpty()) {
                CaseWorkOrderService.updateCaseTaskFlagsForServiceDateChanges(caseMap);
            }
			  } catch(exception excp){
            UTIL_LoggingService.logHandledException(excp, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION,LoggingLevel.ERROR);
        }
    }

    /**@MethodName createCaseComment
    * Method to create Comment related to Case for SDT-18820
    **/
    public Static void createCaseComment(Map<String , List<WorkOrder>> commentWOMap){
        Map<String , Comment_Log_Detail__mdt> commentLogTemplateData = new Map<String , Comment_Log_Detail__mdt>();
        for(Comment_Log_Detail__mdt c : Comment_Log_Detail__mdt.getAll().values()){
            commentLogTemplateData.put(c.DeveloperName , c);
        }
        Map<String , String> fieldTemplateMap = new Map<String , String>();
        List<Comment__c> commentList = new List<Comment__c>();
        Set<String> dateTimeFields = new Set<String>();
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get('WorkOrder');
        Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
        for(Schema.SObjectField field : fieldMap.values()) {
            fieldTemplateMap.put('<' + field.getDescribe().getName() + '>' , field.getDescribe().getName());
            if(field.getDescribe().getType() == Schema.DisplayType.DateTime || field.getDescribe().getType() == Schema.DisplayType.Date){
                dateTimeFields.add('<' + field.getDescribe().getName() + '>');
            }
            
        }
        try {
            for(String key : commentWOMap.keySet()){
                for(WorkOrder wo : commentWOMap.get(key)){
                    String commentBody = commentLogTemplateData.containsKey(key) ? commentLogTemplateData.get(key).Comment__c : '';
                    Comment__c comment = new Comment__c();
                    comment.Case__c = wo.CaseId;
                    for(String field : fieldTemplateMap.keySet()){
                        if(fieldTemplateMap.get(field) != null && commentBody.contains(field)) {
                            String fieldValue = '';
                            if(dateTimeFields.contains(field)){
                                fieldValue = wo.get(fieldTemplateMap.get(field)) != null ? Date.valueOf(wo.get(fieldTemplateMap.get(field))).format() : '';
                            } else {
                                fieldValue = wo.get(fieldTemplateMap.get(field)) != null ? String.valueOf(wo.get(fieldTemplateMap.get(field))) : '';
                            }
                            commentBody = commentBody.replaceAll(field , fieldValue);
                        }   
                    }
                    comment.Comment__c = commentBody;
                    comment.Workflow_Action__c = Constant_Util.WORK_ORDER_ACTION_TYPE;
                    comment.Related_SObject_Id__c = wo.id;
                    comment.Related_SObject_Key__c = wo.Acorn_WorkOrder_Number__c;
                    comment.CreatedDate = System.now();
                    comment.is_Log__c = true;
                    commentList.add(comment);																			 
                }
            }
            Database.saveResult[] insertResult = Database.insert(commentList, false);
        } catch(exception excp){
            UTIL_LoggingService.logHandledException(excp, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION,LoggingLevel.ERROR);
        }
    }
}
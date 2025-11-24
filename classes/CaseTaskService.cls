/**
 * @description CaseTaskService - Service Layer for Case Task Management
 *
 * This service class handles all Task-related operations for Cases.
 * It provides centralized logic for task creation, assignment, completion tracking,
 * and task-driven business rules.
 *
 * Key Responsibilities:
 * - Create Tasks for Cases based on business rules
 * - Assign Tasks to appropriate users/queues
 * - Track task completion and update Case status accordingly
 * - Manage task priority and due dates
 *
 * Design Principles:
 * - Single Responsibility: Only handles Task operations
 * - Service Layer: No direct UI dependencies
 * - Testability: All methods are mockable and bulkified where possible
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer
 */
public class CaseTaskService {

    // ========================================================================
    // TASK CREATION METHODS
    // ========================================================================

    /**
     * @description Creates Tasks for Cases based on business rules
     * @param caseIds Set of Case Ids to create tasks for
     * @return List of created Tasks
     */
    public static List<Task> createTasksForCases(Set<Id> caseIds) {
        List<Task> tasksToInsert = new List<Task>();

        // TODO: Extract task creation logic from CaseTriggerHelper and CaseBusinessRuleService
        // This should consolidate all task creation patterns

        return tasksToInsert;
    }

    /**
     * @description Creates a single Task for a Case
     * @param caseId The Case Id
     * @param subject Task subject
     * @param priority Task priority
     * @param dueDate Task due date
     * @return Task Id of created task
     */
    public static Id createTask(Id caseId, String subject, String priority, Date dueDate) {
        Task newTask = new Task();
        newTask.WhatId = caseId;
        newTask.Subject = subject;
        newTask.Priority = priority;
        newTask.ActivityDate = dueDate;
        newTask.Status = Constant_Util.OPEN;

        try {
            insert newTask;
            return newTask.Id;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                'CaseTaskService.createTask',
                LoggingLevel.ERROR
            );
            return null;
        }
    }

    /**
     * @description Creates tasks for missing required information
     * @param caseIds Set of Case Ids needing required information tasks
     */
    public static void createRequiredInformationTasks(Set<Id> caseIds) {
        // TODO: Extract from CaseTriggerHelper
        // Creates tasks when required fields are missing
    }

    /**
     * @description Creates approval tasks for Cases
     * @param caseIds Set of Case Ids needing approval tasks
     */
    public static void createApprovalTasks(Set<Id> caseIds) {
        // TODO: Extract approval task logic
    }

    // ========================================================================
    // TASK ASSIGNMENT METHODS
    // ========================================================================

    /**
     * @description Assigns Task to appropriate user or queue
     * @param taskId The Task Id
     * @param assigneeId User or Queue Id to assign to
     * @return True if assignment successful
     */
    public static Boolean assignTask(Id taskId, Id assigneeId) {
        try {
            Task taskToUpdate = new Task(Id = taskId, OwnerId = assigneeId);
            update taskToUpdate;
            return true;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                'CaseTaskService.assignTask',
                LoggingLevel.ERROR
            );
            return false;
        }
    }

    /**
     * @description Assigns multiple tasks in bulk
     * @param taskAssignments Map of Task Id to Assignee Id
     */
    public static void assignTasksBulk(Map<Id, Id> taskAssignments) {
        List<Task> tasksToUpdate = new List<Task>();

        for (Id taskId : taskAssignments.keySet()) {
            tasksToUpdate.add(new Task(
                Id = taskId,
                OwnerId = taskAssignments.get(taskId)
            ));
        }

        if (!tasksToUpdate.isEmpty()) {
            try {
                update tasksToUpdate;
            } catch (Exception ex) {
                UTIL_LoggingService.logHandledException(
                    ex,
                    UserInfo.getOrganizationId(),
                    'CaseTaskService.assignTasksBulk',
                    LoggingLevel.ERROR
                );
            }
        }
    }

    // ========================================================================
    // TASK COMPLETION METHODS
    // ========================================================================

    /**
     * @description Completes a Task and updates related Case if needed
     * @param taskId The Task Id to complete
     * @return True if completion successful
     */
    public static Boolean completeTask(Id taskId) {
        try {
            Task taskToComplete = new Task(
                Id = taskId,
                Status = Constant_Util.COMPLETED
            );
            update taskToComplete;
            return true;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                'CaseTaskService.completeTask',
                LoggingLevel.ERROR
            );
            return false;
        }
    }

    /**
     * @description Checks if all required tasks are completed for a Case
     * @param caseId The Case Id
     * @return True if all required tasks are completed
     */
    public static Boolean areAllRequiredTasksCompleted(Id caseId) {
        List<Task> openTasks = [
            SELECT Id
            FROM Task
            WHERE WhatId = :caseId
            AND Status = :Constant_Util.OPEN
            AND Is_Required__c = true
            LIMIT 1
        ];

        return openTasks.isEmpty();
    }

    /**
     * @description Gets count of open tasks for a Case
     * @param caseId The Case Id
     * @return Count of open tasks
     */
    public static Integer getOpenTaskCount(Id caseId) {
        return [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :caseId
            AND Status = :Constant_Util.OPEN
        ];
    }

    // ========================================================================
    // TASK RETRIEVAL METHODS
    // ========================================================================

    /**
     * @description Gets open Tasks for a Case using CaseContextGetter
     * @param caseId The Case Id
     * @return List of open Tasks
     */
    public static List<Task> getOpenTasksForCase(Id caseId) {
        Map<Id, List<Task>> caseTaskMap = CaseContextGetter.getOpenTasksByCaseIds(new Set<Id>{caseId});
        List<Task> tasks = caseTaskMap.get(caseId);
        return tasks != null ? tasks : new List<Task>();
    }

    /**
     * @description Gets all Tasks for multiple Cases
     * @param caseIds Set of Case Ids
     * @return Map of Case Id to List of Tasks
     */
    public static Map<Id, List<Task>> getOpenTasksByCaseIds(Set<Id> caseIds) {
        return CaseContextGetter.getOpenTasksByCaseIds(caseIds);
    }

    // ========================================================================
    // CASE UPDATE METHODS (REFACTORED FROM TASKTRIGGERHELPER)
    // ========================================================================

    /**
     * @description Updates Case Availability_Confirmed flag when vendor confirms availability
     * REFACTORED: Extracted from TaskTriggerHelper.validateCase() lines 229-266
     *
     * @param taskMap Map of Task Id to Task record with Vendor Available outcome
     * @param relatedCaseMap Map of Case Id to Case record
     */
    public static void updateCaseAvailabilityFromTask(Map<Id, Task> taskMap, Map<Id, Case> relatedCaseMap) {
        if (taskMap == null || taskMap.isEmpty() || relatedCaseMap == null || relatedCaseMap.isEmpty()) {
            return;
        }

        List<Case> casesToUpdate = new List<Case>();

        try {
            for (Task t : taskMap.values()) {
                if (!String.isBlank(t.Process__c) &&
                    t.Process__c.contains(Constant_Util.Confirm_Vendor_Availability) &&
                    !String.isBlank(t.Outcome__c) &&
                    t.Outcome__c.contains(Constant_Util.Vendor_Available) &&
                    relatedCaseMap.containsKey(t.WhatId)) {

                    Case c = relatedCaseMap.get(t.WhatId);
                    c.Availability_Confirmed__c = true;
                    casesToUpdate.add(c);
                }
            }

            if (!casesToUpdate.isEmpty()) {
                CaseDMLService.getInstance().updateCases(casesToUpdate);
            }

        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                'CaseTaskService.updateCaseAvailabilityFromTask',
                LoggingLevel.ERROR
            );
        }
    }

    /**
     * @description Updates Case Last Agent ID based on Task updates
     * REFACTORED: Extracted from TaskTriggerHelper.lastAgentIdUpdate() lines 1036-1061
     * Delegates to CaseTriggerHelper.UpdateLocalAgentId() for business logic
     *
     * @param tasks List of Tasks being updated
     */
    public static void updateCaseLastAgentFromTasks(List<Task> tasks) {
        if (tasks == null || tasks.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        Map<Id, Case> caseMap = new Map<Id, Case>();
        List<Case> casesToUpdate = new List<Case>();

        try {
            // Build case map from tasks
            for (Task t : tasks) {
                if (t.WhatId != null && t.WhatId.getSObjectType() == Case.sObjectType) {
                    Case c = new Case(Id = t.WhatId);
                    caseMap.put(t.WhatId, c);
                }
            }

            // Only proceed if we have cases and the trigger is not skipped
            if (!caseMap.isEmpty() && !RecurrsiveTriggerHandler.isSkipCaseTriggerForTask) {
                // Delegate to CaseTriggerHelper for business logic
                casesToUpdate = CaseTriggerHelper.UpdateLocalAgentId(caseMap, new Map<Id, Case>(), false);

                if (!casesToUpdate.isEmpty()) {
                    CaseDMLService.getInstance().updateCases(casesToUpdate);
                }
            }

        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                'CaseTaskService.updateCaseLastAgentFromTasks',
                LoggingLevel.ERROR
            );
        }
    }

    /**
     * @description Updates Case team assignment details from Case Assignment tasks
     * REFACTORED: Extracted from TaskTriggerHelper.updateCaseDetails() lines 1163-1208
     * Handles both standard case assignment and escalation scenarios
     *
     * @param taskMap Map of Task Id to Task record
     */
    public static void updateCaseTeamFromAssignmentTasks(Map<Id, Task> taskMap) {
        if (taskMap == null || taskMap.isEmpty()) {
            return;
        }

        List<Case> casesToUpdate = new List<Case>();

        try {
            for (Task tsk : taskMap.values()) {
                // Standard Case Assignment process
                if (Constant_Util.CASE_ASSIGNMENT.equalsIgnoreCase(tsk.Process__c) &&
                    tsk.WhatId != null && tsk.WhatId.getSObjectType() == Case.sObjectType) {

                    Case c = new Case(Id = tsk.WhatId);

                    if (tsk.Task_Team_Name__c != null) {
                        // Team-based assignment
                        c.Team_Name__c = tsk.Task_Team_Name__c;
                        c.Team_Queue__c = tsk.Task_Team_Queue__c;
                        c.User_Name__c = null;
                    } else {
                        // User-based assignment
                        c.Team_Name__c = null;
                        c.Team_Queue__c = null;
                        c.User_Name__c = tsk.OwnerId;
                    }
                    casesToUpdate.add(c);
                }

                // Escalation Obtain Vendor Information scenario (SDT-21868)
                if (tsk.Subject == Constant_Util.STR_ESCALATION_OBTAIN_VENDOR_INFORMATION &&
                    !(Constant_Util.CASE_ASSIGNMENT.equalsIgnoreCase(tsk.Process__c)) &&
                    tsk.WhatId != null && tsk.WhatId.getSObjectType() == Case.sObjectType) {

                    Case ca = new Case(Id = tsk.WhatId);
                    ca.Team_Name__c = Constant_Util.Vendor_Relations_Mgmnt;
                    ca.Team_Queue__c = Constant_Util.VRM_Inquiry;
                    ca.User_Name__c = null;
                    casesToUpdate.add(ca);
                }
            }

            if (!casesToUpdate.isEmpty()) {
                // Set recursive trigger flag to prevent loops
                RecurrsiveTriggerHandler.isSkipcaseTrigger = true;

                CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCases(casesToUpdate);

                // Error handling is done in CaseDMLService, but log if needed
                if (result.hasErrors) {
                    for (CaseDMLService.DMLError error : result.errors) {
                        System.debug('Error updating case team assignment: ' + error.message);
                    }
                }
            }

        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                'CaseTaskService.updateCaseTeamFromAssignmentTasks',
                LoggingLevel.ERROR
            );
        }
    }

    // ========================================================================
    // HELPER METHODS AND INNER CLASSES
    // ========================================================================

    /**
     * @description Result wrapper for task operations
     */
    public class TaskOperationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Id taskId { get; set; }
        @AuraEnabled public String errorMessage { get; set; }

        public TaskOperationResult(Boolean success, Id taskId, String error) {
            this.success = success;
            this.taskId = taskId;
            this.errorMessage = error;
        }
    }
}

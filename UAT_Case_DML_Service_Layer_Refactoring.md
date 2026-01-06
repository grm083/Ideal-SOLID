# User Acceptance Testing (UAT) Checklist
## Case DML Service Layer Refactoring

**Version:** 1.0
**Date:** 2026-01-06
**Commit:** 17e5cac
**Branch:** claude/review-apex-triggers-01WbjqS5TbEr9Q3uVkuUpRYr

---

## Executive Summary

This refactoring migrated all Case DML operations from WorkOrder and Task triggers to a centralized Service Layer architecture. While the underlying business logic **remains unchanged**, the code structure has been reorganized for better maintainability, error handling, and testability.

**What Changed:**
- ✅ Case updates now flow through `CaseDMLService` (centralized DML layer)
- ✅ Business logic moved to `CaseWorkOrderService` and `CaseTaskService`
- ✅ Improved error logging and transaction management
- ❌ **NO changes to business rules or Case status workflows**

**Testing Objective:**
Verify that all Case status transitions, field updates, and business rules continue to work exactly as before the refactoring.

---

## Pre-Test Setup

### Required Test Data

1. **Test Accounts:**
   - Vendor Account with `Contact_Manually_Vendor__c = true`
   - Vendor Account with `Contact_Manually_Vendor__c = false`
   - Customer Location Account

2. **Test Cases:**
   - At least 5 Cases in different statuses (New, Open, Closed)
   - Cases with various `Case_Sub_Status__c` values
   - Cases with and without Work Orders
   - Cases with `Availability_Confirmed__c = true` and `false`

3. **Test Users:**
   - Service Agent user
   - Vendor Relations Management user
   - System Administrator

4. **Test WorkOrders:**
   - WorkOrders in various statuses (Issued, Sent, Accepted, Cancelled, etc.)
   - WorkOrders with different `Vendor_Service_Status__c` values
   - WorkOrders with Acorn integration enabled

5. **Test Tasks:**
   - "Confirm Vendor Availability" tasks
   - "Case Assignment" tasks
   - "Escalation Obtain Vendor Information" tasks

---

## Test Scenarios

### Section 1: WorkOrder-Driven Case Updates

#### Test Group A: Proposed Service Date Updates

**Test Case 1.1: Update Proposed Service Date from WorkOrder Service_Date__c**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create a Case with Status = "Open" | Case created successfully | ☐ |
| 2 | Create a WorkOrder for the Case | WorkOrder linked to Case | ☐ |
| 3 | Update WorkOrder `Service_Date__c` to 7 days from today | WorkOrder updates successfully | ☐ |
| 4 | Update WorkOrder `Vendor_Service_Status__c` to a different value | Status changes | ☐ |
| 5 | Verify Case `Proposed_Service_Date__c` | Should equal WorkOrder `Service_Date__c` | ☐ |

**Test Case 1.2: Update Proposed Service Date from WorkOrder Rescheduled_Date__c**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Use existing Open Case with WorkOrder | - | ☐ |
| 2 | Update WorkOrder `Rescheduled_Date__c` to 10 days from today | WorkOrder updates | ☐ |
| 3 | Update WorkOrder `Vendor_Service_Status__c` | Status changes | ☐ |
| 4 | Verify Case `Proposed_Service_Date__c` | Should equal WorkOrder `Rescheduled_Date__c.Date()` | ☐ |

**Test Case 1.3: Proposed Service Date NOT Updated for Closed Cases**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create a Case with Status = "Closed" | Case created | ☐ |
| 2 | Create a WorkOrder for the Case | WorkOrder linked | ☐ |
| 3 | Update WorkOrder `Service_Date__c` | WorkOrder updates | ☐ |
| 4 | Verify Case `Proposed_Service_Date__c` | Should **NOT** change | ☐ |

---

#### Test Group B: Pending Manual Dispatch Status

**Test Case 2.1: Set Case to Pending Manual Dispatch (Manual Vendor)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open", `Case_Sub_Status__c` = "Pending Service Integration" | Case created | ☐ |
| 2 | Create WorkOrder with `Vendor_Account_Id__c` = Manual Vendor (Contact_Manually_Vendor__c = true) | WorkOrder created | ☐ |
| 3 | Update WorkOrder `Acorn_WorkOrder_Number__c` to "WO-12345" | WorkOrder updates | ☐ |
| 4 | Ensure Case `Service_Date__c` >= `Service_date_from_local_time__c` | Dates configured | ☐ |
| 5 | Set WorkOrder `Is_Bypass__c` = false | Configured | ☐ |
| 6 | Verify Case `Case_Sub_Status__c` | Should be "Pending Manual Dispatch" | ☐ |
| 7 | Verify Case `Status` | Should remain "Open" | ☐ |

**Test Case 2.2: Pending Dispatch for Non-Manual Vendors**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open", `Case_Sub_Status__c` = "Pending Service Integration" | Case created | ☐ |
| 2 | Create WorkOrder with `Vendor_Account_Id__c` = Non-Manual Vendor (Contact_Manually_Vendor__c = false) | WorkOrder created | ☐ |
| 3 | Update WorkOrder Status to "Issued" OR "Sent" with `send_status__c` = "Scheduled" | WorkOrder updates | ☐ |
| 4 | Verify Case `Case_Sub_Status__c` | Should be "Pending Dispatch" | ☐ |

**Test Case 2.3: Acorn Source System Handling**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with `Source_System__c` = "Acorn", Status = "Open" | Case created | ☐ |
| 2 | Create WorkOrder and set Status to "Issued" | WorkOrder created | ☐ |
| 3 | Verify Case `Case_Sub_Status__c` | Should be "Pending Dispatch" | ☐ |

---

#### Test Group C: Service Confirmation Statuses

**Test Case 3.1: Service Not Performed (Confirmed Negative)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open" | Case created | ☐ |
| 2 | Create WorkOrder for the Case | WorkOrder linked | ☐ |
| 3 | Update WorkOrder `Vendor_Service_Status__c` to contain "Confirmed - Negative" | WorkOrder updates | ☐ |
| 4 | Verify Case Status | Should be "Closed" | ☐ |
| 5 | Verify Case `Case_Sub_Status__c` | Should be "Service Not Performed" | ☐ |
| 6 | Verify Related Case Created | A new related Case should be created via `CaseCreation.createRelatedCase()` | ☐ |

**Test Case 3.2: Service Confirmed (Confirmed Positive) - Open Case**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open", `Case_Sub_Status__c` ≠ "Pending Manual Dispatch" | Case created | ☐ |
| 2 | Create WorkOrder with Status = "Sent" or "Accepted" or "Work Complete" | WorkOrder created | ☐ |
| 3 | Update WorkOrder `Vendor_Service_Status__c` from null to "Confirmed - Positive" | Status changes | ☐ |
| 4 | Verify Case Status | Should be "Closed" | ☐ |
| 5 | Verify Case `Case_Sub_Status__c` | Should be "Service Confirmed" | ☐ |

**Test Case 3.3: Service Confirmed (Confirmed Positive) - Already Closed Case**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Closed" | Case created | ☐ |
| 2 | Create WorkOrder | WorkOrder created | ☐ |
| 3 | Update WorkOrder `Vendor_Service_Status__c` to "Confirmed - Positive" | Status changes | ☐ |
| 4 | Verify Case `Case_Sub_Status__c` | Should be "Service Confirmed" | ☐ |
| 5 | Verify Case Status | Should remain "Closed" | ☐ |

**Test Case 3.4: Pending Service Confirmation**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open", `Availability_Confirmed__c` = true | Case created | ☐ |
| 2 | Create WorkOrder with `Send_Status__c` = "Sent" or "Delivered" | WorkOrder created | ☐ |
| 3 | Set Case `Service_Date__c` to tomorrow or later | Date configured | ☐ |
| 4 | Ensure WorkOrder Status is NOT "Accepted", "Cancelled", or "Closed" | Status configured | ☐ |
| 5 | Verify Case `Case_Sub_Status__c` | Should be "Pending Service Confirmation" | ☐ |
| 6 | Verify Case Status | Should be "Open" | ☐ |

**Test Case 3.5: Pending Schedule Confirmation**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open", `Availability_Confirmed__c` = **false** | Case created | ☐ |
| 2 | Create WorkOrder with `Send_Status__c` = "Sent" or "Delivered" | WorkOrder created | ☐ |
| 3 | Set Case `Service_Date__c` to tomorrow or later | Date configured | ☐ |
| 4 | Ensure WorkOrder Status is NOT "Accepted", "Cancelled", or "Closed" | Status configured | ☐ |
| 5 | Verify Case `Case_Sub_Status__c` | Should be "Pending Schedule Confirmation" | ☐ |

**Test Case 3.6: Pending Service Confirmation (Past Service Date)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open" | Case created | ☐ |
| 2 | Create WorkOrder with Status = "New" | WorkOrder created | ☐ |
| 3 | Set WorkOrder `Service_Date__c` to yesterday | Date in past | ☐ |
| 4 | Update WorkOrder Status from "New" to "Sent" | Status changes | ☐ |
| 5 | Verify WorkOrder `Vendor_Service_Status__c` is blank or "Scheduled" | Status checked | ☐ |
| 6 | Verify Case `Case_Sub_Status__c` | Should be "Pending Service Confirmation" | ☐ |

---

#### Test Group D: Request Cancellation

**Test Case 4.1: Request Canceled when WorkOrder Cancelled**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open", `Case_Sub_Status__c` = "Pending Dispatch" | Case created | ☐ |
| 2 | Create WorkOrder with Status = "Sent" | WorkOrder created | ☐ |
| 3 | Update WorkOrder Status from "Sent" to "Cancelled" | Status changes | ☐ |
| 4 | Verify Case Status | Should be "Closed" | ☐ |
| 5 | Verify Case `Case_Sub_Status__c` | Should be "Request Canceled" | ☐ |

**Test Case 4.2: No Change if Already Request Canceled**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Closed", `Case_Sub_Status__c` = "Request Canceled" | Case created | ☐ |
| 2 | Create WorkOrder with Status = "Sent" | WorkOrder created | ☐ |
| 3 | Update WorkOrder Status to "Cancelled" | Status changes | ☐ |
| 4 | Verify Case `Case_Sub_Status__c` | Should remain "Request Canceled" | ☐ |

---

#### Test Group E: WorkOrder Rejection

**Test Case 5.1: Case Closed when WorkOrder Rejected**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open" | Case created | ☐ |
| 2 | Create WorkOrder with Status = "Issued" | WorkOrder created | ☐ |
| 3 | Update WorkOrder Status to "Rejected" | Status changes | ☐ |
| 4 | Verify Case Status | Should be "Closed" | ☐ |

---

#### Test Group F: Service Date Change Flags

**Test Case 6.1: Reset Is_Case_OSC_Created__c when Service Date > 14 days**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with `Is_Case_OSC_Created__c` = true | Case created | ☐ |
| 2 | Create WorkOrder with `Service_Date__c` = 7 days from today | WorkOrder created | ☐ |
| 3 | Update WorkOrder `Service_Date__c` to 20 days from today | Date changes | ☐ |
| 4 | Verify Case `Is_Case_OSC_Created__c` | Should be **false** (reset) | ☐ |

**Test Case 6.2: Reset Is_Case_CSC_Created__c when Service Date >= today**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with `Is_Case_CSC_Created__c` = true | Case created | ☐ |
| 2 | Create WorkOrder with `Service_Date__c` = yesterday | WorkOrder created | ☐ |
| 3 | Update WorkOrder `Service_Date__c` to today or later | Date changes | ☐ |
| 4 | Verify Case `Is_Case_CSC_Created__c` | Should be **false** (reset) | ☐ |

---

### Section 2: Task-Driven Case Updates

#### Test Group G: Vendor Availability Confirmation

**Test Case 7.1: Set Availability_Confirmed__c when Vendor Available**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with `Availability_Confirmed__c` = false | Case created | ☐ |
| 2 | Create Task with `Process__c` = "Confirm Vendor Availability" | Task created | ☐ |
| 3 | Update Task `Outcome__c` to "Vendor Available" | Outcome set | ☐ |
| 4 | Verify Case `Availability_Confirmed__c` | Should be **true** | ☐ |

**Test Case 7.2: No Change if Outcome is NOT "Vendor Available"**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with `Availability_Confirmed__c` = false | Case created | ☐ |
| 2 | Create Task with `Process__c` = "Confirm Vendor Availability" | Task created | ☐ |
| 3 | Update Task `Outcome__c` to "Vendor Unavailable" | Outcome set | ☐ |
| 4 | Verify Case `Availability_Confirmed__c` | Should remain **false** | ☐ |

---

#### Test Group H: Case Team Assignment

**Test Case 8.1: Assign Case to Team (Team-Based Assignment)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case | Case created | ☐ |
| 2 | Create Task with `Process__c` = "Case Assignment" | Task created | ☐ |
| 3 | Set Task `Task_Team_Name__c` = "Service Operations" | Team set | ☐ |
| 4 | Set Task `Task_Team_Queue__c` = "SO Queue" | Queue set | ☐ |
| 5 | Save Task | Task saved | ☐ |
| 6 | Verify Case `Team_Name__c` | Should be "Service Operations" | ☐ |
| 7 | Verify Case `Team_Queue__c` | Should be "SO Queue" | ☐ |
| 8 | Verify Case `User_Name__c` | Should be **null** | ☐ |

**Test Case 8.2: Assign Case to User (User-Based Assignment)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case | Case created | ☐ |
| 2 | Create Task with `Process__c` = "Case Assignment" | Task created | ☐ |
| 3 | Set Task `Task_Team_Name__c` = **null** | No team | ☐ |
| 4 | Set Task `OwnerId` to a specific User | Owner set | ☐ |
| 5 | Save Task | Task saved | ☐ |
| 6 | Verify Case `Team_Name__c` | Should be **null** | ☐ |
| 7 | Verify Case `Team_Queue__c` | Should be **null** | ☐ |
| 8 | Verify Case `User_Name__c` | Should be the Task Owner's User ID | ☐ |

**Test Case 8.3: Escalation Obtain Vendor Information (SDT-21868)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case | Case created | ☐ |
| 2 | Create Task with `Subject` = "Escalation Obtain Vendor Information" | Task created | ☐ |
| 3 | Ensure `Process__c` is **NOT** "Case Assignment" | Process different | ☐ |
| 4 | Save Task | Task saved | ☐ |
| 5 | Verify Case `Team_Name__c` | Should be "Vendor Relations Management" | ☐ |
| 6 | Verify Case `Team_Queue__c` | Should be "VRM Inquiry" | ☐ |
| 7 | Verify Case `User_Name__c` | Should be **null** | ☐ |

---

#### Test Group I: Last Agent ID Update

**Test Case 9.1: Update Last Agent ID from Task**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case | Case created | ☐ |
| 2 | Create Task related to Case | Task created | ☐ |
| 3 | Update Task (e.g., change Status) | Task updates | ☐ |
| 4 | Check if `RecurrsiveTriggerHandler.isSkipCaseTriggerForTask` = false | Flag checked | ☐ |
| 5 | Verify Case Last Agent ID is updated | (Verify via `CaseTriggerHelper.UpdateLocalAgentId()` logic) | ☐ |

**Test Case 9.2: Skip Update if Recursive Trigger Flag is True**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Set `RecurrsiveTriggerHandler.isSkipCaseTriggerForTask` = true | Flag set | ☐ |
| 2 | Create and update Task | Task updates | ☐ |
| 3 | Verify Case Last Agent ID is **NOT** updated | No change | ☐ |

---

### Section 3: Bulk Operations & Performance

#### Test Group J: Bulkification Testing

**Test Case 10.1: Bulk WorkOrder Updates (100 Records)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create 100 Cases | Cases created | ☐ |
| 2 | Create 100 WorkOrders (1 per Case) | WorkOrders created | ☐ |
| 3 | Bulk update all 100 WorkOrders `Service_Date__c` | All update successfully | ☐ |
| 4 | Verify all 100 Cases have updated `Proposed_Service_Date__c` | All updated correctly | ☐ |
| 5 | Check Debug Logs for governor limits | No governor limit errors | ☐ |

**Test Case 10.2: Bulk Task Updates (100 Records)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create 100 Cases | Cases created | ☐ |
| 2 | Create 100 "Case Assignment" Tasks | Tasks created | ☐ |
| 3 | Bulk update all 100 Tasks with team assignments | All update successfully | ☐ |
| 4 | Verify all 100 Cases have updated team fields | All updated correctly | ☐ |
| 5 | Check Debug Logs for governor limits | No governor limit errors | ☐ |

**Test Case 10.3: Batch Processing (>1 Record, Non-Batch Context)**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create 5 Cases with WorkOrders | Created | ☐ |
| 2 | Bulk update 5 WorkOrders to trigger Case updates | Updated | ☐ |
| 3 | Verify `SObjectUpdateBatch` is **NOT** invoked (since not in batch/future context and >1 record) | Batch executed for volume | ☐ |
| 4 | Verify all 5 Cases updated successfully | All updated | ☐ |

---

### Section 4: Error Handling & Edge Cases

#### Test Group K: Error Scenarios

**Test Case 11.1: Null Pointer Exception Handling**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create WorkOrder with `CaseId` = null | WorkOrder created without Case | ☐ |
| 2 | Update WorkOrder fields | WorkOrder updates | ☐ |
| 3 | Verify no errors thrown | System handles gracefully | ☐ |
| 4 | Check Debug Logs for error logging | Errors logged via `UTIL_LoggingService` if any | ☐ |

**Test Case 11.2: DML Exception Handling**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with required fields | Case created | ☐ |
| 2 | Remove a required field from Case (via API/test) | Field null | ☐ |
| 3 | Trigger Case update via WorkOrder change | Update attempted | ☐ |
| 4 | Verify DML error is caught and logged | Error logged via `CaseDMLService` | ☐ |
| 5 | Verify system doesn't crash | Other records process successfully (partial success) | ☐ |

**Test Case 11.3: Empty Collections Handling**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Call `CaseWorkOrderService.updateCasesFromWorkOrderChanges()` with empty maps | Method called | ☐ |
| 2 | Verify method returns immediately (early exit) | No errors | ☐ |
| 3 | Verify no DML operations performed | No database hits | ☐ |

---

### Section 5: Integration & Regression Testing

#### Test Group L: Integration Points

**Test Case 12.1: CaseCreation.createRelatedCase() Integration**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Case with Status = "Open" | Case created | ☐ |
| 2 | Create WorkOrder | WorkOrder created | ☐ |
| 3 | Set WorkOrder `Vendor_Service_Status__c` = "Confirmed - Negative" | Status set | ☐ |
| 4 | Verify `CaseCreation.createRelatedCase()` is invoked | Method called | ☐ |
| 5 | Verify related Case is created | New Case exists | ☐ |

**Test Case 12.2: RecurrsiveTriggerHandler Flag Handling**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Verify `RecurrsiveTriggerHandler.isSkipcaseTrigger` is set to **true** before Case updates in Task scenarios | Flag set correctly | ☐ |
| 2 | Trigger multiple Task updates | Updates processed | ☐ |
| 3 | Verify recursive triggers are prevented | No infinite loops | ☐ |

**Test Case 12.3: CaseTriggerHelper.UpdateLocalAgentId() Delegation**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Create Task related to Case | Task created | ☐ |
| 2 | Update Task to trigger Last Agent ID update | Task updated | ☐ |
| 3 | Verify `CaseTriggerHelper.UpdateLocalAgentId()` is called | Business logic executed | ☐ |
| 4 | Verify Case Last Agent ID is updated correctly | Correct value set | ☐ |

---

### Section 6: Logging & Monitoring

#### Test Group M: Logging Validation

**Test Case 13.1: Success Logging**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Perform any successful Case update via WorkOrder | Update succeeds | ☐ |
| 2 | Check Debug Logs | Success logged appropriately | ☐ |
| 3 | Verify `CaseDMLService.DMLResult.isSuccess()` returns **true** | Success confirmed | ☐ |

**Test Case 13.2: Error Logging via UTIL_LoggingService**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Force a DML error (e.g., exceed field length) | Error occurs | ☐ |
| 2 | Verify error is logged via `UTIL_LoggingService.logHandledException()` | Error logged | ☐ |
| 3 | Verify `CaseDMLService.DMLResult.hasErrors` = **true** | Error captured | ☐ |
| 4 | Verify `CaseDMLService.DMLResult.errors` contains error details | Details available | ☐ |

**Test Case 13.3: DMLResult Error Details**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Trigger a validation rule failure on Case update | Validation fails | ☐ |
| 2 | Capture `CaseDMLService.DMLResult` | Result captured | ☐ |
| 3 | Verify `DMLResult.errors[0].message` contains validation rule message | Message present | ☐ |
| 4 | Verify `DMLResult.errors[0].recordId` points to failed Case | Record ID correct | ☐ |

---

### Section 7: Backward Compatibility

#### Test Group N: Existing Functionality Validation

**Test Case 14.1: Existing Batch Jobs Still Work**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Run `SObjectUpdateBatch` with Cases | Batch executes | ☐ |
| 2 | Verify Cases are updated via `CaseDMLService` | Updates successful | ☐ |
| 3 | Check for errors in batch execution | No errors | ☐ |

**Test Case 14.2: API/Integrations Still Function**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Trigger WorkOrder update via API (e.g., Acorn integration) | Update received | ☐ |
| 2 | Verify Case is updated correctly | Case updated | ☐ |
| 3 | Verify no integration errors | Integration works | ☐ |

**Test Case 14.3: Existing Test Classes Pass**

| **Step** | **Action** | **Expected Result** | **Pass/Fail** |
|----------|-----------|---------------------|---------------|
| 1 | Run all existing test classes for: <br/>- `WorkOrderTriggerHandler` <br/>- `WorkOrderTriggerHelper` <br/>- `TaskTriggerHandler` <br/>- `TaskTriggerHelper` | Tests execute | ☐ |
| 2 | Verify all tests **pass** | 100% pass rate | ☐ |
| 3 | Verify code coverage remains >= 75% | Coverage maintained | ☐ |

---

## Test Execution Tracking

### Overall Summary

| **Test Group** | **Total Tests** | **Passed** | **Failed** | **Blocked** | **Pass %** |
|----------------|-----------------|------------|------------|-------------|------------|
| A: Proposed Service Date | 3 | ☐ | ☐ | ☐ | ☐ |
| B: Pending Manual Dispatch | 3 | ☐ | ☐ | ☐ | ☐ |
| C: Service Confirmation | 6 | ☐ | ☐ | ☐ | ☐ |
| D: Request Cancellation | 2 | ☐ | ☐ | ☐ | ☐ |
| E: WorkOrder Rejection | 1 | ☐ | ☐ | ☐ | ☐ |
| F: Service Date Flags | 2 | ☐ | ☐ | ☐ | ☐ |
| G: Vendor Availability | 2 | ☐ | ☐ | ☐ | ☐ |
| H: Case Team Assignment | 3 | ☐ | ☐ | ☐ | ☐ |
| I: Last Agent ID | 2 | ☐ | ☐ | ☐ | ☐ |
| J: Bulk Operations | 3 | ☐ | ☐ | ☐ | ☐ |
| K: Error Handling | 3 | ☐ | ☐ | ☐ | ☐ |
| L: Integration Points | 3 | ☐ | ☐ | ☐ | ☐ |
| M: Logging Validation | 3 | ☐ | ☐ | ☐ | ☐ |
| N: Backward Compatibility | 3 | ☐ | ☐ | ☐ | ☐ |
| **TOTAL** | **39** | **☐** | **☐** | **☐** | **☐** |

---

## Sign-Off

### UAT Team Sign-Off

| **Name** | **Role** | **Date** | **Signature** | **Status** |
|----------|----------|----------|---------------|------------|
| __________ | QA Lead | ______ | __________ | ☐ Approved / ☐ Rejected |
| __________ | Business Analyst | ______ | __________ | ☐ Approved / ☐ Rejected |
| __________ | Product Owner | ______ | __________ | ☐ Approved / ☐ Rejected |
| __________ | Technical Lead | ______ | __________ | ☐ Approved / ☐ Rejected |

### Defect Summary

| **Defect ID** | **Test Case** | **Severity** | **Description** | **Status** |
|---------------|---------------|--------------|-----------------|------------|
| | | | | |
| | | | | |
| | | | | |

---

## Notes & Observations

**General Comments:**
- _[Add any observations, concerns, or recommendations here]_

**Performance Metrics:**
- Average response time for Case updates: _________
- Peak concurrent WorkOrder/Task updates handled: _________
- Governor limit usage (DML rows): _________

**Recommendations for Production Deployment:**
- ☐ Deploy during low-traffic window
- ☐ Monitor error logs closely for first 24 hours
- ☐ Have rollback plan ready
- ☐ Notify integration partners (Acorn, etc.) of deployment

---

## Appendix A: Test Data Scripts

### Sample Test Data Creation (Anonymous Apex)

```apex
// Create Test Accounts
Account vendor = new Account(
    Name = 'Test Vendor - Manual',
    Contact_Manually_Vendor__c = true
);
insert vendor;

Account location = new Account(
    Name = 'Test Customer Location',
    ParentId = vendor.Id
);
insert location;

// Create Test Case
Case testCase = new Case(
    Subject = 'UAT Test Case',
    Status = 'Open',
    Case_Sub_Status__c = 'Pending Service Integration',
    Service_Date__c = System.today().addDays(7),
    Availability_Confirmed__c = false
);
insert testCase;

// Create Test WorkOrder
WorkOrder testWO = new WorkOrder(
    CaseId = testCase.Id,
    Status = 'New',
    Service_Date__c = System.today().addDays(7),
    Vendor_Account_Id__c = vendor.Id,
    Customer_Location__c = location.Id
);
insert testWO;

// Create Test Task
Task testTask = new Task(
    WhatId = testCase.Id,
    Subject = 'Test Task',
    Process__c = 'Confirm Vendor Availability',
    Status = 'Open'
);
insert testTask;

System.debug('Test Data Created:');
System.debug('Case ID: ' + testCase.Id);
System.debug('WorkOrder ID: ' + testWO.Id);
System.debug('Task ID: ' + testTask.Id);
```

---

## Appendix B: Known Behaviors (Not Defects)

1. **Batch Processing:** When updating >1 Case outside of batch/future context, `SObjectUpdateBatch` is used for volume handling
2. **Recursive Trigger Prevention:** `RecurrsiveTriggerHandler` flags prevent infinite loops
3. **Partial Success:** `CaseDMLService` uses `optAllOrNone = false`, allowing partial DML success
4. **Empty oldWoRecord:** When no old WorkOrder record exists, an empty `WorkOrder()` object is created for comparison

---

**End of UAT Checklist**

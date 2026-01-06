# UAT Quick Reference Guide
## Case DML Service Layer Refactoring

**Version:** 1.0
**Commit:** 17e5cac
**Testing Duration:** 2-3 days recommended

---

## What Was Changed?

🔄 **Code Structure** - All Case update operations now go through a centralized service layer
✅ **Business Logic** - **NO CHANGES** - All Case workflows work exactly as before
📊 **Error Handling** - Improved logging and error management

---

## Critical Test Scenarios (Top 10)

### Priority 1: Must Test ⭐⭐⭐

#### 1. WorkOrder Service Date → Case Proposed Service Date
**Given:** Open Case with WorkOrder
**When:** Update WorkOrder `Service_Date__c` to next week
**Then:** Case `Proposed_Service_Date__c` should match WorkOrder date

---

#### 2. Service Confirmed (Positive)
**Given:** Open Case with WorkOrder
**When:** Set WorkOrder `Vendor_Service_Status__c` = "Confirmed - Positive"
**Then:** Case Status = "Closed", Sub-Status = "Service Confirmed"

---

#### 3. Service Not Performed (Negative)
**Given:** Open Case with WorkOrder
**When:** Set WorkOrder `Vendor_Service_Status__c` = "Confirmed - Negative"
**Then:** Case Status = "Closed", Sub-Status = "Service Not Performed"
**And:** New related Case is created

---

#### 4. Request Canceled
**Given:** Open Case with WorkOrder Status = "Sent"
**When:** Change WorkOrder Status to "Cancelled"
**Then:** Case Status = "Closed", Sub-Status = "Request Canceled"

---

#### 5. Pending Manual Dispatch
**Given:** Open Case with Manual Vendor (Contact_Manually_Vendor__c = true)
**When:** Set WorkOrder `Acorn_WorkOrder_Number__c`
**Then:** Case Sub-Status = "Pending Manual Dispatch"

---

### Priority 2: Should Test ⭐⭐

#### 6. Vendor Availability Confirmation
**Given:** Case with Task Process = "Confirm Vendor Availability"
**When:** Set Task Outcome = "Vendor Available"
**Then:** Case `Availability_Confirmed__c` = true

---

#### 7. Case Assignment - Team
**Given:** Case
**When:** Create Task with Process = "Case Assignment", set Team Name/Queue
**Then:** Case `Team_Name__c` and `Team_Queue__c` populated, `User_Name__c` = null

---

#### 8. Case Assignment - User
**Given:** Case
**When:** Create Task with Process = "Case Assignment", NO Team Name
**Then:** Case `User_Name__c` = Task Owner, Team fields = null

---

#### 9. Bulk Operations (100 Records)
**Given:** 100 Cases with WorkOrders
**When:** Bulk update all WorkOrders
**Then:** All 100 Cases update successfully, no governor limit errors

---

#### 10. WorkOrder Rejection
**Given:** Open Case with WorkOrder
**When:** Set WorkOrder Status = "Rejected"
**Then:** Case Status = "Closed"

---

## Quick Test Checklist

Use this for rapid smoke testing:

```
☐ Service Date changes update Case
☐ Confirmed Positive closes Case
☐ Confirmed Negative closes Case + creates related Case
☐ Cancelled WorkOrder closes Case
☐ Rejected WorkOrder closes Case
☐ Manual Dispatch works for manual vendors
☐ Vendor Available updates Case flag
☐ Team assignment updates Case
☐ User assignment updates Case
☐ 100+ records update without errors
☐ Error logging works (check Debug Logs)
☐ Existing test classes still pass
```

---

## How to Find Issues

### 1. Check Debug Logs
**Developer Console → Logs → Filter: "UTIL_LoggingService"**

Look for:
- `CaseDMLService` errors
- `CaseWorkOrderService` exceptions
- `CaseTaskService` exceptions

### 2. Verify Case History
**Case Record → Related → Case History**

Confirm Case Status/Sub-Status changes are tracked

### 3. Monitor Governor Limits
**Developer Console → Logs → Filter: "MAXIMUM"**

Ensure no:
- DML row limit exceeded
- SOQL query limit exceeded
- CPU time limit exceeded

---

## Common Issues & Solutions

### Issue: Case not updating after WorkOrder change
**Check:**
1. Is Case Status = "Closed"? (Updates may be restricted)
2. Is `RecurrsiveTriggerHandler.bypassValidation` = true?
3. Are there validation rules blocking the update?

### Issue: Related Case not created for Confirmed Negative
**Check:**
1. Verify `CaseCreation.createRelatedCase()` is enabled
2. Check Debug Logs for errors in that method

### Issue: Bulk update fails
**Check:**
1. Debug Logs for governor limit errors
2. Verify `SObjectUpdateBatch` executes for >1 record
3. Check `CaseDMLService.DMLResult.errors` for specific failures

---

## Test Data Creation (Copy & Paste)

**Anonymous Apex - Quick Setup:**

```apex
// Create Vendor & Location
Account vendor = new Account(Name = 'UAT Vendor', Contact_Manually_Vendor__c = true);
insert vendor;

// Create Case
Case c = new Case(Subject = 'UAT Case', Status = 'Open', Service_Date__c = System.today().addDays(7));
insert c;

// Create WorkOrder
WorkOrder wo = new WorkOrder(CaseId = c.Id, Status = 'New', Service_Date__c = System.today().addDays(7), Vendor_Account_Id__c = vendor.Id);
insert wo;

// Create Task
Task t = new Task(WhatId = c.Id, Subject = 'UAT Task', Process__c = 'Confirm Vendor Availability', Status = 'Open');
insert t;

System.debug('✅ Test Data Created - Case: ' + c.Id + ', WO: ' + wo.Id + ', Task: ' + t.Id);
```

---

## Expected Results Summary

| **Trigger** | **Case Field Updated** | **Condition** |
|-------------|------------------------|---------------|
| WorkOrder Service_Date__c changes | Proposed_Service_Date__c | Case Status ≠ Closed |
| WO Vendor_Service_Status__c = "Confirmed - Positive" | Status = Closed, Sub-Status = Service Confirmed | - |
| WO Vendor_Service_Status__c = "Confirmed - Negative" | Status = Closed, Sub-Status = Service Not Performed | - |
| WO Status = "Cancelled" | Status = Closed, Sub-Status = Request Canceled | Case Status = Open |
| WO Status = "Rejected" | Status = Closed | - |
| Task Outcome = "Vendor Available" | Availability_Confirmed__c = true | Process = Confirm Vendor Availability |
| Task Process = "Case Assignment" | Team_Name__c, Team_Queue__c, User_Name__c | - |

---

## Pass/Fail Criteria

### ✅ UAT Passes If:
- All Priority 1 tests pass (100%)
- At least 90% of Priority 2 tests pass
- No critical defects found
- Bulk operations handle 100+ records
- Existing test classes still pass
- No new governor limit errors

### ❌ UAT Fails If:
- Any Priority 1 test fails
- Critical business logic broken (e.g., Cases not closing when they should)
- Data integrity issues (e.g., wrong Case Status set)
- Governor limit errors in production-like volumes
- Existing functionality broken

---

## Who to Contact

**Questions about:**
- Test scenarios: QA Lead
- Business logic: Business Analyst
- Technical errors: Development Team
- UAT process: Project Manager

---

## Final Sign-Off Checklist

Before approving UAT:

```
☐ All critical scenarios tested
☐ Bulk operations validated (100+ records)
☐ Error logging verified
☐ No data integrity issues found
☐ Existing test classes pass
☐ Performance acceptable
☐ No new governor limit errors
☐ Rollback plan documented
☐ Defects logged and triaged
☐ Stakeholder sign-off obtained
```

---

**Ready for Production?**
If all checkboxes above are ☑️, proceed with deployment approval.

---

**Last Updated:** 2026-01-06
**Document Owner:** Development Team

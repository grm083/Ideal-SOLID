# User Acceptance Testing Checklist
## Ideal-SOLID: Enterprise Case Management System

**Version:** 1.0
**Last Updated:** November 30, 2025
**Purpose:** Comprehensive checklist for validating all features and functionality

---

## Table of Contents

1. [UAT Overview](#uat-overview)
2. [Pre-Testing Setup](#pre-testing-setup)
3. [Functional Testing](#functional-testing)
4. [Performance Testing](#performance-testing)
5. [Integration Testing](#integration-testing)
6. [Security & Access Testing](#security--access-testing)
7. [User Experience Testing](#user-experience-testing)
8. [Regression Testing](#regression-testing)
9. [Sign-Off Criteria](#sign-off-criteria)
10. [Issue Tracking Template](#issue-tracking-template)

---

## UAT Overview

### Purpose

This User Acceptance Testing (UAT) checklist ensures that the Ideal-SOLID Case Management System meets all business requirements, functions correctly, and provides a positive user experience before production deployment.

### Testing Approach

- **Manual Testing**: Conducted by business users and QA team
- **Exploratory Testing**: Users test realistic scenarios
- **Regression Testing**: Verify existing functionality still works
- **Performance Testing**: Ensure system meets performance targets

### Roles & Responsibilities

| Role | Responsibility |
|------|----------------|
| **UAT Lead** | Coordinates testing, tracks issues, approves sign-off |
| **Business Users** | Execute test scenarios, validate business logic |
| **QA Team** | Execute technical tests, document defects |
| **Development Team** | Fix defects, answer questions |
| **Product Owner** | Final sign-off authority |

### Success Criteria

- ✅ All **Critical** and **High** priority test cases pass
- ✅ No **Severity 1** or **Severity 2** defects remain open
- ✅ Performance targets are met
- ✅ All integrations function correctly
- ✅ Security requirements are validated
- ✅ User experience is acceptable to business stakeholders

---

## Pre-Testing Setup

### Environment Preparation

#### Checklist: Environment Readiness

- [ ] UAT sandbox is refreshed from production (or latest stable environment)
- [ ] All code deployments are complete
- [ ] All custom metadata is deployed
- [ ] All Lightning Message Channels are deployed
- [ ] All custom objects and fields are deployed
- [ ] Record Types are configured
- [ ] Page layouts are assigned
- [ ] Profiles and permission sets are configured
- [ ] Sample data is loaded for testing

#### Checklist: User Setup

- [ ] Test users are created for each role:
  - [ ] Customer Service Representative
  - [ ] Customer Service Manager
  - [ ] Sales Representative
  - [ ] System Administrator
  - [ ] Integration User
- [ ] Users have correct profiles assigned
- [ ] Users have correct permission sets assigned
- [ ] Users have access to test accounts/contacts/locations

#### Checklist: Integration Setup

- [ ] CPQ integration endpoint is configured
- [ ] Genesys call center integration is active
- [ ] Acorn system integration is configured
- [ ] OfficeTrax integration is configured
- [ ] Test integration credentials are valid

### Test Data Preparation

#### Checklist: Master Data

- [ ] 10+ test Accounts created (mix of Customer/Vendor/Partner types)
- [ ] 20+ test Contacts created and associated with accounts
- [ ] 15+ test Locations created with complete address data
- [ ] 20+ test Assets created and associated with locations
- [ ] Multiple Record Types available for testing
- [ ] Service Territories configured

#### Checklist: Custom Metadata

- [ ] Case_Highlight_Panel_Button__mdt records are active
- [ ] Business_Rule__mdt records are configured
- [ ] Field_Requirement__mdt records are configured (if exists)
- [ ] All metadata is validated and active

---

## Functional Testing

### 1. Case Creation & Management

#### Test Case 1.1: Create New Customer Service Case

**Priority**: Critical

**Test Steps**:
1. [ ] Navigate to Cases tab
2. [ ] Click "New" button
3. [ ] Select "Customer Service" record type
4. [ ] Fill in required fields:
   - [ ] Contact (search and select existing contact)
   - [ ] Location (select location from contact's account)
   - [ ] Service Type (select "New Service")
   - [ ] Service Sub-Type (select appropriate sub-type)
   - [ ] Service Reason (select reason code)
   - [ ] Subject (enter descriptive subject)
5. [ ] Click Save
6. [ ] Verify case is created successfully
7. [ ] Verify case number is auto-generated
8. [ ] Verify all entered data is saved correctly

**Expected Results**:
- ✅ Case is created without errors
- ✅ All field values are saved correctly
- ✅ Case number follows naming convention
- ✅ Record type is set to "Customer Service"
- ✅ Status is set to default value

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

**Notes**: _[Document any issues or observations]_

---

#### Test Case 1.2: Case Detail View - Data Governor Pattern

**Priority**: Critical

**Test Steps**:
1. [ ] Open an existing case record
2. [ ] Monitor network traffic (browser dev tools)
3. [ ] Count the number of Apex calls made on page load
4. [ ] Verify all case information displays correctly:
   - [ ] Case header information
   - [ ] Account details
   - [ ] Contact information
   - [ ] Related assets
   - [ ] Related tasks
   - [ ] Service details
5. [ ] Verify page loads within 2 seconds

**Expected Results**:
- ✅ Only **1 Apex call** is made (CaseDataGovernorService.getCasePageData)
- ✅ All information displays correctly
- ✅ Page load time is under 2 seconds
- ✅ No JavaScript errors in console

**Actual Results**: _[To be filled during testing]_

**Performance Metrics**:
- Number of Apex calls: _____
- Page load time: _____ seconds
- Number of SOQL queries: _____

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 1.3: Case Highlight Panel - Dynamic Buttons

**Priority**: High

**Test Steps**:
1. [ ] Open a case in "New" status
2. [ ] Verify visible action buttons match business rules:
   - [ ] "Edit" button is visible
   - [ ] "Close" button is NOT visible (case not resolved)
   - [ ] "Submit for Approval" button visible (if approval required)
3. [ ] Change case status to "In Progress"
4. [ ] Refresh the page
5. [ ] Verify button visibility updated based on new status
6. [ ] Click each visible button and verify:
   - [ ] Modal/action opens correctly
   - [ ] No JavaScript errors

**Expected Results**:
- ✅ Buttons display according to Case_Highlight_Panel_Button__mdt configuration
- ✅ Button visibility matches case state
- ✅ All buttons function correctly when clicked

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 1.4: Case Field Requirements - Dynamic Validation

**Priority**: High

**Test Steps**:
1. [ ] Create a new case
2. [ ] Select Service Type = "New Service"
3. [ ] Verify required fields update:
   - [ ] Asset field becomes required
   - [ ] Service Date becomes required
   - [ ] Customer PO becomes required
4. [ ] Attempt to save without required fields
5. [ ] Verify validation error appears
6. [ ] Fill in required fields
7. [ ] Verify case saves successfully
8. [ ] Change Service Type to "Pickup"
9. [ ] Verify required fields update accordingly

**Expected Results**:
- ✅ Required fields update based on Service Type selection
- ✅ Validation prevents save when required fields are empty
- ✅ Clear error messages display
- ✅ Case saves successfully when all requirements met

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### 2. Case Wizard Workflow

#### Test Case 2.1: Wizard Phase 1 - Caller Identification

**Priority**: Critical

**Test Steps**:
1. [ ] Start new case wizard
2. [ ] Phase 1: Entity Selection
   - [ ] Select "Location" as entity type
   - [ ] Search for existing location
   - [ ] Verify search results display correctly
   - [ ] Select a location
3. [ ] Contact Selection
   - [ ] Verify contacts from selected location's account display
   - [ ] Select existing contact
   - [ ] OR click "Create New Contact"
   - [ ] Fill in new contact details
   - [ ] Verify contact is created
4. [ ] Click "Next" to proceed to Phase 2

**Expected Results**:
- ✅ Entity search functions correctly
- ✅ Location selection populates related data
- ✅ Contact search displays relevant contacts
- ✅ New contact creation works inline
- ✅ "Next" button is only enabled when required fields are filled

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 2.2: Wizard Phase 2 - Intent Configuration

**Priority**: Critical

**Test Steps**:
1. [ ] Continue from Phase 1
2. [ ] Asset Selection
   - [ ] Verify assets from selected location display
   - [ ] Select an asset
   - [ ] Verify asset details display
3. [ ] Service Type Selection
   - [ ] Select "Pickup" service type
   - [ ] Verify service sub-types update dynamically
   - [ ] Select appropriate sub-type
4. [ ] Service Reason
   - [ ] Select reason code from dropdown
   - [ ] Verify reason codes are filtered by service type
5. [ ] Click "Next" to proceed to Phase 3

**Expected Results**:
- ✅ Assets display correctly for selected location
- ✅ Service sub-types filter based on service type
- ✅ Reason codes filter appropriately
- ✅ All selections persist when navigating forward/back

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 2.3: Wizard Phase 3 - Details & Requirements

**Priority**: Critical

**Test Steps**:
1. [ ] Continue from Phase 2
2. [ ] Customer Reference Information
   - [ ] Enter Customer PO number
   - [ ] Enter Customer Profile
   - [ ] Enter Customer PSI
3. [ ] Service Date Selection
   - [ ] Open date picker
   - [ ] Select a date 5 business days in the future
   - [ ] Verify SLA Due Date is calculated automatically
   - [ ] Verify SLA compliance indicator (green/yellow/red)
4. [ ] Business Rule Validation
   - [ ] Enter a high-value case (e.g., $60,000)
   - [ ] Verify "Approval Required" checkbox is checked
   - [ ] Verify approval message displays
5. [ ] Capacity Planning (for rolloff services)
   - [ ] If applicable, verify capacity requirements calculate
6. [ ] Click "Next" to proceed to Phase 4

**Expected Results**:
- ✅ All customer reference fields save correctly
- ✅ SLA Due Date calculates based on service type
- ✅ Business rules evaluate correctly
- ✅ Approval requirements display when triggered
- ✅ Capacity planning works for rolloff services

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 2.4: Wizard Phase 4 - Review & Submit

**Priority**: Critical

**Test Steps**:
1. [ ] Continue from Phase 3
2. [ ] Review Summary
   - [ ] Verify all entered information displays correctly
   - [ ] Verify case summary is comprehensive
3. [ ] Work Order Preview
   - [ ] Verify work order preview displays (if applicable)
   - [ ] Verify all work order details are correct
4. [ ] Edit Capability
   - [ ] Click "Back" button
   - [ ] Verify can navigate to previous phases
   - [ ] Make a change to service date
   - [ ] Navigate back to Review phase
   - [ ] Verify change is reflected
5. [ ] Submit
   - [ ] Click "Submit" button
   - [ ] Verify case is created successfully
   - [ ] Verify success message displays
   - [ ] Verify case number is shown
   - [ ] Click link to view created case

**Expected Results**:
- ✅ Review summary accurately reflects all entered data
- ✅ Back navigation preserves all changes
- ✅ Case submission succeeds
- ✅ User is redirected to case detail page
- ✅ All data from wizard is correctly saved to case

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### 3. Lightning Web Components (LWC)

#### Test Case 3.1: Case Data Governor LWC - Data Loading

**Priority**: Critical

**Test Steps**:
1. [ ] Open a case record page
2. [ ] Verify loading spinner displays briefly
3. [ ] Verify all components load data simultaneously
4. [ ] Open browser console
5. [ ] Verify Lightning Message Service publishes case data
6. [ ] Verify no error messages in console
7. [ ] Click browser refresh
8. [ ] Verify data reloads correctly

**Expected Results**:
- ✅ Single Apex call loads all data
- ✅ All child components receive data via LMS
- ✅ Loading spinner displays during data fetch
- ✅ No JavaScript errors

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 3.2: Custom Case Highlight Panel LWC

**Priority**: High

**Test Steps**:
1. [ ] Open a case record
2. [ ] Verify case highlight panel displays:
   - [ ] Case number
   - [ ] Status with colored badge
   - [ ] Priority with icon
   - [ ] Service type
   - [ ] Service date
   - [ ] Owner information
3. [ ] Verify action buttons display
4. [ ] Click "Edit" button
   - [ ] Verify edit modal opens
   - [ ] Make changes
   - [ ] Save changes
   - [ ] Verify highlight panel updates with new data
5. [ ] Test all visible action buttons

**Expected Results**:
- ✅ All case information displays correctly
- ✅ Status badge color matches status value
- ✅ Priority icon displays correctly
- ✅ Action buttons work as expected
- ✅ Panel updates after data changes

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 3.3: Show Case Messages LWC - Timeline View

**Priority**: Medium

**Test Steps**:
1. [ ] Open a case with related activities (tasks, emails, calls)
2. [ ] Verify timeline component displays
3. [ ] Verify activities display in chronological order (newest first)
4. [ ] Verify each activity shows:
   - [ ] Activity type icon
   - [ ] Subject/title
   - [ ] Date/time
   - [ ] Owner
   - [ ] Description/details
5. [ ] Filter by activity type
   - [ ] Select "Tasks" filter
   - [ ] Verify only tasks display
   - [ ] Select "All" filter
   - [ ] Verify all activities display
6. [ ] Create a new task from timeline
7. [ ] Verify task appears in timeline immediately

**Expected Results**:
- ✅ All activities display correctly
- ✅ Chronological order is correct
- ✅ Filtering works correctly
- ✅ New activities appear immediately
- ✅ Timeline is responsive and scrollable

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 3.4: Contact Search LWC

**Priority**: High

**Test Steps**:
1. [ ] Navigate to component that uses contact search
2. [ ] Enter search term (e.g., "John")
3. [ ] Verify search results display after typing
4. [ ] Verify results include:
   - [ ] Contact name
   - [ ] Email
   - [ ] Phone
   - [ ] Account name
5. [ ] Select a contact from results
6. [ ] Verify contact is populated correctly
7. [ ] Test search with no results
   - [ ] Enter "ZZZZZZ" (should match nothing)
   - [ ] Verify "No results found" message displays
   - [ ] Verify "Create New Contact" option appears
8. [ ] Test minimum character requirement
   - [ ] Enter 1 character
   - [ ] Verify message "Enter at least 2 characters to search"

**Expected Results**:
- ✅ Search results display quickly (< 1 second)
- ✅ Results are relevant to search term
- ✅ All contact information displays correctly
- ✅ Selection populates parent component
- ✅ No results scenario handled gracefully

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### 4. Business Rules & Validations

#### Test Case 4.1: Approval Workflow - High Value Cases

**Priority**: Critical

**Test Steps**:
1. [ ] Create a case with estimated value > $50,000
2. [ ] Verify "Approval Required" checkbox is automatically checked
3. [ ] Verify approval status is set to "Pending"
4. [ ] Verify notification is sent to approver
5. [ ] Log in as approver
6. [ ] Navigate to approval queue
7. [ ] Locate the case approval request
8. [ ] Approve the case
9. [ ] Verify case approval status updates to "Approved"
10. [ ] Verify case creator receives approval notification

**Expected Results**:
- ✅ High-value cases automatically require approval
- ✅ Approval request is created
- ✅ Approver receives notification
- ✅ Approval workflow completes successfully
- ✅ Case status updates after approval

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 4.2: SLA Calculation - Service Date Compliance

**Priority**: High

**Test Steps**:
1. [ ] Create a case with Service Type = "Emergency"
2. [ ] Verify SLA Due Date = Today + 1 business day
3. [ ] Verify SLA indicator is RED (urgent)
4. [ ] Create a case with Service Type = "Standard Service"
5. [ ] Verify SLA Due Date = Today + 5 business days
6. [ ] Verify SLA indicator is GREEN (on track)
7. [ ] Create a case 3 days before service date
8. [ ] Verify SLA indicator is YELLOW (warning)

**Expected Results**:
- ✅ SLA dates calculate correctly based on service type
- ✅ Business days are used (excludes weekends/holidays)
- ✅ SLA indicators reflect urgency correctly
- ✅ SLA rules are enforced consistently

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 4.3: Business Rule Validation - Metadata Driven

**Priority**: High

**Test Steps**:
1. [ ] Review Business_Rule__mdt records in setup
2. [ ] Identify an active business rule (e.g., "Service Date Required for New Service")
3. [ ] Create a case that violates the rule:
   - [ ] Service Type = "New Service"
   - [ ] Service Date = blank
4. [ ] Attempt to save
5. [ ] Verify validation error displays with message from metadata
6. [ ] Verify error severity matches metadata configuration
7. [ ] Fill in Service Date
8. [ ] Verify case saves successfully

**Expected Results**:
- ✅ Business rules evaluate from metadata
- ✅ Validation messages come from Business_Rule__mdt
- ✅ Severity levels (Info/Warning/Error) display correctly
- ✅ Rules can be enabled/disabled via metadata

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### 5. Record Type Behavior

#### Test Case 5.1: Customer Service Record Type

**Priority**: Medium

**Test Steps**:
1. [ ] Create case with "Customer Service" record type
2. [ ] Verify correct page layout displays
3. [ ] Verify correct picklist values display
4. [ ] Verify required fields:
   - [ ] Contact is required
   - [ ] Location is required
   - [ ] Service Type is required
5. [ ] Verify specific buttons display:
   - [ ] "Create Work Order" button visible
   - [ ] "Send to Vendor" button visible

**Expected Results**:
- ✅ Correct page layout for record type
- ✅ Filtered picklist values
- ✅ Appropriate field requirements
- ✅ Record type-specific buttons display

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

#### Test Case 5.2: Record Type Change

**Priority**: Low

**Test Steps**:
1. [ ] Create a case with "Customer Service" record type
2. [ ] Save the case
3. [ ] Use "Change Record Type" component
4. [ ] Select "Internal Issue" record type
5. [ ] Verify warning message about field value changes
6. [ ] Confirm record type change
7. [ ] Verify:
   - [ ] Record type updates successfully
   - [ ] Page layout changes
   - [ ] Field values are preserved where possible
   - [ ] Incompatible picklist values are cleared

**Expected Results**:
- ✅ Record type change succeeds
- ✅ User is warned about potential data loss
- ✅ Page layout and picklist values update
- ✅ Compatible field values are preserved

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

## Performance Testing

### Test Case P1: Page Load Performance

**Priority**: Critical

**Test Steps**:
1. [ ] Open a case detail page
2. [ ] Measure and record:
   - [ ] Time to first byte (TTFB): _____ ms
   - [ ] DOM content loaded: _____ ms
   - [ ] Full page load: _____ ms
   - [ ] Number of Apex calls: _____
   - [ ] Number of SOQL queries: _____
3. [ ] Repeat test 5 times and calculate average
4. [ ] Test with different data volumes:
   - [ ] Case with 5 related records
   - [ ] Case with 50 related records
   - [ ] Case with 200 related records

**Performance Targets**:
- ✅ Page loads in < 2 seconds
- ✅ Only 1 Apex call made (Governor pattern)
- ✅ 3-5 SOQL queries maximum
- ✅ No performance degradation with more related records

**Actual Results**:

| Test Run | Page Load Time | Apex Calls | SOQL Queries |
|----------|----------------|------------|--------------|
| 1        |                |            |              |
| 2        |                |            |              |
| 3        |                |            |              |
| 4        |                |            |              |
| 5        |                |            |              |
| **Avg**  |                |            |              |

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case P2: Search Performance

**Priority**: High

**Test Steps**:
1. [ ] Test contact search with 1,000+ contacts in org
2. [ ] Enter search term
3. [ ] Measure time from keystroke to results display: _____ ms
4. [ ] Verify results are limited to 10-20 records
5. [ ] Test with different search terms:
   - [ ] Common name (many results)
   - [ ] Unique name (few results)
   - [ ] No matches
6. [ ] Record performance for each

**Performance Targets**:
- ✅ Search results display in < 1 second
- ✅ Results are limited to prevent performance issues
- ✅ Search uses indexed fields (Name, Email)

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case P3: Bulk Data Processing

**Priority**: Medium

**Test Steps**:
1. [ ] Create 50 cases in quick succession
2. [ ] Verify no governor limit errors
3. [ ] Verify all 50 cases are created successfully
4. [ ] Check debug logs for:
   - [ ] SOQL query count per transaction
   - [ ] DML statement count per transaction
   - [ ] CPU time per transaction
5. [ ] Verify all are within governor limits

**Governor Limit Targets**:
- ✅ SOQL queries < 100 per transaction
- ✅ DML statements < 150 per transaction
- ✅ CPU time < 10,000 ms
- ✅ Heap size < 6 MB

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

## Integration Testing

### Test Case I1: CPQ Integration - Quote Creation

**Priority**: Critical

**Test Steps**:
1. [ ] Create a case requiring a quote
2. [ ] Click "Create Quote" button
3. [ ] Verify quote creation request is sent to CPQ system
4. [ ] Verify quote is created in CPQ
5. [ ] Verify quote ID is stored on case record
6. [ ] Verify quote link displays in case detail
7. [ ] Click quote link
8. [ ] Verify quote opens in CPQ system
9. [ ] In CPQ, approve the quote
10. [ ] Verify case is updated with quote approval status

**Expected Results**:
- ✅ Quote is created in CPQ system
- ✅ Integration completes within 5 seconds
- ✅ Quote details are synced to Salesforce
- ✅ Status updates flow bidirectionally
- ✅ Error handling works if CPQ is unavailable

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case I2: Genesys Integration - Screen Pop

**Priority**: High

**Test Steps**:
1. [ ] Place test call through Genesys
2. [ ] Verify case detail page opens automatically (screen pop)
3. [ ] Verify correct case is displayed based on caller ID
4. [ ] Verify call activity is logged on case
5. [ ] End call
6. [ ] Verify call duration and details are captured

**Expected Results**:
- ✅ Screen pop occurs within 2 seconds of call connection
- ✅ Correct case/contact is identified
- ✅ Call is logged as activity
- ✅ Call details are accurate

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case I3: Acorn System - Work Order Synchronization

**Priority**: Critical

**Test Steps**:
1. [ ] Create a case with work order requirements
2. [ ] Change case status to "Work Order Created"
3. [ ] Verify outbound message is sent to Acorn
4. [ ] Check Acorn system for work order
5. [ ] Verify work order details match case details
6. [ ] In Acorn, complete the work order
7. [ ] Verify callback updates Salesforce case
8. [ ] Verify case status updates to "Work Completed"
9. [ ] Verify completion date is captured

**Expected Results**:
- ✅ Work order is created in Acorn
- ✅ All case details sync correctly
- ✅ Status updates flow from Acorn to Salesforce
- ✅ Integration handles errors gracefully

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case I4: OfficeTrax - Asset Synchronization

**Priority**: Medium

**Test Steps**:
1. [ ] Verify scheduled batch job is running
2. [ ] Create/update an asset in Salesforce
3. [ ] Wait for next batch run (or run manually)
4. [ ] Verify asset is synced to OfficeTrax
5. [ ] In OfficeTrax, update asset status
6. [ ] Wait for next batch run
7. [ ] Verify asset status is synced back to Salesforce

**Expected Results**:
- ✅ Batch job runs successfully
- ✅ Assets sync to OfficeTrax
- ✅ Status updates sync bidirectionally
- ✅ Sync errors are logged and handled

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

## Security & Access Testing

### Test Case S1: Profile-Based Access Control

**Priority**: Critical

**Test Steps**:

**As Customer Service Representative**:
1. [ ] Login as CS Rep user
2. [ ] Verify can view own cases
3. [ ] Verify can create new cases
4. [ ] Verify can edit cases they own
5. [ ] Verify CANNOT delete cases
6. [ ] Verify CANNOT approve cases
7. [ ] Verify CANNOT view confidential fields

**As Customer Service Manager**:
1. [ ] Login as CS Manager user
2. [ ] Verify can view all team cases
3. [ ] Verify can edit all team cases
4. [ ] Verify CAN approve cases
5. [ ] Verify CAN view confidential fields
6. [ ] Verify can run reports

**Expected Results**:
- ✅ Each role has appropriate access
- ✅ Confidential data is protected
- ✅ Approval authority is restricted
- ✅ Field-level security is enforced

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case S2: Sharing Rules

**Priority**: High

**Test Steps**:
1. [ ] Create case as User A (in Territory 1)
2. [ ] Login as User B (in Territory 2)
3. [ ] Verify User B CANNOT see User A's case
4. [ ] Add User B to case team
5. [ ] Verify User B CAN now see the case
6. [ ] Test account-based sharing:
   - [ ] User with account access can see related cases
   - [ ] User without account access cannot see cases

**Expected Results**:
- ✅ Sharing rules enforce territory-based access
- ✅ Case team sharing grants access
- ✅ Account hierarchy sharing works correctly

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case S3: Field-Level Security

**Priority**: High

**Test Steps**:
1. [ ] Login as restricted user
2. [ ] Open a case record
3. [ ] Verify cannot see fields marked as hidden for profile:
   - [ ] Confidential_Notes__c
   - [ ] Internal_Cost__c
   - [ ] Commission_Amount__c
4. [ ] Attempt to update case via API with restricted fields
5. [ ] Verify field values are stripped (Security.stripInaccessible)
6. [ ] Login as admin user
7. [ ] Verify CAN see all fields

**Expected Results**:
- ✅ Field-level security is enforced in UI
- ✅ Field-level security is enforced in Apex
- ✅ Restricted fields are not visible to unauthorized users

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

## User Experience Testing

### Test Case UX1: Mobile Responsiveness

**Priority**: High

**Test Steps**:
1. [ ] Open case detail page on mobile device (or Chrome DevTools mobile emulation)
2. [ ] Verify layout adapts to mobile screen size
3. [ ] Verify all components are visible (no horizontal scroll)
4. [ ] Verify buttons are touch-friendly (min 44x44 pixels)
5. [ ] Test all major actions on mobile:
   - [ ] Create case
   - [ ] Edit case
   - [ ] Add comment
   - [ ] Change status
6. [ ] Verify forms are usable on mobile

**Expected Results**:
- ✅ Responsive design works on all screen sizes
- ✅ No horizontal scrolling required
- ✅ All features are accessible on mobile
- ✅ Touch targets are appropriately sized

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case UX2: Error Messaging

**Priority**: Medium

**Test Steps**:
1. [ ] Trigger various error scenarios:
   - [ ] Leave required field blank and save
   - [ ] Enter invalid data format
   - [ ] Violate business rule
   - [ ] Cause integration error (disconnect network)
2. [ ] For each error, verify:
   - [ ] Clear error message displays
   - [ ] Message indicates what went wrong
   - [ ] Message suggests how to fix
   - [ ] Error is displayed near relevant field
3. [ ] Verify success messages display after successful actions
4. [ ] Verify warning messages display for non-blocking issues

**Expected Results**:
- ✅ Error messages are clear and actionable
- ✅ Success messages confirm completion
- ✅ Warning messages alert user without blocking
- ✅ Messages display in appropriate location

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case UX3: Accessibility (WCAG 2.1 Level AA)

**Priority**: Medium

**Test Steps**:
1. [ ] Test keyboard navigation:
   - [ ] Tab through all interactive elements
   - [ ] Verify tab order is logical
   - [ ] Verify all actions can be completed without mouse
   - [ ] Verify focus indicators are visible
2. [ ] Test with screen reader (NVDA or JAWS):
   - [ ] Verify all elements are announced correctly
   - [ ] Verify form labels are associated with inputs
   - [ ] Verify button purposes are clear
   - [ ] Verify error messages are announced
3. [ ] Test color contrast:
   - [ ] Run browser extension (e.g., axe DevTools)
   - [ ] Verify all text has sufficient contrast
   - [ ] Verify meaning is not conveyed by color alone
4. [ ] Test with 200% browser zoom
   - [ ] Verify layout does not break
   - [ ] Verify all content is still accessible

**Expected Results**:
- ✅ Full keyboard accessibility
- ✅ Screen reader compatible
- ✅ Sufficient color contrast (4.5:1 for text)
- ✅ Functional at 200% zoom

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

## Regression Testing

### Test Case R1: Existing Case Functionality

**Priority**: Critical

**Test Steps**:
1. [ ] Verify all existing case operations still work:
   - [ ] View case detail
   - [ ] Edit case fields
   - [ ] Change case status
   - [ ] Close case
   - [ ] Reopen case
2. [ ] Verify existing triggers still fire:
   - [ ] Auto-assignment rules
   - [ ] Email notifications
   - [ ] Field updates
3. [ ] Verify existing workflows/processes:
   - [ ] Process Builder flows
   - [ ] Flow automation
   - [ ] Approval processes

**Expected Results**:
- ✅ All existing functionality still works
- ✅ No regressions introduced
- ✅ Existing automations continue to run

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case R2: Legacy Aura Components (if any remain)

**Priority**: Medium

**Test Steps**:
1. [ ] Identify pages still using Aura components
2. [ ] For each Aura component, verify:
   - [ ] Still renders correctly
   - [ ] Functionality works
   - [ ] No JavaScript errors
   - [ ] Interoperability with LWC works
3. [ ] Test transition from Aura to LWC pages

**Expected Results**:
- ✅ Legacy Aura components still function
- ✅ No conflicts between Aura and LWC
- ✅ Smooth transition path exists

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

### Test Case R3: Reports and Dashboards

**Priority**: Medium

**Test Steps**:
1. [ ] Run all existing case reports
2. [ ] Verify data displays correctly
3. [ ] Verify filters work
4. [ ] Verify dashboards refresh
5. [ ] Verify no broken report columns
6. [ ] Test report subscriptions

**Expected Results**:
- ✅ All reports run successfully
- ✅ Data is accurate
- ✅ Dashboards display correctly
- ✅ Report subscriptions work

**Actual Results**: _[To be filled during testing]_

**Pass/Fail**: ⬜ Pass ⬜ Fail

---

## Sign-Off Criteria

### Defect Summary

| Severity | Total Found | Resolved | Remaining |
|----------|-------------|----------|-----------|
| Severity 1 (Critical) | | | |
| Severity 2 (High) | | | |
| Severity 3 (Medium) | | | |
| Severity 4 (Low) | | | |
| **Total** | | | |

### Test Case Summary

| Category | Total Cases | Passed | Failed | Not Tested |
|----------|-------------|--------|--------|------------|
| Functional Testing | | | | |
| Performance Testing | | | | |
| Integration Testing | | | | |
| Security Testing | | | | |
| UX Testing | | | | |
| Regression Testing | | | | |
| **Total** | | | | |

### Sign-Off Checklist

- [ ] All Critical and High priority test cases have passed
- [ ] No open Severity 1 or Severity 2 defects remain
- [ ] All Medium severity defects have workarounds or are accepted
- [ ] Performance targets have been met
- [ ] All integrations are functioning correctly
- [ ] Security requirements have been validated
- [ ] User experience is acceptable to stakeholders
- [ ] Documentation is complete and accurate
- [ ] Training materials are ready
- [ ] Rollback plan is documented

### Stakeholder Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| UAT Lead | | | |
| Product Owner | | | |
| Business Stakeholder | | | |
| Technical Lead | | | |
| QA Lead | | | |

---

## Issue Tracking Template

### Defect Report Template

**Defect ID**: _[Auto-generated]_

**Title**: _[Brief description]_

**Severity**:
- ⬜ Severity 1 (Critical - System down, data loss)
- ⬜ Severity 2 (High - Major functionality broken)
- ⬜ Severity 3 (Medium - Feature partially working)
- ⬜ Severity 4 (Low - Cosmetic issue)

**Priority**:
- ⬜ P1 (Fix immediately)
- ⬜ P2 (Fix before release)
- ⬜ P3 (Fix if time permits)
- ⬜ P4 (Fix in future release)

**Test Case**: _[Reference test case ID]_

**Environment**: _[Sandbox/UAT/Production]_

**Steps to Reproduce**:
1.
2.
3.

**Expected Result**: _[What should happen]_

**Actual Result**: _[What actually happened]_

**Screenshots/Attachments**: _[Attach evidence]_

**Browser/Device**: _[Chrome 118 / Windows 10 / etc.]_

**Reported By**: _[Name]_

**Reported Date**: _[Date]_

**Assigned To**: _[Developer name]_

**Status**:
- ⬜ New
- ⬜ In Progress
- ⬜ Fixed
- ⬜ Ready for Retest
- ⬜ Verified
- ⬜ Closed
- ⬜ Won't Fix

**Resolution Notes**: _[How it was fixed]_

**Retest Results**: _[Pass/Fail]_

**Retested By**: _[Name]_

**Retest Date**: _[Date]_

---

## Appendix: Quick Reference

### Test Data Quick Reference

**Test Accounts**:
- ABC Manufacturing (High-value customer)
- XYZ Services (Standard customer)
- Test Vendor 1 (Vendor)

**Test Contacts**:
- John Smith (ABC Manufacturing)
- Jane Doe (XYZ Services)

**Test Users**:
- cs.rep@test.com (Customer Service Rep)
- cs.manager@test.com (Customer Service Manager)
- admin@test.com (System Admin)

### Browser Compatibility Matrix

| Browser | Version | Status |
|---------|---------|--------|
| Chrome | 118+ | ✅ Supported |
| Firefox | 119+ | ✅ Supported |
| Edge | 118+ | ✅ Supported |
| Safari | 16+ | ✅ Supported |

### Performance Benchmarks

| Metric | Target | Actual |
|--------|--------|--------|
| Page Load Time | < 2 seconds | |
| Apex Calls per Page | 1 | |
| SOQL Queries per Page | 3-5 | |
| Search Response Time | < 1 second | |

---

**Document Maintained By**: QA Team
**Last Updated**: November 30, 2025
**Version**: 1.0
**Next Review**: Before each major release

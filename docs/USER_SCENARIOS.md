# User Scenarios - Waste Management Service System
## Given/When/Then Documentation for UX Design

This document describes how users interact with the Waste Management Service system from their perspective. These scenarios are intended to inform UX design and Figma mockups.

---

## 1. CASE CREATION - PHASE 1: CALLER IDENTIFICATION

### Scenario 1.1: Starting a New Service Request
**Given** I need to request a service for one of my locations
**When** I open the case creation interface
**Then** I see a guided wizard with clear steps showing I'm on Phase 1 of 4 (Caller Identification)

### Scenario 1.2: Selecting Service Location
**Given** I am in Phase 1 of the case creation wizard
**When** I need to specify where the service is needed
**Then** I can search and select from my available locations (accounts)

### Scenario 1.3: Identifying Myself as the Requester
**Given** I have selected a location for service
**When** I need to provide my contact information
**Then** I can search for my name in the contact list or create a new contact if I'm not found

### Scenario 1.4: Cannot Proceed Without Required Contact
**Given** I have selected a location but haven't chosen a contact
**When** I try to move to Phase 2
**Then** I see a message that I must select a contact before proceeding

### Scenario 1.5: Vendor-Initiated Service Request
**Given** I am a vendor user needing to create a case for a client
**When** I select "Vendor" as the entity type
**Then** I can search for and select the vendor organization, then proceed with contact selection

---

## 2. CASE CREATION - PHASE 2: INTENT CONFIGURATION

### Scenario 2.1: Viewing Available Assets at Location
**Given** I have completed Phase 1 with location and contact
**When** I enter Phase 2
**Then** I see all active service assets (containers/equipment) at my selected location with their details

### Scenario 2.2: Selecting the Right Container
**Given** I am viewing multiple containers at my location
**When** I need to identify which container needs service
**Then** I can see each container's type, material, current service schedule, and vendor

### Scenario 2.3: Choosing Service Type
**Given** I have selected a specific asset
**When** I need to specify what kind of service I need
**Then** I can choose from service types like Pickup, New Service, Activation, Modify, or Deactivate

### Scenario 2.4: Specifying Detailed Service Sub-Type
**Given** I have selected a service type (e.g., Pickup)
**When** I need to provide more specific details
**Then** I can select a service sub-type (e.g., Special Pickup, Emergency Pickup, Standard Pickup)

### Scenario 2.5: Providing Service Reason
**Given** I have selected type and sub-type
**When** I need to explain why I need this service
**Then** I can select a reason from available options relevant to my service type

### Scenario 2.6: New Service Without Existing Asset
**Given** I am requesting a new service that doesn't have existing equipment
**When** I select "New Service" as the case type
**Then** I can proceed without selecting an existing asset and specify equipment needs later

---

## 3. CASE CREATION - PHASE 3: DETAILS & REQUIREMENTS

### Scenario 3.1: Entering Customer Reference Information
**Given** I am in Phase 3 after defining service intent
**When** I need to provide my internal tracking information
**Then** I can enter my Purchase Order number, Profile number, and PSI (Project Site Information)

### Scenario 3.2: Seeing Required Fields for My Service Type
**Given** I have selected a specific service type
**When** I view Phase 3
**Then** I see which customer information fields are required vs. optional based on business rules

### Scenario 3.3: Selecting Service Date from Calendar
**Given** I need to schedule when the service should occur
**When** I click to select a service date
**Then** I see a calendar showing available dates based on SLA and business hours

### Scenario 3.4: Understanding Service Date Availability
**Given** I am looking at the service date calendar
**When** I see different dates highlighted
**Then** I understand which dates are available, which are outside SLA, and which are already scheduled

### Scenario 3.5: Seeing Automatic SLA-Based Date Suggestion
**Given** I have completed Phase 2 with service type selection
**When** I enter Phase 3
**Then** I see a pre-calculated suggested service date based on my service level agreement

### Scenario 3.6: Using Capacity Planner for Rolloff Services
**Given** I am scheduling a rolloff container service
**When** I select a service date
**Then** The system checks real-time vendor capacity and shows me only dates when service is actually available

### Scenario 3.7: Viewing Business Rule Requirements
**Given** I am filling out Phase 3 details
**When** My service request triggers specific business rules
**Then** I see clear messages about what approvals are needed, spending limits, or additional information required

### Scenario 3.8: Understanding NTE (Cost) Limits
**Given** My service may incur costs
**When** I view business rules in Phase 3
**Then** I see the Non-Time Estimate (cost limit) that applies to my request and whether I'm within limits

### Scenario 3.9: Knowing Approval is Required
**Given** My service request exceeds normal thresholds
**When** I review Phase 3
**Then** I see a message that my request will require approval from a manager before processing

---

## 4. CASE CREATION - PHASE 4: REVIEW & SUBMISSION

### Scenario 4.1: Reviewing Complete Service Request
**Given** I have completed Phases 1-3
**When** I enter Phase 4 (Review)
**Then** I see a complete summary of all information I've entered: location, contact, asset, service type, date, and customer info

### Scenario 4.2: Editing Information Before Submission
**Given** I am reviewing my request in Phase 4
**When** I notice something is incorrect
**Then** I can navigate back to previous phases to make changes without losing my other entries

### Scenario 4.3: Final Validation Before Creating Case
**Given** I am ready to submit in Phase 4
**When** I click the submit button
**Then** The system validates all business rules one final time before creating my case

### Scenario 4.4: Successful Case Creation
**Given** I have submitted a valid service request
**When** The validation passes
**Then** I see confirmation that my case has been created with a case number, and I can view the case details

### Scenario 4.5: Cannot Submit Without Required Information
**Given** I am in Phase 4 but missed required fields
**When** I try to submit
**Then** I see exactly which required fields are missing and which phase they're in

---

## 5. SCHEDULING & SERVICE DATES

### Scenario 5.1: Understanding My Service Level Agreement
**Given** I am a customer with a service contract
**When** I create a service request
**Then** I see my guaranteed service timeframe (e.g., "Next Business Day" or "Within 3 Days")

### Scenario 5.2: Requesting Service After Daily Cutoff
**Given** It is after 2:00 PM in my location's timezone
**When** I request same-day or next-day service
**Then** The system automatically adjusts the service date to account for the late request time

### Scenario 5.3: Weekend Service Request
**Given** I am requesting service on a Friday afternoon
**When** The service date falls on a weekend
**Then** The system automatically moves my service to the next business day (Monday)

### Scenario 5.4: Overriding Suggested Service Date
**Given** The system suggests a service date based on SLA
**When** I need service on a different date
**Then** I can manually select a different date and provide a reason for the override

### Scenario 5.5: Seeing Conflicts with Existing Work Orders
**Given** I am selecting a service date
**When** A work order already exists for that date and asset
**Then** I see a warning about the conflict and can choose to proceed or select a different date

### Scenario 5.6: Multi-Date Service Scheduling
**Given** I need the same service performed on multiple dates
**When** I select "Multiple Dates" in the scheduler
**Then** I can choose several dates from a calendar, and the system will create linked cases for each date

---

## 6. WORK ORDER MANAGEMENT

### Scenario 6.1: Understanding Work Order Creation
**Given** My case has been approved and validated
**When** The case moves to processing status
**Then** A work order is automatically created and I can see the work order number linked to my case

### Scenario 6.2: Tracking Work Order Status
**Given** A work order has been created from my case
**When** I view my case
**Then** I see the current work order status (Scheduled, In Progress, Completed, etc.)

### Scenario 6.3: Work Order Completion
**Given** The vendor has completed the service
**When** They mark the work order as complete
**Then** My case status automatically updates to show the service is complete

### Scenario 6.4: Initiating Work Order Manually
**Given** I have a case that requires manual work order creation
**When** I click "Initiate Work Order"
**Then** The system validates all requirements and creates the work order if conditions are met

### Scenario 6.5: Work Order Cannot Be Created
**Given** I try to create a work order
**When** Required approvals or information are missing
**Then** I see a clear message explaining what needs to be completed before the work order can be created

### Scenario 6.6: Viewing Work Order Preview
**Given** I want to see work order details before finalization
**When** I access work order preview
**Then** I see all the information that will be sent to the vendor: service date, location, instructions, contact info

---

## 7. QUOTE & PRICING MANAGEMENT

### Scenario 7.1: Adding Quote to Service Request
**Given** I am creating a case that requires pricing
**When** I select "Add Quote" in the wizard
**Then** I see a quote creation interface where I can configure pricing details

### Scenario 7.2: Selecting Products for Quote
**Given** I am creating a quote
**When** I need to specify what products/services to price
**Then** I can search and select from available product catalog with equipment types and service frequencies

### Scenario 7.3: Multi-Vendor Pricing
**Given** Multiple vendors can provide the service I need
**When** I request pricing
**Then** I can send pricing requests to multiple vendors and compare their responses

### Scenario 7.4: Viewing Quote Cost Breakdown
**Given** I have received quotes from vendors
**When** I review the quotes
**Then** I see detailed line items showing equipment costs, service fees, and total pricing

### Scenario 7.5: Selecting Preferred Quote
**Given** I have multiple quote options
**When** I choose the best quote for my needs
**Then** I can select that quote and it becomes associated with my case

### Scenario 7.6: Quote Requires Approval Due to Cost
**Given** A quote exceeds spending limits
**When** I try to proceed with that quote
**Then** I see that the quote requires manager approval before the service can be scheduled

### Scenario 7.7: Using Existing Quote
**Given** I have a previously approved quote for similar service
**When** I create a new case
**Then** I can search for and select the existing quote rather than creating a new one

---

## 8. APPROVAL WORKFLOWS

### Scenario 8.1: Knowing My Request Needs Approval
**Given** My service request triggers approval rules (cost, service type, etc.)
**When** I complete the case creation
**Then** I see clear notification that approval is required and who will review it

### Scenario 8.2: Tracking Approval Status
**Given** My case requires approval
**When** I check the case status
**Then** I see the approval status: Pending, Approved, or Rejected

### Scenario 8.3: Understanding Approval Requirements
**Given** I am viewing approval information
**When** I look at why approval is needed
**Then** I see the specific business rule that triggered the approval (e.g., "Cost exceeds $1,000 limit")

### Scenario 8.4: Case on Hold Pending Approval
**Given** My case requires approval
**When** The approval is still pending
**Then** I see that my case cannot proceed to work order creation until approved

### Scenario 8.5: Approval Rejected - Next Steps
**Given** My approval request was rejected
**When** I view my case
**Then** I see the rejection reason and understand what changes are needed to resubmit

### Scenario 8.6: Automatic Approval Based on Threshold
**Given** My service cost is below approval thresholds
**When** I submit my case
**Then** The case automatically proceeds without requiring manual approval

---

## 9. VIEWING & MONITORING CASES

### Scenario 9.1: Viewing Case Highlight Information
**Given** I am looking at an open case
**When** I view the case page
**Then** I see a prominent highlight strip showing key information: location, contact, asset, service type, and date

### Scenario 9.2: Color-Coded Status Indicators
**Given** I am viewing the case highlight strip
**When** I look at different fields
**Then** I see color coding that shows me what's complete, what's missing, and what needs attention

### Scenario 9.3: Seeing Required Actions
**Given** I have an open case that needs information
**When** I view the case
**Then** I see an action messages panel clearly listing what I need to do next

### Scenario 9.4: Quick Edit from Highlight Strip
**Given** I need to update case information
**When** I click on a field in the highlight strip
**Then** I can edit that field directly without opening a separate edit mode

### Scenario 9.5: Viewing Related Cases
**Given** I created multiple cases from a multi-date request
**When** I view any of those cases
**Then** I see links to all related cases (parent and siblings)

### Scenario 9.6: Monitoring SLA Compliance
**Given** I have a case with a service level agreement
**When** I view the case
**Then** I see whether the case is on track to meet SLA or is at risk of missing the deadline

### Scenario 9.7: Viewing Case Comments and History
**Given** I want to understand case activity
**When** I view the case history section
**Then** I see all comments, status changes, and updates in chronological order

### Scenario 9.8: Searching for My Cases
**Given** I need to find a specific case among many
**When** I use the case search/navigation
**Then** I can filter by location, asset, date range, status, or case number

---

## 10. ASSET & LOCATION MANAGEMENT

### Scenario 10.1: Viewing All Assets at a Location
**Given** I want to see what equipment is serviced at one of my locations
**When** I search for that location
**Then** I see a list of all active assets with their service details

### Scenario 10.2: Understanding Asset Service Details
**Given** I am looking at an asset
**When** I view its details
**Then** I see equipment type, material type, current vendor, service frequency, and container position

### Scenario 10.3: Asset Hover Card for Quick Info
**Given** I see an asset name in the interface
**When** I hover over it
**Then** I see a popup card with key asset details without leaving my current page

### Scenario 10.4: Selecting from Favorite Containers
**Given** I frequently request service for specific containers
**When** I create a new case
**Then** I can quickly select from my saved favorite containers

### Scenario 10.5: Adding New Asset During Case Creation
**Given** I am requesting new service that requires new equipment
**When** I select "New Service" case type
**Then** I can specify what type of equipment is needed without selecting an existing asset

### Scenario 10.6: Viewing Asset Service History
**Given** I want to know past service on a specific container
**When** I view the asset details
**Then** I see previous cases and work orders related to that asset

---

## 11. DUPLICATE PREVENTION & VALIDATION

### Scenario 11.1: Warning About Duplicate Request
**Given** I am creating a case
**When** A case or work order already exists for the same asset and date
**Then** I see a warning about the potential duplicate before I submit

### Scenario 11.2: Viewing Conflicting Work Orders
**Given** A duplicate check found conflicts
**When** I review the warning
**Then** I see details of the existing work order: case number, date, status

### Scenario 11.3: Proceeding Despite Duplicate Warning
**Given** I see a duplicate warning but know my request is different
**When** I choose to proceed
**Then** I can override the warning and create my case anyway

### Scenario 11.4: Canceling Duplicate Request
**Given** I realize I'm creating a duplicate request
**When** I see the duplicate warning
**Then** I can cancel my request and view the existing case instead

### Scenario 11.5: Multi-Date Duplicate Checking
**Given** I am scheduling multiple dates
**When** Some dates conflict with existing work orders
**Then** I see which specific dates have conflicts and can remove them from my selection

---

## 12. BUSINESS RULE COMPLIANCE

### Scenario 12.1: Seeing Applicable Business Rules
**Given** I am creating or viewing a case
**When** Business rules apply to my situation
**Then** I see a clear summary of which rules are active and what they require

### Scenario 12.2: Understanding Required Information Rules
**Given** Business rules require specific information
**When** I view the rules
**Then** I see exactly which fields must be completed (e.g., "PO Number Required")

### Scenario 12.3: Understanding Spending Limits (NTE)
**Given** My service has cost limits
**When** I view business rules
**Then** I see the Non-Time Estimate (NTE) limit and whether my request is within that limit

### Scenario 12.4: Case Blocked by Business Rules
**Given** I haven't met all business rule requirements
**When** I try to progress my case
**Then** I see a clear message explaining which rules are blocking progression

### Scenario 12.5: Rule-Based Automatic Routing
**Given** My case meets specific criteria (location, service type, cost)
**When** I submit the case
**Then** The system automatically routes it to the correct approval queue or work group

### Scenario 12.6: Viewing All Rules Modal
**Given** I want to understand all applicable rules
**When** I click "View All Rules"
**Then** I see a detailed modal showing all business rules, their priority, and their requirements

---

## 13. CONTACT & ENTITY MANAGEMENT

### Scenario 13.1: Searching for Existing Contact
**Given** I need to specify who is requesting service
**When** I search for a contact by name
**Then** I see matching contacts from my organization with their details

### Scenario 13.2: Creating New Contact
**Given** I can't find my contact in the search
**When** I select "Create New Contact"
**Then** I can enter contact details and save them to use in my case

### Scenario 13.3: Contact Information Auto-Fill
**Given** I selected a contact
**When** The case is created
**Then** Contact's phone, email, and preferred contact method are automatically included

### Scenario 13.4: Multiple Contacts at Location
**Given** My location has many employees
**When** I search for contacts
**Then** I see all contacts associated with that location and can choose the right person

### Scenario 13.5: Vendor Contact Selection
**Given** I am a client user coordinating with a vendor
**When** I need to specify the vendor contact
**Then** I can search for contacts at the vendor organization

---

## 14. NOTIFICATIONS & COMMUNICATION

### Scenario 14.1: Receiving Case Status Updates
**Given** I created a case
**When** The case status changes (approved, work order created, completed)
**Then** I receive a notification via my preferred method (email, SMS, etc.)

### Scenario 14.2: Configuring Notification Preferences
**Given** I want to control how I'm notified
**When** I access notification settings
**Then** I can specify which events trigger notifications and how I want to be contacted

### Scenario 14.3: Viewing Case Comments
**Given** The vendor or service team added comments to my case
**When** I view the case
**Then** I see all comments with timestamps and author information

### Scenario 14.4: Adding Comments to Case
**Given** I need to provide additional information
**When** I access the comment section
**Then** I can add comments that are visible to the service team

### Scenario 14.5: External Comments for Vendor
**Given** I need to communicate with the vendor
**When** I add a comment marked as "External"
**Then** That comment is shared with the vendor through the Acorn system

### Scenario 14.6: Urgent Service Alerts
**Given** I need immediate attention for a service issue
**When** I mark my case or comment as urgent
**Then** An alert is sent to the appropriate service team or manager

---

## 15. SPECIAL CASE TYPES

### Scenario 15.1: Emergency Pickup Request
**Given** I have an urgent need for unscheduled service
**When** I select "Emergency Pickup" as the case sub-type
**Then** The system prioritizes my request with expedited SLA

### Scenario 15.2: New Service Setup
**Given** I am a new customer or adding service to a new location
**When** I select "New Service" case type
**Then** I go through an extended setup that includes equipment specification and installation scheduling

### Scenario 15.3: Service Activation
**Given** I have a dormant service that needs to restart
**When** I select "Activation" case type
**Then** The system reactivates my service agreement and schedules the first pickup

### Scenario 15.4: Service Modification
**Given** I need to change my existing service (frequency, equipment size, etc.)
**When** I select "Modify" case type
**Then** I can specify what aspects of the service need to change

### Scenario 15.5: Service Deactivation/Cancellation
**Given** I no longer need service at a location
**When** I select "Deactivate" case type
**Then** The system schedules final pickup and processes service termination

### Scenario 15.6: Special Pickup with Custom Instructions
**Given** I need a non-routine pickup with specific requirements
**When** I create a pickup case
**Then** I can enter custom instructions that will be visible to the service driver

---

## 16. MULTI-VENDOR SCENARIOS

### Scenario 16.1: Viewing Multiple Vendor Options
**Given** Multiple vendors can service my location
**When** I view vendor options
**Then** I see a list of available vendors with their service capabilities

### Scenario 16.2: Requesting Pricing from Multiple Vendors
**Given** I want to compare vendor pricing
**When** I create a pricing request
**Then** I can select multiple vendors to receive pricing quotes

### Scenario 16.3: Vendor Response Comparison
**Given** Multiple vendors have responded to my pricing request
**When** I view the responses
**Then** I see a side-by-side comparison of pricing, service dates, and terms

### Scenario 16.4: Selecting Preferred Vendor
**Given** I have reviewed vendor options
**When** I choose a vendor
**Then** My case and work order are assigned to that vendor

### Scenario 16.5: Vendor Escalation
**Given** My current vendor cannot meet my service needs
**When** I request vendor escalation
**Then** The case is routed to alternative vendors or management

---

## 17. RECORD TYPE & CASE CLASSIFICATION

### Scenario 17.1: Changing Case Record Type
**Given** I created a case with the wrong classification
**When** I select "Change Record Type"
**Then** I can reclassify my case and the system adjusts available fields and rules

### Scenario 17.2: Understanding Case Sub-Types
**Given** I selected a case type
**When** I view available sub-types
**Then** I see specific sub-types relevant to my case type (e.g., for Pickup: Standard, Emergency, Special)

### Scenario 17.3: Dynamic Field Display Based on Type
**Given** I changed my case type
**When** I continue filling out the case
**Then** I see different required fields and options based on the selected type

---

## 18. CALENDAR & DATE SELECTION

### Scenario 18.1: Visual Calendar for Date Selection
**Given** I need to choose a service date
**When** I open the date picker
**Then** I see a calendar view with available dates highlighted

### Scenario 18.2: Multi-Date Selection
**Given** I need service on several dates
**When** I use the calendar
**Then** I can click multiple dates and they're all selected for case creation

### Scenario 18.3: Holiday and Blackout Dates
**Given** I am viewing the service calendar
**When** Holidays or blackout dates exist
**Then** Those dates are clearly marked as unavailable

### Scenario 18.4: Custom Date Range Selection
**Given** I need service over a specific period
**When** I specify a date range
**Then** The system suggests appropriate service dates within that range

---

## 19. MOBILE & ACCESSIBILITY SCENARIOS

### Scenario 19.1: Creating Case on Mobile Device
**Given** I am accessing the system from my phone
**When** I create a case
**Then** The interface adapts to mobile screen size with simplified navigation

### Scenario 19.2: Quick Service Request
**Given** I need a simple pickup request on mobile
**When** I access quick request mode
**Then** I can create a standard pickup with minimal steps

### Scenario 19.3: Viewing Case on Mobile
**Given** I am checking case status from my phone
**When** I view a case
**Then** I see the most critical information prominently displayed

---

## 20. ERROR HANDLING & VALIDATION

### Scenario 20.1: Missing Required Field
**Given** I am filling out a case
**When** I skip a required field
**Then** I see a clear validation message identifying the missing field

### Scenario 20.2: Invalid Service Date
**Given** I manually entered a service date
**When** That date is outside acceptable range
**Then** I see an error explaining why the date is invalid and what dates are acceptable

### Scenario 20.3: System Error During Submission
**Given** I am submitting a case
**When** A system error occurs
**Then** I see a friendly error message and my entered information is preserved

### Scenario 20.4: Capacity API Unavailable
**Given** I am scheduling a rolloff service
**When** The capacity planner API is temporarily unavailable
**Then** The system falls back to standard SLA calculation and notifies me of the limitation

### Scenario 20.5: Validation Before Each Phase
**Given** I am completing a phase in the wizard
**When** I click "Next"
**Then** The system validates my entries before allowing me to proceed

---

## 21. CUSTOMER INFORMATION SCENARIOS

### Scenario 21.1: Entering Purchase Order Number
**Given** My organization requires PO tracking
**When** I create a case
**Then** I can enter my PO number which appears on all related documentation

### Scenario 21.2: Profile Number for Billing
**Given** I have multiple billing profiles
**When** I create a case
**Then** I can specify which profile should be charged for this service

### Scenario 21.3: Project Site Information (PSI)
**Given** This service is for a specific project
**When** I enter project details
**Then** I can add PSI information for project tracking and reporting

### Scenario 21.4: Customer Info Auto-Population
**Given** I previously entered customer information for this location
**When** I create a new case
**Then** My PO, Profile, and PSI information auto-populate from the last case

---

## 22. REPORTING & HISTORY SCENARIOS

### Scenario 22.1: Viewing My Service History
**Given** I want to review past service requests
**When** I access my case history
**Then** I see all cases organized by date with status and outcomes

### Scenario 22.2: Filtering Cases by Status
**Given** I have many cases in the system
**When** I want to see only open cases
**Then** I can filter by status (New, In Progress, Completed, Closed)

### Scenario 22.3: Exporting Case Data
**Given** I need to report on service activity
**When** I select cases to export
**Then** I can download case data in a usable format

### Scenario 22.4: Viewing Service Metrics
**Given** I want to understand my service performance
**When** I access the dashboard
**Then** I see metrics like SLA compliance, average response time, and case volume

---

## 23. ADVANCED SEARCH & NAVIGATION

### Scenario 23.1: Global Search for Cases
**Given** I need to find a case but don't remember details
**When** I use global search
**Then** I can search by case number, location name, asset ID, or contact name

### Scenario 23.2: Recently Viewed Cases
**Given** I was working on a case earlier
**When** I want to return to it
**Then** I can see my recently viewed cases for quick access

### Scenario 23.3: Saved Search Filters
**Given** I frequently search with the same criteria
**When** I create a saved filter
**Then** I can quickly apply that filter in future sessions

---

## SUMMARY OF USER PERSONAS & PRIMARY WORKFLOWS

### Persona 1: Site Manager (Primary User)
**Primary Goals:**
- Request routine service pickups
- Track service completion
- Manage service schedule changes
- Monitor service costs

**Key Workflows:**
- Phase 1-4 case creation for standard pickups
- Multi-date scheduling for recurring needs
- Service date rescheduling
- Case status monitoring

### Persona 2: Service Coordinator (Frequent User)
**Primary Goals:**
- Coordinate complex service requests
- Manage multiple locations
- Handle vendor relationships
- Ensure SLA compliance

**Key Workflows:**
- Multi-vendor pricing requests
- New service setup
- Service modifications
- Approval tracking

### Persona 3: Vendor User (External)
**Primary Goals:**
- Receive work orders
- Update service status
- Communicate with customers
- Provide pricing quotes

**Key Workflows:**
- Work order viewing and management
- Status updates
- Comment/communication
- Quote submission

### Persona 4: Service Approver (Occasional User)
**Primary Goals:**
- Review approval requests
- Approve or reject based on business rules
- Monitor spending and compliance

**Key Workflows:**
- Approval queue management
- Case review
- Approval/rejection with comments

---

## DESIGN PRINCIPLES FOR UX IMPROVEMENT

Based on the current implementation, consider these UX principles:

1. **Progressive Disclosure**: Show only relevant information at each phase
2. **Clear Visual Hierarchy**: Use the highlight strip pattern for key information
3. **Inline Validation**: Validate as users complete each field
4. **Color-Coded Status**: Maintain color system for status indicators
5. **Contextual Help**: Provide help text for complex fields and business rules
6. **Mobile-First**: Ensure critical workflows work on mobile devices
7. **Minimal Clicks**: Reduce steps where possible (e.g., quick pickup)
8. **Smart Defaults**: Pre-populate based on history and context
9. **Error Prevention**: Use validation and warnings to prevent mistakes
10. **Confirmation Feedback**: Clearly confirm actions have completed

---

**Document Version:** 1.0
**Last Updated:** 2025-11-24
**Purpose:** UX Research for Figma Mockup Design
**Scope:** Waste Management Service System - Complete User Workflows

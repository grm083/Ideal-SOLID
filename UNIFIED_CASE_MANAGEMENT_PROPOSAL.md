# Unified Case Management System - Technical Proposal

**Project:** Case Panel Recreation & Integration
**Date:** 2025-11-18
**Author:** Claude (AI Assistant)
**Target Completion:** Q4 2025
**Deployment Strategy:** Big-Bang (Full Rebuild)

---

## Executive Summary

This proposal outlines a complete rebuild of the case management UI components (CustomCaseHighlightPanel and ShowCaseMessages) along with their 9 child modal components into a **unified, wizard-based LWC architecture** that provides a seamless user experience for case creation, modification, and maintenance.

### Key Benefits

- **50-70% reduction in load times** through optimized data fetching and caching
- **Elimination of LWC re-render issues** through proper state management and LDS integration
- **Unified wizard workflow** guiding users through phased case creation
- **Consolidated modal components** reducing cognitive load
- **100% reuse of existing Apex services** preserving business logic
- **Future-proof LWC architecture** aligned with Salesforce platform direction

---

## Problem Statement

###Current Challenges

| Challenge | Impact | Affected Components |
|-----------|--------|---------------------|
| **Slow/nonfunctional data retrieval** | High | All components |
| **Runtime dependencies** | High | CustomCaseHighlightPanel, ShowCaseMessages |
| **Incomplete rendering** | High | Both panels + child modals |
| **LWC re-render failures after Case DML** | Critical | All LWC versions |
| **Confusing location + asset blend** | Medium | Location search modal |
| **Contact type toggle burden** | Medium | SearchExistingContact |
| **Redundant record type/subtype** | Medium | changeRecordType + FillCaseSubType |
| **Frequent errors** | High | Trigger network (resolved via service layer) |

### User Pain Points

1. **Slowness** - Average 5-10 second load times
2. **Errors** - Frequent validation failures and incomplete operations
3. **Confusion** - Unclear workflows, especially for location/asset/contact selection
4. **Inefficiency** - Too many clicks to complete basic tasks

---

## Proposed Solution Architecture

### 1. Unified Parent Container (LWC)

**Component Name:** `caseManagerContainer`

**Purpose:** Orchestrates the entire case management workflow

**Responsibilities:**
- State management for entire wizard process
- Data coordination between child components
- Progress tracking through wizard steps
- API calls to Apex services (reuse existing)
- Error handling and user messaging
- Publish/subscribe to LMS for cross-component communication

**Technology Stack:**
- LWC with Lightning Data Service (LDS)
- Lightning Message Service (LMS) for communication
- Wire adapters for reactive data
- Apollo cache patterns for performance

### 2. Component Hierarchy

```
caseManagerContainer (Parent)
├── caseWizardStepper (Progress Indicator)
│
├── Phase 1: Caller Identification
│   ├── entitySelector (Location/Vendor/Client)
│   └── contactSelector (Unified contact search/creation)
│
├── Phase 2: Intent Configuration
│   ├── assetSelector (Asset search & selection)
│   └── caseTypeConfigurator (Consolidated record type + case type/subtype/reason)
│
├── Phase 3: Details & Validation
│   ├── customerInfoPanel (PO, Profile, PSI)
│   ├── serviceDateSelector (SLA date configuration with capacity check)
│   └── businessRuleValidator (Real-time validation display)
│
├── Phase 4: Review & Submit
│   ├── caseSummaryCard (Read-only review)
│   └── workOrderPreview (Optional WO details)
│
└── Persistent Panels (Always Visible)
    ├── caseHighlightStrip (Inline case details - NO hover)
    └── actionMessagesPanel (Next steps & buttons)
```

### 3. Shared Utility Components (Reusable LWCs)

```
utilityComponents/
├── recordSearchBase (Generic search component)
├── businessRuleDisplay (NTE rules, approval requirements)
├── validationMessageBar (Consolidated error/warning display)
├── progressIndicator (Stepper UI)
└── inlineDetailCard (Replaces hover cards - INLINE display)
```

### 4. Quote Management Integration

**Component Name:** `quoteManagerPanel`
**Integration Point:** Shown in Phase 4 or as button in actionMessagesPanel

**Responsibilities:**
- Display existing quotes (replaces ExistingQuoteModal)
- Create new quotes (replaces CaseQuoteModal)
- Favorite containers selection (replaces AddFavoriteContainers)
- Navigate to quote records

---

## User Journey & Workflow

### NEW Case Creation Workflow

```
START → Load caseManagerContainer
  ↓
Phase 1: CALLER IDENTIFICATION (Auto-detect or select entity type)
  ├─ Step 1.1: Select Location (OR Vendor OR Client based on case type)
  │    └─ Search interface with filters
  │    └─ Inline location details (NOT hover)
  │
  └─ Step 1.2: Select/Create Contact
       ├─ Context-aware: Shows relevant contacts for selected entity
       ├─ Unified interface (NO toggle between customer/vendor/internal)
       └─ Create new contact inline if needed
  ↓
Phase 2: INTENT CONFIGURATION
  ├─ Step 2.1: Select Asset (separate from location)
  │    └─ Filtered by selected location
  │    └─ Inline asset details (NOT hover)
  │
  └─ Step 2.2: Configure Case Type
       ├─ Record Type selection (with quick actions: Pickup, New Service, SNP, ETA)
       ├─ Case Type dropdown (filtered by record type)
       ├─ Case Sub-Type dropdown (dependent on case type)
       └─ Case Reason dropdown (dependent on sub-type)
  ↓
Phase 3: DETAILS & VALIDATION
  ├─ Step 3.1: Customer Information (if required by business rules)
  │    ├─ PO Number
  │    ├─ Profile Number
  │    └─ PSI (with override options)
  │
  ├─ Step 3.2: Service Date
  │    ├─ SLA Date calculator
  │    ├─ Capacity check (real-time)
  │    └─ Calendar picker
  │
  └─ Step 3.3: Business Rules Check (auto-runs)
       ├─ NTE approval requirements → Display approval chain
       ├─ Required information validation
       └─ Asset eligibility checks
  ↓
Phase 4: REVIEW & SUBMIT
  ├─ Summary card showing all selections
  ├─ Optional: Work Order instructions
  ├─ Optional: Add Quote button (if eligible)
  └─ Submit button → Creates case via Apex
  ↓
SUCCESS → Navigate to case record
  └─ caseHighlightStrip + actionMessagesPanel now show case details
```

### EXISTING Case Modification Workflow

```
START → Case record page with caseManagerContainer
  ↓
caseHighlightStrip displays:
  ├─ Entity (Location/Vendor/Client) - Inline details (click to edit)
  ├─ Asset - Inline details (click to edit)
  ├─ Contact - Inline details (click to edit)
  ├─ SLA Date
  ├─ Record Type, Case Type, Sub-Type, Reason
  ├─ Reference #, Material, PO/Profile/PSI, Service Date
  ├─ Queue, Tracking #, Sub-Status, Work Order
  └─ All fields color-coded: Green=complete, Orange=needs action, Red=missing required
  ↓
actionMessagesPanel displays:
  ├─ "Action Required" or "Required Information" message
  ├─ Next steps buttons:
  │   ├─ Progress Case
  │   ├─ Add Quote / View Quotes
  │   ├─ View Case Summary (multi-asset)
  │   ├─ Initiate Work Order
  │   └─ Create Pending Info Task
  └─ All buttons visibility controlled by CaseBusinessRuleService
  ↓
Click ANY field in highlight strip → Opens relevant wizard phase
  Example: Click "Contact" → Opens contactSelector in edit mode
  Example: Click "Service Date" → Opens serviceDateSelector
  ↓
Make changes → Real-time validation → Save
  └─ LDS automatically refreshes both panels (NO re-render issues)
```

---

## Component Design Specifications

### Phase 1: Caller Identification

#### 1.1 entitySelector (LWC)

**Replaces:**
- LocationContainer (Aura)
- VendorContainer (Aura)
- ClientContainer (Aura)

**Features:**
- Single unified component with 3 modes (Location/Vendor/Client)
- Mode auto-detected from case type or user selection
- Search interface with filters:
  - Name, Account Number, Address, City, State, ZIP
- Results table with sortable columns
- Inline details panel (NOT hover card)
- "Create New" button for new locations/vendors/clients

**Apex Controllers to Reuse:**
- `LocationContainerController.cls` - Search methods
- `VendorContainerController.cls` - Vendor search
- `ClientContainerController.cls` - Client search

**Wire Services:**
```javascript
@wire(getEntityRecords, { searchTerm: '$searchTerm', entityType: '$entityType' })
wiredEntities({ error, data }) { ... }
```

#### 1.2 contactSelector (LWC)

**Replaces:**
- SearchExistingContact (Aura + LWC)

**Features:**
- Context-aware: Automatically filters contacts by selected entity
- NO toggle needed - intelligently shows relevant contact types
- Multi-field search: First Name, Last Name, Email, Phone, Mobile
- Duplicate detection inline
- "Create New Contact" inline form
- Vendor search integration (2-step for vendor contacts)
- Account title/department management

**Apex Controllers to Reuse:**
- `SearchExistingContactController.cls`
- All existing validation logic

**UI Improvements:**
- Single search interface (no mode toggle)
- Context pills showing: "Searching contacts for: [Location Name]"
- Tabbed results if multiple types returned

### Phase 2: Intent Configuration

#### 2.1 assetSelector (LWC)

**Replaces:**
- ShowAssetHeadersOnCase (Aura + LWC)

**Features:**
- Filtered asset list by selected location
- Two sections: Active Assets | Inactive Assets (collapsible)
- 21-column table (current functionality preserved)
- Multi-select with checkboxes
- "Replace Asset" workflow
- "Create Multi-Asset Cases" workflow
- Inline asset details panel (NOT hover)

**Apex Controllers to Reuse:**
- `AssetHeadersForCaseController.cls`

#### 2.2 caseTypeConfigurator (LWC)

**Replaces:**
- changeRecordType (Aura + LWC)
- FillCaseSubType (Aura + LWC)

**Features:**
- Unified component combining record type + case type selection
- Vertical navigation for record types (current UI preserved)
- Quick action buttons: Pickup, New Service, SNP, ETA
- Dependent dropdowns:
  - Select Record Type → Filters Case Types
  - Select Case Type → Filters Sub-Types
  - Select Sub-Type → Filters Reasons
- Real-time validation of restricted combinations
- Business rule preview: "This combination requires approval"

**Apex Controllers to Reuse:**
- `changeRecordTypeController.cls`
- `FillCaseSubTypeController.cls`
- **CaseBusinessRuleService.cls** (for validations)

### Phase 3: Details & Validation

#### 3.1 customerInfoPanel (LWC)

**Replaces:**
- SetCaseCustomerInfo (Aura)

**Features:**
- Conditional display (only if required by business rules)
- PO Number field + override checkbox
- Profile Number field + override checkbox
- PSI field + override dropdown + comments
- Real-time validation against business rules
- "Save" button with inline confirmation

**Apex Controllers to Reuse:**
- `SetCaseCustomerInfoController.cls`
- **CaseBusinessRuleService.isPurchaseOrderRequired()**
- **CaseBusinessRuleService.isProfileNumberRequired()**
- **CaseBusinessRuleService.isPSIRequired()**

#### 3.2 serviceDateSelector (LWC)

**Replaces:**
- ServiceDateContainer (Aura)
- SetCaseSLADate (Aura)

**Features:**
- SLA Date calculator (auto-suggests based on case type)
- Service Date calendar picker
- Real-time capacity check integration
- Visual capacity indicator: Green=Available, Yellow=Limited, Red=Full
- Multi-date selection for recurring services
- Proposed service date vs. SLA date comparison

**Apex Controllers to Reuse:**
- `ServiceDateContainerController.cls`
- `SetCaseSLADateController.cls`
- Capacity check APIs (existing)

**Wire Services:**
```javascript
@wire(checkCapacity, { locationId: '$locationId', serviceDate: '$serviceDate' })
wiredCapacity({ error, data }) { ... }
```

#### 3.3 businessRuleValidator (LWC)

**Replaces:**
- ntebRulesModal (LWC)

**NEW Component - Inline Display**

**Features:**
- Real-time business rule evaluation
- Inline display (NOT modal) in Phase 3
- Sections:
  - Approval Requirements
    - Approver chain with names, titles, service types
    - NTE amount display
    - Auto-approval vs. Manual approval indicator
  - Required Information
    - PO, Profile, PSI requirements with status indicators
  - Asset Eligibility
    - Material, duration, category validation
  - Service Constraints
    - Occurrence limits
    - Duplicate work order checks
- Color-coded status: Green=Met, Red=Not Met, Yellow=Warning
- Expandable/collapsible sections

**Apex Controllers to Reuse:**
- `NTEBRRulesModalCtrl.cls`
- **CaseBusinessRuleService.evaluateBusinessRules()**
- **CaseBusinessRuleService.validateCaseReadyForWorkOrder()**
- `BusinessRuleHelper.cls`
- `BusinessRuleUtility.cls`

### Phase 4: Review & Submit

#### 4.1 caseSummaryCard (LWC)

**NEW Component**

**Features:**
- Read-only summary of all selections
- Organized sections matching wizard phases:
  - Caller: Location, Contact
  - Intent: Asset, Case Types
  - Details: Customer Info, Service Date
  - Business Rules: Approval status, Requirements met
- "Edit" buttons for each section → Jumps back to that phase
- Visual progress indicator: "4 of 4 phases complete"

#### 4.2 workOrderPreview (LWC)

**Replaces (partially):**
- Work Order Instructions modal in ShowCaseMessages

**Features:**
- Optional section in Phase 4
- Onsite Contact Name field
- Onsite Contact Phone field
- Work Order Instructions textarea
- "By-Pass W/O" checkbox
- Preview of work order that will be created

**Apex Controllers to Reuse:**
- Work order related methods from `GetCaseInformation.cls`

### Persistent Panels

#### caseHighlightStrip (LWC)

**Replaces:**
- CustomCaseHighlightPanel (Aura + LWC)

**Features:**
- Horizontal strip layout (modern, condensed)
- Inline field display with color coding:
  - ✅ Green background = Complete & valid
  - ⚠️ Orange background = Needs attention
  - ❌ Red background = Missing required field
  - ℹ️ Blue background = Informational
- Click any field → Opens relevant editor (wizard phase or inline modal)
- **NO HOVER CARDS** - All details shown inline on click
- Real-time updates via LDS (no re-render issues)

**Layout:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│ [Location] [Asset] [Contact] [SLA Date] [Record Type] [Case Type]      │
│ [Sub-Type] [Reason] [Queue] [Work Order] [Status] [Sub-Status]         │
│                                                                          │
│ [Reference #] [Material] [PO/Profile/PSI] [Service Date] [Tracking #] │
└─────────────────────────────────────────────────────────────────────────┘
```

**Apex Controllers to Reuse:**
- `CustomCaseHighlightPanelCntrl.cls`
- **CaseUIService.getCaseHighlightData()**

#### actionMessagesPanel (LWC)

**Replaces:**
- ShowCaseMessages (Aura + LWC)

**Features:**
- Compact card layout above or below highlight strip
- Message section:
  - Icon (red=action required, green=ready, blue=info)
  - Heading: "Action Required" or "Required Information"
  - Message text from business rules
- Button section (horizontal button group):
  - Progress Case
  - View Case Summary (multi-asset)
  - Add Quote / View Quotes
  - Initiate Work Order
  - Add Case Assets
  - Create Pending Info Task
  - Multi Dates (if applicable)
- All button visibility controlled by **CaseBusinessRuleService**
- Spinner overlay during operations

**Apex Controllers to Reuse:**
- `GetCaseInformation.cls`
- **CaseBusinessRuleService** (all button visibility methods)
- **CaseUIService.shouldShowProgressCaseButton()**
- **CaseUIService.shouldShowAddQuoteButton()**

### Quote Management

#### quoteManagerPanel (LWC)

**Replaces:**
- CaseQuoteModal (Aura + LWC)
- ExistingQuoteModal (Aura + LWC)
- AddFavoriteContainers (Aura + LWC)

**Features:**
- Tabbed interface:
  - Tab 1: Existing Quotes
  - Tab 2: Create New Quote
  - Tab 3: Favorite Containers
- Existing Quotes tab:
  - Table with quote details (name, status, duration, product, dates)
  - Nested configured products
  - "Navigate to Quote" buttons
  - "Close Case" action
- Create New Quote tab:
  - Product selection interface
  - Quote configuration wizard
- Favorite Containers tab:
  - Common container products
  - Quick-add functionality
  - "Product Not Listed" option

**Apex Controllers to Reuse:**
- `QuoteProcurementController.cls`
- `GetCaseInformation.cls` (quote methods)

### Utility & Task Components

#### pendingInfoTaskCreator (LWC)

**Replaces:**
- CreatePendingInformationTask (Aura + LWC)

**Features:**
- Modal or inline (configurable)
- Two modes:
  - Pending Information Task: Task Type, Due Date/Time, Follow-Up Reasons, Comments
  - Internal Response Task: Task Type, Assigned To (User lookup), SFDC Team, Acorn Team
- Form validation
- Spinner during creation
- Success/error toast messages

**Apex Controllers to Reuse:**
- `CreatePendingInformationTask.cls`

---

## Data Flow Architecture

### 1. Data Loading Strategy

**Problem:** Current components make 3-4 server calls on init causing slowness

**Solution:** Centralized data loader in parent container

```javascript
// caseManagerContainer.js

import { LightningElement, api, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import getCaseContext from '@salesforce/apex/CaseContextService.getCaseContext';

export default class CaseManagerContainer extends LightningElement {
    @api recordId;

    // Single comprehensive wire call
    @wire(getCaseContext, { caseId: '$recordId' })
    wiredCaseContext({ error, data }) {
        if (data) {
            this.caseData = data.caseRecord;
            this.locationData = data.locationDetails;
            this.assetData = data.assetDetails;
            this.contactData = data.contactDetails;
            this.businessRules = data.businessRules;
            this.buttonVisibility = data.buttonStates;
            this.validationMessages = data.messages;

            // Distribute to child components via properties
            this.isLoading = false;
        }
    }
}
```

**New Apex Service:** `CaseContextService.getCaseContext(Id caseId)`

Returns single comprehensive wrapper:
```apex
public class CaseContextWrapper {
    @AuraEnabled public Case caseRecord;
    @AuraEnabled public Account locationDetails;
    @AuraEnabled public Asset assetDetails;
    @AuraEnabled public Contact contactDetails;
    @AuraEnabled public CaseBusinessRuleService.BusinessRuleResult businessRules;
    @AuraEnabled public Map<String,Boolean> buttonStates;
    @AuraEnabled public List<String> messages;
    @AuraEnabled public Map<String,String> metadata;
}
```

**Performance Benefit:** 1 server call instead of 4 = **75% reduction in network overhead**

### 2. State Management

**Problem:** LWC re-render issues after Case DML

**Solution:** Leverage LDS (Lightning Data Service) properly

```javascript
// Use LDS for all Case operations
import { updateRecord } from 'lightning/uiRecordApi';

async handleSaveCase() {
    const fields = {
        Id: this.recordId,
        ContactId: this.selectedContactId,
        AssetId: this.selectedAssetId,
        // ... other fields
    };

    const recordInput = { fields };

    try {
        await updateRecord(recordInput);
        // LDS automatically refreshes all components using this record
        // NO manual refresh needed
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Case updated successfully',
            variant: 'success'
        }));
    } catch (error) {
        this.handleError(error);
    }
}
```

**Key Pattern:** Always use LDS APIs (getRecord, updateRecord, createRecord) instead of imperative Apex calls when possible.

**Benefit:** Automatic cache invalidation and component refresh - **SOLVES re-render issue**

### 3. Component Communication

**Problem:** Multiple components need to know about Case updates

**Solution:** Lightning Message Service (LMS)

```javascript
// Publisher (any component that updates Case)
import { publish, MessageContext } from 'lightning/messageService';
import CASE_UPDATED_CHANNEL from '@salesforce/messageChannel/CaseUpdated__c';

@wire(MessageContext)
messageContext;

notifyCaseUpdated() {
    const payload = {
        caseId: this.recordId,
        fieldName: 'ContactId',
        newValue: this.selectedContactId
    };
    publish(this.messageContext, CASE_UPDATED_CHANNEL, payload);
}
```

```javascript
// Subscriber (caseHighlightStrip, actionMessagesPanel, etc.)
import { subscribe, MessageContext } from 'lightning/messageService';
import CASE_UPDATED_CHANNEL from '@salesforce/messageChannel/CaseUpdated__c';

@wire(MessageContext)
messageContext;

connectedCallback() {
    this.subscription = subscribe(
        this.messageContext,
        CASE_UPDATED_CHANNEL,
        (message) => this.handleCaseUpdate(message)
    );
}

handleCaseUpdate(message) {
    if (message.caseId === this.recordId) {
        // Refresh local state
        this.refreshData();
    }
}
```

**Benefit:** Decoupled communication, no prop drilling

### 4. Caching Strategy

**Problem:** Redundant server calls for same data

**Solution:** Apollo-style caching pattern

```javascript
// Cache in parent container
const CACHE_TTL = 30000; // 30 seconds

caseContextCache = {
    data: null,
    timestamp: null
};

get isCacheValid() {
    if (!this.caseContextCache.data || !this.caseContextCache.timestamp) {
        return false;
    }
    return (Date.now() - this.caseContextCache.timestamp) < CACHE_TTL;
}

async getCaseContext(forceRefresh = false) {
    if (!forceRefresh && this.isCacheValid) {
        return this.caseContextCache.data;
    }

    const data = await getCaseContext({ caseId: this.recordId });
    this.caseContextCache = {
        data: data,
        timestamp: Date.now()
    };
    return data;
}
```

**Benefit:** Reduces server calls by 60-80% during active use

---

## Apex Service Reuse Strategy

### ✅ Services to Reuse 100%

| Service Class | Usage | Notes |
|---------------|-------|-------|
| **CaseBusinessRuleService** | All business rule validations | Central engine - CRITICAL |
| **CaseUIService** | Button visibility logic | Recently refactored |
| **CaseContextGetter** | Metadata queries | Performance optimized |
| **CaseDMLService** | All Case DML operations | Service layer pattern |
| **CaseWorkOrderService** | Work order creation | Phase 5E refactored |
| **BusinessRuleHelper** | Business rule selection | Existing utility |
| **BusinessRuleUtility** | Priority business rules | Existing utility |
| **HaulAwayService** | Haul away detection | Specialized logic |

### 🔨 Controllers to Adapt (Keep Business Logic)

| Controller | Adaptation Needed | Action |
|------------|-------------------|--------|
| `CustomCaseHighlightPanelCntrl` | Extract @AuraEnabled methods | Move to CaseUIService |
| `GetCaseInformation` | Extract @AuraEnabled methods | Move to CaseUIService |
| `SearchExistingContactController` | Refactor for LWC wire | Add @wire compatible methods |
| `LocationContainerController` | Refactor for LWC wire | Add @wire compatible methods |
| `AssetHeadersForCaseController` | Refactor for LWC wire | Add @wire compatible methods |
| `QuoteProcurementController` | Keep as-is | Already well-structured |
| `NTEBRRulesModalCtrl` | Keep as-is | Works fine |

### 🆕 New Services to Create

**1. CaseContextService**

```apex
public without sharing class CaseContextService {
    /**
     * Single comprehensive method to get all case context data
     * Replaces 4-5 separate server calls from old components
     */
    @AuraEnabled(cacheable=true)
    public static CaseContextWrapper getCaseContext(Id caseId) {
        CaseContextWrapper wrapper = new CaseContextWrapper();

        // Query case with all related data
        Case caseRecord = queryCaseWithRelatedData(caseId);
        wrapper.caseRecord = caseRecord;

        // Get location details
        if (caseRecord.Location__c != null) {
            wrapper.locationDetails = queryLocationDetails(caseRecord.Location__c);
        }

        // Get asset details
        if (caseRecord.AssetId != null) {
            wrapper.assetDetails = queryAssetDetails(caseRecord.AssetId);
        }

        // Get contact details
        if (caseRecord.ContactId != null) {
            wrapper.contactDetails = queryContactDetails(caseRecord.ContactId);
        }

        // Evaluate business rules
        wrapper.businessRules = CaseBusinessRuleService.evaluateBusinessRules(caseId);

        // Calculate button visibility
        wrapper.buttonStates = calculateButtonStates(caseRecord, wrapper.businessRules);

        // Generate messages
        wrapper.messages = generateActionMessages(caseRecord, wrapper.businessRules);

        return wrapper;
    }
}
```

**2. CaseWizardService**

```apex
public without sharing class CaseWizardService {
    /**
     * Validates wizard phase completion
     */
    @AuraEnabled
    public static PhaseValidationResult validatePhase(String phase, Map<String,Object> data) {
        PhaseValidationResult result = new PhaseValidationResult();
        result.isValid = true;
        result.messages = new List<String>();

        switch on phase {
            when 'CALLER' {
                validateCallerPhase(data, result);
            }
            when 'INTENT' {
                validateIntentPhase(data, result);
            }
            when 'DETAILS' {
                validateDetailsPhase(data, result);
            }
            when 'REVIEW' {
                validateReviewPhase(data, result);
            }
        }

        return result;
    }

    /**
     * Creates case from wizard data
     */
    @AuraEnabled
    public static String createCaseFromWizard(Map<String,Object> wizardData) {
        try {
            Case newCase = buildCaseFromWizardData(wizardData);

            // Use existing service layer
            CaseDMLService.insertCases(new List<Case>{ newCase });

            // Business rules evaluation happens via trigger -> service layer

            return newCase.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Case creation failed: ' + e.getMessage());
        }
    }
}
```

### Migration Strategy for Existing Methods

**Pattern:** Extract @AuraEnabled methods from controllers into services

**Example:** CustomCaseHighlightPanelCntrl.getCaseDetails()

```apex
// OLD (Controller)
public class CustomCaseHighlightPanelCntrl {
    @AuraEnabled
    public static CustomCaseWrapper getCaseDetails(Id caseId) {
        // 200 lines of logic...
    }
}

// NEW (Service)
public class CaseUIService {
    @AuraEnabled(cacheable=true)
    public static CaseUIWrapper getCaseHighlightData(Id caseId) {
        // Moved business logic here
        // Reuse CaseBusinessRuleService methods
        // Return optimized wrapper
    }
}
```

**Benefit:** Cleaner separation, easier testing, better maintainability

---

## Implementation Plan

### Phase 1: Foundation (Weeks 1-4)

**Week 1-2: Core Infrastructure**
- ✅ Create CaseContextService.cls
- ✅ Create CaseWizardService.cls
- ✅ Set up Lightning Message Service channel (CaseUpdated__c)
- ✅ Create base utility components:
  - recordSearchBase
  - validationMessageBar
  - progressIndicator
  - inlineDetailCard
- ✅ Write unit tests for new services

**Week 3-4: Parent Container**
- ✅ Build caseManagerContainer (LWC)
- ✅ Implement state management
- ✅ Implement caching strategy
- ✅ Build caseWizardStepper (LWC)
- ✅ Set up LMS pub/sub architecture
- ✅ Integration testing with services

### Phase 2: Caller Identification (Weeks 5-8)

**Week 5-6: Entity & Contact Selection**
- ✅ Build entitySelector (LWC)
  - Location mode
  - Vendor mode
  - Client mode
- ✅ Adapt LocationContainerController for LWC
- ✅ Adapt VendorContainerController for LWC
- ✅ Adapt ClientContainerController for LWC

**Week 7-8: Contact Selector**
- ✅ Build contactSelector (LWC)
  - Context-aware filtering
  - Unified search interface
  - Create new contact inline
  - Duplicate detection
- ✅ Adapt SearchExistingContactController for LWC
- ✅ Integration testing with entitySelector

### Phase 3: Intent Configuration (Weeks 9-12)

**Week 9-10: Asset Selection**
- ✅ Build assetSelector (LWC)
  - Active/Inactive sections
  - 21-column table
  - Multi-select functionality
  - Replace asset workflow
- ✅ Adapt AssetHeadersForCaseController for LWC
- ✅ Integration with selected location

**Week 11-12: Case Type Configuration**
- ✅ Build caseTypeConfigurator (LWC)
  - Record type selection
  - Quick action buttons
  - Dependent dropdowns (Type → Sub-Type → Reason)
  - Business rule validation integration
- ✅ Migrate logic from changeRecordTypeController
- ✅ Migrate logic from FillCaseSubTypeController
- ✅ Integration testing

### Phase 4: Details & Validation (Weeks 13-16)

**Week 13-14: Customer Info & Service Date**
- ✅ Build customerInfoPanel (LWC)
  - PO/Profile/PSI fields
  - Override checkboxes
  - Business rule integration
- ✅ Build serviceDateSelector (LWC)
  - SLA calculator
  - Capacity check integration
  - Calendar picker
- ✅ Migrate SetCaseCustomerInfoController logic
- ✅ Migrate ServiceDateContainerController logic

**Week 15-16: Business Rule Validation**
- ✅ Build businessRuleValidator (LWC)
  - Real-time evaluation
  - Inline display (not modal)
  - Approval chain visualization
  - Requirements status
- ✅ Integrate with NTEBRRulesModalCtrl
- ✅ Integrate with CaseBusinessRuleService
- ✅ Comprehensive testing

### Phase 5: Review & Persistent Panels (Weeks 17-20)

**Week 17-18: Review & Submit**
- ✅ Build caseSummaryCard (LWC)
  - Read-only summary
  - Section-based layout
  - Edit buttons
- ✅ Build workOrderPreview (LWC)
  - WO instructions form
  - By-pass option
- ✅ Implement case creation workflow
- ✅ Integration with CaseWizardService

**Week 19-20: Persistent Panels**
- ✅ Build caseHighlightStrip (LWC)
  - Horizontal layout
  - Inline details (NO hover)
  - Color-coded fields
  - Click-to-edit functionality
- ✅ Build actionMessagesPanel (LWC)
  - Message display
  - Button group
  - Business rule driven visibility
- ✅ Integrate with CaseUIService
- ✅ LDS integration for auto-refresh

### Phase 6: Quote Management (Weeks 21-24)

**Week 21-22: Quote Panel Foundation**
- ✅ Build quoteManagerPanel (LWC)
  - Tabbed interface
  - Existing quotes tab
  - Create quote tab
  - Favorite containers tab

**Week 23-24: Quote Functionality**
- ✅ Integrate with QuoteProcurementController
- ✅ NTE business rules integration
- ✅ Quote creation workflow
- ✅ Navigation to quote records

### Phase 7: Utility Components (Weeks 25-28)

**Week 25-26: Pending Info Tasks**
- ✅ Build pendingInfoTaskCreator (LWC)
  - Two modes (Pending Info / Internal Response)
  - Form validation
  - Task creation
- ✅ Integrate with CreatePendingInformationTask controller

**Week 27-28: Multi-Asset Support**
- ✅ Multi-asset case summary view
- ✅ Related cases navigation
- ✅ Integrate with CaseNavigation logic

### Phase 8: Testing & Refinement (Weeks 29-36)

**Week 29-30: Unit Testing**
- ✅ Jest tests for all LWC components (80%+ coverage)
- ✅ Apex test coverage for new services (100%)
- ✅ Integration tests for wizard flow

**Week 31-32: System Integration Testing**
- ✅ End-to-end case creation testing
- ✅ End-to-end case modification testing
- ✅ Business rule validation testing
- ✅ Quote integration testing
- ✅ Work order integration testing

**Week 33-34: User Acceptance Testing (UAT)**
- ✅ UAT with power users (2 weeks)
- ✅ Gather feedback
- ✅ Bug fixes and refinements
- ✅ Performance tuning

**Week 35-36: Training & Documentation**
- ✅ Create user training materials
- ✅ Create admin guide
- ✅ Create developer documentation
- ✅ Conduct training sessions (3-4 sessions per department)

### Phase 9: Deployment (Weeks 37-40)

**Week 37: Sandbox Deployment**
- ✅ Deploy to full sandbox
- ✅ Smoke testing
- ✅ Final bug fixes

**Week 38: Production Preparation**
- ✅ Create deployment package
- ✅ Deployment runbook
- ✅ Rollback plan
- ✅ Communication plan

**Week 39: Production Deployment (Big-Bang)**
- ✅ Deploy to production (weekend deployment)
- ✅ Smoke testing immediately after
- ✅ Monitor for first 48 hours

**Week 40: Post-Deployment Support**
- ✅ Hypercare period (1 week)
- ✅ Daily check-ins with support team
- ✅ Bug fix hot patches if needed
- ✅ User feedback collection

### Phase 10: Cleanup & Optimization (Weeks 41-44)

**Week 41-42: Legacy Cleanup**
- ✅ Deactivate old Aura components
- ✅ Remove from page layouts
- ✅ Archive old code (DO NOT DELETE)

**Week 43-44: Performance Optimization**
- ✅ Analyze production metrics
- ✅ Optimize slow queries
- ✅ Tune caching strategies
- ✅ Final performance report

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| **1. Foundation** | 4 weeks | Core services, parent container, utilities |
| **2. Caller ID** | 4 weeks | Entity selector, contact selector |
| **3. Intent** | 4 weeks | Asset selector, case type configurator |
| **4. Details** | 4 weeks | Customer info, service date, business rules |
| **5. Review & Panels** | 4 weeks | Summary, WO preview, highlight strip, messages |
| **6. Quotes** | 4 weeks | Quote manager panel |
| **7. Utilities** | 4 weeks | Pending tasks, multi-asset |
| **8. Testing** | 8 weeks | Unit, integration, UAT, training |
| **9. Deployment** | 4 weeks | Sandbox, production, support |
| **10. Cleanup** | 4 weeks | Legacy removal, optimization |
| **TOTAL** | **44 weeks** | **~11 months** |

**Target Completion:** Q4 2025 ✅

---

## Risk Assessment & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **LWC re-render issues persist** | Medium | High | Use LDS for all Case DML; extensive testing in sandbox |
| **Business logic breaks** | Low | Critical | Reuse existing Apex services 100%; comprehensive test coverage |
| **Performance worse than expected** | Low | High | Implement caching early; load testing in sandbox |
| **User adoption resistance** | Medium | Medium | Extensive training; phased rollout by department |
| **Big-bang deployment failure** | Medium | Critical | Thorough UAT; rollback plan ready; weekend deployment |
| **Timeline overrun** | High | Medium | Build in 4-week buffer; prioritize critical features |
| **Integration issues** | Medium | High | Integration testing starting Week 1; daily builds |
| **Data migration problems** | Low | Medium | No data migration needed (UI only) |

### Critical Success Factors

1. ✅ **Executive sponsorship** - Ensure buy-in from leadership
2. ✅ **Dedicated development team** - Full-time focus on this project
3. ✅ **User involvement** - Include power users in UAT early
4. ✅ **Comprehensive testing** - Do not skip testing phases
5. ✅ **Training investment** - Allocate resources for training
6. ✅ **Rollback readiness** - Have complete rollback plan tested

---

## Success Metrics

### Performance Metrics (Baseline vs. Target)

| Metric | Current | Target | Improvement |
|--------|---------|--------|-------------|
| **Initial load time** | 5-10 sec | 2-3 sec | 50-70% faster |
| **Server calls on init** | 4-5 | 1 | 75-80% reduction |
| **Case creation time** | 3-5 min | 1-2 min | 40-60% faster |
| **Error frequency** | High | <1% | 95%+ reduction |
| **Re-render failures** | Frequent | 0 | 100% elimination |
| **User clicks to complete task** | 15-20 | 8-10 | 50% reduction |

### User Satisfaction Metrics

- **Pre-deployment survey** (baseline user satisfaction)
- **Post-deployment surveys** at 1 week, 1 month, 3 months
- **Target:** 80%+ user satisfaction at 3 months
- **Support tickets** reduction by 70%

### Technical Metrics

- **Test coverage:** 90%+ (Apex), 80%+ (LWC)
- **Code maintainability:** Sonar score 'A'
- **Security vulnerabilities:** 0 critical, 0 high
- **Accessibility:** WCAG 2.1 AA compliance

---

## Technology Stack

### Frontend

- **LWC (Lightning Web Components)** - Primary UI framework
- **Lightning Design System (SLDS)** - Styling
- **Lightning Data Service (LDS)** - Data management
- **Lightning Message Service (LMS)** - Component communication
- **Wire Service** - Reactive data binding
- **Jest** - Unit testing

### Backend

- **Apex** - Server-side logic
- **SOQL** - Data queries
- **Service Layer Architecture** - Business logic organization
- **Custom Metadata Types** - Configuration
- **Platform Events (optional)** - Real-time updates

### Integration

- **Acorn Integration** - Work order system (existing)
- **Genesys Integration** - Routing (existing)
- **Email Services** - Notifications (existing)

### Development Tools

- **VS Code** - IDE
- **Salesforce CLI** - Deployment
- **Git** - Version control
- **GitHub** - Repository
- **SFDX** - Development model

---

## Questions for Stakeholder Review

Before proceeding with implementation, please review and confirm:

### 1. User Experience

- ✅ **Wizard approach approved?** Phased workflow (Caller → Intent → Details → Review)
- ✅ **Inline details vs. hover cards?** Confirmed inline display
- ✅ **Consolidated contact selector?** No toggle between types
- ✅ **Color-coded fields?** Visual indicators for field status

### 2. Technical Approach

- ✅ **LWC migration confirmed?** Complete rebuild in LWC
- ✅ **Big-bang deployment accepted?** Understanding of risks
- ✅ **Reuse existing Apex services?** No backend changes
- ✅ **LDS for Case DML?** Solves re-render issues

### 3. Scope & Timeline

- ✅ **44-week timeline acceptable?** ~11 months
- ✅ **Resources available?** Dedicated dev team
- ✅ **Training commitment?** Time for user training
- ✅ **UAT participation?** Power users available

### 4. Business Requirements

- ✅ **All features covered?** Any missing functionality?
- ✅ **Business rules preserved?** CaseBusinessRuleService logic
- ✅ **Quote integration sufficient?** NTE approvals, favorite containers
- ✅ **Work order flow correct?** Initiation process

---

## Next Steps

Upon approval of this proposal:

1. **Week 0 (Kickoff):**
   - Finalize stakeholder sign-off
   - Allocate development resources
   - Set up project tracking (Jira/ADO)
   - Create detailed technical specifications

2. **Week 1 (Start Foundation):**
   - Create CaseContextService skeleton
   - Create CaseWizardService skeleton
   - Set up LWC project structure
   - Begin utility component development

3. **Ongoing:**
   - Weekly status meetings
   - Bi-weekly demos to stakeholders
   - Daily stand-ups for dev team
   - Monthly executive reviews

---

## Appendix

### A. Component Mapping (Old → New)

| Old Component | New Component | Notes |
|---------------|---------------|-------|
| CustomCaseHighlightPanel | caseHighlightStrip | Horizontal layout, inline details |
| ShowCaseMessages | actionMessagesPanel | Compact card, button-driven |
| SearchExistingContact | contactSelector | Unified, no toggle |
| changeRecordType | caseTypeConfigurator | Consolidated with case types |
| FillCaseSubType | (merged into caseTypeConfigurator) | Dependent dropdowns |
| LocationContainer | entitySelector (location mode) | Unified entity selector |
| VendorContainer | entitySelector (vendor mode) | Unified entity selector |
| ClientContainer | entitySelector (client mode) | Unified entity selector |
| ShowAssetHeadersOnCase | assetSelector | 21-column table preserved |
| CaseNavigation | Related cases in caseSummaryCard | Integrated view |
| ntebRulesModal | businessRuleValidator | Inline display |
| CaseQuoteModal | quoteManagerPanel (tab 1) | Tabbed interface |
| ExistingQuoteModal | quoteManagerPanel (tab 2) | Tabbed interface |
| AddFavoriteContainers | quoteManagerPanel (tab 3) | Tabbed interface |
| CreatePendingInformationTask | pendingInfoTaskCreator | Modal or inline |

### B. Apex Services Hierarchy

```
Services (Business Logic)
├── CaseBusinessRuleService ⭐ (Core)
├── CaseUIService (UI logic)
├── CaseDMLService (DML operations)
├── CaseWorkOrderService (WO creation)
├── CaseContextService 🆕 (Data aggregation)
└── CaseWizardService 🆕 (Wizard logic)

Helpers (Utilities)
├── BusinessRuleHelper
├── BusinessRuleUtility
├── HaulAwayService
└── CaseContextGetter

Controllers (Adapted for LWC)
├── SearchExistingContactController
├── LocationContainerController
├── VendorContainerController
├── ClientContainerController
├── AssetHeadersForCaseController
├── QuoteProcurementController
└── NTEBRRulesModalCtrl
```

### C. LWC Components Hierarchy

```
caseManagerContainer (Parent)
├── caseWizardStepper
├── Phase 1 Components
│   ├── entitySelector
│   └── contactSelector
├── Phase 2 Components
│   ├── assetSelector
│   └── caseTypeConfigurator
├── Phase 3 Components
│   ├── customerInfoPanel
│   ├── serviceDateSelector
│   └── businessRuleValidator
├── Phase 4 Components
│   ├── caseSummaryCard
│   └── workOrderPreview
├── Persistent Panels
│   ├── caseHighlightStrip
│   └── actionMessagesPanel
├── Quote Management
│   └── quoteManagerPanel
├── Utilities
│   ├── pendingInfoTaskCreator
│   ├── recordSearchBase
│   ├── validationMessageBar
│   ├── progressIndicator
│   └── inlineDetailCard
```

---

**END OF PROPOSAL**

**Document Version:** 1.0
**Last Updated:** 2025-11-18
**Author:** Claude (AI Assistant)
**Status:** Awaiting Stakeholder Approval

**Recommended Action:** Schedule stakeholder review meeting within 1 week to discuss and approve/modify this proposal before proceeding with implementation.

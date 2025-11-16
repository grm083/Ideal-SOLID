# Aura to LWC Conversion Guide

## Overview

This guide documents the conversion of Aura Lightning Components to Lightning Web Components (LWC) while leveraging the existing service layer architecture.

---

## Completed Conversions

### ✅ ShowCaseMessages (Priority Component)
**Location**: `lwc/showCaseMessages/`
**Original**: `aura/ShowCaseMessages/`
**Status**: ✅ Complete, Committed, Pushed

**Key Features Converted**:
- Action required panel with case messaging
- Multi-asset case support
- Work order creation and management
- Quote management (Add Quote / View Quotes)
- Case summary modal with multi-select
- W/O instructions modal
- Email template editing modal
- Lightning Message Service (LMS) integration
- Service layer integration (CaseUIService, CaseBusinessRuleService, CaseDMLService)

**Architecture Highlights**:
- Uses `@wire` adapters for reactive record data
- Imperative Apex calls to service layer methods
- LMS for pub/sub communication between components
- Modern modal patterns (no overlay components needed)
- Proper error handling with toast notifications

---

## Remaining Conversions

### Batch 1: Simple Modal Components

#### 1. HoverOverCards
**Complexity**: Low
**Purpose**: Display asset, location, or contact details in a hover card
**Controller**: `HoverOverCardsCntrl.cls`
**Dependencies**: None
**Conversion Effort**: ~2 hours

**Key Patterns**:
- Display-only component (no DML)
- Three display modes: Asset, Location, Contact
- Conditional rendering based on object type
- Currency formatting

#### 2. VendorContainer
**Complexity**: Low
**Purpose**: Modal container for vendor search
**Controller**: `LocationContainerController.cls`
**Dependencies**: VendorSearch child component
**Conversion Effort**: ~1 hour

**Key Patterns**:
- Simple modal with tabset
- Single tab for vendor search
- Child component integration

#### 3. LocationContainer
**Complexity**: Low-Medium
**Purpose**: Modal container for location selection with details and search tabs
**Controller**: `LocationContainerController.cls`
**Dependencies**:
  - CaseLocationDetails
  - LocationAssetSearch
**Conversion Effort**: ~2 hours

**Key Patterns**:
- Modal with tabset (2 tabs)
- Conditional tab selection based on whether location is already set
- Child component integration

---

### Batch 2: Form Modal Components

#### 4. CloseCasePop
**Complexity**: Medium
**Purpose**: Modal for closing cases with reason selection
**Controller**: TBD
**Dependencies**: None
**Conversion Effort**: ~3 hours

**Key Patterns**:
- Form inputs with validation
- Picklist selection
- Case update via service layer
- Error handling

#### 5. FillCaseSubType
**Complexity**: Medium
**Purpose**: Modal for selecting Case Type, Sub-Type, and Reason
**Controller**: TBD
**Dependencies**: None
**Conversion Effort**: ~3 hours

**Key Patterns**:
- Dependent picklists (cascading selections)
- Form validation
- Case update via CaseDMLService

#### 6. SetCaseCustomerInfo
**Complexity**: Medium
**Purpose**: Modal for setting customer-required info (PO, Profile, PSI, vendor)
**Controller**: TBD
**Dependencies**: None
**Conversion Effort**: ~3 hours

**Key Patterns**:
- Multiple input types
- Override reason handling
- Validation rules

#### 7. ServiceDateContainer
**Complexity**: Medium
**Purpose**: Modal for service date selection with capacity checks
**Controller**: `ServiceDateContainerController.cls`
**Dependencies**: Calendar/date picker components
**Conversion Effort**: ~3-4 hours

**Key Patterns**:
- Date/time selection
- Multi-date support
- Capacity eligibility checks
- SLA calculations

---

### Batch 3: Complex Modal Components

#### 8. ClientContainer
**Complexity**: Medium-High
**Purpose**: Modal for client search with tabset interface
**Controller**: TBD
**Dependencies**: Client search components
**Conversion Effort**: ~4 hours

**Key Patterns**:
- Tabbed interface
- Search functionality
- Account selection

#### 9. CreatePendingInformationTask
**Complexity**: High
**Purpose**: Complex modal for creating pending info and internal response tasks
**Controller**: `CreatePendingInformationTask.cls` (Service Layer)
**Dependencies**: Team/queue selection components
**Conversion Effort**: ~5 hours

**Key Patterns**:
- Complex form with multiple sections
- Team assignment
- Queue selection
- Task creation via service layer
- Validation across multiple fields

---

### Batch 4: Data Display Components

#### 10. CaseNavigation
**Complexity**: Medium
**Purpose**: Display related cases in table format
**Controller**: TBD
**Dependencies**: None
**Conversion Effort**: ~3 hours

**Key Patterns**:
- Data table display
- Case details formatting
- Navigation to related records

#### 11. ShowAssetHeadersOnCase
**Complexity**: High
**Purpose**: Comprehensive asset header table with multi-select
**Controller**: `AssetHeadersForCaseController.cls`
**Dependencies**: None
**Conversion Effort**: ~5 hours

**Key Patterns**:
- Complex data table
- Active/inactive sections
- Multi-select capability
- Asset attribute display
- Selection state management

---

### Batch 5: Complex Dashboard Components

#### 12. SearchExistingContact
**Complexity**: Very High
**Purpose**: Large complex component for contact search and creation
**Controller**: `ContactSearchandCreate.cls` (Service Layer)
**Dependencies**: None
**Conversion Effort**: ~8 hours

**Key Patterns**:
- SOSL search integration
- Contact creation with duplicate detection
- Vendor/customer/internal user support
- Complex form validation
- Multiple result handling

#### 13. changeRecordType
**Complexity**: High
**Purpose**: Record type selector with quick actions
**Controller**: `changeRecordTypeController.cls`
**Dependencies**: None
**Conversion Effort**: ~5 hours

**Key Patterns**:
- Record type selection
- Quick action buttons (Pickup, New Service, SNP, ETA)
- Case type/sub-type cascading
- Dynamic button rendering

#### 14. CustomCaseHighlightPanel
**Complexity**: Very High
**Purpose**: Primary case management dashboard
**Controller**: `CustomCaseHighlightPanelCntrl.cls`
**Dependencies**: Multiple child components
**Conversion Effort**: ~10 hours

**Key Patterns**:
- Main orchestrator component
- Multiple modal integrations
- Asset/location/contact info display
- Related data editing
- Complex state management
- Event coordination

#### 15. ShowCaseMessages
**Status**: ✅ COMPLETED
See above for details.

---

## Conversion Patterns and Best Practices

### 1. Service Layer Integration

**Always use the service layer for business logic:**

```javascript
// ❌ DON'T: Direct SOQL or DML in LWC
updateCase({ caseId: this.recordId, status: 'Closed' });

// ✅ DO: Use service layer methods
import getCaseMessages from '@salesforce/apex/CaseUIService.getCaseMessages';
import updateCase from '@salesforce/apex/CaseDMLService.updateCases';

async loadData() {
    const result = await getCaseMessages({ caseId: this.recordId });
    // Use result...
}
```

**Service Layer Classes Available:**
- `CaseUIService` - UI data preparation
- `CaseBusinessRuleService` - Business logic and validation
- `CaseDMLService` - Database operations
- `CaseContextGetter` - Data retrieval
- `CaseAssetValidator` - Asset validation
- `ContactSearchandCreate` - Contact operations
- `AssetHeadersForCaseController` - Asset header operations

### 2. Data Loading with @wire

**Use @wire for reactive data:**

```javascript
import { wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

@wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
caseRecord;

get caseStatus() {
    return getFieldValue(this.caseRecord.data, CASE_STATUS);
}
```

### 3. Aura Events → LWC Events or LMS

**Aura Component Events:**
```javascript
// Aura (old)
var event = $A.get("e.c:RelatedCaseListener");
event.setParams({ "triggeringCase": caseId });
event.fire();
```

**LWC Options:**

**Option A: Lightning Message Service (for cross-component communication)**
```javascript
import { publish, subscribe, MessageContext } from 'lightning/messageService';
import CASE_CHANNEL from '@salesforce/messageChannel/CaseChannel__c';

@wire(MessageContext)
messageContext;

publishEvent() {
    publish(this.messageContext, CASE_CHANNEL, { triggeringCase: this.caseId });
}
```

**Option B: Custom Events (for parent-child communication)**
```javascript
// Child LWC
handleClick() {
    this.dispatchEvent(new CustomEvent('caseselected', {
        detail: { caseId: this.caseId }
    }));
}

// Parent HTML
<c-child-component oncaseselected={handleCaseSelected}></c-child-component>
```

### 4. Modals

**Aura Modal:**
```html
<aura:if isTrue="{!v.showModal}">
    <div class="slds-modal slds-fade-in-open">
        <!-- content -->
    </div>
    <div class="slds-backdrop slds-backdrop_open"></div>
</aura:if>
```

**LWC Modal:**
```html
<template if:true={showModal}>
    <section role="dialog" class="slds-modal slds-fade-in-open">
        <div class="slds-modal__container">
            <!-- content -->
        </div>
    </section>
    <div class="slds-backdrop slds-backdrop_open"></div>
</template>
```

### 5. Form Validation

**Aura:**
```javascript
var validity = component.find('myInput').get('v.validity');
```

**LWC:**
```javascript
const allValid = [...this.template.querySelectorAll('lightning-input')]
    .reduce((validSoFar, inputCmp) => {
        inputCmp.reportValidity();
        return validSoFar && inputCmp.checkValidity();
    }, true);
```

### 6. Navigation

**Aura:**
```javascript
var navEvt = $A.get("e.force:navigateToSObject");
navEvt.setParams({ "recordId": recordId });
navEvt.fire();
```

**LWC:**
```javascript
import { NavigationMixin } from 'lightning/navigation';

export default class MyComponent extends NavigationMixin(LightningElement) {
    navigateToRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }
}
```

### 7. Dynamic Component Creation

**Aura:**
```javascript
$A.createComponent("c:MyComponent", {...}, function(cmp) {
    // use cmp
});
```

**LWC:**
LWC doesn't support dynamic component creation the same way. Instead:

**Option A: Use conditional rendering**
```html
<template if:true={showComponent}>
    <c-my-component></c-my-component>
</template>
```

**Option B: Use `lwc:dynamic` directive (Lightning 59.0+)**
```html
<lwc:component lwc:is={dynamicComponent}></lwc:component>
```

```javascript
import MyComponent from 'c/myComponent';

@track dynamicComponent = MyComponent;
```

### 8. Toast Messages

**Aura:**
```javascript
var toastEvent = $A.get("e.force:showToast");
toastEvent.setParams({
    "title": "Success!",
    "message": "The record has been updated.",
    "type": "success"
});
toastEvent.fire();
```

**LWC:**
```javascript
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

showSuccess() {
    this.dispatchEvent(new ShowToastEvent({
        title: 'Success',
        message: 'The record has been updated',
        variant: 'success'
    }));
}
```

### 9. Refreshing Views

**Aura:**
```javascript
$A.get('e.force:refreshView').fire();
```

**LWC:**
```javascript
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

refreshRecord() {
    notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
}

// Or use this for complete page refresh
import { refreshApex } from '@salesforce/apex';
refreshApex(this.wiredResult);
```

---

## Conversion Checklist

For each component conversion, follow this checklist:

### Planning Phase
- [ ] Read and understand the Aura component structure
- [ ] Identify controller methods and their service layer equivalents
- [ ] Document dependencies on other components
- [ ] Identify events used for communication
- [ ] List all attributes and their purposes

### Development Phase
- [ ] Create LWC directory structure (`lwc/componentName/`)
- [ ] Create HTML template (`.html`)
- [ ] Create JavaScript controller (`.js`)
- [ ] Create metadata file (`.js-meta.xml`)
- [ ] Create CSS file if needed (`.css`)
- [ ] Implement @wire adapters for reactive data
- [ ] Convert Apex calls to use service layer methods
- [ ] Convert events to LMS or custom events
- [ ] Implement error handling with toasts
- [ ] Add form validation where applicable

### Testing Phase
- [ ] Test all user interactions
- [ ] Test form validation
- [ ] Test service layer integration
- [ ] Test error scenarios
- [ ] Test event communication
- [ ] Test modal open/close
- [ ] Test navigation
- [ ] Verify no console errors

### Documentation Phase
- [ ] Update this guide with lessons learned
- [ ] Document any new patterns discovered
- [ ] Note any issues or limitations

### Deployment Phase
- [ ] Commit with descriptive message
- [ ] Push to feature branch
- [ ] Preserve original Aura component
- [ ] Update deployment notes

---

## Example: Converting a Simple Modal

Let's convert a hypothetical "CloseCasePop" component as an example:

### 1. Original Aura Structure
```
aura/CloseCasePop/
├── CloseCasePop.cmp
├── CloseCasePopController.js
├── CloseCasePopHelper.js
└── CloseCasePop.css
```

### 2. New LWC Structure
```
lwc/closeCasePop/
├── closeCasePop.html
├── closeCasePop.js
├── closeCasePop.css
└── closeCasePop.js-meta.xml
```

### 3. HTML Template (closeCasePop.html)
```html
<template>
    <template if:true={showModal}>
        <section role="dialog" class="slds-modal slds-fade-in-open">
            <div class="slds-modal__container">
                <header class="slds-modal__header">
                    <lightning-button-icon
                        icon-name="utility:close"
                        alternative-text="Close"
                        variant="bare"
                        class="slds-modal__close"
                        onclick={handleClose}>
                    </lightning-button-icon>
                    <h2 class="slds-text-heading_medium">Close Case</h2>
                </header>
                <div class="slds-modal__content slds-p-around_medium">
                    <lightning-combobox
                        name="closeReason"
                        label="Close Reason"
                        value={closeReason}
                        placeholder="Select a reason"
                        options={closeReasonOptions}
                        onchange={handleReasonChange}
                        required>
                    </lightning-combobox>
                    <lightning-input
                        type="checkbox"
                        label="Irrelevant Case"
                        checked={isIrrelevant}
                        onchange={handleIrrelevantChange}>
                    </lightning-input>
                </div>
                <footer class="slds-modal__footer">
                    <lightning-button
                        label="Cancel"
                        onclick={handleClose}>
                    </lightning-button>
                    <lightning-button
                        variant="brand"
                        label="Close Case"
                        onclick={handleCloseCase}>
                    </lightning-button>
                </footer>
            </div>
        </section>
        <div class="slds-backdrop slds-backdrop_open"></div>
    </template>
</template>
```

### 4. JavaScript Controller (closeCasePop.js)
```javascript
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

// Import Apex from service layer
import closeCase from '@salesforce/apex/CaseBusinessRuleService.closeCase';

export default class CloseCasePop extends LightningElement {
    @api recordId;
    @api showModal = false;

    @track closeReason = '';
    @track isIrrelevant = false;

    // Close reason picklist values
    get closeReasonOptions() {
        return [
            { label: 'Resolved', value: 'Resolved' },
            { label: 'Duplicate', value: 'Duplicate' },
            { label: 'Invalid Request', value: 'Invalid Request' },
            { label: 'Customer Request', value: 'Customer Request' }
        ];
    }

    handleReasonChange(event) {
        this.closeReason = event.detail.value;
    }

    handleIrrelevantChange(event) {
        this.isIrrelevant = event.target.checked;
    }

    handleClose() {
        this.showModal = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    async handleCloseCase() {
        // Validate
        if (!this.closeReason) {
            this.showToast('Error', 'Please select a close reason', 'error');
            return;
        }

        try {
            // Call service layer
            const result = await closeCase({
                caseId: this.recordId,
                closeReason: this.closeReason,
                isIrrelevant: this.isIrrelevant
            });

            if (result === 'Success') {
                this.showToast('Success', 'Case closed successfully', 'success');

                // Refresh the record
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

                // Close modal
                this.handleClose();
            } else {
                this.showToast('Error', 'Failed to close case', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'An error occurred', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
```

### 5. Metadata (closeCasePop.js-meta.xml)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__RecordPage</target>
    </targets>
</LightningComponentBundle>
```

---

## Service Layer Reference

### CaseUIService Methods
- `getCaseMessages(caseId)` - Get comprehensive case UI data
- `getBusinessRule(caseId)` - Get business rule information
- `getEntitlement(caseId)` - Get SLA information
- `getCaseSummary(caseId, referenceNo, parentId)` - Get case summary
- `getCaseRecordTypeList()` - Get record type names
- `getRecordTypeId(caseId)` - Get record type ID
- `getCaseRecordDetails(caseId)` - Get case details
- `getCaseAssetDetails(caseId)` - Get case asset details
- `hasCPQAccess()` - Check CPQ permissions
- `hasUpdateAssetAccess()` - Check asset update permissions

### CaseBusinessRuleService Methods
- `initiateWorkOrderCreation(caseId, caseIdList)` - Initiate work orders
- `copyAcornComments(recordId, caseObj)` - Copy Acorn comments
- `evaluateBusinessRules(caseId)` - Evaluate all business rules
- `validateRequiredInformation(caseId)` - Validate required fields

### CaseDMLService Methods
- `getInstance()` - Get singleton instance
- `updateCases(caseList)` - Update cases with error handling
- `insertCases(caseList)` - Insert cases with error handling
- `deleteCases(caseList)` - Delete cases with error handling

### CaseContextGetter Methods
- `getCaseById(caseId)` - Get full case record with related data
- `getCasesWithAssets(caseIds)` - Get cases with asset information
- `getCasesWithContacts(caseIds)` - Get cases with contact information

### CaseAssetValidator Methods
- `validatePickupAssets(assetParams)` - Validate pickup case assets
- `validateNonPickupAssets(assetParams)` - Validate non-pickup assets
- `validateAssetAssignment(caseId, assetId)` - Validate asset assignment

---

## Testing Strategy

### Unit Testing (Jest)
Create Jest tests for each LWC component:

```javascript
// __tests__/closeCasePop.test.js
import { createElement } from 'lwc';
import CloseCasePop from 'c/closeCasePop';

describe('c-close-case-pop', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('displays modal when showModal is true', () => {
        const element = createElement('c-close-case-pop', {
            is: CloseCasePop
        });
        element.showModal = true;
        document.body.appendChild(element);

        const modal = element.shadowRoot.querySelector('.slds-modal');
        expect(modal).not.toBeNull();
    });

    // Add more tests...
});
```

### Integration Testing
- Test component integration with service layer
- Test event communication between components
- Test data flow and state management

### Manual Testing Checklist
- [ ] Component renders correctly
- [ ] All buttons and links work
- [ ] Forms validate correctly
- [ ] Data loads and displays
- [ ] Error messages show appropriately
- [ ] Modals open and close
- [ ] Events fire correctly
- [ ] Service layer calls succeed
- [ ] Browser console shows no errors

---

## Common Issues and Solutions

### Issue 1: "Cannot read property 'data' of undefined"
**Cause**: Accessing @wire data before it's loaded
**Solution**: Use null checks and optional chaining
```javascript
get caseStatus() {
    return this.caseRecord?.data?.fields?.Status?.value;
}
```

### Issue 2: "Maximum call stack size exceeded"
**Cause**: Infinite loop in reactive properties
**Solution**: Use tracked properties correctly and avoid circular dependencies

### Issue 3: Events not firing between components
**Cause**: Trying to use Aura events in LWC
**Solution**: Use LMS or custom events

### Issue 4: Modal not closing
**Cause**: State not updating correctly
**Solution**: Ensure you're updating tracked properties

---

## Migration Timeline Estimate

Based on complexity and effort:

| Batch | Components | Est. Hours | Priority |
|-------|-----------|------------|----------|
| ✅ Priority | ShowCaseMessages | 6 | DONE |
| 1 | HoverOverCards, VendorContainer, LocationContainer | 5 | High |
| 2 | CloseCasePop, FillCaseSubType, SetCaseCustomerInfo, ServiceDateContainer | 12 | High |
| 3 | ClientContainer, CreatePendingInformationTask | 9 | Medium |
| 4 | CaseNavigation, ShowAssetHeadersOnCase | 8 | Medium |
| 5 | SearchExistingContact, changeRecordType, CustomCaseHighlightPanel | 23 | Low |
| **Total** | **15 Components** | **63 hours** | |

**Recommendation**: Tackle batches sequentially, testing thoroughly after each batch.

---

## Resources

- [LWC Developer Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Aura to LWC Migration Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.migrate)
- [Lightning Message Service](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.reference_lightning_messaging)
- [Service Layer Architecture](https://developer.salesforce.com/wiki/apex_enterprise_patterns_service_layer)

---

## Support

For questions or issues during conversion:
1. Review this guide
2. Check the ShowCaseMessages LWC implementation as a reference
3. Consult the service layer class documentation
4. Review Salesforce LWC documentation

---

**Document Version**: 1.0
**Last Updated**: 2025-11-15
**Author**: Claude AI Assistant
**Status**: ShowCaseMessages Complete ✅, 14 Components Remaining

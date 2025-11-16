# Component Refactoring Guide - Governor Pattern

## Overview

This guide provides step-by-step instructions for refactoring existing LWC components to use the Case Data Governor architecture. By following this pattern, you'll eliminate redundant Apex calls and improve overall application performance.

## Quick Reference

| Component Status | Description | Action Needed |
|-----------------|-------------|---------------|
| ✅ **COMPLETED** | customCaseHighlightPanel | None - already refactored |
| ✅ **COMPLETED** | setCaseCustomerInfo | None - already refactored |
| 📝 **PENDING** | All other components | Follow this guide |

## Refactoring Categories

### Category 1: Read-Only Components (Easiest)
**Components that only read case data on load:**
- fillCaseSubType
- closeCasePop
- caseNavigation
- serviceDateContainer

**Refactoring Effort:** Low (30-60 minutes each)
**Apex Calls Eliminated:** 1-2 per component

### Category 2: Interactive Components (Medium)
**Components with some user actions:**
- changeRecordType
- showAssetHeadersOnCase
- showCaseMessages

**Refactoring Effort:** Medium (1-2 hours each)
**Apex Calls Eliminated:** 2-5 per component

### Category 3: Complex Components (Advanced)
**Components with heavy user interaction:**
- searchExistingContact
- createPendingInformationTask
- ntebRulesModal

**Refactoring Effort:** High (2-4 hours each)
**Apex Calls Eliminated:** 1-3 initial calls (keep user action calls)

### Category 4: Utility Components (No Change Needed)
**Reusable components used in multiple contexts:**
- uiCustomLookup
- uiCustomLookupResult
- createNewAccountTitle
- locationContainer
- vendorContainer
- clientContainer

**Refactoring Effort:** None
**Reason:** These are generic utilities not tied to Case pages

## Step-by-Step Refactoring Process

### Step 1: Analyze Current Apex Calls

1. **Identify all Apex imports:**
   ```javascript
   import getCaseDetails from '@salesforce/apex/SomeController.getCaseDetails';
   import updateCase from '@salesforce/apex/SomeController.updateCase';
   ```

2. **Categorize each call:**
   - **Initial Load:** Called in `connectedCallback()` or `@wire` - **REFACTOR THESE**
   - **User Actions:** Called in `handleSave()`, `handleUpdate()`, etc. - **KEEP THESE**

3. **Check if data is in governor:**
   - Open `classes/CaseDataGovernorService.cls`
   - Look at `CasePageDataWrapper` class
   - Verify if your needed data is included

### Step 2: Add Governor Integration Code

#### 2.1 Add Imports

**Before:**
```javascript
import { LightningElement, api, track } from 'lwc';
import getCaseDetails from '@salesforce/apex/MyController.getCaseDetails';
```

**After:**
```javascript
import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext, publish } from 'lightning/messageService';

// Import LMS Channel
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

// Keep Apex imports for fallback and user actions
import getCaseDetails from '@salesforce/apex/MyController.getCaseDetails';
```

#### 2.2 Add Governor Properties

**Add to class:**
```javascript
export default class MyComponent extends LightningElement {
    @api recordId;

    // ... existing properties ...

    // Governor integration - ADD THESE
    subscription = null;
    hasReceivedGovernorData = false;
    governorTimeout = null;

    // Wire message context - ADD THIS
    @wire(MessageContext)
    messageContext;
```

#### 2.3 Update Lifecycle Hooks

**Before:**
```javascript
async connectedCallback() {
    await this.loadData();
}
```

**After:**
```javascript
connectedCallback() {
    this.subscribeToGovernor();

    // Fallback timeout if governor doesn't respond
    this.governorTimeout = setTimeout(() => {
        if (!this.hasReceivedGovernorData) {
            console.warn('Governor data not received, falling back to direct Apex');
            this.loadDataDirectly();
        }
    }, 2000);
}

disconnectedCallback() {
    this.unsubscribeFromGovernor();
    if (this.governorTimeout) {
        clearTimeout(this.governorTimeout);
    }
}
```

### Step 3: Implement Governor Methods

**Add these methods to your component:**

```javascript
// ========================================================================
// GOVERNOR INTEGRATION
// ========================================================================

subscribeToGovernor() {
    if (this.subscription) {
        return;
    }

    this.subscription = subscribe(
        this.messageContext,
        CASE_DATA_CHANNEL,
        (message) => this.handleGovernorMessage(message)
    );
}

unsubscribeFromGovernor() {
    if (this.subscription) {
        unsubscribe(this.subscription);
        this.subscription = null;
    }
}

handleGovernorMessage(message) {
    // Only process messages for this case
    if (message.caseId !== this.recordId) {
        return;
    }

    switch (message.eventType) {
        case 'load':
        case 'refresh':
            this.processGovernorData(message);
            break;
        case 'error':
            console.error('Governor error:', message.errorMessage);
            this.loadDataDirectly(); // Fallback
            break;
    }
}

processGovernorData(message) {
    try {
        const pageData = JSON.parse(message.pageData);

        if (!pageData || !pageData.caseRecord) {
            return;
        }

        this.hasReceivedGovernorData = true;
        if (this.governorTimeout) {
            clearTimeout(this.governorTimeout);
        }

        // Map governor data to component
        this.mapGovernorDataToComponent(pageData);

    } catch (error) {
        console.error('Error processing governor data:', error);
        this.loadDataDirectly(); // Fallback
    }
}

mapGovernorDataToComponent(pageData) {
    // TODO: Map pageData to your component properties
    //
    // Available data in pageData:
    // - pageData.caseRecord (complete Case record)
    // - pageData.caseUI (UI wrapper with flags and messages)
    // - pageData.clientAccount, .locationAccount, .supplierAccount
    // - pageData.caseContact
    // - pageData.caseAsset
    // - pageData.relatedCases
    // - pageData.businessRules
    // - pageData.slaInfo
    // - pageData.userContext
    // - pageData.pageConfig
    //
    // Example:
    this.caseType = pageData.caseRecord.Case_Type__c;
    this.caseStatus = pageData.caseRecord.Status;
    this.isAssetRequired = pageData.caseUI.isAssetMandatory;
    // ... map other properties as needed
}
```

### Step 4: Rename Original Load Method

**Before:**
```javascript
async loadData() {
    const result = await getCaseDetails({ caseId: this.recordId });
    this.data = result;
}
```

**After:**
```javascript
// ========================================================================
// FALLBACK DIRECT DATA LOADING
// ========================================================================

async loadDataDirectly() {
    // Keep original logic for fallback
    const result = await getCaseDetails({ caseId: this.recordId });
    this.data = result;
}
```

### Step 5: Request Governor Refresh on Updates

**When component updates data, request governor to refresh:**

```javascript
handleSuccess() {
    // ... existing success logic ...

    // Request governor to refresh - ADD THIS
    if (this.hasReceivedGovernorData) {
        this.requestGovernorRefresh();
    }
}

requestGovernorRefresh() {
    const message = {
        caseId: this.recordId,
        eventType: 'refresh',
        section: 'case', // or 'contact', 'asset', etc.
        timestamp: new Date().toISOString()
    };
    publish(this.messageContext, CASE_DATA_CHANNEL, message);
}
```

## Complete Example: fillCaseSubType

### Before Refactoring
```javascript
import { LightningElement, api, track, wire } from 'lwc';
import getCaseAssetDetails from '@salesforce/apex/GetCaseInformation.getcaseAssetDetails';

export default class FillCaseSubType extends LightningElement {
    @api recordId;

    async validatePickupCase(fields) {
        const caseAssets = await getCaseAssetDetails({ caseId: this.recordId });
        // validation logic...
    }
}
```

### After Refactoring
```javascript
import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';

import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';
import getCaseAssetDetails from '@salesforce/apex/GetCaseInformation.getcaseAssetDetails';

export default class FillCaseSubType extends LightningElement {
    @api recordId;

    // Governor integration
    subscription = null;
    hasReceivedGovernorData = false;
    governorTimeout = null;
    cachedAssetData = null; // Cache asset from governor

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeToGovernor();

        this.governorTimeout = setTimeout(() => {
            if (!this.hasReceivedGovernorData) {
                // No fallback needed - will call Apex when validating
            }
        }, 2000);
    }

    disconnectedCallback() {
        this.unsubscribeFromGovernor();
        if (this.governorTimeout) {
            clearTimeout(this.governorTimeout);
        }
    }

    subscribeToGovernor() {
        this.subscription = subscribe(
            this.messageContext,
            CASE_DATA_CHANNEL,
            (message) => this.handleGovernorMessage(message)
        );
    }

    unsubscribeFromGovernor() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    handleGovernorMessage(message) {
        if (message.caseId !== this.recordId || !message.eventType.match(/load|refresh/)) {
            return;
        }

        try {
            const pageData = JSON.parse(message.pageData);
            this.hasReceivedGovernorData = true;

            // Cache asset data from governor
            if (pageData.caseAsset) {
                this.cachedAssetData = {
                    Asset: pageData.caseAsset
                };
            }
        } catch (error) {
            console.error('Error processing governor data:', error);
        }
    }

    async validatePickupCase(fields) {
        // Use cached data from governor if available
        if (this.cachedAssetData) {
            const asset = this.cachedAssetData.Asset;
            this.performValidation(asset, fields);
        } else {
            // Fallback to Apex call
            const caseAssets = await getCaseAssetDetails({ caseId: this.recordId });
            if (caseAssets && caseAssets.length > 0) {
                const asset = caseAssets[0].Asset;
                this.performValidation(asset, fields);
            }
        }
    }

    performValidation(asset, fields) {
        // Extracted validation logic...
    }
}
```

## Data Mapping Reference

### Accessing Case Data from Governor

```javascript
mapGovernorDataToComponent(pageData) {
    // Case Record Fields
    const caseId = pageData.caseRecord.Id;
    const caseNumber = pageData.caseRecord.CaseNumber;
    const caseStatus = pageData.caseRecord.Status;
    const caseType = pageData.caseRecord.Case_Type__c;
    const caseSubType = pageData.caseRecord.Case_Sub_Type__c;
    const recordTypeId = pageData.caseRecord.RecordTypeId;
    const assetId = pageData.caseRecord.AssetId;
    const contactId = pageData.caseRecord.ContactId;
    const clientId = pageData.caseRecord.Client__c;
    const locationId = pageData.caseRecord.Location__c;
    // ... all Case fields available

    // UI Wrapper Flags & Messages
    const caseInfo = pageData.caseUI.caseInfo;
    const reqInfo = pageData.caseUI.reqInfo;
    const approvalInfo = pageData.caseUI.approvalInfo;
    const channelReq = pageData.caseUI.channelReq;
    const specialInstructions = pageData.caseUI.specialInstructions;
    const slaInstructions = pageData.caseUI.slaInstructions;
    const isAssetMandatory = pageData.caseUI.isAssetMandatory;
    const workOrderCreation = pageData.caseUI.workOrderCreation;
    const progressCaseVisibility = pageData.caseUI.progressCaseVisibility;
    const addQuoteVisibility = pageData.caseUI.addQuoteVisibility;
    // ... all UI flags available

    // Related Records
    const clientAccount = pageData.clientAccount;
    const locationAccount = pageData.locationAccount;
    const supplierAccount = pageData.supplierAccount;
    const contact = pageData.caseContact;
    const asset = pageData.caseAsset;
    const relatedCases = pageData.relatedCases; // Array

    // Business Rules & SLA
    const channelName = pageData.businessRules?.channelName;
    const slaDetails = pageData.slaInfo?.slaInstructions;

    // User Context
    const isCPQUser = pageData.userContext.isCPQUser;
    const isUpdateAssetUser = pageData.userContext.isUpdateAssetActiveUser;
    const userProfile = pageData.userContext.profileName;
    const userUCC = pageData.userContext.userCategorizationCode;

    // Page Configuration
    const caseRecordTypes = pageData.pageConfig.caseRecordTypes; // Array
}
```

## Common Patterns & Solutions

### Pattern 1: Component Calls Apex on Load

**Issue:** Component calls Apex in `connectedCallback()`
**Solution:** Subscribe to governor, get data from `pageData`

### Pattern 2: Component Needs Specific Case Field

**Issue:** Component needs `Case.Custom_Field__c`
**Solution:** Check if field is in governor's query (see `CaseContextGetter.CASE_EXTENDED_FIELDS`), if not, add it

### Pattern 3: Component Needs Related Object Data

**Issue:** Component needs Contact or Asset details
**Solution:** Use `pageData.caseContact` or `pageData.caseAsset`

### Pattern 4: Component Has User Actions

**Issue:** Component has `handleSave()` that calls Apex
**Solution:** Keep the Apex call - only refactor initial data loading

### Pattern 5: Component Needs Metadata

**Issue:** Component needs picklist values or metadata
**Solution:** Either add to `pageConfig` in governor, or keep Apex call for this specific data

## Testing Checklist

After refactoring a component:

- [ ] Component loads without errors
- [ ] Component displays correct data
- [ ] Component works when governor is present
- [ ] Component falls back correctly when governor is absent (test with timeout)
- [ ] User actions still work correctly
- [ ] Component refreshes when data is updated
- [ ] No console errors in browser
- [ ] Apex call count reduced (check Developer Console)

## Performance Validation

Before and after refactoring, test with Developer Console:

1. **Before:** Open Developer Console → Debug → View Log Panel
2. **Clear** existing logs
3. **Load** Case record page
4. **Count** "SOQL_EXECUTE_BEGIN" entries = number of queries
5. **Refactor** component
6. **Repeat** test
7. **Verify** query count decreased

**Example Results:**
- Before: 15 SOQL queries
- After: 3 SOQL queries ✅
- **Improvement: 80% reduction**

## Need Help?

### If Data Not in Governor

If your component needs data not currently in `CasePageDataWrapper`:

1. **Option A:** Add field to `CaseContextGetter.CASE_EXTENDED_FIELDS`
2. **Option B:** Add logic to `CaseDataGovernorService.loadRelatedRecords()`
3. **Option C:** Keep specific Apex call for now, add TODO comment

### If Stuck

1. Review completed examples:
   - `lwc/customCaseHighlightPanel/customCaseHighlightPanel.js`
   - `lwc/setCaseCustomerInfo/setCaseCustomerInfo.js`

2. Check documentation:
   - `docs/GOVERNOR_ARCHITECTURE.md`
   - This file (`docs/COMPONENT_REFACTORING_GUIDE.md`)

3. Test incremental changes:
   - Add governor integration
   - Test
   - Map one field at a time
   - Test each change

## Summary

**For each component:**
1. ✅ Identify Apex calls made on load
2. ✅ Add governor subscription
3. ✅ Map pageData to component properties
4. ✅ Rename original load method as fallback
5. ✅ Request refresh on updates
6. ✅ Test thoroughly

**Result:**
- Fewer Apex calls
- Better performance
- Single source of truth
- Consistent data across components

---

**Last Updated:** 2025
**Architecture Version:** 1.0

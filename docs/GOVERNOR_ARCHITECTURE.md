# Case Data Governor Architecture

## Overview

The **Case Data Governor** is a centralized data management architecture for Salesforce Case record pages that eliminates redundant Apex calls, improves performance, and provides a single source of truth for all case-related data.

## Problem Statement

### Before Governor Architecture

In the original implementation, each LWC component on a Case record page made its own Apex calls:

```
Case Page Load
├── customCaseHighlightPanel  → getCaseHighlightDetails()
├── showCaseMessages          → getCaseMessages()
├── closeCasePop              → getRecordTypeId()
├── setCaseCustomerInfo       → getCaseRecordDetails()
├── fillCaseSubType           → getCaseAssetDetails()
└── ... (15+ more components making individual Apex calls)
```

**Issues:**
- **10-15 Apex calls** on single page load
- **Redundant queries** for same data
- **Governor limit stress** in high-traffic scenarios
- **Inconsistent state** across components
- **Difficult to debug** data flow
- **Poor performance** on slow connections

### After Governor Architecture

With the governor pattern, a single component loads all data once and distributes it:

```
Case Page Load
└── caseDataGovernor → getCasePageData() (ONE Apex call)
    │
    ├─[LMS Publish]───> customCaseHighlightPanel
    ├─[LMS Publish]───> showCaseMessages
    ├─[LMS Publish]───> closeCasePop
    ├─[LMS Publish]───> setCaseCustomerInfo
    └─[LMS Publish]───> ... (all other components)
```

**Benefits:**
- ✅ **1 Apex call** instead of 10-15
- ✅ **90% reduction** in SOQL queries
- ✅ **Single source of truth** for data
- ✅ **Auto-sync** across components
- ✅ **Better performance** and UX
- ✅ **Easier debugging** and maintenance

## Architecture Components

### 1. Apex Service Layer

#### CaseDataGovernorService.cls
**Purpose:** Centralized Apex service that consolidates all data fetching for Case pages.

**Key Method:**
```apex
@AuraEnabled
public static CasePageDataWrapper getCasePageData(
    Id caseId,
    Boolean includeRelated,
    Boolean includeBusinessRules
)
```

**Returns:** `CasePageDataWrapper` containing:
- `Case caseRecord` - Complete case record
- `CaseUIWrapper caseUI` - UI-specific data and validations
- `Account clientAccount, locationAccount, supplierAccount` - Related accounts
- `Contact caseContact` - Case contact
- `Asset caseAsset` - Case asset
- `List<Case> relatedCases` - Related cases
- `BusinessRuleUIWrapper businessRules` - Business rule info
- `SLAUIWrapper slaInfo` - SLA instructions
- `UserContextWrapper userContext` - User permissions and context
- `Map<String, Object> pageConfig` - Page-level configuration

**Leverages existing service layer:**
- `CaseContextGetter` - Data retrieval with caching
- `ContactContextGetter`, `AccountContextGetter`, `AssetContextGetter` - Related data
- `CaseUIService` - UI logic and validations
- `CaseBusinessRuleService` - Business rule evaluation

### 2. Lightning Message Service (LMS)

#### CaseDataChannel.messageChannel-meta.xml
**Purpose:** Communication channel for publishing/subscribing to case data updates.

**Message Fields:**
- `caseId` - Case ID
- `eventType` - Event type (load, refresh, update, error)
- `pageData` - Complete page data as JSON string
- `section` - Section being updated (for targeted refreshes)
- `timestamp` - Event timestamp
- `errorMessage` - Error message if applicable

### 3. Governor LWC Component

#### lwc/caseDataGovernor/
**Purpose:** Central data management component that loads and publishes data.

**Functionality:**
1. **On Load:**
   - Calls `getCasePageData()` Apex method
   - Receives comprehensive `CasePageDataWrapper`
   - Publishes data via LMS to all subscribers

2. **On Refresh Request:**
   - Listens for refresh messages from child components
   - Calls `refreshPageSection()` for targeted updates
   - Publishes updated data via LMS

3. **Error Handling:**
   - Catches and logs errors
   - Publishes error events via LMS
   - Shows toast notifications

**Usage:**
Add to Case record page layout (typically at the top):

```xml
<c-case-data-governor record-id="{!recordId}"></c-case-data-governor>
```

### 4. Refactored Child Components

Child components are refactored to consume data from the governor instead of making direct Apex calls.

#### Pattern for Refactoring:

**Before (Direct Apex):**
```javascript
import getCaseDetails from '@salesforce/apex/MyController.getCaseDetails';

connectedCallback() {
    this.loadData();
}

async loadData() {
    const result = await getCaseDetails({ caseId: this.recordId });
    this.data = result;
}
```

**After (Governor Pattern):**
```javascript
import { subscribe, MessageContext } from 'lightning/messageService';
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';
import getCaseDetails from '@salesforce/apex/MyController.getCaseDetails'; // Fallback only

@wire(MessageContext)
messageContext;

connectedCallback() {
    this.subscribeToGovernor();

    // Fallback timeout if governor doesn't respond
    this.governorTimeout = setTimeout(() => {
        if (!this.hasReceivedGovernorData) {
            this.loadDataDirectly(); // Fallback to direct Apex
        }
    }, 2000);
}

subscribeToGovernor() {
    this.subscription = subscribe(
        this.messageContext,
        CASE_DATA_CHANNEL,
        (message) => this.handleGovernorMessage(message)
    );
}

handleGovernorMessage(message) {
    if (message.caseId !== this.recordId) return;

    if (message.eventType === 'load' || message.eventType === 'refresh') {
        const pageData = JSON.parse(message.pageData);
        this.mapGovernorDataToComponent(pageData);
        this.hasReceivedGovernorData = true;
    }
}

mapGovernorDataToComponent(pageData) {
    // Extract needed data from pageData
    this.data = pageData.caseRecord;
    this.uiData = pageData.caseUI;
    // etc.
}
```

## Implementation Guide

### Step 1: Deploy Governor Infrastructure

1. **Deploy Apex Service:**
   ```bash
   sfdx force:source:deploy -p classes/CaseDataGovernorService.cls
   ```

2. **Deploy LMS Channel:**
   ```bash
   sfdx force:source:deploy -p messageChannels/CaseDataChannel.messageChannel-meta.xml
   ```

3. **Deploy Governor Component:**
   ```bash
   sfdx force:source:deploy -p lwc/caseDataGovernor
   ```

### Step 2: Add Governor to Page Layout

1. Open Case record page in Lightning App Builder
2. Add `caseDataGovernor` component to the page
3. Place it at the top of the page (loads first)
4. Save and activate

### Step 3: Refactor Child Components

For each component on the Case page:

1. **Identify Apex calls** made on component load
2. **Check if data is available** in `CasePageDataWrapper`
3. **Refactor component** to subscribe to LMS
4. **Map governor data** to component properties
5. **Keep fallback** for backward compatibility
6. **Test thoroughly**

### Step 4: Incremental Migration

**Phase 1:** Deploy governor alongside existing components (no breaking changes)

**Phase 2:** Refactor 3-5 high-impact components as proof of concept
- customCaseHighlightPanel
- showCaseMessages
- closeCasePop

**Phase 3:** Migrate remaining components incrementally

**Phase 4:** Monitor performance improvements and optimize

## Performance Improvements

### Metrics (Estimated)

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Apex Calls (page load) | 10-15 | 1 | **90% reduction** |
| SOQL Queries | 25-40 | 3-5 | **85% reduction** |
| Page Load Time | 3-5s | 1-2s | **60% faster** |
| CPU Time | 8000ms | 1500ms | **81% reduction** |
| Heap Size | 4MB | 1MB | **75% reduction** |

### Governor Limits Impact

**Before:**
- High risk of hitting SOQL query limits (100 queries per transaction)
- Potential for hitting CPU time limits
- Memory pressure from multiple large queries

**After:**
- Single consolidated query with caching
- Predictable resource consumption
- Headroom for future features

## Testing Strategy

### Unit Tests

1. **Test CaseDataGovernorService:**
   ```apex
   @isTest
   private class CaseDataGovernorServiceTest {
       @isTest
       static void testGetCasePageData() {
           // Create test case
           Case testCase = createTestCase();

           // Call service
           CaseDataGovernorService.CasePageDataWrapper result =
               CaseDataGovernorService.getCasePageData(testCase.Id, true, true);

           // Verify
           System.assertNotEquals(null, result);
           System.assertEquals(true, result.isSuccess);
           System.assertNotEquals(null, result.caseRecord);
       }
   }
   ```

2. **Test LMS Communication:**
   - Use `@wire(MessageContext)` in Jest tests
   - Mock LMS publish/subscribe
   - Verify messages sent/received correctly

3. **Test Component Integration:**
   - Test governor loads data on page load
   - Test child components receive data via LMS
   - Test fallback when governor unavailable

### Integration Tests

1. Add governor to sandbox Case page
2. Load page and verify single Apex call
3. Verify all components display correctly
4. Test refresh scenarios
5. Test error handling

## Troubleshooting

### Governor Not Publishing Data

**Symptoms:** Child components not receiving data, showing loading spinners indefinitely

**Debugging:**
1. Open browser console
2. Check for JavaScript errors in caseDataGovernor
3. Verify Apex call succeeded (Network tab)
4. Check LMS channel configuration

**Solutions:**
- Ensure `caseDataGovernor` is on the page
- Verify LMS channel is deployed
- Check Apex permissions

### Components Not Subscribing

**Symptoms:** Governor loads data but components don't update

**Debugging:**
1. Check component's `subscribeToGovernor()` method
2. Verify `@wire(MessageContext)` is present
3. Check message filtering logic (caseId matching)

**Solutions:**
- Ensure component calls `subscribe()` in `connectedCallback()`
- Verify message filtering doesn't exclude valid messages
- Check for unsubscribe in `disconnectedCallback()`

### Performance Not Improving

**Symptoms:** Page still slow after implementing governor

**Debugging:**
1. Check Developer Console for Apex call count
2. Verify only governor is making initial Apex calls
3. Check if components still making direct calls

**Solutions:**
- Ensure all components are refactored
- Remove direct Apex calls from child components
- Verify governor timeout is not triggering fallbacks

## Future Enhancements

### 1. Real-time Updates
- Integrate with Platform Events for real-time case updates
- Push updates to all users viewing same case

### 2. Client-side Caching
- Implement browser storage caching
- Reduce even the single Apex call on revisits

### 3. Lazy Loading
- Load sections on-demand instead of all at once
- Further optimize initial page load

### 4. Governor for Other Objects
- Create similar governors for Account, Contact, etc.
- Standardize data management across app

### 5. Analytics
- Track performance metrics
- Monitor governor effectiveness
- Identify optimization opportunities

## Best Practices

### For Apex Developers

1. **Keep Service Layer Thin**
   - Governor service coordinates, doesn't contain business logic
   - Delegate to ContextGetter and Business Rule services

2. **Use Caching Wisely**
   - Leverage existing ContextGetter caching
   - Consider session caching for expensive calculations

3. **Return Complete Data**
   - Include all data components might need
   - Avoid forcing components to make additional calls

### For LWC Developers

1. **Always Implement Fallback**
   - Components should work with or without governor
   - Timeout after 2 seconds and load directly

2. **Filter Messages Carefully**
   - Only process messages for your recordId
   - Check eventType before processing

3. **Request Targeted Refreshes**
   - Only refresh what changed, not everything
   - Use section parameter for targeted updates

4. **Handle Errors Gracefully**
   - Listen for error events
   - Show user-friendly messages

## Conclusion

The Case Data Governor architecture provides a robust, scalable solution for centralizing data management on Salesforce record pages. By eliminating redundant Apex calls and providing a single source of truth, it dramatically improves performance, reduces governor limit pressure, and simplifies component development.

This pattern can be extended to other objects and serves as a foundation for modern, high-performance Salesforce Lightning applications.

---

**Version:** 1.0
**Last Updated:** 2025
**Author:** Waste Management Development Team

# Case Record Page Refresh Pattern

## Overview

This document explains the centralized refresh mechanism for Case record pages using the **CaseDataGovernorLWC** pattern and Lightning Message Service (LMS).

## Architecture

### Components Involved

1. **CaseDataGovernorLWC** - Central data hub (placed on Case record page)
2. **CustomCaseHighlightPanelLWC** - Displays case highlights, subscribes to data
3. **ShowCaseMessagesLWC** - Displays case messages and actions, subscribes to data
4. **Child Modal Components** - Perform DML operations and trigger refreshes

### Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Case Record Page                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────┐         ┌──────────────────────┐   │
│  │ CaseDataGovernorLWC│◄────────│  CaseDataChannel LMS │   │
│  │  (Data Hub)        │         │  (Message Bus)       │   │
│  └────────┬───────────┘         └──────▲───────────────┘   │
│           │ publishes                   │ subscribes        │
│           │ fresh data                  │ to refresh        │
│           ▼                             │                   │
│  ┌─────────────────────────────────────┴──────────────┐    │
│  │                                                     │    │
│  │  ┌──────────────────────┐  ┌─────────────────────┐│    │
│  │  │CustomCaseHighlightLWC│  │ShowCaseMessagesLWC  ││    │
│  │  │ - subscribes         │  │ - subscribes        ││    │
│  │  │ - requests refresh   │  │ - requests refresh  ││    │
│  │  └──────────┬───────────┘  └─────────┬───────────┘│    │
│  │             │                         │            │    │
│  │             │ onrefresh               │            │    │
│  │             ▼                         ▼            │    │
│  │  ┌─────────────────┐       After DML operations   │    │
│  │  │ Child Modals    │       call refreshView()     │    │
│  │  │ (Location,      │                              │    │
│  │  │  Contact, etc.) │                              │    │
│  │  └─────────────────┘                              │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Refresh Flow After DML

### Step-by-Step Process

1. **Component performs DML** (via Apex method)
   ```javascript
   const result = await updateCase({...});
   if (result === 'Success') {
       this.refreshView(); // Trigger refresh
   }
   ```

2. **refreshView() executes three actions:**
   - Calls `notifyRecordUpdateAvailable()` → Refreshes wire adapters
   - Calls `requestCaseDataRefresh()` → Publishes 'reload' message to LMS
   - (Optional) Calls local data load method as fallback

3. **CaseDataGovernorLWC receives message**
   - Listens on CaseDataChannel for 'reload' or 'refresh' events
   - Calls `loadCaseData()` to fetch fresh data from Apex
   - Gets updated CasePageDataWrapper with all case context

4. **CaseDataGovernorLWC publishes fresh data**
   - Publishes via CaseDataChannel with eventType: 'load'
   - Includes complete pageData with case, UI, related records

5. **All subscriber components receive update**
   - CustomCaseHighlightPanelLWC updates its display
   - ShowCaseMessagesLWC updates buttons and messages
   - Any other subscribed components update automatically

## Implementation Patterns

### Pattern 1: Parent Component DML (ShowCaseMessagesLWC)

```javascript
async handleSaveWorkOrderDetails() {
    try {
        const result = await addWorkOrderDetails({
            caseWoFields: {...},
            caseIdList: this.selectedCases
        });

        if (result === 'Success') {
            this.showToast('Success', 'Work order details saved', 'success');
            this.handleCancelModal();
            this.refreshView(); // ← ALWAYS CALL THIS AFTER SUCCESSFUL DML
        }
    } catch (error) {
        this.showToast('Error', error.body?.message, 'error');
    }
}
```

### Pattern 2: Child Component DML (Modal Components)

**In Child Component (after DML):**
```javascript
// After successful Case update
this.dispatchEvent(new CustomEvent('refresh'));
this.dispatchEvent(new CustomEvent('close'));
```

**In Parent HTML:**
```html
<c-location-modal
    record-id={recordId}
    is-open={isModalOpenLocation}
    onrefresh={handleRefresh}
    onclose={handleCloseModal}>
</c-location-modal>
```

**In Parent JavaScript:**
```javascript
async handleRefresh() {
    await this.loadDataDirectly();          // Local refresh
    if (this.hasReceivedGovernorData) {
        this.requestGovernorRefresh();       // Notify governor
    }
    await notifyRecordUpdateAvailable([{ recordId: this.recordId }]); // Refresh wires
}
```

## Message Types

### CaseDataChannel Messages

| Event Type | Purpose | Triggered By | Handled By |
|-----------|---------|--------------|------------|
| `load` | Initial data load complete | CaseDataGovernorLWC | All subscribers |
| `refresh` | Partial data refresh | Components | CaseDataGovernorLWC |
| `reload` | Full data reload | Components | CaseDataGovernorLWC |
| `error` | Error occurred | CaseDataGovernorLWC | All subscribers |

### Message Structure

```javascript
{
    caseId: '500xxx',              // Case record ID
    eventType: 'reload',           // Message type
    pageData: '{...}',             // JSON stringified CasePageDataWrapper (for load events)
    section: 'contact',            // Optional: specific section to refresh
    timestamp: '2025-01-01T12:00:00Z',
    requestedBy: 'showCaseMessagesLWC'  // Component requesting refresh
}
```

## Best Practices

### ✅ DO

- **Always call refreshView()** after successful Case DML operations
- **Use 'reload' eventType** for full refreshes after DML
- **Fire 'refresh' event** from child components after their DML
- **Check for success** before triggering refresh
- **Include notifyRecordUpdateAvailable()** to refresh wire adapters

### ❌ DON'T

- Don't perform direct Apex queries after DML - use refresh mechanism
- Don't forget to call refresh after updates
- Don't refresh on error conditions
- Don't use setTimeout() to "wait for Apex" - the LMS handles timing
- Don't call refreshApex() directly - use the centralized pattern

## Troubleshooting

### Components not refreshing after DML

**Check:**
1. Is CaseDataGovernorLWC added to the Case record page layout?
2. Is refreshView() being called after successful DML?
3. Are child components firing 'refresh' events?
4. Check browser console for LMS errors

### Data appears stale

**Check:**
1. Verify eventType is 'reload' not 'refresh' for full refreshes
2. Ensure caseId matches in LMS messages
3. Check if hasReceivedGovernorData is true
4. Verify CaseDataGovernorLWC is loading data successfully

### Multiple refreshes occurring

**This is expected and optimal:**
- Local component refresh = immediate UI update
- Governor refresh = propagates to all components
- Wire adapter refresh = updates standard fields

The multi-layered approach ensures all components stay in sync.

## Code References

| Component | File | Key Methods |
|-----------|------|-------------|
| CaseDataGovernorLWC | `lwc/caseDataGovernorLWC/caseDataGovernorLWC.js` | loadCaseData(), handleRefreshRequest() |
| ShowCaseMessagesLWC | `lwc/showCaseMessagesLWC/showCaseMessagesLWC.js:677-706` | refreshView(), requestCaseDataRefresh() |
| CustomCaseHighlightPanelLWC | `lwc/customCaseHighlightPanelLWC/customCaseHighlightPanelLWC.js:591-633` | handleRefresh(), requestGovernorRefresh() |
| CaseDataGovernorService | `classes/CaseDataGovernorService.cls:108-149` | getCasePageData() |

## Examples

### Example 1: Updating Location

```javascript
// In c-location-modal component
async handleSaveLocation() {
    try {
        const result = await updateCaseLocation({
            caseId: this.recordId,
            locationId: this.selectedLocationId
        });

        if (result === 'Success') {
            this.showToast('Success', 'Location updated');
            this.dispatchEvent(new CustomEvent('refresh')); // Triggers parent handleRefresh()
            this.dispatchEvent(new CustomEvent('close'));
        }
    } catch (error) {
        this.showToast('Error', error.message);
    }
}
```

### Example 2: Bulk Case Update

```javascript
// In showCaseMessagesLWC
async handleInitiateWorkorder() {
    try {
        const result = await initiateWorkOrder({
            caseId: this.recordId,
            caseIdList: this.selectedCases
        });

        if (result === 'Success') {
            this.showToast('Success', 'Work orders initiated');
            this.refreshView(); // Refreshes all components on page
        }
    } catch (error) {
        this.showToast('Error', error.message);
    }
}
```

## Migration Guide

### Converting Old Pattern to New Pattern

**Before (direct refresh):**
```javascript
// Old way - component-specific refresh
async handleUpdate() {
    await updateCase({...});
    await this.loadCaseData(); // Only refreshes this component
}
```

**After (centralized refresh):**
```javascript
// New way - refreshes ALL components
async handleUpdate() {
    const result = await updateCase({...});
    if (result === 'Success') {
        this.refreshView(); // Refreshes entire page
    }
}
```

## Performance Considerations

- **Single Apex Call**: CaseDataGovernorLWC consolidates multiple queries into one
- **Optimized Updates**: Only refreshes when needed (after DML)
- **Cached Data**: Components receive updates via LMS without additional Apex calls
- **Wire Adapter Integration**: Works seamlessly with standard LDS caching

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-17 | Initial documentation of refresh pattern |

---

**Questions or Issues?** Contact the development team or refer to the inline documentation in the component files.

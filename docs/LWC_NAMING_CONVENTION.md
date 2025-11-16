# LWC Naming Convention - Avoiding Aura Conflicts

## Overview

All Lightning Web Components (LWC) in this project have been renamed to include an "LWC" suffix to avoid naming conflicts with Aura components during the migration period.

## Naming Pattern

### Directory Names
- **Old:** `lwc/customCaseHighlightPanel/`
- **New:** `lwc/customCaseHighlightPanelLWC/`

### File Names
- **Old:** `customCaseHighlightPanel.js`, `customCaseHighlightPanel.html`
- **New:** `customCaseHighlightPanelLWC.js`, `customCaseHighlightPanelLWC.html`

### Class Names (JavaScript)
- **Old:** `export default class CustomCaseHighlightPanel`
- **New:** `export default class CustomCaseHighlightPanelLWC`

### Component References (HTML)
- **Old:** `<c-custom-case-highlight-panel>`
- **New:** `<c-custom-case-highlight-panel-l-w-c>`

## Complete Component List

All 21 LWC components have been renamed:

| Original Name | New Name with LWC Suffix |
|--------------|-------------------------|
| caseDataGovernor | caseDataGovernorLWC |
| caseNavigation | caseNavigationLWC |
| changeRecordType | changeRecordTypeLWC |
| clientContainer | clientContainerLWC |
| clientSearch | clientSearchLWC |
| closeCasePop | closeCasePopLWC |
| createNewAccountTitle | createNewAccountTitleLWC |
| createPendingInformationTask | createPendingInformationTaskLWC |
| customCaseHighlightPanel | customCaseHighlightPanelLWC |
| fillCaseSubType | fillCaseSubTypeLWC |
| hoverOverCards | hoverOverCardsLWC |
| locationContainer | locationContainerLWC |
| ntebRulesModal | ntebRulesModalLWC |
| searchExistingContact | searchExistingContactLWC |
| serviceDateContainer | serviceDateContainerLWC |
| setCaseCustomerInfo | setCaseCustomerInfoLWC |
| showAssetHeadersOnCase | showAssetHeadersOnCaseLWC |
| showCaseMessages | showCaseMessagesLWC |
| uiCustomLookup | uiCustomLookupLWC |
| uiCustomLookupResult | uiCustomLookupResultLWC |
| vendorContainer | vendorContainerLWC |

## Updated Component References

The following component references were updated in HTML templates:

- `<c-ui-custom-lookup>` → `<c-ui-custom-lookup-l-w-c>`
- `<c-ui-custom-lookup-result>` → `<c-ui-custom-lookup-result-l-w-c>`
- `<c-client-search>` → `<c-client-search-l-w-c>`
- `<c-service-date-container>` → `<c-service-date-container-l-w-c>`

## External Component References (Not Updated)

The following component references were found but NOT updated as they appear to be external components or not yet converted from Aura:

- `c-vendor-search`
- `c-case-quote-modal`
- `c-existing-quote-modal`
- `c-add-favorite-containers`
- `c-case-location-details`
- `c-location-asset-search`
- `c-wm-capacity`
- `c-set-case-s-l-a-date`
- `c-custom-calendar`

**Action Required:** When these components are converted to LWC, they should also follow the LWC suffix naming convention.

## Why This Naming Convention?

### Problem
During the Aura to LWC migration, having both an Aura component and an LWC component with the same name causes conflicts:
- Deployment errors
- Ambiguous component references
- Runtime conflicts

### Solution
By adding the "LWC" suffix to all Lightning Web Components:
- ✅ Clear distinction between Aura and LWC versions
- ✅ No deployment conflicts
- ✅ Can run both versions side-by-side during migration
- ✅ Easy to identify which technology is being used

## Usage in Lightning App Builder

When adding components to Lightning pages, the components will appear with their LWC suffix:

- **Component Name:** Custom Case Highlight Panel LWC
- **API Name:** `customCaseHighlightPanelLWC`

## Usage in HTML Templates

When referencing a component in another LWC component's template:

```html
<template>
    <!-- Correct: Use kebab-case with -l-w-c suffix -->
    <c-custom-case-highlight-panel-l-w-c
        record-id={recordId}>
    </c-custom-case-highlight-panel-l-w-c>

    <!-- Incorrect: Old naming without suffix -->
    <!-- <c-custom-case-highlight-panel record-id={recordId}></c-custom-case-highlight-panel> -->
</template>
```

## Future Considerations

### After Full Migration Complete

Once all Aura components have been fully replaced and removed from the org, the team may choose to:

1. **Option A: Keep LWC Suffix**
   - Pros: Clear identification, consistent naming
   - Cons: Longer names

2. **Option B: Remove LWC Suffix**
   - Pros: Shorter names, cleaner
   - Cons: Another refactoring effort

### Recommendation

Keep the LWC suffix permanently for these reasons:
- Clearly identifies the technology being used
- No breaking changes to existing implementations
- Consistent with other orgs' migration strategies
- Avoids future refactoring effort

## Migration Checklist

When converting a new Aura component to LWC:

- [ ] Create component with LWC suffix (e.g., `myComponentLWC`)
- [ ] Update class name with LWC suffix (e.g., `MyComponentLWC`)
- [ ] Update any component references in templates to use `-l-w-c` suffix
- [ ] Test component in isolation
- [ ] Test component integrated with other components
- [ ] Update documentation to reflect new component name
- [ ] Deploy to sandbox first
- [ ] Validate in production

## Automated Rename Process

The renaming was performed using automated scripts that:

1. Renamed all component directories (`component` → `componentLWC`)
2. Renamed all files inside directories
3. Updated class names in JavaScript files
4. Updated component references in HTML templates
5. Preserved all functionality and logic

No manual code changes were required, ensuring consistency and reducing errors.

## Questions?

Refer to:
- `docs/GOVERNOR_ARCHITECTURE.md` - For governor pattern
- `docs/COMPONENT_REFACTORING_GUIDE.md` - For refactoring patterns

---

**Last Updated:** 2025
**Naming Convention Version:** 1.0

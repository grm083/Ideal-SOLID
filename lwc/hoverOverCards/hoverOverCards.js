import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

// Import Case fields for all three modes
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_ASSET_ID from '@salesforce/schema/Case.AssetId';
import CASE_ASSET_NAME from '@salesforce/schema/Case.Asset.Name';
import CASE_ASSET_MATERIAL_TYPE from '@salesforce/schema/Case.Asset.Material_Type__c';
import CASE_ASSET_SID from '@salesforce/schema/Case.Asset.Acorn_SID__c';
import CASE_ASSET_DURATION from '@salesforce/schema/Case.Asset.Duration__c';
import CASE_ASSET_OCCURRENCE from '@salesforce/schema/Case.Asset.Occurrence_Type__c';
import CASE_ASSET_SCHEDULE from '@salesforce/schema/Case.Asset.Schedule__c';
import CASE_ASSET_START_DATE from '@salesforce/schema/Case.Asset.Start_Date__c';
import CASE_ASSET_END_DATE from '@salesforce/schema/Case.Asset.End_Date__c';
import CASE_ASSET_SENSITIVITY_CODE from '@salesforce/schema/Case.Asset.Sensitivity_Code__c';
import CASE_ASSET_HAS_EXTRA_PICKUP from '@salesforce/schema/Case.Asset.Has_Extra_Pickup__c';
import CASE_ASSET_EQUIPMENT_OWNER from '@salesforce/schema/Case.Asset.Equipment_Owner__c';
import CASE_ASSET_CONTAINER_POSITION from '@salesforce/schema/Case.Asset.Container_Position__c';
import CASE_ASSET_CATEGORY from '@salesforce/schema/Case.Asset.Category__c';
import CASE_ASSET_VENDOR_ACCOUNT_NUMBER from '@salesforce/schema/Case.Asset.Vendor_Account_Number__c';
import CASE_ASSET_MAS_UNIQUE_ID from '@salesforce/schema/Case.Asset.MAS_Customer_Unique_Id__c';
import CASE_ASSET_MAS_COMPANY_ACCOUNT from '@salesforce/schema/Case.Asset.MAS_Company_Account_Number__c';
import CASE_ASSET_MAS_LIBRARY from '@salesforce/schema/Case.Asset.MAS_Library__c';
import CASE_ASSET_SUPPLIER_ID from '@salesforce/schema/Case.Asset.Supplier__c';
import CASE_ASSET_SUPPLIER_NAME from '@salesforce/schema/Case.Asset.Supplier__r.Name';
import CASE_ASSET_VENDOR_ID from '@salesforce/schema/Case.Asset.Vendor_ID__c';
import CASE_ASSET_PROJECT_CODE_ID from '@salesforce/schema/Case.Asset.Project_Code__r.ProjectCode_Id__c';

// Location fields
import CASE_CLIENT_NAME from '@salesforce/schema/Case.Client__r.Name';
import CASE_LOCATION_CODE from '@salesforce/schema/Case.Location__r.Location_Code__c';
import CASE_LOCATION_STREET from '@salesforce/schema/Case.Location__r.ShippingStreet';
import CASE_LOCATION_CITY from '@salesforce/schema/Case.Location__r.ShippingCity';
import CASE_LOCATION_STATE from '@salesforce/schema/Case.Location__r.ShippingState';
import CASE_LOCATION_ZIP from '@salesforce/schema/Case.Location__r.ShippingPostalCode';
import CASE_LOCATION_COUNTRY from '@salesforce/schema/Case.Location__r.ShippingCountry';
import CASE_LOCATION_PHONE from '@salesforce/schema/Case.Location__r.Phone';
import CASE_LOCATION_SEGMENT from '@salesforce/schema/Case.Location__r.Primary_Segment__c';
import CASE_LOCATION_LOCAL_TIME from '@salesforce/schema/Case.Location__r.tz__Local_Time_Short__c';
import CASE_LOCATION_CUSTOMER_CODE from '@salesforce/schema/Case.Location__r.Customer_Location_Code__c';
import CASE_LOCATION_IS_PORTAL from '@salesforce/schema/Case.Location__r.Is_Portal_Customer__c';
import CASE_LOCATION_PORTAL_NAME from '@salesforce/schema/Case.Location__r.Portal_Name__c';

// Contact fields
import CASE_CONTACT_NAME from '@salesforce/schema/Case.Contact.Name';
import CASE_CONTACT_TITLE from '@salesforce/schema/Case.Contact_Title__c';
import CASE_CONTACT_PHONE from '@salesforce/schema/Case.Contact.Phone';
import CASE_CONTACT_MOBILE from '@salesforce/schema/Case.Contact.MobilePhone';
import CASE_CONTACT_EMAIL from '@salesforce/schema/Case.Contact.Email';
import CASE_CONTACT_PREFERRED_METHOD from '@salesforce/schema/Case.Contact.Preferred_Method__c';
import CASE_CONTACT_EMAIL_VALIDATED from '@salesforce/schema/Case.Contact.Email_Validated__c';

const CASE_FIELDS = [
    CASE_ID,
    CASE_ASSET_ID,
    CASE_ASSET_NAME,
    CASE_ASSET_MATERIAL_TYPE,
    CASE_ASSET_SID,
    CASE_ASSET_DURATION,
    CASE_ASSET_OCCURRENCE,
    CASE_ASSET_SCHEDULE,
    CASE_ASSET_START_DATE,
    CASE_ASSET_END_DATE,
    CASE_ASSET_SENSITIVITY_CODE,
    CASE_ASSET_HAS_EXTRA_PICKUP,
    CASE_ASSET_EQUIPMENT_OWNER,
    CASE_ASSET_CONTAINER_POSITION,
    CASE_ASSET_CATEGORY,
    CASE_ASSET_VENDOR_ACCOUNT_NUMBER,
    CASE_ASSET_MAS_UNIQUE_ID,
    CASE_ASSET_MAS_COMPANY_ACCOUNT,
    CASE_ASSET_MAS_LIBRARY,
    CASE_ASSET_SUPPLIER_ID,
    CASE_ASSET_SUPPLIER_NAME,
    CASE_ASSET_VENDOR_ID,
    CASE_ASSET_PROJECT_CODE_ID,
    CASE_CLIENT_NAME,
    CASE_LOCATION_CODE,
    CASE_LOCATION_STREET,
    CASE_LOCATION_CITY,
    CASE_LOCATION_STATE,
    CASE_LOCATION_ZIP,
    CASE_LOCATION_COUNTRY,
    CASE_LOCATION_PHONE,
    CASE_LOCATION_SEGMENT,
    CASE_LOCATION_LOCAL_TIME,
    CASE_LOCATION_CUSTOMER_CODE,
    CASE_LOCATION_IS_PORTAL,
    CASE_LOCATION_PORTAL_NAME,
    CASE_CONTACT_NAME,
    CASE_CONTACT_TITLE,
    CASE_CONTACT_PHONE,
    CASE_CONTACT_MOBILE,
    CASE_CONTACT_EMAIL,
    CASE_CONTACT_PREFERRED_METHOD,
    CASE_CONTACT_EMAIL_VALIDATED
];

/**
 * HoverOverCards - LWC component for displaying hover card information
 * Converted from Aura component: aura/HoverOverCards
 *
 * @description Displays detailed information in three modes:
 * - Asset: Shows comprehensive asset details with pricing and cost information
 * - Location: Shows location details with address and portal information
 * - Contact: Shows contact details with phone, email, and preferences
 */
export default class HoverOverCards extends NavigationMixin(LightningElement) {
    // Public properties
    @api recordId; // Case ID
    @api objectType = 'Asset'; // 'Asset', 'Location', or 'Contact'

    // Asset service details (from child assets)
    assetQuantity = 0;
    pickUpCost = null;
    pickUpPrice = null;
    extraPickUpCost = null;
    extraPickUpPrice = null;
    haulCost = null;
    haulPrice = null;
    disposalCost = null;
    disposalPrice = null;

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties for display modes
    get isAssetMode() {
        return this.objectType === 'Asset';
    }

    get isLocationMode() {
        return this.objectType === 'Location';
    }

    get isContactMode() {
        return this.objectType === 'Contact';
    }

    // Asset computed properties
    get assetName() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_NAME);
    }

    get assetMaterialType() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_MATERIAL_TYPE);
    }

    get assetSID() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_SID);
    }

    get assetDuration() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_DURATION);
    }

    get assetOccurrence() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_OCCURRENCE);
    }

    get assetSchedule() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_SCHEDULE);
    }

    get assetStartDate() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_START_DATE);
    }

    get assetEndDate() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_END_DATE);
    }

    get hasEndDate() {
        return !!this.assetEndDate;
    }

    get endDateHeaderClass() {
        return this.hasEndDate ? 'head slds-size_1-of-5 red' : 'head slds-size_1-of-5';
    }

    get endDateCellClass() {
        return this.hasEndDate ? 'slds-size_1-of-5 highlight' : 'slds-size_1-of-5';
    }

    get assetSensitivityCode() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_SENSITIVITY_CODE);
    }

    get hasExtraPickup() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_HAS_EXTRA_PICKUP);
    }

    get equipmentOwner() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_EQUIPMENT_OWNER);
    }

    get assetContainerPosition() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_CONTAINER_POSITION);
    }

    get assetCategory() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_CATEGORY);
    }

    get vendorAccountNumber() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_VENDOR_ACCOUNT_NUMBER);
    }

    get masUniqueId() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_MAS_UNIQUE_ID);
    }

    get masCompanyAccount() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_MAS_COMPANY_ACCOUNT);
    }

    get masLibrary() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_MAS_LIBRARY);
    }

    get vendorId() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_SUPPLIER_ID);
    }

    get vendorName() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_SUPPLIER_NAME);
    }

    get vendorIdDisplay() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_VENDOR_ID);
    }

    get projectCodeId() {
        return getFieldValue(this.caseRecord.data, CASE_ASSET_PROJECT_CODE_ID);
    }

    // Pricing/Cost boolean properties
    get hasPickUpCost() {
        return this.pickUpCost != null;
    }

    get hasPickUpPrice() {
        return this.pickUpPrice != null;
    }

    get hasExtraPickUpCost() {
        return this.extraPickUpCost != null;
    }

    get hasExtraPickUpPrice() {
        return this.extraPickUpPrice != null;
    }

    get hasHaulCost() {
        return this.haulCost != null;
    }

    get hasHaulPrice() {
        return this.haulPrice != null;
    }

    get hasDisposalCost() {
        return this.disposalCost != null;
    }

    get hasDisposalPrice() {
        return this.disposalPrice != null;
    }

    // Location computed properties
    get clientName() {
        return getFieldValue(this.caseRecord.data, CASE_CLIENT_NAME);
    }

    get locationCode() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_CODE);
    }

    get locationStreet() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_STREET);
    }

    get locationPhone() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_PHONE);
    }

    get locationSegment() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_SEGMENT);
    }

    get locationCityStateZip() {
        const city = getFieldValue(this.caseRecord.data, CASE_LOCATION_CITY);
        const state = getFieldValue(this.caseRecord.data, CASE_LOCATION_STATE);
        const zip = getFieldValue(this.caseRecord.data, CASE_LOCATION_ZIP);
        return `${city}, ${state} ${zip}`;
    }

    get locationCountry() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_COUNTRY);
    }

    get locationLocalTime() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_LOCAL_TIME);
    }

    get locationCustomerCode() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_CUSTOMER_CODE);
    }

    get isPortalCustomer() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_IS_PORTAL);
    }

    get portalName() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION_PORTAL_NAME);
    }

    // Contact computed properties
    get contactName() {
        return getFieldValue(this.caseRecord.data, CASE_CONTACT_NAME);
    }

    get contactTitle() {
        return getFieldValue(this.caseRecord.data, CASE_CONTACT_TITLE);
    }

    get contactEmail() {
        return getFieldValue(this.caseRecord.data, CASE_CONTACT_EMAIL);
    }

    get contactPreferredMethod() {
        return getFieldValue(this.caseRecord.data, CASE_CONTACT_PREFERRED_METHOD);
    }

    get emailValidated() {
        return getFieldValue(this.caseRecord.data, CASE_CONTACT_EMAIL_VALIDATED);
    }

    get contactPhone() {
        const preferredMethod = this.contactPreferredMethod;
        if (preferredMethod === 'MobilePhone') {
            return getFieldValue(this.caseRecord.data, CASE_CONTACT_MOBILE);
        } else if (preferredMethod === 'Phone') {
            return getFieldValue(this.caseRecord.data, CASE_CONTACT_PHONE);
        }
        return '';
    }

    // Event Handlers
    handleNavigateToVendor(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    // Note: Asset service details (pricing/cost) would need to be fetched from child Asset records
    // This would require an Apex method to query child assets and aggregate pricing data
    // For now, the template shows N/A when these values are null
}

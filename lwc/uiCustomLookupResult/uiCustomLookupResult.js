import { LightningElement, api } from 'lwc';

export default class UiCustomLookupResult extends LightningElement {
    @api record;
    @api iconName;

    get recordName() {
        return this.record ? this.record.Name : '';
    }

    get recordEmail() {
        return this.record ? this.record.Email : '';
    }

    get recordId() {
        return this.record ? this.record.Id : '';
    }

    handleClick() {
        // Dispatch custom event to parent
        const selectEvent = new CustomEvent('recordselect', {
            detail: {
                recordId: this.recordId,
                record: this.record
            }
        });
        this.dispatchEvent(selectEvent);
    }
}

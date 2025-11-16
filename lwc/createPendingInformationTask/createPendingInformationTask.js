import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex methods
import getCaseObject from '@salesforce/apex/CreatePendingInformationTask.getCaseObject';
import filedWrapperDataSet from '@salesforce/apex/CreatePendingInformationTask.filedWrapperDataSet';
import createPsiTask from '@salesforce/apex/CreatePendingInformationTask.createPsiTask';
import createObtainInternalRespoTask from '@salesforce/apex/CreatePendingInformationTask.createObtainInternalRespoTask';
import checkUserIsTaskUser from '@salesforce/apex/CreatePendingInformationTask.checkUserIsTaskUser';

// Import Custom Labels
import PENDING_INFO_TASKS from '@salesforce/label/c.Pending_Information_Tasks';
import INITIATE_TASK from '@salesforce/label/c.Initiate_Task';

/**
 * CreatePendingInformationTask - LWC component for task creation
 * Converted from Aura component: aura/CreatePendingInformationTask
 *
 * @description Two-mode task creation component:
 * - Mode 1: Pending Information Task (simple task with due date and follow-up reasons)
 * - Mode 2: Initiate Task (complex task with user assignment and team routing)
 *
 * Features extensive conditional logic for team/user assignment and validation.
 */
export default class CreatePendingInformationTask extends LightningElement {
    // Public properties
    @api caseId;

    // Modal and UI state
    @track showTaskButtons = false;
    @track showTaskCreatePopUpPI = false;
    @track showPendingInfoTask = false;
    @track showInternalResponseTask = false;
    @track showSpinner = false;
    @track headerMessage = '';

    // Task object
    @track task = {
        Subject: '',
        Description: '',
        Due_Date_Time__c: '',
        Outcome__c: 'null',
        Follow_Up_Reasons__c: '',
        Next_Task_Due_Date_Time__c: '',
        Task_Team_Name__c: '',
        Task_Team_Queue__c: '',
        OwnerId: null
    };

    // Picklist values
    @track taskTypes = [];
    @track followUpReasons = [];
    @track teamName = [];
    @track teamQueValues = [];
    @track sfdcteamNameList = [];
    @track salesforceTeamUserList = [];

    // Selection values
    @track salesforceTeamUserValue = '';
    @track sfdcTeamValue = '';

    // Conditional visibility and state
    @track disabledTeamQ = true;
    @track disabledTeamUser = true;
    @track disabledAcornTeam = true;
    @track disabledSfdcTeam = false;
    @track caseTrackingNumber = false;
    @track isTaskUser = true;

    // User lookup (for Assigned To field)
    @track selectedLookUpRecord = {};

    // Maps for dependent picklists
    @track teamNameQueMap = {};
    @track sfdcTeamUserNameMap = {};

    // Case record
    @track caseRecObj = {};
    @track loggedInUserId = {};

    // Lifecycle Hooks
    async connectedCallback() {
        await this.loadCaseDetails();
    }

    // Computed properties
    get shouldShowUserLookup() {
        return !this.disabledSfdcTeam;
    }

    get userLookupClass() {
        return this.disabledSfdcTeam ? 'disableDiv' : '';
    }

    get taskTypeOptions() {
        return this.taskTypes.map(type => ({ label: type, value: type }));
    }

    get followUpReasonOptions() {
        return this.followUpReasons.map(reason => ({ label: reason, value: reason }));
    }

    get acornTeamOptions() {
        return this.teamName.map(team => ({ label: team, value: team }));
    }

    get teamQueueOptions() {
        return this.teamQueValues.map(queue => ({ label: queue, value: queue }));
    }

    get sfdcTeamOptions() {
        return this.sfdcteamNameList.map(team => ({ label: team, value: team }));
    }

    get sfdcTeamUserOptions() {
        return this.salesforceTeamUserList.map(user => ({ label: user, value: user }));
    }

    // Data Loading Methods
    async loadCaseDetails() {
        try {
            const wrapper = await getCaseObject({ caseId: this.caseId });
            this.caseRecObj = wrapper.caseObj;
            this.showTaskButtons = wrapper.showButton;
            this.loggedInUserId = wrapper.currentUserRec;

            if (wrapper.caseObj && wrapper.caseObj.Tracking_Number__c) {
                this.caseTrackingNumber = true;
                this.disabledAcornTeam = false;
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading case details', 'error');
        }
    }

    async loadFieldValues() {
        try {
            const wrapper = await filedWrapperDataSet({ whatId: this.caseId });

            if (wrapper.teamNameQueData) {
                this.teamNameQueMap = wrapper.teamNameQueData;

                // Convert map keys to array and sort
                const teamNameList = Object.keys(wrapper.teamNameQueData);
                teamNameList.sort();
                this.teamName = teamNameList;
            }

            if (wrapper.sfdcTeamData) {
                this.sfdcTeamUserNameMap = wrapper.sfdcTeamData;

                // Convert map keys to array and sort
                const sfdcTeamList = Object.keys(wrapper.sfdcTeamData);
                sfdcTeamList.sort();
                this.sfdcteamNameList = sfdcTeamList;
            }

            if (wrapper.followUpReasons) {
                this.followUpReasons = wrapper.followUpReasons;
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading field values', 'error');
        }
    }

    // Button Click Handlers
    handlePendingInfoTask() {
        // Parse custom label for task types
        this.taskTypes = PENDING_INFO_TASKS.split(';');

        // Reset task object
        this.task = {
            Subject: '',
            Description: '',
            Due_Date_Time__c: '',
            Follow_Up_Reasons__c: ''
        };

        this.showTaskCreatePopUpPI = true;
        this.showPendingInfoTask = true;
        this.headerMessage = 'Create Pending Information Task';
    }

    async handleInitateTask() {
        if (!this.isTaskUser) {
            this.isTaskUser = true;
        }

        // Parse custom label for task types
        this.taskTypes = INITIATE_TASK.split(';');

        // Reset values
        this.sfdcTeamValue = '';
        this.salesforceTeamUserList = [];
        this.selectedLookUpRecord = {};
        this.teamQueValues = [];
        this.disabledTeamQ = true;
        this.disabledSfdcTeam = false;
        this.disabledTeamUser = true;

        // Reset task object
        this.task = {
            Subject: '',
            Description: '',
            Task_Team_Name__c: '',
            Task_Team_Queue__c: '',
            OwnerId: null
        };

        await this.loadFieldValues();

        this.showPendingInfoTask = false;
        this.showInternalResponseTask = true;
        this.showTaskCreatePopUpPI = true;
        this.headerMessage = 'Create Initiate Task';
    }

    // Modal Actions
    handleCloseModal() {
        this.showTaskCreatePopUpPI = false;
        this.showPendingInfoTask = false;
        this.showInternalResponseTask = false;
        this.taskTypes = [];

        // Reset task object
        this.task = {
            Subject: '',
            Description: '',
            Due_Date_Time__c: '',
            Follow_Up_Reasons__c: '',
            Task_Team_Name__c: '',
            Task_Team_Queue__c: '',
            OwnerId: null
        };

        this.selectedLookUpRecord = {};
        this.disabledTeamUser = true;
        this.disabledAcornTeam = false;
        this.salesforceTeamUserValue = '';
        this.sfdcTeamValue = '';
        this.salesforceTeamUserList = [];
    }

    // Field Change Handlers
    handleTaskTypeChange(event) {
        this.task = { ...this.task, Subject: event.detail.value };
    }

    handleDueDateChange(event) {
        this.task = { ...this.task, Due_Date_Time__c: event.detail.value };
    }

    handleFollowUpChange(event) {
        this.task = { ...this.task, Follow_Up_Reasons__c: event.detail.value };
    }

    handleCommentChange(event) {
        this.task = { ...this.task, Description: event.detail.value };
    }

    handleAcornTeamChange(event) {
        const teamName = event.detail.value;
        this.task = { ...this.task, Task_Team_Name__c: teamName };

        if (!teamName || teamName.length === 0) {
            this.enableSfdcTeam();
            this.disabledTeamQ = true;
        } else {
            this.disableSfdcTeam();
            this.disabledTeamQ = false;
        }

        // Update team queue values based on selected team
        if (this.teamNameQueMap && teamName) {
            this.teamQueValues = this.teamNameQueMap[teamName] || [];
        }
    }

    handleTeamQueueChange(event) {
        this.task = { ...this.task, Task_Team_Queue__c: event.detail.value };
    }

    handleSfdcTeamChange(event) {
        const selectedTeam = event.detail.value;
        this.sfdcTeamValue = selectedTeam;

        if (!selectedTeam || selectedTeam.length === 0) {
            this.salesforceTeamUserValue = '';
            this.disabledTeamUser = true;

            if (this.caseTrackingNumber) {
                this.enableAcornTeam();
            }
        } else {
            this.disabledTeamUser = false;
            this.disableAcornTeam();
        }

        // Update SFDC team user values based on selected SFDC team
        if (this.sfdcTeamUserNameMap && selectedTeam) {
            this.salesforceTeamUserList = this.sfdcTeamUserNameMap[selectedTeam] || [];
        }
    }

    handleSfdcTeamUserChange(event) {
        this.salesforceTeamUserValue = event.detail.value;
    }

    // Custom Events (from child components)
    handleSelectedRecordEvent(event) {
        this.selectedLookUpRecord = event.detail;
        this.isTaskUser = true;
        this.disabledSfdcTeam = true;
        this.disabledAcornTeam = true;

        // Check if user is a task user
        if (!this.caseTrackingNumber &&
            this.selectedLookUpRecord &&
            this.selectedLookUpRecord.Id &&
            this.selectedLookUpRecord.User_categorization_code__c) {
            this.checkAssignedToUser();
        }
    }

    handleRecordRemove() {
        this.disabledSfdcTeam = false;
        this.disabledAcornTeam = false;
        this.selectedLookUpRecord = {};
    }

    // Validation and Save Methods
    async handleSaveTask() {
        if (this.showPendingInfoTask) {
            await this.savePsiTask();
        } else if (this.showInternalResponseTask) {
            await this.saveInternalResponseTask();
        }
    }

    async savePsiTask() {
        // Validate all required fields
        if (!this.validatePendingInfoFields()) {
            return;
        }

        this.showSpinner = true;

        try {
            const result = await createPsiTask({
                taskObj: this.task,
                whatId: this.caseId
            });

            this.showSpinner = false;

            if (result === 'Duplicate Task Found') {
                this.showToast('Error', `Please Complete Open ${this.task.Subject} Task`, 'error');
            } else if (result === 'Task Created') {
                this.showToast('Success', `${this.task.Subject} Task Was Created.`, 'success');
                this.showTaskCreatePopUpPI = false;
                this.refreshView();
            }
        } catch (error) {
            this.showSpinner = false;
            this.showToast('Error', error.body?.message || 'Error creating task', 'error');
        }
    }

    async saveInternalResponseTask() {
        // Complex validation for internal response task
        if (!this.validateInternalResponseFields()) {
            return;
        }

        // Set OwnerId if user is selected
        if (this.selectedLookUpRecord && this.selectedLookUpRecord.Id) {
            this.task = { ...this.task, OwnerId: this.selectedLookUpRecord.Id };
        } else {
            this.task = { ...this.task, OwnerId: null };
        }

        this.showSpinner = true;

        try {
            await createObtainInternalRespoTask({
                taskObj: this.task,
                whatId: this.caseId,
                sfdcTeam: this.salesforceTeamUserValue
            });

            this.showSpinner = false;
            this.showToast('Success', `${this.task.Subject} Task Was Created.`, 'success');
            this.showTaskCreatePopUpPI = false;
            this.selectedLookUpRecord = {};
            this.task = {};
            this.disabledTeamUser = false;
            this.disabledAcornTeam = false;
            this.salesforceTeamUserValue = '';
            this.refreshView();
        } catch (error) {
            this.showSpinner = false;
            this.showToast('Error', error.body?.message || 'Error creating task', 'error');
            this.showTaskCreatePopUpPI = false;
        }
    }

    validatePendingInfoFields() {
        const allInputs = this.template.querySelectorAll('[data-field="required"]');
        let allValid = true;

        allInputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                allValid = false;
            }
        });

        if (!allValid) {
            this.showToast('Error', 'Please Fill All The Required Fields', 'error');
            return false;
        }

        // Validate due date is in future
        if (this.task.Due_Date_Time__c) {
            const dueDateTime = new Date(this.task.Due_Date_Time__c);
            const currentDateTime = new Date();

            if (dueDateTime <= currentDateTime) {
                this.showToast('Error', 'Please Select a Future Due date Time', 'error');
                return false;
            }
        }

        return true;
    }

    validateInternalResponseFields() {
        // Validation 1: Task type
        if (!this.task.Subject) {
            this.showToast('Error', 'Please Select Task Type', 'error');
            return false;
        }

        // Validation 2: Comment
        if (!this.task.Description) {
            this.showToast('Error', 'Please Fill Comment', 'error');
            return false;
        }

        // Validation 3: Assigned to user and tracking number
        if (this.selectedLookUpRecord &&
            this.selectedLookUpRecord.Id &&
            !this.isTaskUser &&
            !this.caseTrackingNumber) {
            this.showToast('Error', 'An Acorn Ticket Number is required to assign a Task to a Non SFDC user', 'error');
            return false;
        }

        // Validation 4: SFDC Team User
        if (this.sfdcTeamValue &&
            this.sfdcTeamValue.length > 0 &&
            (!this.salesforceTeamUserValue || this.salesforceTeamUserValue.length === 0)) {
            this.showToast('Error', 'Please select SFDC Team User', 'error');
            return false;
        }

        // Validation 5: Assign To User OR SFDC Team User for case with no tracking number
        if (!this.salesforceTeamUserValue &&
            !this.selectedLookUpRecord.Id &&
            !this.caseTrackingNumber) {
            this.showToast('Error', 'Please select a Assign To User Or SFDC Team User', 'error');
            return false;
        }

        // Validation 6: All three options for case with tracking number
        if (!this.task.Task_Team_Name__c &&
            !this.salesforceTeamUserValue &&
            !this.selectedLookUpRecord.Id &&
            this.caseTrackingNumber) {
            this.showToast('Error', 'Please select a Assign To User Or Acorn Team and Queue or SFDC Team User', 'error');
            return false;
        }

        // Validation 7: Team Queue
        if (this.task.Task_Team_Name__c &&
            (!this.task.Task_Team_Queue__c || this.task.Task_Team_Queue__c.length === 0)) {
            this.showToast('Error', 'Team Queue is Mandatory.', 'error');
            return false;
        }

        return true;
    }

    async checkAssignedToUser() {
        try {
            const isSfdcTaskUser = await checkUserIsTaskUser({
                userCatCode: this.selectedLookUpRecord.User_categorization_code__c
            });

            if (!isSfdcTaskUser) {
                this.isTaskUser = false;
                this.showToast('Error', 'An Acorn Ticket Number is required to assign a Task to a Non SFDC user', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error checking user', 'error');
        }
    }

    // Helper Methods
    enableSfdcTeam() {
        this.disabledSfdcTeam = false;
    }

    disableSfdcTeam() {
        this.disabledSfdcTeam = true;
    }

    enableAcornTeam() {
        this.disabledAcornTeam = false;
    }

    disableAcornTeam() {
        this.disabledAcornTeam = true;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'pester'
        });
        this.dispatchEvent(event);
    }

    refreshView() {
        // Dispatch custom event to refresh parent
        this.dispatchEvent(new CustomEvent('refresh'));

        // Use eval to refresh the view (LWC equivalent of $A.get('e.force:refreshView').fire())
        eval("$A.get('e.force:refreshView').fire();");
    }
}

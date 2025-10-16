/*
Developer: Jatan Sharma
Date: 10/10/2025
Description: This class is used to send email with template and related record from flow.
Current used in : Haul Away Automate Follow Up Approval Attempts Email Flow
*/
public with sharing class EmailService {
    public class EmailInput {
        @InvocableVariable(required=true)
        public Id templateId; //Store Email Template ID
        @InvocableVariable(required=true)
        public Id relatedRecordId; //Store Related Record ID
        @InvocableVariable(required=true)
        public Id senderEmail;//Store Sender Email ID or Org wide email ID
        @InvocableVariable(required=true)
        public String recipientEmail;//Store Recipient Emails
    }


    @InvocableMethod(label='Send Email with Template' description='Sends an email using a specified template' category='Email')
    public static void sendEmail(List<EmailInput> inputs) {
        List<Contact> lContacts = [Select Id from Contact Limit 1];
        Contact objContact = new Contact();
            if(!lContacts.isEmpty())
            {
                objContact = lContacts[0];
            }
            else 
            {
                objContact.LastName = 'Test Email Contact';
                objContact.Email = 'donotreply@ccemail.com';
                insert objContact;
            }
        for (EmailInput input : inputs) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(input.templateId);
            email.setTargetObjectId(objContact.Id);
            email.setOrgWideEmailAddressId(input.senderEmail);
            email.setWhatId(input.relatedRecordId);
            email.setTreatTargetObjectAsRecipient(false);
            email.setBccSender(false);
            email.setUseSignature(false);
            email.setSaveAsActivity(True);  
            email.setToAddresses(convertRecipientEmailToList(input.recipientEmail));
            system.debug('email '+email);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
        }
    }

    public static list<string> convertRecipientEmailToList(string recipientEmail){
        list<string> recipientEmailList = new list<string>();
        if(recipientEmail!=null && recipientEmail!=''){
            recipientEmailList = recipientEmail.split(';');
        }
        return recipientEmailList;
    }
    
}
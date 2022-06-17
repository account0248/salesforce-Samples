trigger DuplicateRegistrationValidation on ReceiptJournal__c(before insert, before update) {
    List<ReceiptJournal__c> existRecordList = [SELECT ReceiptDate__c, Ruby__c FROM ReceiptJournal__c];
    for(ReceiptJournal__c inputRecord : Trigger.New){
        for(ReceiptJournal__c existRecord : existRecordList){
            if((inputRecord.ReceiptDate__c + inputRecord.Ruby__c) == (existRecord.ReceiptDate__c + existRecord.Ruby__c)){
                inputRecord.addError(Schema.SObjectType.ReceiptJournal__c.fields.ReceiptDate__c.label + 'と' + Schema.SObjectType.ReceiptJournal__c.fields.Ruby__c.label + 'の組み合わせが、既存の情報と重複しています。');
            }
        }
    }
}
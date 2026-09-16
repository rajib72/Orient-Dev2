public with sharing class ctrl_BTLQuestionScreenController {

    @AuraEnabled(cacheable=true)
    public static List<ActivityWrapper> getActivities(String searchKey) {
        String key = '%' + String.escapeSingleQuotes(searchKey == null ? '' : searchKey.trim()) + '%';

        List<ActivityWrapper> result = new List<ActivityWrapper>();

        for (BTL_Activities__c act : [
            SELECT Id, Name, Activity_Type__c, Sr_No__c
            FROM BTL_Activities__c
            WHERE (Activity_Type__c LIKE :key AND Active__c = true)
            ORDER BY Sr_No__c ASC
            LIMIT 100
        ]) {
            result.add(new ActivityWrapper(act.Id, act.Activity_Type__c));
        }

        return result;
    }
    
    /** FROM QUESTIONS DIRECT **/
    
    /* @AuraEnabled(cacheable=true)
    public static List<QuestionWrapper> getQuestionsByActivities(List<Id> activityIds) {
        List<QuestionWrapper> result = new List<QuestionWrapper>();

        if (activityIds == null || activityIds.isEmpty()) {
            return result;
        }

        for (BTL_Questions__c ques : [
            SELECT Id, Name, BTL_Activities__c, Answer_Type__c, BTL_Activities__r.Activity_Type__c, Question__c
            FROM BTL_Questions__c
            WHERE BTL_Activities__c IN :activityIds
            ORDER BY BTL_Activities__r.Name, CreatedDate ASC
        ]) {
            QuestionWrapper qw = new QuestionWrapper();
            
            qw.questionId = ques.Id;
            qw.questionName = ques.Question__c;
            qw.activityId = ques.BTL_Activities__c;
            qw.activityName = ques.BTL_Activities__r.Activity_Type__c;
            qw.answerType = ques.Answer_Type__c;
            result.add(qw);
        }

        return result;
    } */
    
    /** FROM QUESTIONS DIRECT **/
    
    /** FROM ACTIVITY WISE QUESTIONS **/
    
    @AuraEnabled(cacheable=true)
    public static List<QuestionWrapper> getQuestionsByActivities(List<Id> activityIds) {
    
        List<QuestionWrapper> result = new List<QuestionWrapper>();
    
        if (activityIds == null || activityIds.isEmpty()) {
            return result;
        }
    
        List<Activity_Wise_Question__c> awqList = [
            SELECT Id,
                   BTL_Activity__c,
                   BTL_Activity__r.Name,
                   BTL_Activity__r.Activity_Type__c,
                   BTL_Question__c,
                   BTL_Question__r.Question__c,
                   BTL_Question__r.Answer_Type__c,
                   Category__c,
                   Question__c
            FROM Activity_Wise_Question__c
            WHERE BTL_Activity__c IN :activityIds
            ORDER BY BTL_Activity__r.Name, CreatedDate ASC
        ];
    
        for (Activity_Wise_Question__c awq : awqList) {
    
            QuestionWrapper qw = new QuestionWrapper();
    
            /*
             * Important:
             * questionId is now junction record Id.
             * Because delete/remove is only from UI list, not actual delete.
             */
            qw.questionId = awq.Id;
    
            /*
             * Actual BTL Question Id, useful for save later.
             */
            qw.btlQuestionId = awq.BTL_Question__c;
    
            qw.activityId = awq.BTL_Activity__c;
            //qw.activityName = awq.BTL_Activity__r != null ? awq.BTL_Activity__r.Activity_Type__c : awq.Category__c;
            
            qw.activityName = awq.BTL_Activity__r != null && String.isNotBlank(awq.BTL_Activity__r.Activity_Type__c)
                ? awq.BTL_Activity__r.Activity_Type__c
                : awq.Category__c;
    
            /*
             * Question text will come from Activity_Wise_Question__c.Question__c.
             * If blank, fallback to BTL_Question__r.Name.
             */
            qw.questionName = String.isNotBlank(awq.Question__c)
                ? awq.Question__c
                : (awq.BTL_Question__r != null ? awq.BTL_Question__r.Question__c : '');
    
            qw.answerType = awq.BTL_Question__r != null
                ? awq.BTL_Question__r.Answer_Type__c
                : '';
    
            qw.category = awq.Category__c;
    
            result.add(qw);
        }
    
        return result;
    }
    
    /** FROM ACTIVITY WISE QUESTIONS **/

    /** SAVE LOGIC **/

    @AuraEnabled
    public static Id saveFinalCustomizeForm(String formName, List<FinalQuestionSaveWrapper> questionList) {

        if (String.isBlank(formName)) {
            throw new AuraHandledException('Form Name is required.');
        }

        if (questionList == null || questionList.isEmpty()) {
            throw new AuraHandledException('Minimum one question is required.');
        }

        Final_Customize_Form__c parentForm = new Final_Customize_Form__c();
        parentForm.Form_Name__c = formName;
        parentForm.Active__c = true;

        insert parentForm;

        List<Final_Customize_Form_Line_Item__c> lineItems = new List<Final_Customize_Form_Line_Item__c>();
        Set<Integer> usedSerialNumbers = new Set<Integer>();

        for (FinalQuestionSaveWrapper item : questionList) {

            System.debug('SAVE WRAPPER ITEM ===> ' + JSON.serialize(item));

            Final_Customize_Form_Line_Item__c line = new Final_Customize_Form_Line_Item__c();

            line.Final_Customize_Form__c = parentForm.Id;

            if (String.isNotBlank(item.activityId)) {
                line.BTL_Activities__c = item.activityId;
            }

            if (String.isNotBlank(item.btlQuestionId)) {
                line.BTL_Questions__c = item.btlQuestionId;
            }

            if (String.isNotBlank(item.activityWiseQuestionId)) {
                line.Activity_Wise_Question__c = item.activityWiseQuestionId;
            }

            if (String.isNotBlank(item.questionName)) {
                line.Question__c = item.questionName;
            }

            line.Mandatory__c = item.isRequired == true;

            if (item.serialNo == null || item.serialNo <= 0) {
                throw new AuraHandledException(
                    'A valid serial number is required for every question.'
                );
            }

            if (usedSerialNumbers.contains(item.serialNo)) {
                throw new AuraHandledException(
                    'Duplicate serial number found: ' + item.serialNo
                );
            }

            usedSerialNumbers.add(item.serialNo);

            line.Sl_No__c = item.serialNo;

            lineItems.add(line);
        }

        if (!lineItems.isEmpty()) {
            insert lineItems;
        }

        return parentForm.Id;
    }

    /** SAVE LOGIC **/

    public class ActivityWrapper {
        @AuraEnabled public Id activityId { get; set; }
        @AuraEnabled public String activityName { get; set; }

        public ActivityWrapper(Id activityId, String activityName) {
            this.activityId = activityId;
            this.activityName = activityName;
        }
    }

    public class FinalQuestionSaveWrapper {
        @AuraEnabled public String activityId { get; set; }
        @AuraEnabled public String btlQuestionId { get; set; }
        @AuraEnabled public String activityWiseQuestionId { get; set; }
        @AuraEnabled public String questionName { get; set; }
        @AuraEnabled public String answerType { get; set; }
        @AuraEnabled public String activityName { get; set; }
        @AuraEnabled public Boolean isRequired { get; set; }
        @AuraEnabled public Integer serialNo { get; set; }
    }
    
    public class QuestionWrapper {
        @AuraEnabled public Id questionId { get; set; }
        @AuraEnabled public Id btlQuestionId { get; set; }
        @AuraEnabled public String questionName { get; set; }
        @AuraEnabled public Id activityId { get; set; }
        @AuraEnabled public String activityName { get; set; }
        @AuraEnabled public String answerType { get; set; }
        @AuraEnabled public String category { get; set; }
    }
}
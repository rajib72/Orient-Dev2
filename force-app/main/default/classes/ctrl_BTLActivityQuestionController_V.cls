/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_BTLActivityQuestionController_V
 * Author          : <Amit>
 * Created Date    : May 22, 2026
 * Last Modified By: <Amit>
 * Last Modified On: May 22, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 22, 2026  │ <Amit>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ctrl_BTLActivityQuestionController_V {

    public class QuestionWrapper {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public String category;
        @AuraEnabled public Boolean isSelected;
        @AuraEnabled public Id junctionId;
    }

    @AuraEnabled
    public static List<QuestionWrapper> getQuestionsForActivity(Id activityId) {
        if (activityId == null) {
            throw new AuraHandledException('Activity Id is missing.');
        }

        Map<Id, Activity_Wise_Question__c> existingQuestionMap = new Map<Id, Activity_Wise_Question__c>();

        for (Activity_Wise_Question__c awq : [
            SELECT Id, BTL_Activity__c, BTL_Question__c, Question__c
            FROM Activity_Wise_Question__c
            WHERE BTL_Activity__c = :activityId
            AND BTL_Question__c != null
        ]) {
            existingQuestionMap.put(awq.BTL_Question__c, awq);
        }

        List<QuestionWrapper> finalList = new List<QuestionWrapper>();

        for (BTL_Questions__c ques : [
            SELECT Id, Question__c, Category__c
            FROM BTL_Questions__c
            ORDER BY CreatedDate DESC
        ]) {
            // Question__c is Long Text Area, so blank check is done in Apex.
            if (String.isBlank(ques.Question__c)) {
                continue;
            }

            QuestionWrapper wrap = new QuestionWrapper();
            wrap.questionId = ques.Id;
            wrap.questionText = ques.Question__c;
            wrap.category = ques.Category__c;

            if (existingQuestionMap.containsKey(ques.Id)) {
                wrap.isSelected = true;
                wrap.junctionId = existingQuestionMap.get(ques.Id).Id;
            } else {
                wrap.isSelected = false;
                wrap.junctionId = null;
            }

            finalList.add(wrap);
        }

        return finalList;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getQuestionCategories() {
        List<String> categories = new List<String>();

        Schema.DescribeFieldResult fieldResult = BTL_Questions__c.Category__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                categories.add(entry.getLabel());
            }
        }

        return categories;
    }

    @AuraEnabled
    public static String saveActivityQuestions(Id activityId, List<Id> selectedQuestionIds) {
        if (activityId == null) {
            throw new AuraHandledException('Activity Id is missing.');
        }

        if (selectedQuestionIds == null) {
            selectedQuestionIds = new List<Id>();
        }

        Set<Id> selectedQuestionSet = new Set<Id>(selectedQuestionIds);

        List<Activity_Wise_Question__c> existingJunctions = [
            SELECT Id, BTL_Activity__c, BTL_Question__c, Question__c
            FROM Activity_Wise_Question__c
            WHERE BTL_Activity__c = :activityId
        ];

        Set<Id> existingQuestionIds = new Set<Id>();
        List<Activity_Wise_Question__c> junctionsToDelete = new List<Activity_Wise_Question__c>();

        for (Activity_Wise_Question__c junctionRec : existingJunctions) {
            existingQuestionIds.add(junctionRec.BTL_Question__c);

            if (!selectedQuestionSet.contains(junctionRec.BTL_Question__c)) {
                junctionsToDelete.add(junctionRec);
            }
        }

        Map<Id, BTL_Questions__c> questionMap = new Map<Id, BTL_Questions__c>();

        if (!selectedQuestionSet.isEmpty()) {
            questionMap = new Map<Id, BTL_Questions__c>([
                SELECT Id, Question__c, Category__c
                FROM BTL_Questions__c
                WHERE Id IN :selectedQuestionSet
            ]);
        }

        List<Activity_Wise_Question__c> junctionsToInsert = new List<Activity_Wise_Question__c>();

        for (Id questionId : selectedQuestionSet) {
            if (!existingQuestionIds.contains(questionId)) {
                BTL_Questions__c questionRec = questionMap.get(questionId);

                if (questionRec == null) {
                    continue;
                }

                Activity_Wise_Question__c newJunction = new Activity_Wise_Question__c();
                newJunction.BTL_Activity__c = activityId;
                newJunction.BTL_Question__c = questionId;
                newJunction.Question__c = questionRec.Question__c;

                // Remove this line if Activity_Wise_Question__c.Category__c is not created.
                newJunction.Category__c = questionRec.Category__c;

                junctionsToInsert.add(newJunction);
            }
        }

        if (!junctionsToDelete.isEmpty()) {
            delete junctionsToDelete;
        }

        if (!junctionsToInsert.isEmpty()) {
            insert junctionsToInsert;
        }

        return 'Questions saved successfully.';
    }
}
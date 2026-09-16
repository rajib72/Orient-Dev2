/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_BTLActivityQuestionController
 * Author          : <Amit Banerjee>
 * Created Date    : May 21, 2026
 * Last Modified By: Amit Banerjee
 * Last Modified On: May 21, 2026
 * Description     : This class implements for add questions from BTL Question object to Activity wise question object
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 21, 2026  │ <Amit Banerjee>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ctrl_BTLActivityQuestionController {

    public class QuestionWrapper {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public Boolean isSelected;
        @AuraEnabled public Id junctionId;
    }

    @AuraEnabled(cacheable=true)
    public static List<QuestionWrapper> getQuestionsForActivity(Id activityId) {
        if (activityId == null) {
            throw new AuraHandledException('Activity Id is missing.');
        }

        List<QuestionWrapper> finalList = new List<QuestionWrapper>();

        Map<Id, Activity_Wise_Question__c> existingQuestionMap = new Map<Id, Activity_Wise_Question__c>();

        for (Activity_Wise_Question__c awq : [
            SELECT Id, BTL_Activity__c, BTL_Question__c, Question__c
            FROM Activity_Wise_Question__c
            WHERE BTL_Activity__c = :activityId
            AND BTL_Question__c != null
        ]) {
            existingQuestionMap.put(awq.BTL_Question__c, awq);
        }

        for (BTL_Questions__c ques : [
            SELECT Id, Question__c
            FROM BTL_Questions__c
            ORDER BY CreatedDate DESC
        ]) {

			// Long Text Area cannot be filtered in SOQL,
            // so blank check is done in Apex.
            if (String.isBlank(ques.Question__c)) {
                continue;
            }

            QuestionWrapper wrap = new QuestionWrapper();
            wrap.questionId = ques.Id;
            wrap.questionText = ques.Question__c;

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
                SELECT Id, Question__c
                FROM BTL_Questions__c
                WHERE Id IN :selectedQuestionSet
            ]);
        }

        List<Activity_Wise_Question__c> junctionsToInsert = new List<Activity_Wise_Question__c>();

        for (Id questionId : selectedQuestionSet) {
            if (!existingQuestionIds.contains(questionId)) {

				BTL_Questions__c questionRec = questionMap.get(questionId);

                Activity_Wise_Question__c newJunction = new Activity_Wise_Question__c();
                newJunction.BTL_Activity__c = activityId;
                newJunction.BTL_Question__c = questionId;

				
                if (questionRec != null) {
                    newJunction.Question__c = questionRec.Question__c;
                }

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
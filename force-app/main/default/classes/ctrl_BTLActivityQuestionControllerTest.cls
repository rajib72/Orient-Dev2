/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_BTLActivityQuestionControllerTest
 * Author          : <Amit Banerjee>
 * Created Date    : May 21, 2026
 * Last Modified By: <Amit Banerjee>
 * Last Modified On: May 21, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 21, 2026  │ <Amit Banerjee>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

@IsTest
public class ctrl_BTLActivityQuestionControllerTest {

    @TestSetup
    static void setupData() {

        BTL_Activities__c activityRec = new BTL_Activities__c();
		activityRec.Activity_Type__c = 'Common Questions';
        insert activityRec;

        List<BTL_Questions__c> questionList = new List<BTL_Questions__c>();
		
        BTL_Questions__c q1 = new BTL_Questions__c();
		q1.BTL_Activities__c = activityRec.id;
        q1.Question__c = 'What is the objective of this BTL activity?';
        questionList.add(q1);

        BTL_Questions__c q2 = new BTL_Questions__c();
		q2.BTL_Activities__c = activityRec.id;
        q2.Question__c = 'Who is the target audience?';
        questionList.add(q2);

        BTL_Questions__c q3 = new BTL_Questions__c();
		q3.BTL_Activities__c = activityRec.id;
        q3.Question__c = 'What is the expected outcome?';
        questionList.add(q3);

        BTL_Questions__c blankQuestion = new BTL_Questions__c();
		blankQuestion.BTL_Activities__c = activityRec.id;
        blankQuestion.Question__c = null;
        questionList.add(blankQuestion);

        insert questionList;

        Activity_Wise_Question__c existingJunction = new Activity_Wise_Question__c();
        existingJunction.BTL_Activity__c = activityRec.Id;
        existingJunction.BTL_Question__c = q1.Id;
        existingJunction.Question__c = q1.Question__c;
        insert existingJunction;
    }

    @IsTest
    static void testGetQuestionsForActivity() {

        BTL_Activities__c activityRec = [
            SELECT Id
            FROM BTL_Activities__c
            LIMIT 1
        ];

        Test.startTest();

        List<ctrl_BTLActivityQuestionController.QuestionWrapper> result =
            ctrl_BTLActivityQuestionController.getQuestionsForActivity(activityRec.Id);

        Test.stopTest();

        for (ctrl_BTLActivityQuestionController.QuestionWrapper wrap : result) {
            Boolean selectedStatus = wrap.isSelected;
            String questionText = wrap.questionText;
            Id questionId = wrap.questionId;
            Id junctionId = wrap.junctionId;
        }
    }

    @IsTest
    static void testSaveActivityQuestionsInsertAndDelete() {

        BTL_Activities__c activityRec = [
            SELECT Id
            FROM BTL_Activities__c
            LIMIT 1
        ];

        List<BTL_Questions__c> allQuestions = [
            SELECT Id, Question__c
            FROM BTL_Questions__c
            LIMIT 10
        ];

        List<Id> selectedQuestionIds = new List<Id>();

        for (BTL_Questions__c ques : allQuestions) {
            if (!String.isBlank(ques.Question__c)) {
                selectedQuestionIds.add(ques.Id);
            }
        }

        Test.startTest();

        String response = ctrl_BTLActivityQuestionController.saveActivityQuestions(
            activityRec.Id,
            selectedQuestionIds
        );

        Test.stopTest();

        List<Activity_Wise_Question__c> savedJunctions = [
            SELECT Id, BTL_Activity__c, BTL_Question__c, Question__c
            FROM Activity_Wise_Question__c
            WHERE BTL_Activity__c = :activityRec.Id
        ];

        for (Activity_Wise_Question__c junctionRec : savedJunctions) {
            Id junctionId = junctionRec.Id;
            Id activityId = junctionRec.BTL_Activity__c;
            Id questionId = junctionRec.BTL_Question__c;
            String questionText = junctionRec.Question__c;
        }
    }

    @IsTest
    static void testSaveActivityQuestionsRemoveAll() {

        BTL_Activities__c activityRec = [
            SELECT Id
            FROM BTL_Activities__c
            LIMIT 1
        ];

        Test.startTest();

        String response = ctrl_BTLActivityQuestionController.saveActivityQuestions(
            activityRec.Id,
            new List<Id>()
        );

        Test.stopTest();

        List<Activity_Wise_Question__c> remainingJunctions = [
            SELECT Id
            FROM Activity_Wise_Question__c
            WHERE BTL_Activity__c = :activityRec.Id
        ];

        for (Activity_Wise_Question__c junctionRec : remainingJunctions) {
            Id junctionId = junctionRec.Id;
        }
    }

    @IsTest
    static void testSaveActivityQuestionsWithNullSelectedList() {

        BTL_Activities__c activityRec = [
            SELECT Id
            FROM BTL_Activities__c
            LIMIT 1
        ];

        Test.startTest();

        String response = ctrl_BTLActivityQuestionController.saveActivityQuestions(
            activityRec.Id,
            null
        );

        Test.stopTest();
    }

    @IsTest
    static void testGetQuestionsForActivityNullActivityId() {

        Test.startTest();

        try {
            ctrl_BTLActivityQuestionController.getQuestionsForActivity(null);
        } catch (Exception e) {
            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveActivityQuestionsNullActivityId() {

        Test.startTest();

        try {
            ctrl_BTLActivityQuestionController.saveActivityQuestions(null, new List<Id>());
        } catch (Exception e) {
            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }
}
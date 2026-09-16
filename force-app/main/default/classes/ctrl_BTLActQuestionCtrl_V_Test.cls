@IsTest
public class ctrl_BTLActQuestionCtrl_V_Test {


    @TestSetup
    static void setupData() {

        BTL_Activities__c activityRec = new BTL_Activities__c(
         //   Name = 'Test Activity'
        );
        insert activityRec;

        List<BTL_Questions__c> questionList = new List<BTL_Questions__c>();

        BTL_Questions__c q1 = new BTL_Questions__c();
        q1.BTL_Activities__c = activityRec.Id;
        q1.Question__c = 'What is Question 1?';
        q1.Category__c = 'Common Questions';
        questionList.add(q1);

        BTL_Questions__c q2 = new BTL_Questions__c();
        q2.BTL_Activities__c = activityRec.Id;
        q2.Question__c = 'What is Question 2?';
        q2.Category__c = 'Apartment & Society Activities';
        questionList.add(q2);

        BTL_Questions__c q3 = new BTL_Questions__c();
        q3.BTL_Activities__c = activityRec.Id;
        q3.Question__c = 'What is Question 3?';
        q3.Category__c = 'Bridal Activities';
        questionList.add(q3);

        BTL_Questions__c blankQuestion = new BTL_Questions__c();
        blankQuestion.BTL_Activities__c = activityRec.Id;
        blankQuestion.Question__c = null;
        blankQuestion.Category__c = 'Club Culture Activities';
        questionList.add(blankQuestion);

        insert questionList;

        Activity_Wise_Question__c existingJunction = new Activity_Wise_Question__c();
        existingJunction.BTL_Activity__c = activityRec.Id;
        existingJunction.BTL_Question__c = q1.Id;
        existingJunction.Question__c = q1.Question__c;
        existingJunction.Category__c = q1.Category__c;

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

        List<ctrl_BTLActivityQuestionController_V.QuestionWrapper> result =
            ctrl_BTLActivityQuestionController_V.getQuestionsForActivity(
                activityRec.Id
            );

        Test.stopTest();

        for (ctrl_BTLActivityQuestionController_V.QuestionWrapper wrap : result) {

            Id questionId = wrap.questionId;
            String questionText = wrap.questionText;
            String category = wrap.category;
            Boolean selectedStatus = wrap.isSelected;
            Id junctionId = wrap.junctionId;
        }
    }

    @IsTest
    static void testGetQuestionCategories() {

        Test.startTest();

        List<String> categories =
            ctrl_BTLActivityQuestionController_V.getQuestionCategories();

        Test.stopTest();

        for (String category : categories) {
            String categoryName = category;
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
            SELECT Id, Question__c, Category__c
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

        String response =
            ctrl_BTLActivityQuestionController_V.saveActivityQuestions(
                activityRec.Id,
                selectedQuestionIds
            );

        Test.stopTest();

        List<Activity_Wise_Question__c> savedJunctions = [
            SELECT Id,
                   BTL_Activity__c,
                   BTL_Question__c,
                   Question__c,
                   Category__c
            FROM Activity_Wise_Question__c
            WHERE BTL_Activity__c = :activityRec.Id
        ];

        for (Activity_Wise_Question__c junctionRec : savedJunctions) {

            Id junctionId = junctionRec.Id;
            Id activityId = junctionRec.BTL_Activity__c;
            Id questionId = junctionRec.BTL_Question__c;
            String questionText = junctionRec.Question__c;
            String category = junctionRec.Category__c;
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

        String response =
            ctrl_BTLActivityQuestionController_V.saveActivityQuestions(
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

        String response =
            ctrl_BTLActivityQuestionController_V.saveActivityQuestions(
                activityRec.Id,
                null
            );

        Test.stopTest();
    }

    @IsTest
    static void testGetQuestionsForActivityNullActivityId() {

        Test.startTest();

        try {

            ctrl_BTLActivityQuestionController_V.getQuestionsForActivity(null);

        } catch (Exception e) {

            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveActivityQuestionsNullActivityId() {

        Test.startTest();

        try {

            ctrl_BTLActivityQuestionController_V.saveActivityQuestions(
                null,
                new List<Id>()
            );

        } catch (Exception e) {

            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }
}
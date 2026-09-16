@IsTest
public class ctrl_BTLQuestionScreenController_Test {

    @TestSetup
    static void setupData() {

        BTL_Activities__c activityRec = new BTL_Activities__c();
  //      activityRec.Name = 'Test Activity';
        activityRec.Activity_Type__c = 'Common Questions';
        activityRec.Active__c = true;
        activityRec.Sr_No__c = 1;
        insert activityRec;

        List<BTL_Questions__c> questionList = new List<BTL_Questions__c>();

        BTL_Questions__c q1 = new BTL_Questions__c();
        q1.BTL_Activities__c = activityRec.Id;
        q1.Question__c = 'Question 1';
        q1.Answer_Type__c = 'Alphanumaric';
        q1.Category__c = 'Common Questions';
        questionList.add(q1);

        BTL_Questions__c q2 = new BTL_Questions__c();
        q2.BTL_Activities__c = activityRec.Id;
        q2.Question__c = 'Question 2';
        q2.Answer_Type__c = 'Picklist';
        q2.Category__c = 'Festival Activities';
        questionList.add(q2);

        insert questionList;

        List<Activity_Wise_Question__c> awqList =
            new List<Activity_Wise_Question__c>();

        Activity_Wise_Question__c awq1 =
            new Activity_Wise_Question__c();

        awq1.BTL_Activity__c = activityRec.Id;
        awq1.BTL_Question__c = q1.Id;
        awq1.Question__c = q1.Question__c;
        awq1.Category__c = q1.Category__c;

        awqList.add(awq1);

        Activity_Wise_Question__c awq2 =
            new Activity_Wise_Question__c();

        awq2.BTL_Activity__c = activityRec.Id;
        awq2.BTL_Question__c = q2.Id;
        awq2.Question__c = q2.Question__c;
        awq2.Category__c = q2.Category__c;

        awqList.add(awq2);

        insert awqList;
    }

    @IsTest
    static void testGetActivities() {

        Test.startTest();

        List<ctrl_BTLQuestionScreenController.ActivityWrapper> result =
            ctrl_BTLQuestionScreenController.getActivities('Common');

        Test.stopTest();

        for (
            ctrl_BTLQuestionScreenController.ActivityWrapper wrap
            : result
        ) {

            Id activityId = wrap.activityId;
            String activityName = wrap.activityName;
        }
    }

    @IsTest
    static void testGetQuestionsByActivities() {

        BTL_Activities__c activityRec = [
            SELECT Id
            FROM BTL_Activities__c
            LIMIT 1
        ];

        List<Id> activityIds = new List<Id>();
        activityIds.add(activityRec.Id);

        Test.startTest();

        List<ctrl_BTLQuestionScreenController.QuestionWrapper> result =
            ctrl_BTLQuestionScreenController.getQuestionsByActivities(
                activityIds
            );

        Test.stopTest();

        for (
            ctrl_BTLQuestionScreenController.QuestionWrapper wrap
            : result
        ) {

            Id questionId = wrap.questionId;
            Id btlQuestionId = wrap.btlQuestionId;
            String questionName = wrap.questionName;
            Id activityId = wrap.activityId;
            String activityName = wrap.activityName;
            String answerType = wrap.answerType;
            String category = wrap.category;
        }
    }

    @IsTest
    static void testGetQuestionsByActivitiesWithEmptyList() {

        Test.startTest();

        List<ctrl_BTLQuestionScreenController.QuestionWrapper> result =
            ctrl_BTLQuestionScreenController.getQuestionsByActivities(
                new List<Id>()
            );

        Test.stopTest();
    }

    @IsTest
    static void testSaveFinalCustomizeForm() {

        BTL_Activities__c activityRec = [
            SELECT Id
            FROM BTL_Activities__c
            LIMIT 1
        ];

        Activity_Wise_Question__c awq = [
            SELECT Id,
                   BTL_Question__c,
                   Question__c
            FROM Activity_Wise_Question__c
            LIMIT 1
        ];

        List<ctrl_BTLQuestionScreenController.FinalQuestionSaveWrapper>
            wrapperList =
                new List<
                    ctrl_BTLQuestionScreenController.FinalQuestionSaveWrapper
                >();

        ctrl_BTLQuestionScreenController.FinalQuestionSaveWrapper wrap =
            new ctrl_BTLQuestionScreenController.FinalQuestionSaveWrapper();

        wrap.activityId = activityRec.Id;
        wrap.btlQuestionId = awq.BTL_Question__c;
        wrap.activityWiseQuestionId = awq.Id;
        wrap.questionName = awq.Question__c;
        wrap.answerType = 'Alphanumaric';
        wrap.activityName = 'Common Questions';
        wrap.serialNo = 1001;

        wrapperList.add(wrap);

        Test.startTest();

        Id formId =
            ctrl_BTLQuestionScreenController.saveFinalCustomizeForm(
                'Test Form',
                wrapperList
            );

        Test.stopTest();

        Final_Customize_Form__c formRec = [
            SELECT Id,
                   Form_Name__c
            FROM Final_Customize_Form__c
            WHERE Id = :formId
            LIMIT 1
        ];

        List<Final_Customize_Form_Line_Item__c> lineItems = [
            SELECT Id,
                   Final_Customize_Form__c,
                   BTL_Activities__c,
                   BTL_Questions__c,
                   Activity_Wise_Question__c,
                   Question__c
            FROM Final_Customize_Form_Line_Item__c
            WHERE Final_Customize_Form__c = :formId
        ];

        for (Final_Customize_Form_Line_Item__c line : lineItems) {

            Id lineId = line.Id;
            Id parentId = line.Final_Customize_Form__c;
            Id activityId = line.BTL_Activities__c;
            Id questionId = line.BTL_Questions__c;
            Id awqId = line.Activity_Wise_Question__c;
            String questionText = line.Question__c;
        }
    }

    @IsTest
    static void testSaveFinalCustomizeFormBlankName() {

        List<ctrl_BTLQuestionScreenController.FinalQuestionSaveWrapper>
            wrapperList =
                new List<
                    ctrl_BTLQuestionScreenController.FinalQuestionSaveWrapper
                >();

        Test.startTest();

        try {

            ctrl_BTLQuestionScreenController.saveFinalCustomizeForm(
                '',
                wrapperList
            );

        } catch (Exception e) {

            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }

    @IsTest
    static void testSaveFinalCustomizeFormEmptyQuestions() {

        Test.startTest();

        try {

            ctrl_BTLQuestionScreenController.saveFinalCustomizeForm(
                'Test Form',
                new List<
                    ctrl_BTLQuestionScreenController.FinalQuestionSaveWrapper
                >()
            );

        } catch (Exception e) {

            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }
}
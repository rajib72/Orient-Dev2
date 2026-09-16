@IsTest
private class BTLAccountFieldSelectorController_Test {

    @TestSetup
    static void setupTestData() {
        BTL_Activities__c btl_activity = new BTL_Activities__c();
        btl_activity.Activity_Type__c = 'Digital BTL';
        insert btl_activity;
        
        BTL_Questions__c questionRecord = new BTL_Questions__c();

        /*
         * Set the Name only when it is a writable text field.
         * This supports both Text and Auto Number Name configurations.
         */
        Schema.DescribeFieldResult nameDescribe =
            BTL_Questions__c.Name.getDescribe();

        questionRecord.Customer_Field_Name__c = 'Name';
        questionRecord.BTL_Activities__c = btl_activity.Id;
        insert questionRecord;
    }

    @IsTest
    static void testGetAccountFieldOptions() {
        Test.startTest();

        List<BTLAccountFieldSelectorController.FieldOptionWrapper> options =
            BTLAccountFieldSelectorController.getAccountFieldOptions();

        Test.stopTest();

        System.assertNotEquals(
            null,
            options,
            'The method should return a list of Account fields.'
        );

        System.assert(
            !options.isEmpty(),
            'At least one accessible Account field should be returned.'
        );

        Boolean nameFieldFound = false;
        String previousLabel;

        for (
            BTLAccountFieldSelectorController.FieldOptionWrapper optionRecord :
            options
        ) {
            System.assertNotEquals(
                null,
                optionRecord.label,
                'Every option should have a label.'
            );

            System.assertNotEquals(
                null,
                optionRecord.value,
                'Every option should have a field API name.'
            );

            System.assertNotEquals(
                null,
                optionRecord.fieldType,
                'Every option should have a field type.'
            );

            if (optionRecord.value == 'Name') {
                nameFieldFound = true;

            }

            if (previousLabel != null) {
                System.assert(
                    previousLabel.toLowerCase()
                        .compareTo(optionRecord.label.toLowerCase()) <= 0,
                    'Account field options should be sorted alphabetically.'
                );
            }

            previousLabel = optionRecord.label;
        }

        System.assert(
            nameFieldFound,
            'The accessible Account Name field should be returned.'
        );
    }

    @IsTest
    static void testGetExistingCustomerFieldName() {
        BTL_Questions__c questionRecord = [
            SELECT Id, Customer_Field_Name__c
            FROM BTL_Questions__c
            LIMIT 1
        ];

        Test.startTest();

        String existingFieldName =
            BTLAccountFieldSelectorController.getExistingCustomerFieldName(questionRecord.Id);

        Test.stopTest();

        System.assertEquals(
            'Name',
            existingFieldName,
            'The saved Account field API name should be returned.'
        );
    }

    @IsTest
    static void testGetExistingCustomerFieldNameWithNullId() {
        Test.startTest();

        String existingFieldName =
            BTLAccountFieldSelectorController.getExistingCustomerFieldName(null);

        Test.stopTest();

        System.assertEquals(
            null,
            existingFieldName,
            'Null should be returned when the BTL Question Id is missing.'
        );
    }

    @IsTest
    static void testSaveCustomerFieldName() {
        BTL_Questions__c questionRecord = [
            SELECT Id, Customer_Field_Name__c
            FROM BTL_Questions__c
            LIMIT 1
        ];

        Test.startTest();

        BTLAccountFieldSelectorController.saveCustomerFieldName(
            questionRecord.Id,
            '  Phone  '
        );

        Test.stopTest();

        BTL_Questions__c updatedQuestion = [
            SELECT Customer_Field_Name__c
            FROM BTL_Questions__c
            WHERE Id = :questionRecord.Id
        ];

        System.assertEquals(
            'Phone',
            updatedQuestion.Customer_Field_Name__c,
            'The trimmed Account field API name should be saved.'
        );
    }

    @IsTest
    static void testSaveCustomerFieldNameWithNullQuestionId() {
        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            BTLAccountFieldSelectorController.saveCustomerFieldName(
                null,
                'Phone'
            );
        } catch (AuraHandledException exceptionRecord) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(
            exceptionThrown,
            'An exception should be thrown when the BTL Question Id is missing.'
        );
    }

    @IsTest
    static void testSaveCustomerFieldNameWithBlankField() {
        BTL_Questions__c questionRecord = [
            SELECT Id
            FROM BTL_Questions__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            BTLAccountFieldSelectorController.saveCustomerFieldName(
                questionRecord.Id,
                '   '
            );
        } catch (AuraHandledException exceptionRecord) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(
            exceptionThrown,
            'An exception should be thrown when no Account field is selected.'
        );
    }

    @IsTest
    static void testSaveCustomerFieldNameWithInvalidField() {
        BTL_Questions__c questionRecord = [
            SELECT Id
            FROM BTL_Questions__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            BTLAccountFieldSelectorController.saveCustomerFieldName(
                questionRecord.Id,
                'Invalid_Account_Field__c'
            );
        } catch (AuraHandledException exceptionRecord) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(
            exceptionThrown,
            'An exception should be thrown for an invalid Account field.'
        );
    }

    @IsTest
    static void testFieldOptionWrapperSorting() {
        BTLAccountFieldSelectorController.FieldOptionWrapper alphaOption =
            new BTLAccountFieldSelectorController.FieldOptionWrapper(
                'Alpha Field',
                'Alpha__c',
                'STRING'
            );

        BTLAccountFieldSelectorController.FieldOptionWrapper betaOption =
            new BTLAccountFieldSelectorController.FieldOptionWrapper(
                'Beta Field',
                'Beta__c',
                'STRING'
            );

        BTLAccountFieldSelectorController.FieldOptionWrapper nullOptionOne =
            new BTLAccountFieldSelectorController.FieldOptionWrapper(
                null,
                'Null_One__c',
                'STRING'
            );

        BTLAccountFieldSelectorController.FieldOptionWrapper nullOptionTwo =
            new BTLAccountFieldSelectorController.FieldOptionWrapper(
                null,
                'Null_Two__c',
                'STRING'
            );

        System.assert(
            alphaOption.compareTo(betaOption) < 0,
            'Alpha should be sorted before Beta.'
        );

        System.assert(
            betaOption.compareTo(alphaOption) > 0,
            'Beta should be sorted after Alpha.'
        );

        System.assertEquals(
            0,
            alphaOption.compareTo(alphaOption),
            'Identical labels should be equal.'
        );

        System.assert(
            nullOptionOne.compareTo(alphaOption) < 0,
            'A null label should be sorted before a populated label.'
        );

        System.assert(
            alphaOption.compareTo(nullOptionOne) > 0,
            'A populated label should be sorted after a null label.'
        );

        System.assertEquals(
            0,
            nullOptionOne.compareTo(nullOptionTwo),
            'Two null labels should be treated as equal.'
        );

        List<BTLAccountFieldSelectorController.FieldOptionWrapper> options =
            new List<BTLAccountFieldSelectorController.FieldOptionWrapper>{
                betaOption,
                alphaOption
            };

        options.sort();

        System.assertEquals(
            'Alpha__c',
            options[0].value,
            'Alpha should be the first option after sorting.'
        );

        System.assertEquals(
            'Beta__c',
            options[1].value,
            'Beta should be the second option after sorting.'
        );
    }
}
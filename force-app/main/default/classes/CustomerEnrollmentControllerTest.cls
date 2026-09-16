@isTest
private class CustomerEnrollmentControllerTest {

    @testSetup
    static void setupData() {

        // Existing Account for duplicate validation
        Account acc = new Account(
            Name = 'Existing Customer',
            Phone = '9999999999',
            Whatsapp_number__c = '8888888888',
            Status__c = 'Prospect'
        );
        insert acc;
    }

    @isTest
    static void testSaveCustomer_Success() {

        Map<String, Object> formData = new Map<String, Object>();

        formData.put('Name', 'Test Customer');
        formData.put('Phone', '7777777777');
        formData.put('Whatsapp_number__c', '6666666666');
        formData.put('Date_Of_Birth__c', '1995-05-20');
        formData.put('Status__c', 'Prospect');

        Test.startTest();
        CustomerEnrollmentController.saveCustomer(formData);
        Test.stopTest();
    }

    @isTest
    static void testSaveCustomer_DefaultStatus() {

        Map<String, Object> formData = new Map<String, Object>();

        formData.put('Name', 'Default Status Customer');
        formData.put('Phone', '5555555555');
        formData.put('Whatsapp_number__c', '4444444444');
        formData.put('Date_Of_Birth__c', '1990-01-01');

        Test.startTest();
        CustomerEnrollmentController.saveCustomer(formData);
        Test.stopTest();
    }

    @isTest
    static void testSaveCustomer_InvalidDOB() {

        Map<String, Object> formData = new Map<String, Object>();

        formData.put('Name', 'Invalid DOB');
        formData.put('Phone', '3333333333');
        formData.put('Whatsapp_number__c', '2222222222');
        formData.put('Date_Of_Birth__c', String.valueOf(Date.today()));

        Test.startTest();

        try {
            CustomerEnrollmentController.saveCustomer(formData);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveCustomer_InvalidDateFormat() {

        Map<String, Object> formData = new Map<String, Object>();

        formData.put('Name', 'Bad Date');
        formData.put('Phone', '1111111111');
        formData.put('Whatsapp_number__c', '0000000000');
        formData.put('Date_Of_Birth__c', '20-20-2020');

        Test.startTest();

        try {
            CustomerEnrollmentController.saveCustomer(formData);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveCustomer_DuplicatePhone() {

        Map<String, Object> formData = new Map<String, Object>();

        formData.put('Name', 'Duplicate Customer');
        formData.put('Phone', '9999999999');
        formData.put('Whatsapp_number__c', '1231231234');
        formData.put('Date_Of_Birth__c', '1992-02-02');

        Test.startTest();

        try {
            CustomerEnrollmentController.saveCustomer(formData);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveCustomer_DuplicateWhatsapp() {

        Map<String, Object> formData = new Map<String, Object>();

        formData.put('Name', 'Duplicate WhatsApp');
        formData.put('Phone', '1212121212');
        formData.put('Whatsapp_number__c', '8888888888');
        formData.put('Date_Of_Birth__c', '1993-03-03');

        Test.startTest();

        try {
            CustomerEnrollmentController.saveCustomer(formData);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testGetPicklistValues() {

        Test.startTest();
        CustomerEnrollmentController.getPicklistValues();
        Test.stopTest();
    }

    @isTest
    static void testUploadFile() {

        Account acc = new Account(
            Name = 'File Customer'
        );
        insert acc;

        String body = EncodingUtil.base64Encode(Blob.valueOf('Test File'));

        Test.startTest();

        CustomerEnrollmentController.uploadFile(
            acc.Id,
            'TestFile.txt',
            body
        );

        Test.stopTest();
    }

    @isTest
    static void testUploadFile_Exception() {

        Test.startTest();

        try {
            CustomerEnrollmentController.uploadFile(
                null,
                'BadFile.txt',
                'InvalidBase64'
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testGetActiveUsers() {

        Test.startTest();
        CustomerEnrollmentController.getActiveUsers();
        Test.stopTest();
    }
}
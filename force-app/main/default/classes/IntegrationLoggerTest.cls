@isTest
public class IntegrationLoggerTest {

    @isTest
    static void testLogError() {

        Test.startTest();

        IntegrationLogger.logError(
            'TestClass',
            'testMethod',
            25,
            500,
            'Sample error message',
            'REST API'
        );

        Test.stopTest();
    }

    @isTest
    static void testLogErrorWithLongMessage() {

        String longMessage = '';

        for(Integer i = 0; i < 40000; i++) {
            longMessage += 'A';
        }

        Test.startTest();

        IntegrationLogger.logError(
            'LongMessageClass',
            'longMethod',
            100,
            400,
            longMessage,
            'SOAP API'
        );

        Test.stopTest();
    }

    @isTest
    static void testLogErrorWithNullValues() {

        Test.startTest();

        IntegrationLogger.logError(
            null,
            null,
            null,
            null,
            null,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testLogErrorWithBlankMessage() {

        Test.startTest();

        IntegrationLogger.logError(
            'BlankClass',
            'blankMethod',
            10,
            200,
            '',
            'Test API'
        );

        Test.stopTest();
    }
}
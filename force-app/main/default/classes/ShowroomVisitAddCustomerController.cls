public with sharing class ShowroomVisitAddCustomerController {

    public class CustomerWrapper {
        @AuraEnabled public Id customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String phone;
    }

    @AuraEnabled(cacheable=true)
    public static List<CustomerWrapper> searchCustomersByPhone(String phoneNumber) {
        List<CustomerWrapper> resultList = new List<CustomerWrapper>();

        if (String.isBlank(phoneNumber) || phoneNumber.trim().length() < 3) {
            return resultList;
        }

        String searchKey = phoneNumber.trim() + '%';

        List<Account> accList = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone LIKE :searchKey
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        for (Account acc : accList) {
            CustomerWrapper wrap = new CustomerWrapper();
            wrap.customerId = acc.Id;
            wrap.customerName = acc.Name;
            wrap.phone = acc.Phone;
            resultList.add(wrap);
        }

        return resultList;
    }

    @AuraEnabled
    public static String addCustomerToShowroomVisit(
        Id showroomVisitId,
        String phoneNumber,
        String customerName,
        Id existingCustomerId
    ) {
        if (showroomVisitId == null) {
            throw new AuraHandledException('Showroom Visit Id is missing.');
        }

        if (String.isBlank(phoneNumber)) {
            throw new AuraHandledException('Please enter customer phone number.');
        }

        if (String.isBlank(customerName)) {
            throw new AuraHandledException('Please enter customer name.');
        }

        Id customerIdToTag;
        String customerNameToSet;

        if (existingCustomerId != null) {
            Account existingCustomer = [
                SELECT Id, Name, Phone
                FROM Account
                WHERE Id = :existingCustomerId
                LIMIT 1
            ];

            customerIdToTag = existingCustomer.Id;
            customerNameToSet = existingCustomer.Name;
        } else {
            Account newCustomer = new Account();
            newCustomer.Name = customerName.trim();
            newCustomer.Phone = phoneNumber.trim();
            insert newCustomer;

            customerIdToTag = newCustomer.Id;
            customerNameToSet = newCustomer.Name;
        }

        Showroom_Visit__c sv = new Showroom_Visit__c();
        sv.Id = showroomVisitId;

        // Lookup field update
        sv.CUSTOMERlookup__c = customerIdToTag;

        // Text field update with Account Name
        sv.Customer_Name__c = customerNameToSet;

        update sv;

        return 'Customer added successfully.';
    }
}
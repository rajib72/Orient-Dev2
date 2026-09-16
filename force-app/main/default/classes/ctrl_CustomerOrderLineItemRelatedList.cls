/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_CustomerOrderLineItemRelatedList
 * Author          : <Amit>
 * Created Date    : Jun 4, 2026
 * Last Modified By: <Amit>
 * Last Modified On: Jun 4, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jun 4, 2026  │ <Amit>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ctrl_CustomerOrderLineItemRelatedList {

    @AuraEnabled(cacheable=true)
    public static List<Customer_Order_Line_Item__c> getLineItems(Id customerOrderId) {

        if (customerOrderId == null) {
            return new List<Customer_Order_Line_Item__c>();
        }

        List<Customer_Order_Line_Item__c> lineItems = [
            SELECT
                Id,
                Name,
                Line_Item_Status_On_Salesforce__c,
                Barcode_Value__c,
                SKU_Details__c,
                Active_Sales_Executive_Details__c,
                Total_Price_Incl_GST__c,
                CreatedDate
            FROM Customer_Order_Line_Item__c
            WHERE Customer_Order__c = :customerOrderId
        ];

        lineItems.sort(new LineItemStatusSorter());

        return lineItems;
    }

    public class LineItemStatusSorter implements Comparator<Customer_Order_Line_Item__c> {

        public Integer compare(
            Customer_Order_Line_Item__c item1,
            Customer_Order_Line_Item__c item2
        ) {
            Integer rank1 = getStatusRank(item1.Line_Item_Status_On_Salesforce__c);
            Integer rank2 = getStatusRank(item2.Line_Item_Status_On_Salesforce__c);

            if (rank1 == rank2) {
                if (item1.CreatedDate == item2.CreatedDate) {
                    return 0;
                }

                return item1.CreatedDate > item2.CreatedDate ? -1 : 1;
            }

            return rank1 < rank2 ? -1 : 1;
        }
    }

    private static Integer getStatusRank(String statusValue) {

        switch on statusValue {
            when 'Draft' {
                return 1; // Ready For Invoice
            }
            when 'Finalize In Post' {
                return 2;
            }
            when 'Finalize In Pre' {
                return 3;
            }
            when 'Sent To ERP - PRE' {
                return 4;
            }
            when 'Newly Added' {
                return 5;
            }
            when 'Back To Available Wishlist Item' {
                return 6; // Removed
            }
            when 'Removed' {
                return 7; // Removed From ERP
            }
            when else {
                return 99;
            }
        }
    }
}
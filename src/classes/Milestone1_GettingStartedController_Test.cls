@IsTest
public with sharing class Milestone1_GettingStartedController_Test {

    static testMethod void testGetSettings() {
        Milestone1_GettingStartedController cont = new Milestone1_GettingStartedController();
        Milestone1_Settings__c settings = cont.getInitialSettingsWithoutSave();

        System.assert(!settings.Auto_Follow_Complete_Task__c);
        System.assert(!settings.Auto_Follow_Task__c);
        System.assert(!settings.Auto_Unfollow_Reassignment__c);
    }

    static testMethod void testGettingStartedProject() {
        String content = '<?xml version="1.0"?>' +
            '<export>' +
                '<meta>' +
                    '<exportPackage>Milestone1_Project_Export</exportPackage>' +
                    '<exportAuthor>Alejandro+De+Gregorio</exportAuthor>' +
                    '<exportOrganization>undefined</exportOrganization>' +
                    '<exportCreateDate>2014-11-12+20%3A21%3A40</exportCreateDate>' +
                    '<exportVersion>1.0</exportVersion>' +
                '</meta>' +
                '<Milestone1_Project__c>' +
                    '<Id>a05F000000NzLzpIAF</Id>' +
                    '<Total_Hours_Budget__c>10.00</Total_Hours_Budget__c>' +
                    '<Status__c>Planning</Status__c>' +
                    '<Description__c>Test+description.</Description__c>' +
                    '<Name>Test+project</Name>' +
                    '<Milestone1_Milestone__c>' +
                        '<Id>a03F000000Htu79IAB</Id>' +
                        '<Expense_Budget__c>0.00</Expense_Budget__c>' +
                        '<Hours_Budget__c>0.00</Hours_Budget__c>' +
                        '<Name>Test+milestone</Name>' +
                    '</Milestone1_Milestone__c>' +
                '</Milestone1_Project__c>' +
            '</export>';

        Document doc = new Document(
            Name = 'Starter Project (LPM1)',
            DeveloperName = 'Starter_Project_LPM1a',
            Body = Blob.valueOf(content),
            ContentType = 'text/plain',
            Type = 'xml',
            FolderId = UserInfo.getUserId()
        );
        insert doc;

        Test.startTest();
        Milestone1_GettingStartedController cont = new Milestone1_GettingStartedController();
        Milestone1_Project__c project = cont.handleGettingStartedProjectInitialization();
        System.assert(project != null);
        Test.stopTest();
    }
}

@isTest
public with sharing class Project_Active_Sched_Update_Test {

    public static testMethod void testUdpateProject() {
        //clean the org with projects
        delete [SELECT Id FROM Milestone1_Project__c LIMIT 1000];

        Date today = Date.today();
        Milestone1_Project__c project = Milestone1_Test_Utility.sampleProjectActive('My Project');
        insert project;
        //modify a status to update the project
        project.Status__c = 'Active';
        Milestone1_Project_Active_Sched_Update scheduleJob = new Milestone1_Project_Active_Sched_Update();
        scheduleJob.execute(null);

        System.assertEquals(
            1,
            [SELECT count() FROM Milestone1_Project__c WHERE Id =:project.Id AND Status__c = 'Active']
        );
    }
}

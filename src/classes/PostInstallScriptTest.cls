@isTest
public class PostInstallScriptTest {

    static testMethod void testDefaultSettings() {

        Test.startTest();
        PostInstallScript postinstall = new PostInstallScript();
        Test.testInstall(postinstall, null);
        Test.stopTest();

        Milestone1_Settings__c settings = Milestone1_Settings__c.getOrgDefaults();

        System.assert(!settings.Auto_Follow_Complete_Task__c);
        System.assert(!settings.Auto_Follow_Task__c);
        System.assert(!settings.Auto_Unfollow_Reassignment__c);
    }
}

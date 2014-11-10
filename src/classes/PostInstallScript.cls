global class PostInstallScript implements InstallHandler {
    private InstallContext context;

    global void onInstall(InstallContext context) {
        this.context = context;

        if (context.isUpgrade()) {
            performUpgrade();
        } else {
            performInstall();
        }
    }

    private void performInstall() {
        insertDefaultSettings();
    }

    private void performUpgrade() {
    }

    private Boolean beforeVersion(Integer major, Integer minor, Integer patch){
        return this.context.previousVersion().compareTo(
            new Version(major, minor, patch)
        ) < 0;
    }

    private void insertDefaultSettings() {
        Milestone1_Settings__c settings = new Milestone1_Settings__c();

        settings.Auto_Follow_Task__c = false;
        settings.Auto_Unfollow_Reassignment__c = false;
        settings.Auto_Follow_Complete_Task__c = false;

        insert settings;

    }
}

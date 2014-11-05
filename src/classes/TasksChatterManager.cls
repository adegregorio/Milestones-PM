public with sharing class TasksChatterManager {

    private static final Schema.SObjectType entitySubscriptionType =
        Milestone1_Schema_Helper.getGlobalDescribe().get('entitysubscription');

    public List<sObject> newSubscriptions {get; set;}
    public List<sObject> subscriptionsToRemove {get; set;}
    private Map<String, List<sObject>> subscriptionsByUserId;

    public TasksChatterManager(
            Map<Id, Milestone1_Task__c> newTasksMap,
            Map<Id, Milestone1_Task__c> oldTasksMap
    ) {
        this.newSubscriptions = new List<sObject>();
        this.subscriptionsToRemove = new List<sObject>();
        loadSubscriptionsByUserId();

        for (Milestone1_Task__c currentTask : newTasksMap.values()) {
            Milestone1_Task__c oldTask = oldTasksMap != null
                ? oldTasksMap.get(currentTask.Id)
                : null;

            if (newSubscriptionNeeded(currentTask)) {
                this.newSubscriptions.add(createSubscription(currentTask));
            }

            if (mustUnfollow(currentTask, oldTask)) {
                if (currentTask.Complete__c) {
                    this.subscriptionsToRemove.add(getSubscriptionForUserAndRec(currentTask));
                } else {
                    this.subscriptionsToRemove.add(getSubscriptionForUserAndRec(oldTask));
                }
            }
        }
    }

    private void loadSubscriptionsByUserId() {
        List<sObject> existingSubscriptions = new List<sObject>();
        List<Id> newRecordsIds = new List<Id> (Trigger.newMap.keySet());

        if (Milestone1_Schema_Helper.isOrgChatterEnabled()) {
            String queryString =
                'SELECT ' +
                    'Id, ' +
                    'ParentId, ' +
                    'SubscriberId ' +
                'FROM ' +
                    'EntitySubscription ' +
                'WHERE ' +
                    'ParentId in (\'' + String.join(newRecordsIds, '\',\'') + '\')';
            existingSubscriptions = Database.query(queryString);
        }

        this.subscriptionsByUserId = new Map<String, List<sObject>>();
        for (sObject aSubscription : existingSubscriptions) {
            if (this.subscriptionsByUserId.get( (id)aSubscription.get('SubscriberId')) == null) {
                this.subscriptionsByUserId.put( (id)aSubscription.get('SubscriberId'),new List<sObject>());
            }
            List<sObject> tempList = this.subscriptionsByUserId.get((id)aSubscription.get('SubscriberId'));
            tempList.add(aSubscription);
            this.subscriptionsByUserId.put((id)aSubscription.get('SubscriberId'),tempList);
        }
    }

    private Boolean newSubscriptionNeeded(Milestone1_Task__c currentTask) {
        Boolean result = false;
        if (currentTask.Assigned_To__c != null) {
            List<sObject> existingSubscriptionList = subscriptionsByUserId.get(currentTask.Assigned_To__c);
            sObject existingSubscription = getSubscriptionForUserAndRec(currentTask);

            AutoChatterSetting chatterSettings = new AutoChatterSetting(
                currentTask.Assigned_To__c,
                currentTask.Assigned_To__r.ProfileId
            );

            if (chatterSettings.autoFollow && existingSubscription == null && entitySubscriptionType != null) {
                result = true;
            }
        }
        return result;
    }

    private sObject createSubscription(Milestone1_Task__c task) {
        sObject subscription = entitySubscriptionType.newSObject();
        subscription.put('parentId', task.id);
        subscription.put('SubscriberId', task.Assigned_To__c);

        return subscription;
    }

    private Boolean mustUnfollow(Milestone1_Task__c currentTask, Milestone1_Task__c oldTask) {
        if (currentTask.Assigned_To__c != null) {
            AutoChatterSetting chatterSettings = new AutoChatterSetting(
                currentTask.Assigned_To__c,
                currentTask.Assigned_To__r.ProfileId
            );
            if (chatterSettings.autoCompleteFollow && currentTask.Complete__c
                    && getSubscriptionForUserAndRec(currentTask) != null
            ) {
                return true;
            }
        }

        if (oldTask != null && oldTask.Assigned_To__c != null
                && oldTask.Assigned_To__c != currentTask.Assigned_To__c
        ) {
            AutoChatterSetting chatterSettings = new AutoChatterSetting(
                oldTask.Assigned_To__c,
                oldTask.Assigned_To__r.ProfileId
            );
            sObject existingSubscription = getSubscriptionForUserAndRec(
                oldTask
            );

            if (chatterSettings.autoUnassignFollow && existingSubscription != null) {
                return true;
            }
        }

        return false;
    }

    private sObject getSubscriptionForUserAndRec(
            Milestone1_Task__c task
    ) {
        List<sObject> existingSubscriptionList = this.subscriptionsByUserId.get(task.Assigned_To__c);
        sObject existingSubscription = null;
        if (existingSubscriptionList != null) {
            for (sObject tempSubscription : existingSubscriptionList) {
                if ((id)tempSubscription.get('SubscriberId') == task.Assigned_To__c
                        && (id)tempSubscription.get('ParentId') == task.Id
                ) {
                    existingSubscription = tempSubscription;
                    break;
                }
            }
        }
        return existingSubscription;
    }

    private class AutoChatterSetting {
        public Boolean autoFollow = false;
        public Boolean autoCompleteFollow = false;
        public Boolean autoUnassignFollow = false;

        public autoChatterSetting(String userid, String profileId) {
            Milestone1_Settings__c defaultSettings = Milestone1_Settings__c.getOrgDefaults();
            Milestone1_Settings__c profileSettings = Milestone1_Settings__c.getInstance(userid);
            Milestone1_Settings__c userSettings = Milestone1_Settings__c.getInstance(profileid);

            if (userSettings != null) {
                autoFollow = userSettings.Auto_Follow_Task__c;
                autoCompleteFollow = userSettings.Auto_Follow_Complete_Task__c;
                autoUnassignFollow = userSettings.Auto_Unfollow_Reassignment__c;
            } else if (profileSettings != null) {
                autoFollow = profileSettings.Auto_Follow_Task__c;
                autoCompleteFollow = profileSettings.Auto_Follow_Complete_Task__c;
                autoUnassignFollow = profileSettings.Auto_Unfollow_Reassignment__c;
            } else if (defaultSettings != null) {
                autoFollow = defaultSettings.Auto_Follow_Task__c;
                autoCompleteFollow = defaultSettings.Auto_Follow_Complete_Task__c;
                autoUnassignFollow = defaultSettings.Auto_Unfollow_Reassignment__c;
            }
        }
    }
}

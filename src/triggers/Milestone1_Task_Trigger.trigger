trigger Milestone1_Task_Trigger on Milestone1_Task__c (
        before insert,
        before update,
        after insert,
        after update
) {

    if (trigger.isBefore) {
        Milestone1_Task_Trigger_Utility.handleTaskBeforeTrigger(trigger.new);
    }

    if (trigger.isAfter) {
        if (Trigger.isUpdate) {
            //shift Dates of successor Tasks if Task Due Date is shifted
            Milestone1_Task_Trigger_Utility.checkSuccessorDependencies(
                Trigger.oldMap,
                Trigger.newMap
            );
        }
        Milestone1_Task_Trigger_Utility.handleTaskAfterTrigger(Trigger.newMap, Trigger.oldMap);
    }
}
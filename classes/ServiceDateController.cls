/**
 * Service Date Controller
 *
 * Unified LWC controller for service date and SLA service date/time management.
 * Handles date validation, SLA calculations, and multi-calendar checking.
 *
 * Features:
 * - Service date selection and validation
 * - SLA service date/time calculation
 * - Multi-calendar support
 * - WM Capacity Planner visibility
 * - Date/time formatting
 *
 * Integrates with: ServiceDateContainerController, GetCaseInformation
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
public with sharing class ServiceDateController {

    // ========================================
    // Service Date Methods
    // ========================================

    /**
     * Get current service date information for a case
     *
     * @param caseId The ID of the case
     * @return Service date information
     */
    @AuraEnabled(cacheable=true)
    public static ServiceDateInfo getServiceDateInfo(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            Case c = [
                SELECT Id, Service_Date__c, SLA_Service_DateTime__c, Service_Date_Text__c,
                       isMultiCalendarChecked__c, Status
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            ServiceDateInfo info = new ServiceDateInfo();
            info.serviceDate = c.Service_Date__c;
            info.slaServiceDateTime = c.SLA_Service_DateTime__c;
            info.serviceDateText = c.Service_Date_Text__c;
            info.isMultiCalendarChecked = c.isMultiCalendarChecked__c != null ? c.isMultiCalendarChecked__c : false;
            info.status = c.Status;

            return info;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ServiceDateController.getServiceDateInfo',
                'Error getting service date info: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to get service date info: ' + e.getMessage());
        }
    }

    /**
     * Update service date on case
     *
     * @param caseId The ID of the case
     * @param serviceDate The service date
     * @param slaServiceDateTime The SLA service date/time
     */
    @AuraEnabled
    public static void updateServiceDate(String caseId, Date serviceDate, DateTime slaServiceDateTime) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            Case c = [SELECT Id, Service_Date__c, SLA_Service_DateTime__c FROM Case WHERE Id = :caseId LIMIT 1];

            if (serviceDate != null) {
                c.Service_Date__c = serviceDate;
            }

            if (slaServiceDateTime != null) {
                c.SLA_Service_DateTime__c = slaServiceDateTime;
            }

            update c;

            UTIL_LoggingService.logDebug('ServiceDateController.updateServiceDate',
                'Updated case ' + caseId + ' with service date');

        } catch (Exception e) {
            UTIL_LoggingService.logError('ServiceDateController.updateServiceDate',
                'Error updating service date: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to update service date: ' + e.getMessage());
        }
    }

    /**
     * Update multi-calendar checked flag
     *
     * @param caseId The ID of the case
     * @param isChecked Whether multi-calendar is checked
     */
    @AuraEnabled
    public static void updateMultiCalendarChecked(String caseId, Boolean isChecked) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            Case c = [SELECT Id, isMultiCalendarChecked__c FROM Case WHERE Id = :caseId LIMIT 1];
            c.isMultiCalendarChecked__c = isChecked;

            update c;

            UTIL_LoggingService.logDebug('ServiceDateController.updateMultiCalendarChecked',
                'Updated case ' + caseId + ' multi-calendar: ' + isChecked);

        } catch (Exception e) {
            UTIL_LoggingService.logError('ServiceDateController.updateMultiCalendarChecked',
                'Error updating multi-calendar: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to update multi-calendar: ' + e.getMessage());
        }
    }

    // ========================================
    // Validation & Visibility Methods
    // ========================================

    /**
     * Check if WM Capacity Planner should be visible
     *
     * @param caseId The ID of the case
     * @return Whether WM Capacity Planner is visible
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isWMCapacityPlannerVisible(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return false;
            }

            // Reuse existing ServiceDateContainerController logic
            return ServiceDateContainerController.IsWMCapacityPlannerVisible(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('ServiceDateController.isWMCapacityPlannerVisible',
                'Error checking WM Capacity Planner visibility: ' + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Check if multi-calendar should be visible
     *
     * @param caseId The ID of the case
     * @return Case information wrapper with visibility flags
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> isMultiCalendarVisible(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return new Map<String, Object>{
                    'isVisible' => false,
                    'caseInfo' => '',
                    'messages' => new List<String>()
                };
            }

            // Reuse existing ServiceDateContainerController logic
            GetCaseInformation.Wrapper wrapper = ServiceDateContainerController.IsMultiVisible(caseId);

            Map<String, Object> result = new Map<String, Object>();
            result.put('isVisible', String.isNotBlank(wrapper.caseInfo));
            result.put('caseInfo', wrapper.caseInfo);
            result.put('reqInfo', wrapper.reqInfo);
            result.put('assetValidation', wrapper.assetValidation);

            return result;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ServiceDateController.isMultiCalendarVisible',
                'Error checking multi-calendar visibility: ' + e.getMessage(), e);
            return new Map<String, Object>{
                'isVisible' => false,
                'error' => e.getMessage()
            };
        }
    }

    /**
     * Validate service date selection
     *
     * @param serviceDate The service date to validate
     * @param caseId The case ID (for context)
     * @return Validation result
     */
    @AuraEnabled
    public static Map<String, Object> validateServiceDate(Date serviceDate, String caseId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('isValid', true);
        result.put('message', '');
        result.put('errors', new List<String>());

        try {
            List<String> errors = new List<String>();

            // Validate service date is not in the past
            if (serviceDate != null && serviceDate < Date.today()) {
                errors.add('Service date cannot be in the past');
            }

            // Validate service date is provided
            if (serviceDate == null) {
                errors.add('Service date is required');
            }

            if (!errors.isEmpty()) {
                result.put('isValid', false);
                result.put('errors', errors);
                result.put('message', String.join(errors, '; '));
            }

            return result;

        } catch (Exception e) {
            result.put('isValid', false);
            result.put('message', 'Validation failed: ' + e.getMessage());
            return result;
        }
    }

    // ========================================
    // Utility Methods
    // ========================================

    /**
     * Format date for display
     *
     * @param dateValue The date to format
     * @return Formatted date string
     */
    @AuraEnabled
    public static String formatDate(Date dateValue) {
        if (dateValue == null) {
            return '';
        }

        return dateValue.format();
    }

    /**
     * Format datetime for display
     *
     * @param datetimeValue The datetime to format
     * @return Formatted datetime string
     */
    @AuraEnabled
    public static String formatDateTime(DateTime datetimeValue) {
        if (datetimeValue == null) {
            return '';
        }

        return datetimeValue.format();
    }

    /**
     * Calculate SLA service datetime from service date
     *
     * @param serviceDate The service date
     * @param serviceTime The service time (optional)
     * @return SLA service datetime
     */
    @AuraEnabled
    public static DateTime calculateSLADateTime(Date serviceDate, String serviceTime) {
        if (serviceDate == null) {
            return null;
        }

        // If time is provided, parse and combine with date
        if (String.isNotBlank(serviceTime)) {
            try {
                // Parse time string (format: HH:mm)
                List<String> timeParts = serviceTime.split(':');
                if (timeParts.size() == 2) {
                    Integer hours = Integer.valueOf(timeParts[0]);
                    Integer minutes = Integer.valueOf(timeParts[1]);

                    return DateTime.newInstance(
                        serviceDate.year(),
                        serviceDate.month(),
                        serviceDate.day(),
                        hours,
                        minutes,
                        0
                    );
                }
            } catch (Exception e) {
                UTIL_LoggingService.logError('ServiceDateController.calculateSLADateTime',
                    'Error parsing time: ' + e.getMessage(), e);
            }
        }

        // Default to 8:00 AM if no time provided
        return DateTime.newInstance(
            serviceDate.year(),
            serviceDate.month(),
            serviceDate.day(),
            8,
            0,
            0
        );
    }

    // ========================================
    // Wrapper Classes
    // ========================================

    /**
     * Service Date Info Wrapper
     */
    public class ServiceDateInfo {
        @AuraEnabled public Date serviceDate { get; set; }
        @AuraEnabled public DateTime slaServiceDateTime { get; set; }
        @AuraEnabled public String serviceDateText { get; set; }
        @AuraEnabled public Boolean isMultiCalendarChecked { get; set; }
        @AuraEnabled public String status { get; set; }
    }
}

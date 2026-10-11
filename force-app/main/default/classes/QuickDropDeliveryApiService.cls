
public with sharing class QuickDropDeliveryApiService {

    // Request payload sent to the external API.
    public class DeliveryApiRequest {
        public String orderNumber;
        public String storeName;
        public String deliveryAddress;
        public Decimal totalAmount;
    }

    // Example response expected from the external API.
    public class DeliveryApiResponse {
        public String deliveryId;
        public String status;
    }

    // Result returned to the calling Apex code.
    public class DeliveryApiResult {
        public Boolean success;
        public Integer statusCode;
        public String deliveryId;
        public String deliveryStatus;
        public String errorMessage;
    }

    public static DeliveryApiResult createDeliveryRequest(
        Id orderId
    ) {
        if (orderId == null) {
            throw new AuraHandledException(
                'Order Id is required.'
            );
        }

        List<Customer_Order__c> orders = [
            SELECT Id,
                   Name,
                   Grand_Total__c,
                   Store__r.Name,
                   Delivery_Address__r.Name
            FROM Customer_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException(
                'Customer Order was not found.'
            );
        }

        Customer_Order__c order = orders[0];

        // Build the JSON request data.
        DeliveryApiRequest payload =
            new DeliveryApiRequest();

        payload.orderNumber = order.Name;
        payload.storeName = order.Store__r.Name;
        payload.deliveryAddress =
            order.Delivery_Address__r.Name;
        payload.totalAmount = order.Grand_Total__c;

        // Prepare the HTTP request.
        HttpRequest request = new HttpRequest();

        request.setEndpoint(
            'callout:QuickDrop_Delivery_API/deliveries'
        );

        request.setMethod('POST');

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        request.setHeader(
            'Accept',
            'application/json'
        );
        request.setHeader(
    'Idempotency-Key',
    'QD-DELIVERY-' + String.valueOf(order.Id)
);

        request.setBody(JSON.serialize(payload));

        DeliveryApiResult result =
            new DeliveryApiResult();

        // Send the request and handle transport errors.
        HttpResponse response;

        try {
            response = new Http().send(request);
        } catch (Exception e) {
            result.success = false;
            result.errorMessage =
                'HTTP callout failed: ' + e.getMessage();

            return result;
        }

        result.statusCode = response.getStatusCode();

        // Accept any successful 2xx status code.
        result.success =
            result.statusCode >= 200 &&
            result.statusCode < 300;

        if (!result.success) {
            result.errorMessage =
                'Delivery API returned HTTP ' +
                result.statusCode;

            return result;
        }

        // Parse the response returned by the API.
        try {
            if (String.isBlank(response.getBody())) {
                result.success = false;
                result.errorMessage =
                    'Delivery API returned an empty response.';

                return result;
            }

            DeliveryApiResponse apiResponse =
                (DeliveryApiResponse) JSON.deserialize(
                    response.getBody(),
                    DeliveryApiResponse.class
                );

            if (
                apiResponse == null ||
                String.isBlank(apiResponse.deliveryId)
            ) {
                result.success = false;
                result.errorMessage =
                    'Delivery API response is missing the delivery ID.';

                return result;
            }

            result.deliveryId = apiResponse.deliveryId;
            result.deliveryStatus = apiResponse.status;

        } catch (Exception e) {
            result.success = false;
            result.errorMessage =
                'Unable to parse the Delivery API response.';
        }

        return result;
    }
}

@IsTest
global class QuickDropDeliveryApiMock
    implements HttpCalloutMock {

    private Integer statusCode;
    private String responseBody;

    global QuickDropDeliveryApiMock(
        Integer statusCode,
        String responseBody
    ) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    global HttpResponse respond(HttpRequest request) {

        HttpResponse response = new HttpResponse();

        response.setStatusCode(statusCode);

        response.setHeader(
            'Content-Type',
            'application/json'
        );

        response.setBody(responseBody);

        return response;
    }
}
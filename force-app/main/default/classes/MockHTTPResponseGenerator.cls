/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Test utility class providing mock HTTP responses for callout testing.
 *              Includes success mock (200), failure mock (500), and exception mock
 *              to simulate different API response scenarios in unit tests.
 */
@isTest
public class MockHTTPResponseGenerator {
    public class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"meta":{"success":true,"message":"Success","errors":[]}}');
            res.setStatusCode(200);
            return res;
        }
    }

    public class MockHttpFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody(
                '{ "meta": {"timestamp": "2026-04-20T02:11:17Z", "success": false, "requestCount": 1, "message": "Invalid request payload", "errors": ["Missing required field: Request[0].items."], "endpoint": "account"}, "data": null}'
            );
            return res;
        }
    }

    public class MockHttpExceptionResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Connection timeout');
        }
    }
}

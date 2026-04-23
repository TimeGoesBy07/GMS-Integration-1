/**
 * @author Tran Trung Hieu
 * @modified 2026-04-21
 * @description Data structure class for parsing API responses from external systems.
 *              Contains metadata about success status, error messages, request count,
 *              endpoint information, and timestamp.
 */
public with sharing class ApiResponse {
    public Meta meta;

    public class Meta {
        public Boolean success;
        public String message;
        public List<String> errors;
        public Integer requestCount;
        public String endpoint;
        public Datetime timestamp;
    }
}

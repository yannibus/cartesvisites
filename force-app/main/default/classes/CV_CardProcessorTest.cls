@IsTest
private class CV_CardProcessorTest {

    @IsTest
    static void parser_extracts_fields_with_code_fences() {
        String raw = '```json\n{"firstName":"Yann","lastName":"Jourdain","email":"y@test.com","mobile":"+33612","phone":"N/A","company":"Salesforce"}\n```';
        CV_PromptJsonParser.ParsedCard card = CV_PromptJsonParser.parseOne(raw);
        System.assertEquals('Yann', card.firstName);
        System.assertEquals('Jourdain', card.lastName);
        System.assertEquals('Salesforce', card.company);
        System.assertEquals(null, card.phone, 'N/A must be normalised to null');
    }

    @IsTest
    static void parser_handles_invalid_json() {
        CV_PromptJsonParser.ParsedCard card = CV_PromptJsonParser.parseOne('not a json');
        System.assertNotEquals(null, card.errorMessage);
    }

    @IsTest
    static void linkCardToLead_links_document_to_lead() {
        ContentVersion cv = new ContentVersion(
            Title = 'card.png',
            PathOnClient = 'card.png',
            VersionData = Blob.valueOf('test'),
            Origin = 'H'
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Lead l = new Lead(FirstName = 'Alice', LastName = 'Martin', Company = 'Acme');
        insert l;

        Test.startTest();
        CV_CardProcessor.linkCardToLead(docId, l.Id);
        Test.stopTest();

        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :l.Id AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, linkCount);
    }

    @IsTest
    static void linkCardToLead_noop_when_null() {
        Test.startTest();
        CV_CardProcessor.linkCardToLead(null, null);
        Test.stopTest();
        // No exception expected
    }

    @IsTest
    static void uploadCard_creates_content_version() {
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('hello'));
        Test.startTest();
        Id docId = CV_CardProcessor.uploadCard('hello.png', base64);
        Test.stopTest();
        System.assertNotEquals(null, docId);
    }
}

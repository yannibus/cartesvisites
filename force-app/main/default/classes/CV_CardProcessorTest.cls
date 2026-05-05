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
    static void createLeads_creates_leads_and_links_documents() {
        ContentVersion cv = new ContentVersion(
            Title = 'card.png',
            PathOnClient = 'card.png',
            VersionData = Blob.valueOf('test'),
            Origin = 'H'
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        CV_CardProcessor.LeadDraft draft = new CV_CardProcessor.LeadDraft();
        draft.contentDocumentId = docId;
        draft.firstName = 'Alice';
        draft.lastName = 'Martin';
        draft.company = 'Acme';
        draft.email = 'alice@acme.com';

        Test.startTest();
        List<CV_CardProcessor.CreatedLead> out = CV_CardProcessor.createLeads(
            new List<CV_CardProcessor.LeadDraft>{ draft }
        );
        Test.stopTest();

        System.assertEquals(1, out.size());
        Lead created = [SELECT Id, FirstName, LastName, Company, Email FROM Lead WHERE Id = :out[0].leadId];
        System.assertEquals('Alice', created.FirstName);
        System.assertEquals('Acme', created.Company);

        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :created.Id AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, linkCount);
    }

    @IsTest
    static void createLeads_uses_fallbacks_when_missing() {
        CV_CardProcessor.LeadDraft draft = new CV_CardProcessor.LeadDraft();
        draft.firstName = 'NoLastName';
        // no lastName, no company
        Test.startTest();
        List<CV_CardProcessor.CreatedLead> out = CV_CardProcessor.createLeads(
            new List<CV_CardProcessor.LeadDraft>{ draft }
        );
        Test.stopTest();

        Lead created = [SELECT LastName, Company FROM Lead WHERE Id = :out[0].leadId];
        System.assertEquals('Unknown', created.LastName);
        System.assertEquals('Unknown', created.Company);
    }

    @IsTest
    static void createLeads_empty_list_returns_empty() {
        List<CV_CardProcessor.CreatedLead> out = CV_CardProcessor.createLeads(null);
        System.assertEquals(0, out.size());
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

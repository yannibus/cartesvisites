public with sharing class CV_CardProcessor {

    private static final String PROMPT_TEMPLATE = 'ImageF';
    private static final String INPUT_PARAM = 'Input:ImageF';

    @AuraEnabled
    public static Id uploadCard(String fileName, String base64Data) {
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('File name and data are required.');
        }
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        cv.Origin = 'H';
        insert cv;

        ContentVersion inserted = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        return inserted.ContentDocumentId;
    }

    @AuraEnabled(cacheable=false)
    public static CardResult processCard(Id contentDocumentId) {
        CardResult result = new CardResult();
        result.contentDocumentId = contentDocumentId;

        try {
            ContentDocument doc = [
                SELECT Id, Title
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];
            result.title = doc.Title;

            String rawResponse = invokePromptTemplate(doc);
            result.rawResponse = rawResponse;

            CV_PromptJsonParser.ParsedCard parsed = CV_PromptJsonParser.parseOne(rawResponse);
            result.firstName = parsed.firstName;
            result.lastName  = parsed.lastName;
            result.email     = parsed.email;
            result.mobile    = parsed.mobile;
            result.phone     = parsed.phone;
            result.company   = parsed.company;
            result.status    = 'ready';
        } catch (Exception e) {
            result.status = 'error';
            result.errorMessage = e.getMessage();
            System.debug(LoggingLevel.ERROR, 'CV_CardProcessor.processCard failed: ' + e);
        }
        return result;
    }

    @AuraEnabled
    public static void linkCardToLead(Id contentDocumentId, Id leadId) {
        if (contentDocumentId == null || leadId == null) return;
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentDocumentId;
        link.LinkedEntityId    = leadId;
        link.ShareType         = 'V';
        link.Visibility        = 'AllUsers';
        insert link;
    }

    private static String invokePromptTemplate(ContentDocument doc) {
        ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
        wrapped.value = new Map<String, String>{
            'id'   => doc.Id,
            'type' => 'ContentDocument'
        };

        Map<String, ConnectApi.WrappedValue> inputs = new Map<String, ConnectApi.WrappedValue>();
        inputs.put(INPUT_PARAM, wrapped);

        ConnectApi.EinsteinPromptTemplateGenerationsInput genInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        genInput.inputParams = inputs;
        genInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        genInput.isPreview = false;

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE, genInput);

        if (response == null || response.generations == null || response.generations.isEmpty()) {
            String details = '';
            if (response != null && response.generationErrors != null && !response.generationErrors.isEmpty()) {
                details = ' | ' + response.generationErrors[0].errorMessage;
            }
            throw new CV_ProcessorException('Empty response from prompt template ' + PROMPT_TEMPLATE + details);
        }
        return response.generations[0].text;
    }

    public class CardResult {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String company;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String phone;
        @AuraEnabled public String rawResponse;
        @AuraEnabled public String status;
        @AuraEnabled public String errorMessage;
    }

    public class CV_ProcessorException extends Exception {}
}

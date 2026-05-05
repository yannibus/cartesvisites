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
    public static List<CreatedLead> createLeads(List<LeadDraft> drafts) {
        if (drafts == null || drafts.isEmpty()) {
            return new List<CreatedLead>();
        }

        List<Lead> toInsert = new List<Lead>();
        for (LeadDraft d : drafts) {
            Lead l = new Lead();
            l.FirstName   = d.firstName;
            l.LastName    = String.isNotBlank(d.lastName) ? d.lastName : 'Unknown';
            l.Company     = String.isNotBlank(d.company) ? d.company : 'Unknown';
            l.Email       = d.email;
            l.MobilePhone = d.mobile;
            l.Phone       = d.phone;
            l.LeadSource  = 'Business Card';
            toInsert.add(l);
        }
        insert toInsert;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Integer i = 0; i < toInsert.size(); i++) {
            Id cdId = drafts[i].contentDocumentId;
            if (cdId == null) continue;
            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = cdId;
            link.LinkedEntityId    = toInsert[i].Id;
            link.ShareType         = 'V';
            link.Visibility        = 'AllUsers';
            links.add(link);
        }
        if (!links.isEmpty()) {
            insert links;
        }

        List<CreatedLead> out = new List<CreatedLead>();
        for (Integer i = 0; i < toInsert.size(); i++) {
            CreatedLead cl = new CreatedLead();
            cl.leadId = toInsert[i].Id;
            cl.contentDocumentId = drafts[i].contentDocumentId;
            cl.name = (String.isNotBlank(toInsert[i].FirstName) ? toInsert[i].FirstName + ' ' : '') + toInsert[i].LastName;
            out.add(cl);
        }
        return out;
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

    public class LeadDraft {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String company;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String phone;
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

    public class CreatedLead {
        @AuraEnabled public Id leadId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String name;
    }

    public class CV_ProcessorException extends Exception {}
}

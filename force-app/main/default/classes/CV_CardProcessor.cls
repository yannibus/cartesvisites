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
            result.lastName = parsed.lastName;
            result.email = parsed.email;
            result.mobile = parsed.mobile;
            result.phone = parsed.phone;
            result.company = parsed.company;
            result.status = 'ready';
        } catch (Exception e) {
            result.status = 'error';
            result.errorMessage = e.getMessage();
            System.debug(LoggingLevel.ERROR, 'CV_CardProcessor.processCard failed: ' + e);
        }
        return result;
    }

    @AuraEnabled
    public static LeadCreateResult createLead(
        String firstName,
        String lastName,
        String company,
        String email,
        String mobile,
        String phone,
        String leadSource
    ) {
        LeadCreateResult res = new LeadCreateResult();

        Lead l = new Lead();
        l.FirstName = firstName;
        l.LastName = String.isBlank(lastName) ? 'Unknown' : lastName;
        l.Company = String.isBlank(company) ? 'Unknown' : company;
        l.Email = email;
        l.MobilePhone = mobile;
        l.Phone = phone;
        l.LeadSource = leadSource;

        // Let duplicate rules run but never block the insert: we want to
        // surface the existing record in the UI instead of throwing.
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.duplicateRuleHeader.allowSave = true;
        l.setOptions(dml);

        Database.SaveResult sr = Database.insert(l, false);

        if (sr.isSuccess()) {
            // Even with allowSave, detect whether a rule matched to inform the UI.
            Id existingId = findFirstDuplicateLeadId(l);
            if (existingId != null && existingId != sr.getId()) {
                res.status = 'duplicate';
                res.leadId = sr.getId();
                res.duplicateLeadId = existingId;
            } else {
                res.status = 'created';
                res.leadId = sr.getId();
            }
            return res;
        }

        // Insert failed: most likely a blocking duplicate rule.
        Id dupId = extractDuplicateLeadId(sr);
        if (dupId != null) {
            res.status = 'duplicate';
            res.duplicateLeadId = dupId;
            return res;
        }

        res.status = 'error';
        res.errorMessage = sr.getErrors().isEmpty() ? 'Lead creation failed.' : sr.getErrors()[0].getMessage();
        return res;
    }

    private static Id extractDuplicateLeadId(Database.SaveResult sr) {
        for (Database.Error err : sr.getErrors()) {
            if (err instanceof Database.DuplicateError) {
                Datacloud.DuplicateResult dr = ((Database.DuplicateError) err).getDuplicateResult();
                Id existing = firstMatchId(dr);
                if (existing != null)
                    return existing;
            }
        }
        return null;
    }

    private static Id findFirstDuplicateLeadId(Lead candidate) {
        if (String.isBlank(candidate.Email))
            return null;
        List<Lead> matches = [
            SELECT Id
            FROM Lead
            WHERE Email = :candidate.Email AND Id != :candidate.Id
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }

    private static Id firstMatchId(Datacloud.DuplicateResult dr) {
        if (dr == null)
            return null;
        for (Datacloud.MatchResult mr : dr.getMatchResults()) {
            for (Datacloud.MatchRecord rec : mr.getMatchRecords()) {
                if (rec.getRecord() != null)
                    return rec.getRecord().Id;
            }
        }
        return null;
    }

    @AuraEnabled
    public static void linkCardToLead(Id contentDocumentId, Id leadId) {
        if (contentDocumentId == null || leadId == null)
            return;
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentDocumentId;
        link.LinkedEntityId = leadId;
        link.ShareType = 'V';
        link.Visibility = 'AllUsers';
        insert link;
    }

    private static String invokePromptTemplate(ContentDocument doc) {
        ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
        wrapped.value = new Map<String, String>{ 'id' => doc.Id, 'type' => 'ContentDocument' };

        Map<String, ConnectApi.WrappedValue> inputs = new Map<String, ConnectApi.WrappedValue>();
        inputs.put(INPUT_PARAM, wrapped);

        ConnectApi.EinsteinPromptTemplateGenerationsInput genInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        genInput.inputParams = inputs;
        genInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        genInput.isPreview = false;

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
            PROMPT_TEMPLATE,
            genInput
        );

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
        @AuraEnabled
        public Id contentDocumentId;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String firstName;
        @AuraEnabled
        public String lastName;
        @AuraEnabled
        public String company;
        @AuraEnabled
        public String email;
        @AuraEnabled
        public String mobile;
        @AuraEnabled
        public String phone;
        @AuraEnabled
        public String rawResponse;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String errorMessage;
    }

    public class LeadCreateResult {
        @AuraEnabled
        public String status; // 'created' | 'duplicate' | 'error'
        @AuraEnabled
        public Id leadId; // id of the lead just created (null if blocked)
        @AuraEnabled
        public Id duplicateLeadId; // id of the pre-existing matching lead
        @AuraEnabled
        public String errorMessage;
    }

    public class CV_ProcessorException extends Exception {
    }
}

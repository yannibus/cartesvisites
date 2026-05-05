public class CV_PromptJsonParser {

    @InvocableMethod(label='Parse Contact JSON from Prompt' description='Parses JSON string and returns contact fields.')
    public static List<Result> parseJson(List<String> jsonInputs) {
        List<Result> results = new List<Result>();
        if (jsonInputs == null || jsonInputs.isEmpty()) {
            results.add(new Result());
            return results;
        }
        results.add(toResult(parseOne(jsonInputs[0])));
        return results;
    }

    public static ParsedCard parseOne(String jsonString) {
        ParsedCard card = new ParsedCard();
        if (String.isBlank(jsonString)) {
            return card;
        }

        String cleaned = stripCodeFences(jsonString);

        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(cleaned);
            card.firstName = readString(data, 'firstName');
            card.lastName  = readString(data, 'lastName');
            card.email     = readString(data, 'email');
            card.mobile    = readString(data, 'mobile');
            card.phone     = readString(data, 'phone');
            card.company   = readString(data, 'company');
        } catch (Exception e) {
            System.debug('CV_PromptJsonParser error: ' + e.getMessage() + ' | raw: ' + jsonString);
            card.errorMessage = e.getMessage();
        }
        return card;
    }

    private static String stripCodeFences(String raw) {
        String s = raw.trim();
        if (s.startsWith('```')) {
            s = s.replaceFirst('^```(?:json)?\\s*', '');
            s = s.replaceFirst('\\s*```\\s*$', '');
        }
        return s;
    }

    private static String readString(Map<String, Object> data, String key) {
        if (!data.containsKey(key) || data.get(key) == null) return null;
        String v = String.valueOf(data.get(key));
        if (String.isBlank(v) || v.equalsIgnoreCase('N/A')) return null;
        return v;
    }

    private static Result toResult(ParsedCard card) {
        Result r = new Result();
        r.outputFirstName = card.firstName;
        r.outputLastName  = card.lastName;
        r.outputEmail     = card.email;
        r.outputMobile    = card.mobile;
        r.outputPhone     = card.phone;
        return r;
    }

    public class ParsedCard {
        public String firstName;
        public String lastName;
        public String email;
        public String mobile;
        public String phone;
        public String company;
        public String errorMessage;
    }

    public class Result {
        @InvocableVariable(label='First Name' description='Extracted First Name')
        public String outputFirstName;

        @InvocableVariable(label='Last Name' description='Extracted Last Name')
        public String outputLastName;

        @InvocableVariable(label='Email' description='Extracted Email')
        public String outputEmail;

        @InvocableVariable(label='Mobile' description='Extracted Mobile')
        public String outputMobile;

        @InvocableVariable(label='Phone' description='Extracted Phone')
        public String outputPhone;
    }
}

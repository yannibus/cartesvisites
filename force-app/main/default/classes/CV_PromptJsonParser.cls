public class CV_PromptJsonParser {

    @InvocableMethod(label='Parse Contact JSON from Prompt' description='Parses JSON string and returns contact fields.')
    public static List<Result> parseJson(List<String> jsonInputs) {
        List<Result> results = new List<Result>();
        if (jsonInputs != null && !jsonInputs.isEmpty()) {
            String jsonString = jsonInputs[0];
            // Add null check for jsonString
            if (String.isBlank(jsonString)) {
                System.debug('Input JSON string is blank.');
                 results.add(new Result()); // Return empty result
                 return results;
            }
            try {
                Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

                Result res = new Result();
                // Add null checks for map keys before casting
                res.outputFirstName = data.containsKey('firstName') ? (String)data.get('firstName') : null;
                res.outputLastName = data.containsKey('lastName') ? (String)data.get('lastName') : null;
                res.outputEmail = data.containsKey('email') ? (String)data.get('email') : null;
                res.outputMobile = data.containsKey('mobile') ? (String)data.get('mobile') : null;
                res.outputPhone = data.containsKey('phone') ? (String)data.get('phone') : null;
                // Add other fields as needed
                results.add(res);

            } catch (Exception e) {
                // Handle parsing error (e.g., return null values or throw exception)
                System.debug('Error parsing JSON: ' + e.getMessage() + ' for JSON: ' + jsonString);
                 // Optionally create a result indicating error, or just return empty
                 results.add(new Result()); // Return empty result on error
            }
        } else {
             System.debug('Input JSON list is null or empty.');
             results.add(new Result()); // Return empty result
        }
        return results;
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
         // Add other fields as needed
    }
}
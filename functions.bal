import ballerina/io;
import ballerinax/azure.openai.chat;
import ballerinax/azure.openai.embeddings;
import ballerinax/pinecone.vector;

final embeddings:Client embeddingsClient = check new (
    config = {auth: {apiKey: AZURE_API_KEY}},
    serviceUrl = AZURE_SERVICE_URL
);

final vector:Client pineconeVectorClient = check new ({
    apiKey: PINECONE_API_KEY
}, serviceUrl = PINECONE_URL);

final chat:Client chatClient = check new (
    config = {auth: {apiKey: AZURE_API_KEY}},
    serviceUrl = AZURE_SERVICE_URL
);

isolated vector:QueryRequest queryRequest = {
    topK: 4,
    includeMetadata: true
};

public type Metadata record {
    string text;
};

isolated function llmChat(string query) returns string|error {

    lock {

        embeddings:Deploymentid_embeddings_body embeddingsBody = {
            input: query
        };

        final string embedding = "text-embed";

        embeddings:Inline_response_200 embeddingsResult = check embeddingsClient->/deployments/[embedding]/embeddings.post("2023-03-15-preview", embeddingsBody);

        decimal[] dec = embeddingsResult.data[0].embedding;

        float[] floatArray = [];

        foreach decimal d in dec {
            floatArray.push(<float>d);
        }

        queryRequest.vector = floatArray;

        vector:QueryResponse response = check pineconeVectorClient->/query.post(queryRequest);

        vector:QueryMatch[]? matches = response.matches;

        if (matches == null) {
            io:println("No matches found");
            return error("No matches found");
        }

        string context = "";
        foreach vector:QueryMatch data in matches {
            Metadata metadata = check data.metadata.cloneWithType();
            context = context.concat(metadata.text);
        }

        string systemPrompt = string `You are an HR Policy Assistant that provides employees with accurate answers based on company HR policies. Your responses must be clear and strictly based on the provided context. ${context}`;

        chat:CreateChatCompletionRequest chatRequest = {
            messages: [
                {
                    role: "system",
                    "content": systemPrompt
                },
                {
                    role: "user",
                    "content": query
                }
            ]
        };

        chat:CreateChatCompletionResponse chatResult = check chatClient->/deployments/["gpt4o-mini"]/chat/completions.post("2023-12-01-preview", chatRequest);
        record {|chat:ChatCompletionResponseMessage message?; chat:ContentFilterChoiceResults content_filter_results?; int index?; string finish_reason?; anydata...;|}[] choices = check chatResult.choices.ensureType();
        string? chatResponse = choices[0].message?.content;

        if (chatResponse == null) {
            return error("No chat response found");
        }

        io:println("LLM chat Response: ", chatResponse);
        return chatResponse;

    }
}

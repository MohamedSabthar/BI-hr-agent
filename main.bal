import ballerina/http;
import ballerinax/ai;

listener ai:Listener personalAssistantListener = new (listenOn = check http:getDefaultListener());

service /personalAssistant on personalAssistantListener {
    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string agentResponse = check llmChat(request.message);
        return {message: agentResponse};
    }
}

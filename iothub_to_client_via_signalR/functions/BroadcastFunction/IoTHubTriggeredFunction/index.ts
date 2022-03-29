import { AzureFunction, Context} from "@azure/functions"

const IoTHubTrigger: AzureFunction = async function (context: Context, IoTHubMessage: any): Promise<void> {
    context.log(JSON.stringify(IoTHubMessage));
    // ここがsignalRを使って送るメッセージを構築する部分
    context.bindings.signalRMessages = [{
        target:'test',
        arguments:[{message:IoTHubMessage.value,timestamp:new Date()}]
    }]
};

export default IoTHubTrigger;

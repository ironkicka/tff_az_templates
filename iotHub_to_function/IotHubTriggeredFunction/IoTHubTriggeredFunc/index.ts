import { AzureFunction, Context } from "@azure/functions"

const IoTHubTrigger: AzureFunction = async function (context: Context, IoTHubMessage: any): Promise<void> {
    context.log(JSON.stringify(IoTHubMessage));
};

export default IoTHubTrigger;

# How to use
1. Deploy
```shell
terraform plan
terraform apply
```

2. Deploy a function
   ```shell
   cd IoTHubTriggeredFunction && npm i && npm run deploy 
   ```
3. Create a device on iothub
    ```shell
    export IOTHUB_NAME=xxxx
    export DEVICE_NAME=xxxx
    az iot hub device-identity create -n $IOTHUB_NAME -d $DEVICE_NAME
    ```
4. Generate SAS token
    ```shell
    export IOTHUB_NAME=xxxx
    export EXPIRATION_SECONDS=xxxx
    az iot hub generate-sas-token -n $IOTHUB_NAME --du $EXPIRATION_SECONDS
    ```
5. Publish a message to iot-hub
    ```shell
    export SAS=xxxx
    export IOTHUB_NAME=xxxx
    export DEVICE_NAME=xxxx
    sh publish.sh
    ```

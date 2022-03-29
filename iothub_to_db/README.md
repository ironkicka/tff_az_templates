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
5. Get your private key
    ```shell
    terraform output -raw tls_private_key > secret_key.pem 
    ```

6. Connect to VM
    ```shell
    ssh -i path/to/secret_key.pem azureuser@VM_PUBLIC_IP
    ```

7. Connect to DB
    ```shell
    mysql -h terraform-db.mysql.database.azure.com -u test_db_admin -p --ssl-mode=REQUIRED --ssl-ca=DigiCertGlobalRootCA.crt.pem
    ```
8. Create table
    ```sql
    CREATE TABLE
    test_table (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        message VARCHAR(255),
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    );
    ```
9. Publish a message to iot-hub
    ```shell
    export SAS=xxxx
    export IOTHUB_NAME=xxxx
    export DEVICE_NAME=xxxx
    sh publish.sh
    ```
10. Check if a record was added
   

Other commands

- Destroy only vm and its related resources
```shell
terraform destroy -target=azurerm_linux_virtual_machine.myterraformv
```

- Get your private key
```shell
terraform output -raw tls_private_key > secret_key.pem 
```
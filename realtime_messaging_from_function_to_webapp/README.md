# How to use

- Deploy
```shell
terraform plan
terraform apply
```

- Destroy all resources
```shell
terraform destroy
```

- Generate SAS token
```shell
export IOTHUB_NAME=xxxx
export EXPIRATION_SECONDS=xxxx
az iot hub generate-sas-token -n ${IOTHUB_NAME} --du ${EXPIRATION_SECONDS}
```

- Publish a message to iot-hub
```shell
export SAS=xxxx
export IOTHUB_NAME=xxxx
export DEVICE_NAME=xxxx
sh publish.sh
```

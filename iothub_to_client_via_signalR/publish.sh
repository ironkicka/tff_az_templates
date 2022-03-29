curl -i -X POST \
-H "Content-Type:application/json" \
-H "Authorization:$SAS" \
-d '{"value":"hello,world with https"}' \
"https://$IOTHUB_NAME.azure-devices.net/devices/$DEVICE_NAME/messages/events?api-version=2018-06-30"
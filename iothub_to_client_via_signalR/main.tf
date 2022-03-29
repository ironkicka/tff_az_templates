variable "imageName" {}
variable "imageTag" {}

terraform {

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name      = "iothub-to-client-via-signalr"
  location  = var.resource_group_location
}


resource "azurerm_iothub" "my-iot-hub" {
  name = "terra-iot-hub"
  resource_group_name = azurerm_resource_group.rg.name
  location = var.resource_group_location
  sku {
    capacity = 1
    name     = "F1"
  }
}

resource "azurerm_signalr_service" "mysignalR" {
  name                = "terra-signalr"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Free_F1"
    capacity = 1
  }

  // allow access from localhost for testing purpose
  cors {
    allowed_origins = [
      "http://localhost:3000",
      "https://${azurerm_linux_web_app.myWebApp.name}.azurewebsites.net"
    ]
  }

  connectivity_logs_enabled = true
  messaging_logs_enabled    = true
  service_mode              = "Serverless"
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

resource "azurerm_storage_account" "mystorageaccount" {
  name                        = "st${random_id.randomId.hex}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                     = var.resource_group_location
  account_tier                = "Standard"
  account_replication_type    = "LRS"
}

resource "azurerm_service_plan" "myAppservicePlan" {
  name                = "my-app-service-plan-${random_id.randomId.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_application_insights" "myAppInsight" {
  name                = "tf-test-appinsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "Node.JS"
}

# never succeeded to deploy
#resource "azurerm_linux_function_app" "myFunction" {
#  name                = "my-iothub-triggerd-function"
#  resource_group_name = azurerm_resource_group.rg.name
#  location            = azurerm_resource_group.rg.location
#
#  storage_account_name = azurerm_storage_account.mystorageaccount.name
#  service_plan_id      = azurerm_service_plan.myAppservicePlan.id
#
#  site_config {
#    ftps_state = "AllAllowed"
##    application_stack {
##      node_version = 14 # could not set this value with this code.Even if I set it from Portal, the deployment still returns 400
##    }
#  }
#
#  app_settings = {
#    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.myAppInsight.connection_string
#    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.myAppInsight.instrumentation_key
#    myIoTHub = azurerm_iothub.my-iot-hub.name
#    eventHubCompatibleEndpoint = "Endpoint=${azurerm_iothub.my-iot-hub.event_hub_events_endpoint};SharedAccessKeyName=${azurerm_iothub.my-iot-hub.shared_access_policy[0].key_name};SharedAccessKey=${azurerm_iothub.my-iot-hub.shared_access_policy[0].primary_key};EntityPath=${azurerm_iothub.my-iot-hub.event_hub_events_path}"
#    FUNCTIONS_WORKER_RUNTIME ="node" #Without this you won't be able to publish function
#    WEBSITE_RUN_FROM_PACKAGE =1
#  }
#}

resource "azurerm_function_app" "myFunction" {
  name                       = "broadcast-function"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.myAppservicePlan.id
  storage_account_name       = azurerm_storage_account.mystorageaccount.name
  storage_account_access_key = azurerm_storage_account.mystorageaccount.primary_access_key
  os_type                    = "linux"
  version                    = "~4"

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.myAppInsight.connection_string
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.myAppInsight.instrumentation_key
    AzureSignalRConnectionString = azurerm_signalr_service.mysignalR.primary_connection_string
    MyEventHub = azurerm_iothub.my-iot-hub.name
    myEventHubReadConnectionAppSetting = "Endpoint=${azurerm_iothub.my-iot-hub.event_hub_events_endpoint};SharedAccessKeyName=${azurerm_iothub.my-iot-hub.shared_access_policy[0].key_name};SharedAccessKey=${azurerm_iothub.my-iot-hub.shared_access_policy[0].primary_key};EntityPath=${azurerm_iothub.my-iot-hub.event_hub_events_path}"
    FUNCTIONS_WORKER_RUNTIME ="node" #Without this you won't be able to publish function
    WEBSITE_RUN_FROM_PACKAGE =1
  }

  site_config {
    linux_fx_version = "node|14"
  }
}

resource "azurerm_function_app" "myNegotiatorFunction" {
  name                       = "negotiator-function"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.myAppservicePlan.id
  storage_account_name       = azurerm_storage_account.mystorageaccount.name
  storage_account_access_key = azurerm_storage_account.mystorageaccount.primary_access_key
  os_type                    = "linux"
  version                    = "~4"

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.myAppInsight.connection_string
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.myAppInsight.instrumentation_key
    AzureSignalRConnectionString = azurerm_signalr_service.mysignalR.primary_connection_string
    FUNCTIONS_WORKER_RUNTIME ="node" #Without this you won't be able to publish function
    WEBSITE_RUN_FROM_PACKAGE =1
  }

  site_config {
    linux_fx_version = "node|14"
    // allow access from localhost for testing purpose
    cors {
      allowed_origins = [
        "http://localhost:3000",
        "https://${azurerm_linux_web_app.myWebApp.name}.azurewebsites.net"
      ]
      support_credentials = true // needs to be true to connect signalr
    }
  }
}

resource "azurerm_linux_web_app" "myWebApp" {
  name                = "signalr-test-client-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.myAppservicePlan.location
  service_plan_id     = azurerm_service_plan.myAppservicePlan.id

  site_config {
    application_stack{
      docker_image= "${azurerm_container_registry.acr.name}.azurecr.io/${var.imageName}"
      docker_image_tag=var.imageTag
    }
  }
  app_settings = {
    DOCKER_ENABLE_CI = true # This enables continuous deployment on deployment center page
    # The following settings are required to authenticate webapp when it pulls the image;
    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "myContainerRegistry${random_id.randomId.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

#resource "null_resource" "always-running-command" {
#  triggers = {
#    always_run = timestamp()
#  }
#
#  provisioner "local-exec" {
#    command = <<EOT
#      cd functions/NegotiationFunction/ && npm run build && func azure functionapp publish ${azurerm_function_app.myNegotiatorFunction.name}
#      cd ../BroadcastFunction/ && npm run build && func azure functionapp publish ${azurerm_function_app.myFunction.name}
#    EOT
#  }
#}

resource "null_resource" "run_when_broadcastfunction_is_created" {
  triggers = {
    negotiator = azurerm_function_app.myFunction.id
  }

  provisioner "local-exec" {
    command = "cd functions/BroadcastFunction/ && npm run build && func azure functionapp publish ${azurerm_function_app.myFunction.name}"
  }

  depends_on = [
    azurerm_function_app.myFunction
  ]
}

resource "null_resource" "run_when_negotiator_is_created" {
  triggers = {
    negotiator = azurerm_function_app.myNegotiatorFunction.id
  }

  provisioner "local-exec" {
    command = "cd functions/NegotiationFunction/ && npm run build && func azure functionapp publish ${azurerm_function_app.myNegotiatorFunction.name}"
  }

  depends_on = [
    azurerm_function_app.myNegotiatorFunction
  ]
}

#resource "null_resource" "run_when_webapp_is_created" {
#  triggers = {
#    webapp = azurerm_linux_web_app.myWebApp.id
#  }
#
#  provisioner "local-exec" {
#    command = "cd webapp && az acr build --registry ${azurerm_container_registry.acr.name} --image ${var.imageName} ."
#  }
#
#  depends_on = [
#    azurerm_linux_web_app.myWebApp,
#    azurerm_container_registry.acr
#  ]
#}

output "EventHubCompatibleEndpoint" {
  value = "Endpoint=${azurerm_iothub.my-iot-hub.event_hub_events_endpoint};SharedAccessKeyName=${azurerm_iothub.my-iot-hub.shared_access_policy[0].key_name};SharedAccessKey=${azurerm_iothub.my-iot-hub.shared_access_policy[0].primary_key};EntityPath=${azurerm_iothub.my-iot-hub.event_hub_events_path}"
}
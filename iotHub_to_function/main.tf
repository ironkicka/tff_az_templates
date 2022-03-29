variable "deviceName" {}
variable "expirationSeconds" {}

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
  name      = "iothub-to-function"
  location  = var.resource_group_location
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
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

resource "azurerm_storage_account" "mystorageaccount" {
  name                        = "st${random_id.randomId.hex}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                     = var.resource_group_location
  account_tier                = "Standard"
  account_replication_type    = "LRS"

  tags = {
    environment = "Terraform Demo"
  }
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

# never succeeded to deploy iothub-triggered function code
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
  name                       = "my-iothub-triggered-function"
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
    eventHubCompatibleEndpoint = "Endpoint=${azurerm_iothub.my-iot-hub.event_hub_events_endpoint};SharedAccessKeyName=${azurerm_iothub.my-iot-hub.shared_access_policy[0].key_name};SharedAccessKey=${azurerm_iothub.my-iot-hub.shared_access_policy[0].primary_key};EntityPath=${azurerm_iothub.my-iot-hub.event_hub_events_path}"
    FUNCTIONS_WORKER_RUNTIME ="node" #Without this you won't be able to publish function
    WEBSITE_RUN_FROM_PACKAGE =1
  }

  site_config {
    linux_fx_version = "node|14"
  }
}

output "EventHubCompatibleEndpoint" {
  value = "Endpoint=${azurerm_iothub.my-iot-hub.event_hub_events_endpoint};SharedAccessKeyName=${azurerm_iothub.my-iot-hub.shared_access_policy[0].key_name};SharedAccessKey=${azurerm_iothub.my-iot-hub.shared_access_policy[0].primary_key};EntityPath=${azurerm_iothub.my-iot-hub.event_hub_events_path}"
}

output "DeviceId" {
  value = var.deviceName
}
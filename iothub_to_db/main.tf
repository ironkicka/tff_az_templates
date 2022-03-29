variable "db_password" {}
variable "db_name" {}
variable "db_user_name" {}

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
  name      = "iothub-to-db"
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

# vnet
resource "azurerm_virtual_network" "vnet1" {
  name                = "terra-net"
  location = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = ["10.0.0.0/16"]
}

# subnet
resource "azurerm_subnet" "db_subnet" {
  name                 = "default"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/24"]
  service_endpoints    = ["Microsoft.AzureCosmosDB"]
  delegation {
    name = "dlg-Microsoft.DBforMySQL-flexibleServers"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# dns_zone
resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "terraform-db.private.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

#
resource "azurerm_private_dns_zone_virtual_network_link" "pdz_vent_link" {
  name                  = "pdz-ventlink-${random_id.randomId.hex}"
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet1.id
  resource_group_name   = azurerm_resource_group.rg.name
}

# db
resource "azurerm_mysql_flexible_server" "database_server" {
  name                = "terraform-db"
  resource_group_name = azurerm_resource_group.rg.name
  location = var.resource_group_location
  administrator_login    = var.db_user_name
  administrator_password = var.db_password
  backup_retention_days  = 7
  delegated_subnet_id = azurerm_subnet.db_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.dns_zone.id
  zone = 1
  version    = "8.0.21"
  sku_name = "B_Standard_B1s"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.pdz_vent_link]
}

resource "azurerm_mysql_flexible_database" "database" {
  name                = var.db_name
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.database_server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}


// 踏み台
# Create public IPs
resource "azurerm_public_ip" "bastion_public_ip" {
  name                         = "bastionPublicIP"
  location                     = var.resource_group_location
  resource_group_name          = azurerm_resource_group.rg.name
  allocation_method            = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "bastion_sg" {
  name                = "bastionSecurityGroup"
  location                     = var.resource_group_location
  resource_group_name          = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# bastion subnet
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "bastionSubnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create network interface
resource "azurerm_network_interface" "bastion_nic" {
  name                      = "bastionNIC"
  location                     = var.resource_group_location
  resource_group_name          = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.bastion_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_public_ip.id
  }

}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.bastion_nic.id
  network_security_group_id = azurerm_network_security_group.bastion_sg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                        = "diag${random_id.randomId.hex}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                     = var.resource_group_location
  account_tier                = "Standard"
  account_replication_type    = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "bastion_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
  name                  = "myBastion"
  resource_group_name         = azurerm_resource_group.rg.name
  location                     = var.resource_group_location
  network_interface_ids = [azurerm_network_interface.bastion_nic.id]
  size                  = "Standard_B1s"

  os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name  = "mybastion"
  admin_username = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username       = "azureuser"
    public_key     = tls_private_key.bastion_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }

}

# https://stackoverflow.com/questions/54088476/terraform-azurerm-virtual-machine-extension
resource "azurerm_virtual_machine_extension" "myextension" {
  name                 = "mybastionExtension"
  virtual_machine_id   = azurerm_linux_virtual_machine.myterraformvm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${base64encode(file(var.script_file))}"
    }
  SETTINGS
}

resource "azurerm_service_plan" "myAppservicePlan" {
  name                = "my-app-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "S1"
}

# function subnet
resource "azurerm_subnet" "subnet-for-vent-integration" {
  name                 = "subnetForVnetIntegration"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "subnet-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "function_vnet_integration" {
  app_service_id = azurerm_function_app.myFunction.id
  subnet_id      = azurerm_subnet.subnet-for-vent-integration.id
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "myKeyVault" {
  name                = "terra-vault-2022"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "List",
      "Set",
      "Get",
      "Delete",
      "Purge"
    ]
  }
}

resource "azurerm_key_vault_secret" "example" {
  name         = "DB-PASSWORD"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.myKeyVault.id
}

resource "azurerm_application_insights" "myAppInsight" {
  name                = "tf-test-appinsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "Node.JS"
}

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
    myEventHubReadConnectionAppSetting = "Endpoint=${azurerm_iothub.my-iot-hub.event_hub_events_endpoint};SharedAccessKeyName=${azurerm_iothub.my-iot-hub.shared_access_policy[0].key_name};SharedAccessKey=${azurerm_iothub.my-iot-hub.shared_access_policy[0].primary_key};EntityPath=${azurerm_iothub.my-iot-hub.event_hub_events_path}"
    FUNCTIONS_WORKER_RUNTIME ="node" #Without this you won't be able to publish function
    WEBSITE_RUN_FROM_PACKAGE =1
    DB_HOST = "${azurerm_mysql_flexible_server.database_server.name}.mysql.database.azure.com"
    DB_USER_NAME = azurerm_mysql_flexible_server.database_server.administrator_login
    DB_DATABASE_NAME = var.db_name
    DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=https://${azurerm_key_vault.myKeyVault.name}.vault.azure.net/secrets/DB-PASSWORD/${azurerm_key_vault_secret.example.version})"
  }

  site_config {
    linux_fx_version = "node|14"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id = azurerm_key_vault.myKeyVault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_function_app.myFunction.identity[0].principal_id

  secret_permissions = [
    "Get",
  ]
}


# 出力関連
output "tls_private_key" {
  value = tls_private_key.bastion_ssh.private_key_pem
  sensitive = true
}

data "azurerm_public_ip" "public_ip_data" {
  name                = azurerm_public_ip.bastion_public_ip.name
  resource_group_name = azurerm_linux_virtual_machine.myterraformvm.resource_group_name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.public_ip_data.ip_address
}
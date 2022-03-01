resource "azurerm_resource_group" "example" {
  name     = "privateendpoint-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "example" {
  name                = "${var.environment}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "storage" {
  name                                           = "${var.environment}-storage-subnet"
  resource_group_name                            = azurerm_resource_group.example.name
  virtual_network_name                           = azurerm_virtual_network.example.name
  address_prefix                                 = "10.0.1.0/24"
  enforce_private_link_endpoint_network_policies = false
  // enforce_private_link_service_network_policies = false
  // service_endpoints                              = ["Microsoft.Storage"]
}  

resource "random_integer" "sa_num" {
  min = 10000
  max = 99999
}

resource "azurerm_storage_account" "example" {
  name                     = "${var.adoit_number}${lower(var.environment)}${random_integer.sa_num.result}"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
  tags                      = local.common_tags
}

resource "azurerm_storage_container" "example" {
  name                  = "acctestcont"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "example" {
  name                = "${var.environment}-pe"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.storage.id

  private_service_connection {
    name                           = "${var.environment}-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.example.id
    subresource_names              = ["blob"]
  }

}

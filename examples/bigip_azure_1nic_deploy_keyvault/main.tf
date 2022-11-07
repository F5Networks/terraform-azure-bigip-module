provider "azurerm" {
  //  version = "~>2.0"
  features {}
}

#
# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}

data "azurerm_client_config" "current" {
}

#
# Create a resource group
#
resource "azurerm_resource_group" "rg" {
  name     = format("%s-rg-%s", var.prefix, random_id.id.hex)
  location = var.location
}

resource "azurerm_ssh_public_key" "f5_key" {
  name                = format("%s-pubkey-%s", var.prefix, random_id.id.hex)
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  public_key          = file("~/.ssh/id_rsa.pub")
}

resource "azurerm_resource_group" "keyvalrg" {
  name     = format("%s-kvrg-%s", var.prefix, random_id.id.hex)
  location = var.location
}

resource "azurerm_user_assigned_identity" "user_identity" {
  name                = format("%s-user-iden-%s", var.prefix, random_id.id.hex)
  resource_group_name = azurerm_resource_group.keyvalrg.name
  location            = azurerm_resource_group.keyvalrg.location
}

resource "azurerm_key_vault" "key_vault" {
  name                        = format("keyvalbigip%s", random_id.id.hex)
  location                    = azurerm_resource_group.keyvalrg.location
  resource_group_name         = azurerm_resource_group.keyvalrg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7


  # Allows Terraform to create the the secret
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get"
    ]

    secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"]

    storage_permissions = [
      "Get"
    ]
  }

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

#
# Create random password for BIG-IP
#
resource "random_string" "keyvaultpasswd" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}


resource "azurerm_key_vault_secret" "adminsecret" {
  name         = "bigIpPass"
  value        = random_string.keyvaultpasswd.result
  key_vault_id = azurerm_key_vault.key_vault.id

}

#
#Create N-nic bigip
#
module "bigip" {
  count                       = var.instance_count
  source                      = "../../"
  prefix                      = format("%s-1nic", var.prefix)
  resource_group_name         = azurerm_resource_group.rg.name
  f5_ssh_publickey            = azurerm_ssh_public_key.f5_key.public_key
  az_key_vault_authentication = var.az_key_vault_authentication
  azure_secret_rg             = var.az_key_vault_authentication ? azurerm_resource_group.keyvalrg.name : ""
  azure_keyvault_name         = var.az_key_vault_authentication ? azurerm_key_vault.key_vault.name : ""
  azure_keyvault_secret_name  = var.az_key_vault_authentication ? azurerm_key_vault_secret.adminsecret.name : ""
  mgmt_subnet_ids             = [{ "subnet_id" = data.azurerm_subnet.mgmt.id, "public_ip" = true, "private_ip_primary" = "" }]
  mgmt_securitygroup_ids      = [module.mgmt-network-security-group.network_security_group_id]
  availability_zone           = var.availability_zone
  availabilityZones_public_ip = var.availabilityZones_public_ip
}


resource "null_resource" "clusterDO" {

  count = var.instance_count

  provisioner "local-exec" {
    command = "cat > DO_1nic-instance${count.index}.json <<EOL\n ${module.bigip[count.index].onboard_do}\nEOL"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf DO_1nic-instance${count.index}.json"
  }
  depends_on = [module.bigip.onboard_do]
}


#
# Create the Network Module to associate with BIGIP
#

module "network" {
  source              = "Azure/vnet/azurerm"
  version             = "3.0.0"
  vnet_name           = format("%s-vnet-%s", var.prefix, random_id.id.hex)
  resource_group_name = azurerm_resource_group.rg.name
  vnet_location       = var.location
  address_space       = [var.cidr]
  subnet_prefixes     = [cidrsubnet(var.cidr, 8, 1)]
  subnet_names        = ["mgmt-subnet"]

  tags = {
    environment = "dev"
    costcenter  = "it"
  }
}

data "azurerm_subnet" "mgmt" {
  name                 = "mgmt-subnet"
  virtual_network_name = module.network.vnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  depends_on           = [module.network]
}

#
# Create the Network Security group Module to associate with BIGIP-Mgmt-Nic
#
module "mgmt-network-security-group" {
  source              = "Azure/network-security-group/azurerm"
  resource_group_name = azurerm_resource_group.rg.name
  security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  tags = {
    environment = "dev"
    costcenter  = "terraform"
  }
}

resource "azurerm_network_security_rule" "mgmt_allow_https" {
  name                        = "Allow_Https"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  destination_address_prefix  = "*"
  source_address_prefixes     = var.AllowedIPs
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  depends_on                  = [module.mgmt-network-security-group]
}
resource "azurerm_network_security_rule" "mgmt_allow_http" {
  name                        = "Allow_Http"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  source_address_prefixes     = var.AllowedIPs
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  depends_on                  = [module.mgmt-network-security-group]
}
resource "azurerm_network_security_rule" "mgmt_allow_ssh" {
  name                        = "Allow_ssh"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  destination_address_prefix  = "*"
  source_address_prefixes     = var.AllowedIPs
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  depends_on                  = [module.mgmt-network-security-group]
}

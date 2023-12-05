terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.71.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Configuration options
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config.html
data "azurerm_client_config" "current" {}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "vnet" {
  name = var.vnet_name
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = var.vnet_address_space
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "snet_common" {
  name = var.snet_common_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_common_cidr]

  service_endpoints = [
    "Microsoft.KeyVault"
  ]
}

resource "azurerm_subnet" "snet_apim" {
  name = var.snet_apim_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_apim_cidr]

  service_endpoints = [
    "Microsoft.KeyVault"
  ]
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_security_group.html
resource "azurerm_network_security_group" "nsg_common" {
  name                = "nsg-common"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "nsg_apim" {
  name                = "nsg-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule
# https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet?tabs=stv2#configure-nsg-rules
resource "azurerm_network_security_rule" "apim_management_3443" {
  name                        = "Allow-APIM-Management-3443"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "ApiManagement"
  destination_port_range      = "3443"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_apim.name
}

resource "azurerm_network_security_rule" "apim_lb_6390" {
  name                        = "Allow-APIM-LB-6390"
  priority                    = 1020
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_port_range      = "6390"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_apim.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
resource "azurerm_subnet_network_security_group_association" "snet_nsg_common" {
  subnet_id                 = azurerm_subnet.snet_common.id
  network_security_group_id = azurerm_network_security_group.nsg_common.id
}

resource "azurerm_subnet_network_security_group_association" "snet_nsg_apim" {
  subnet_id                 = azurerm_subnet.snet_apim.id
  network_security_group_id = azurerm_network_security_group.nsg_apim.id
}
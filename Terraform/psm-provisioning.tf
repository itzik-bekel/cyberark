variable "client_id" {
}
variable "client_secret" {
}
variable "tenant_id" {
}
variable "subscription_id" {
}
variable "location" {
    default = "East US"
}
variable "vmname" {
}
variable "vm_password" {
}
variable "vm_size" {
  default = "Standard_DS3_V2"
}


# Example "10.0.3.1/32"
variable "client_ip_addresses" {
  default = null
}
variable "managed_image_id" {
}

provider "azurerm" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.vmname}-rg"
  location = var.location
}

resource "azurerm_application_security_group" "main" {
  name                = "PSM-ASG"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

output "psm-asm-id" {
  value = "${azurerm_application_security_group.main.id}"
}

resource "azurerm_network_security_group" "main" {
  name                = "PSM-NSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags = {
    environment = "development"
  }
}

resource "azurerm_network_security_rule" "first" {
  name                        = "Allow-RDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = var.client_ip_addresses
  destination_application_security_group_ids = [azurerm_application_security_group.main.id]
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
  description                 = "Allow RDP from Client IP"
}
resource "azurerm_network_security_rule" "second" {
  name                        = "Allow-From-Vault"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1858"
  source_address_prefix       = "VirtualNetwork" #ToDo - change to Vault ASG
  destination_application_security_group_ids = [azurerm_application_security_group.main.id]
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}
resource "azurerm_network_security_rule" "third" {
  name                        = "Allow-To-Vault"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1858"
  source_application_security_group_ids = [azurerm_application_security_group.main.id]
  destination_address_prefix  = "VirtualNetwork" #ToDo - change to Vault ASG
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}
resource "azurerm_virtual_network" "main" {
  name                = "${var.vmname}-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "psm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_public_ip" "vmpip" {
  name                    = "${var.vmname}-pip"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "development"
  }
}

resource "azurerm_network_interface" "main" {
  name                = "${var.vmname}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig01"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vmpip.id
  }
}

resource "azurerm_network_interface_application_security_group_association" "example" {
  network_interface_id          = azurerm_network_interface.main.id
  application_security_group_id = azurerm_application_security_group.main.id
}
resource "azurerm_windows_virtual_machine" "main" {
  name                  = "${var.vmname}-vm"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  size               = var.vm_size
  admin_username = "cyberark-admin"
  admin_password = var.vm_password
  source_image_id = var.managed_image_id
  enable_automatic_updates = true
  os_disk {
    caching           = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  tags = {
    environment = "development"
    executed_by = "ItzikB"
  }
}


##################################################################################
# VARIABLES
##################################################################################

variable "arm_subscription_id" {}
variable "arm_principal" {}
variable "arm_password" {}
variable "tenant_id" {}

variable "instance_count" {
  default = 1
}

variable "vm_hostname" {
  description = "local name of the Virtual Machine."
  type        = string
  default     = "coba"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "azurerm" {
  version = "~>2.0"
  subscription_id = var.arm_subscription_id
  client_id       = var.arm_principal
  client_secret   = var.arm_password
  tenant_id       = var.tenant_id
  features {}
}

##################################################################################
# RESOURCES
##################################################################################

# Create Resource Group
resource "azurerm_resource_group" "arm_rg" {
    name     = "pentestRG"
    location = "westeurope"

    tags = {
        environment = "Pentest"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "arm_net" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.arm_rg.name

    tags = {
        environment = "Pentest"
    }
}

resource "azurerm_subnet" "arm_subnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.arm_rg.name
    virtual_network_name = azurerm_virtual_network.arm_net.name
    address_prefixes       = ["10.0.2.0/24"]
}


######### Create Azure VMs

# Create virtual machine

# Create (and display) an SSH key
resource "tls_private_key" "arm_ssh_key" {

  algorithm = "RSA"
  rsa_bits = 4096
}

# Create public IP address
resource "azurerm_public_ip" "pip" {
  
    name                         = "${var.vm_hostname}-pip"
    location                     = "westeurope"
    resource_group_name          = azurerm_resource_group.arm_rg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Pentest"
    }
}

# Create Network Security Group

resource "azurerm_network_security_group" "arm_nsg" {

    name                = "${var.vm_hostname}-nsg"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.arm_rg.name

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

        security_rule {
        name                       = "HTTPS"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Pentest"
    }
}

# Create virtual network interface card

resource "azurerm_network_interface" "arm_nic" {

  count = var.instance_count

    name                        = "${var.vm_hostname}-nic-${count.index}"
    location                    = "westeurope"
    resource_group_name         = azurerm_resource_group.arm_rg.name

    ip_configuration {
        name                          = "${var.vm_hostname}-ip-${count.index}"
        subnet_id                     = azurerm_subnet.arm_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.pip.id
    }

    tags = {
        environment = "Pentest"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "arm_connect" {

  count = var.instance_count

  network_interface_id = azurerm_network_interface.arm_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.arm_nsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "arm_vm" {

  count = var.instance_count

    name                  = "${var.vm_hostname}-vmLinux-${count.index}"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.arm_rg.name
    network_interface_ids = [element(azurerm_network_interface.arm_nic.*.id, count.index)]
    size                  = "Standard_B2s"

    os_disk {
        name              = "osdisk-${var.vm_hostname}-${count.index}"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "${var.vm_hostname}-${count.index}"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.arm_ssh_key.public_key_openssh        
    }

    tags = {
        environment = "Pentest"
    }

    ############ Set up Cobalt


    provisioner "remote-exec" {
      inline = [
        "sudo apt update",
        "sudo apt -y install openjdk-11-jre-headless"
      ]

      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }

    provisioner "file" {
      source = "./configs/cs.tar"
      destination = "/home/azureuser/cs.tar.gz"

      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }

    provisioner "remote-exec" {
      inline = [
        "tar -xvf /home/azureuser/cs.tar.gz"
      ]

      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }
}

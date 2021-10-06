##################################################################################
# VARIABLES
##################################################################################

variable "arm_subscription_id" {}
variable "arm_principal" {}
variable "arm_password" {}
variable "tenant_id" {}

variable "site_domain_name" {}
variable "cobalt_server_ip" {}

variable "instance_count" {
  default = 1
}

variable "vm_hostname" {
  description = "local name of the Virtual Machine."
  type        = string
  default     = "redir"
}

variable "arm_resource_group" {}
variable "arm_subnet_id" {}

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
    resource_group_name          = var.arm_resource_group
    allocation_method            = "Dynamic"

    tags = {
        environment = "Pentest"
    }
}

# Create Network Security Group

resource "azurerm_network_security_group" "redir_nsg" {

    name                = "${var.vm_hostname}-nsg"
    location            = "westeurope"
    resource_group_name = var.arm_resource_group

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

        security_rule {
        name                       = "HTTP"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Pentest"
    }
}

# Create virtual network interface card

resource "azurerm_network_interface" "redir_nic" {

  count = var.instance_count

    name                        = "${var.vm_hostname}-nic-${count.index}"
    location                    = "westeurope"
    resource_group_name         = var.arm_resource_group

    ip_configuration {
        name                          = "${var.vm_hostname}-ip-${count.index}"
        subnet_id                     = var.arm_subnet_id
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

  network_interface_id = azurerm_network_interface.redir_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.redir_nsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "redir_vm" {

  count = var.instance_count

    name                  = "${var.vm_hostname}-vmLinux-${count.index}"
    location              = "westeurope"
    resource_group_name   = var.arm_resource_group
    network_interface_ids = [element(azurerm_network_interface.redir_nic.*.id, count.index)]
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
        public_key = tls_private_key.arm_ssh_key.public_key_openssh
    }

    tags = {
        environment = "Pentest"
    }

    ######## Set up NGINX

    provisioner "remote-exec" {
      inline = [
        "sudo apt update", 
        "sudo apt -y install nginx"
      ]

      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }

    provisioner "file" {
      source = "./configs/default"
      destination = "/tmp/default"
    
      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }

    provisioner "file" {
      source = "./configs/keystore-build.sh"
      destination = "/tmp/keystore-build.sh"

      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }

    provisioner "file" {
      source = "./configs/site.tar.gz"
      destination = "/tmp/site.tar.gz"

      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }

    provisioner "remote-exec" {
      inline = [
      "sudo service nginx start",
      "sudo snap install certbot --classic",
      "sudo mv /tmp/default /etc/nginx/sites-enabled/default",
      "sed -i 's/<COBALT_SERVER_IP>/${var.cobalt_server_ip}/' /tmp/keystore-build.sh",
      "sed -i 's/<DOMAIN>/${var.site_domain_name}/' /tmp/keystore-build.sh",
      "sudo apt -y update && sudo apt install -y openjdk-11-jre-headless",
      "sudo chmod +x /tmp/keystore-build.sh && sudo /tmp/keystore-build.sh",
      "sudo service nginx restart",
      "tar -xvf /tmp/site.tar.gz && cd payroll-services && sudo cp -r * /var/www/html",
      "sudo sed -i 's/\\[cat-site-url\\]/${var.site_domain_name}/' /var/www/html/index.html && sudo sed -i 's/\\[cat-site-name\\]/${var.site_domain_name}/' /var/www/html/index.html"
      ]

      connection {
        type        = "ssh"
        host        = self.public_ip_address
        user        = "azureuser"
        private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
      }
    }
}
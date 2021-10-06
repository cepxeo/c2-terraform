output "azure_instance_public" { value = [azurerm_linux_virtual_machine.arm_vm.*.public_ip_address] }

output "azurerm_subnet_id" { value = "${azurerm_subnet.arm_subnet.id}"}

resource "local_file" "private_key" {
  content         = tls_private_key.arm_ssh_key.private_key_pem
  filename        = "cobalt-key.pem"
}
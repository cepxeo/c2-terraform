output "tls_private_key" { value = tls_private_key.redir_ssh_key.private_key_pem }

output "azure_instance_public" {
  value = [azurerm_linux_virtual_machine.redir_vm.*.public_ip_address]
}
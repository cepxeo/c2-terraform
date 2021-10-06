output "azure_instance_public" {
  value = [azurerm_linux_virtual_machine.redir_vm.*.public_ip_address]
}

resource "local_file" "private_key" {
  content         = tls_private_key.arm_ssh_key.private_key_pem
  filename        = "redir-key.pem"
}
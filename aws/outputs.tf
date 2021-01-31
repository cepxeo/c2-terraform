output "tls_private_key" { value = tls_private_key.redir_ssh_key.private_key_pem }

output "aws_instance_public" {
  value = [ 
    "aws_instance_public_dns ${aws_instance.nginx.public_dns}",
    "aws_instance_public_IP ${aws_instance.nginx.public_ip}"
  ]
}
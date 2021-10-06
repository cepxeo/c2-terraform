##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "region" {}
variable "site_domain_name" {}
variable "cobalt_server_ip" {}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# RESOURCES
##################################################################################

######### Create first redirector AWS

resource "aws_default_vpc" "default" {

}

resource "aws_security_group" "allow_ssh" {
  name        = "nginx"
  description = "Allow ports for nginx"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an SSH key
resource "tls_private_key" "arm_ssh_key" {

  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = "${tls_private_key.arm_ssh_key.public_key_openssh}"
}

resource "aws_instance" "nginx" {
  ami                    = "ami-092391a11f8aa4b7b"
  instance_type          = "t2.micro"
  key_name      = "ssh-key"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = "${tls_private_key.arm_ssh_key.private_key_pem}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt -y install nginx"
    ]
  }

  provisioner "file" {
    source = "./configs/default"
    destination = "/tmp/default"
  }

  provisioner "file" {
    source = "./configs/keystore-build.sh"
    destination = "/tmp/keystore-build.sh"
  }

  provisioner "file" {
    source = "./configs/site.tar.gz"
    destination = "/tmp/site.tar.gz"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service nginx start",
      "sudo apt -y install certbot",
      "sudo mv /tmp/default /etc/nginx/sites-enabled/default",
      "sed -i 's/<COBALT_SERVER_IP>/${var.cobalt_server_ip}/' /tmp/keystore-build.sh",
      "sed -i 's/<DOMAIN>/${var.site_domain_name}/' /tmp/keystore-build.sh",
      "sudo chmod +x /tmp/keystore-build.sh; sudo /tmp/keystore-build.sh",
      "sudo service nginx restart",
      "tar -xvf /tmp/site.tar.gz && cd payroll-services && sudo cp -r * /var/www/html",
      "sudo sed -i 's/\\[cat-site-url\\]/${var.site_domain_name}/' /var/www/html/index.html && sudo sed -i 's/\\[cat-site-name\\]/${var.site_domain_name}/' /var/www/html/index.html"
    ]  
  }
}

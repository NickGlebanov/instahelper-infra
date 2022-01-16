terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.7.0"
    }
  }
}

# Ищем образ с последней версией Ubuntu
data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Указываем, что мы хотим разворачивать окружение в AWS
provider "aws" {
  region = "eu-central-1"
}

resource "aws_eip" "server" {
  instance = aws_instance.web.id
}


provider "cloudflare" {
  email     = "n.n.glebanov@gmail.com"
  api_token = "CNRQbfDUSJEsWhur29xiEHRyEjNjzOy5I5IwNLe1"
}

variable "domain" {
  default = "diplomproj.ru"
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]
  user_data              = <<-EOF
#!/bin/bash
echo "Hello, World" > index.html
nohup busybox httpd -f -p 8080 &
EOF


}

resource "cloudflare_record" "www" {
  zone_id = "cc965f05e57b7751af5448a0d15ac29f"
  name    = "www"
  value   = aws_eip.server.public_ip
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "root" {
  zone_id = "cc965f05e57b7751af5448a0d15ac29f"
  name    = var.domain
  value   = aws_eip.server.public_ip
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "test" {
  zone_id = "cc965f05e57b7751af5448a0d15ac29f"
  name    = "test"
  value   = aws_eip.server.public_ip
  type    = "A"
  proxied = true
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

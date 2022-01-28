terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.7.0"
    }
  }
  backend "remote" {
    organization = "skillboxngdiplom"

    workspaces {
      name = "infra2"
    }
  }

}

variable "cloudflare_api_token" {
  type = string
}

variable "email" {
  type = string
}

variable "domain" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "aws_zone" {
  type = string
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


data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnet" "dest" {
  count = length(data.aws_subnet_ids.default.ids)
  id    = tolist(data.aws_subnet_ids.default.ids)[count.index]
}

# Указываем, что мы хотим разворачивать окружение в AWS
provider "aws" {
  region = var.aws_zone
}

provider "cloudflare" {
  email     = var.email
  api_token = var.cloudflare_api_token
}

resource "aws_instance" "backend_1" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.backend.id]
  key_name        = "id_rsa"

  subnet_id       = data.aws_subnet.dest[1].id
  tags = {
    key                 = "Name"
    value               = "Service instance"
    propagate_at_launch = true
  }
}

resource "aws_instance" "backend_2" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.backend.id]
  key_name        = "id_rsa"

  subnet_id       = data.aws_subnet.dest[0].id
  tags = {
    key                 = "Name"
    value               = "Service instance"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "backend" {
  name = "backend security 2"
  dynamic ingress {
    for_each = [22, 8080, 9100, 9115]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
      protocol    = "tcp"
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# балансер

resource "aws_lb" "main" {
  name               = "terraform-backend-balancer"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.alb.id]
  internal           = false
  load_balancer_type = "application"

}readme update

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404"
      status_code  = 404
    }
  }
}

resource "aws_eip" "backend_1_ip" {
  instance = aws_instance.backend_1.id
  vpc      = true
}

resource "aws_eip" "backend_2_ip" {
  instance = aws_instance.backend_2.id
  vpc      = true
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}
resource "aws_security_group" "alb" {
  name = "balancer security 2"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-backend"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "cloudflare_record" "www" {
  name    = "www"
  value   = aws_lb.main.dns_name
  type    = "CNAME"
  proxied = true
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_record" "root" {
  name    = var.domain
  value   = aws_lb.main.dns_name
  type    = "CNAME"
  proxied = true
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_record" "test" {
  name    = "test"
  value   = aws_lb.main.dns_name
  type    = "CNAME"
  proxied = true
  zone_id = var.cloudflare_zone_id
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The domain name of the load balancer"
}

output "ip1" {
  value = aws_eip.backend_1_ip.public_ip
}

output "ip2" {
  value = aws_eip.backend_2_ip.public_ip
}

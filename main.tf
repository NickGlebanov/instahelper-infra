terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.7.0"
    }
  }
}

variable "domain" {
  default = "diplomproj.ru"
}

variable "cloudflare_zone_id" {
  default = "cc965f05e57b7751af5448a0d15ac29f"
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

# Указываем, что мы хотим разворачивать окружение в AWS
provider "aws" {
  region = "eu-central-1"
}

provider "cloudflare" {
  email     = "n.n.glebanov@gmail.com"
  api_token = "CNRQbfDUSJEsWhur29xiEHRyEjNjzOy5I5IwNLe1"
}

resource "aws_security_group" "backend" {
  name = "backend security 2"
  dynamic ingress {
    for_each = [22, 80]
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

#конфигурация серверов входящих в автоскейлинг группу
resource "aws_launch_configuration" "example" {
  image_id        = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.backend.id]
  key_name        = "id_rsa"
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids
  target_group_arns    = [aws_lb_target_group.asg.arn]

  tag {
    key                 = "Name"
    value               = "Service instance"
    propagate_at_launch = true
  }
  # Требуется при использовании группы автомасштабирования
  # в конфигурации запуска.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}


# балансер

resource "aws_lb" "main" {
  name               = "terraform-asg-example"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.alb.id]
  internal           = false
  load_balancer_type = "application"

}

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
  port     = 80
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

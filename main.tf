provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "LBWebServer1" {
  ami                         = "ami-02c21308fed24a8ab"
  instance_type               = "t2.micro"
  key_name                    = "LBserverKP"
  associate_public_ip_address = true
  user_data                   = <<EOF
  "#!/bin/bash
  sudo su
  yum update -y
  yum install httpd -y
  systemctl start httpd
  systemctl enable httpd
  echo "<html><h1> Welcome to Luca's 1st server! </h1><html>" >> /var/www/html/index.html"
  EOF
  tags = {
    name = "LBWebServer1"
  }
}

resource "aws_instance" "LBWebServer2" {
  ami                         = "ami-02c21308fed24a8ab"
  instance_type               = "t2.micro"
  key_name                    = "LBserverKP"
  associate_public_ip_address = true
  user_data                   = <<EOF
  #!/bin/bash
  sudo su
  yum update -y
  yum install httpd -y
  systemctl start httpd
  systemctl enable httpd
  echo "<html><h1> Welcome to Luca's 2nd server! </h1><html>" >> /var/www/html/index.html"
  EOF
  tags = {
    name = "LBWebServer2"
  }
}

resource "aws_security_group" "LBserverSG" {
  description = "Luca's Server SG"
  tags = {
    Name = "LBserverSG"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "LucaWAFvpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "LucaWAFsn"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.LBserverSG.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 22
  ip_protocol       = "ssh"
  to_port           = 22
  description       = "allows ssh"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.LBserverSG.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 8080
  ip_protocol       = "http"
  to_port           = 8080
  description       = "allows http"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.LBserverSG.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  ip_protocol       = "https"
  to_port           = 443
  description       = "allows https"
}

resource "aws_lb_target_group" "LB-WAF-TG" {
  name     = "LB-WAF-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb" "LB-WAF-ALB" {
  name               = "LB-WAF-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.LBserverSG]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = true

  tags = {
    Name = "LB-WAF-ALB"
  }
}

resource "aws_lb_listener" "LB-WAF-ALB" {
  load_balancer_arn = aws_lb.LB-WAF-ALB.arn
  port              = "8080"
  protocol          = "HTTP"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.LB-WAF-TG.arn
  }
}
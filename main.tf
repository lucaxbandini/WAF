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

resource "aws_security_group" "LBserverSG2" {
  description = "Luca's Server SG2"
  tags = {
    Name = "LBserverSG2"
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

resource "aws_security_group_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.LBserverSG.id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  type              = "ingress"
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  description       = "allows ssh"
}

resource "aws_security_group_rule" "allow_http_ipv4" {
  security_group_id        = aws_security_group.LBserverSG.id
  source_security_group_id = aws_security_group.LBserverSG2.id
  type                     = "ingress"
  from_port                = 80
  protocol                 = "tcp"
  to_port                  = 80
  description              = "allows http"
}

resource "aws_security_group_rule" "lb_allow_http_ipv4" {
  security_group_id = aws_security_group.LBserverSG2.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "ingress"
  from_port         = 80
  protocol          = "tcp"
  to_port           = 80
  description       = "allows http"
}

resource "aws_lb_target_group" "LB-WAF-TG" {
  name     = "LB-WAF-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "LB-WAF-TG-EC2-1" {
  target_group_arn = aws_lb_target_group.LB-WAF-TG.arn
  target_id        = aws_instance.LBWebServer1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "LB-WAF-TG-EC2-2" {
  target_group_arn = aws_lb_target_group.LB-WAF-TG.arn
  target_id        = aws_instance.LBWebServer2.id
  port             = 80
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
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.LB-WAF-TG.arn
  }
}


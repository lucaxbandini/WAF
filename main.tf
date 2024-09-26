provider "aws" {

  region = "us-east-1"
}

resource "aws_instance" "LBWebServer1" {
  ami           = "ami-02c21308fed24a8ab"
  instance_type = "t2.micro"
  key_name      = "LBserverKP"

  network_interface {
    network_interface_id = aws_network_interface.server1.id
    device_index         = 0
  }

  user_data = <<EOF
  #!/bin/bash
  sudo su
  yum update -y
  yum install httpd -y
  systemctl start httpd
  systemctl enable httpd
  echo "<html><h1> Welcome to Luca's 1st server! </h1><html>" >> /var/www/html/index.html
  EOF
  tags = {
    name = "LBWebServer1"
  }
}

resource "aws_instance" "LBWebServer2" {
  ami           = "ami-02c21308fed24a8ab"
  instance_type = "t2.micro"
  key_name      = "LBserverKP"

  network_interface {
    network_interface_id = aws_network_interface.server2.id
    device_index         = 0
  }

  user_data = <<EOF
  #!/bin/bash
  sudo su
  yum update -y
  yum install httpd -y
  systemctl start httpd
  systemctl enable httpd
  echo "<html><h1> Welcome to Luca's 2nd server! </h1><html>" >> /var/www/html/index.html
  EOF
  tags = {
    name = "LBWebServer2"
  }
}

resource "aws_security_group" "LBserverSG" {
  description = "Luca Server SG"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "LBserverSG"
  }
}

resource "aws_security_group" "LBserverSG2" {
  description = "Luca Server SG2"
  vpc_id      = aws_vpc.main.id
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
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "LucaWAFsn1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "LucaWAFsn2"
  }
}

resource "aws_network_interface" "server1" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.LBserverSG.id]

  tags = {
    Name = "primary_network_interface1"
  }
}

resource "aws_network_interface" "server2" {
  subnet_id       = aws_subnet.public2.id
  security_groups = [aws_security_group.LBserverSG.id]

  tags = {
    Name = "primary_network_interface2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
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

resource "aws_security_group_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.LBserverSG.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
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
  name        = "LB-WAF-TG"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "LB-WAF-TG-EC2-1" {
  target_group_arn = aws_lb_target_group.LB-WAF-TG.arn
  target_id        = aws_network_interface.server1.private_ip
  port             = 80
}

resource "aws_lb_target_group_attachment" "LB-WAF-TG-EC2-2" {
  target_group_arn = aws_lb_target_group.LB-WAF-TG.arn
  target_id        = aws_network_interface.server2.private_ip
  port             = 80
}

resource "aws_lb" "LB-WAF-ALB" {
  name               = "LB-WAF-ALB"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.LBserverSG.id]
  subnets         = [aws_subnet.public.id, aws_subnet.public2.id]

  enable_deletion_protection = false

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

resource "aws_wafv2_web_acl" "ruleset" {
  name        = "luca_web_acl_rules"
  description = "Rules for IP Reputation, Anonymous IPs, Core Rule Set, and Known Bad Inputs"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "ip-reputation-list"
    priority = 1

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ip-reputation-metrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "anonymous-ip-list"
    priority = 2

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "anonymous-ip-metrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "core-rule-set"
    priority = 3

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "core-rule-set-metrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "known-bad-inputs"
    priority = 4

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "known-bad-inputs-metrics"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Tag1 = "Security"
    Tag2 = "WAFv2"
  }

  token_domains = ["mywebsite.com", "myotherwebsite.com"]

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "web-acl-metrics"
    sampled_requests_enabled   = true
  }
}

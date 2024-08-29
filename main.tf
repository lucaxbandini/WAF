provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "LBWebServer1" {
  ami           = "ami-02c21308fed24a8ab"
  instance_type = "t2.micro"
  key_name      = "LBserverKP"
  tags = {
    name = "LBWebServer1"
  }
}

resource "aws_instance" "LBWebServer2" {
  ami           = "ami-02c21308fed24a8ab"
  instance_type = "t2.micro"
  key_name      = "LBserverKP"
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

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 0
  ip_protocol       = "ssh"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 0
  ip_protocol       = "http"
  to_port           = 8080
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.allow_https.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 0
  ip_protocol       = "https"
  to_port           = 443
}
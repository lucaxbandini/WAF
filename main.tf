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
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

resource "aws_vpc" "nginx_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"
  instance_tenancy     = "default"
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.nginx_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-central-1a"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nginx_vpc.id
}

resource "aws_route_table" "public_crt" {
  vpc_id = aws_vpc.nginx_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public CRT"
  }
}

resource "aws_route_table_association" "crta_public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_crt.id
}

resource "aws_security_group" "nginx_sg" {
  vpc_id = aws_vpc.nginx_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-09042b2f6d07d164a"
  instance_type = "t2.micro"

  tags = {
    Name = "nginx_server"
  }

  subnet_id = aws_subnet.public_1.id

  vpc_security_group_ids = ["${aws_security_group.nginx_sg.id}"]

  user_data = <<EOF
#!/bin/bash

# install nginx
apt-get update
apt-get -y install nginx

# make sure nginx is started
service nginx start
EOF

}

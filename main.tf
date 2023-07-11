resource "aws_vpc" "simonvpc" {
  cidr_block       = "192.168.0.0/24"
  instance_tenancy = "default"

  tags = {
    Name = "simonvpc"
  }
}

resource "aws_internet_gateway" "simonigw" {
  vpc_id = aws_vpc.simonvpc.id

  tags = {
    Name = "simonigw"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.simonvpc.id
  cidr_block = "192.168.0.0/28"

  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.simonvpc.id
  cidr_block = "192.168.0.16/28"

  tags = {
    Name = "private"
  }
}


resource "aws_route_table" "simonrt" {
  vpc_id = aws_vpc.simonvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.simonigw.id
  }

    tags = {
    Name = "simonrt"
  }
}

resource "aws_route_table_association" "rt_associate" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.simonrt.id
}



resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http from vpc"
  vpc_id      = aws_vpc.simonvpc.id

   ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

   }
} 

provider "aws" {
  access_key = "AKIAWZZ73FKZYGBEJTMJ"
  secret_key = "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"
  region     = "eu-west-2"
}



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
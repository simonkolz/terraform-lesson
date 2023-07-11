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


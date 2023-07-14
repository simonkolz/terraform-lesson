resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    instance_tenancy = "default"
    tags = {
        Name = "osivaya-vpc"
        automated = "yes"
    
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "osivaya-igw"
        automated = "yes"
    }    
        
}


resource "aws_subnet" "public-subnets" {
    count = 3
    vpc_id = aws_vpc.main.id
    cidr_block = element((var.cidrs), count.index)
    availability_zone = element((var.az), count.index)

     tags = {
        Name = "${element(var.public_subnet, count.index)}"
     }
}

resource "aws_subnet" "private-subnets" {
   count = 3
    vpc_id = aws_vpc.main.id
    availability_zone = element((var.az), count.index) 
    cidr_block = element((var.privatecidrs), count.index)
   
    tags = {
        Name = "${element(var.private_subnet, count.index)}"
    }
}

resource "aws_route_table" "main" {
    count = 3
    vpc_id = aws_vpc.main.id
    
    tags = {
        Name = "${element(var.route-names, count.index)}-routes"
    }

}

resource "aws_route" "main" {
    count = 3
    destination_cidr_block = "0.0.0.0/0"
    route_table_id = element(aws_route_table.main.*.id, count.index)
    gateway_id = aws_internet_gateway.main.id
}


resource "aws_route_table_association" "main" {
    count = 3
    subnet_id = element((aws_subnet.public-subnets.*.id), count.index)
    route_table_id = element(aws_route_table.main.*.id, count.index)
}

resource "aws_security_group" "main" {
    name = "allow_tls"
    description = "Allow TLS inbound traffic"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "HTTP from VPC"
        from_port   = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTPS from VPC"
        from_port   = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

    }
    egress {
        description = "HTTP from VPC"
        from_port   = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

}
resource "aws_instance" "main" {
    count = 3
    ami = "ami-0eb260c4d5475b901"
    key_name = "dev"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.main.id]
    user_data = filebase64("script.sh")
    associate_public_ip_address = true 
    
    subnet_id = element(aws_subnet.public-subnets.*.id, count.index)


    tags = {
        Name = "${element(var.public_subnet, count.index)}-instance"
    }
}

resource "aws_lb_target_group" "main" {
  name     = "simon-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "main" {
    count = 3
    target_group_arn = aws_lb_target_group.main.arn
    target_id = element(aws_instance.main.*.id, count.index)
    port = 80
}

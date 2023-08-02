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
    map_public_ip_on_launch = true

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
    name = "alloxw_tls"
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
# resource "aws_instance" "main" {
#     count = 3
#     ami = "ami-0eb260c4d5475b901"
#     key_name = "true"
#     instance_type = "t2.micro"
#     vpc_security_group_ids = [aws_security_group.main.id]
#     user_data = filebase64("script.sh")
#     associate_public_ip_address = true 
    
#     subnet_id = element(aws_subnet.public-subnets.*.id, count.index)


#     tags = {
#         Name = "${element(var.public_subnet, count.index)}-instance"
#     }


# }

resource "aws_eip" "lb" {
    count = 3
    vpc = true
}

resource "aws_nat_gateway" "main" {
    count = 3
    allocation_id = element(aws_eip.lb.*.id, count.index)
    subnet_id = element(aws_subnet.public-subnets.*.id, count.index)

    tags = {
        Name = "${element(var.nat_gateway, count.index)}" 
    }
}



resource "aws_lb_target_group" "main" {
  name     = "simon-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

#resource "aws_lb_target_group_attachment" "main" {
 #   count = 3
  #  target_group_arn = "${aws_lb_target_group.main.arn}"
   # target_id = aws_launch_template.main.id
    #port = 80
#}

resource "aws_lb" "main" {
    load_balancer_type = "application"
    subnets = [for subnet in aws_subnet.public-subnets : subnet.id]
    security_groups = [aws_security_group.main.id]
}

resource "aws_lb_listener" "front_end" {
    load_balancer_arn = aws_lb.main.arn
    port = "443"
    protocol = "HTTPS"
    ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    certificate_arn = aws_acm_certificate.cert.arn


    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.main.arn

  }

}
    
data "aws_route53_zone" "public" {
    name = "kolz.link"
    private_zone = false
}

resource "aws_acm_certificate" "cert" {
    domain_name = "*.kolz.link"
    validation_method = "DNS"
    subject_alternative_names = ["www.kolz.link"]

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_route53_record" "validation" {
    for_each = {
        for x in aws_acm_certificate.cert.domain_validation_options : x.domain_name => {
            name = x.resource_record_name
            record = x.resource_record_value
            type = x.resource_record_type
            zone_id = x.domain_name == "kolz.link" ? data.aws_route53_zone.public.zone_id : data.aws_route53_zone.public.zone_id
        }
    }
    allow_overwrite = true 
    name = each.value.name
    records = [each.value.record]
    ttl = 300
    type = each.value.type
    zone_id = "Z0561335343HFQ40JFOWR"
}

resource "aws_route53_record" "www" {
    zone_id = "Z0561335343HFQ40JFOWR"
    name = "www.kolz.link"
    type = "A"

    alias {
        name = aws_lb.main.dns_name
        zone_id = aws_lb.main.zone_id 
        evaluate_target_health = true
    }
}


resource "aws_s3_bucket" "main" {
    bucket = "kolzy-bucket-123"
    

    tags = {
        Name = "Simon bucket"
        Environment = "Dev"
    }
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "main" {
  depends_on = [
    aws_s3_bucket_ownership_controls.main,
    aws_s3_bucket_public_access_block.main,
  ]

  bucket = aws_s3_bucket.main.id
  acl    = "public-read"
}



resource "aws_s3_bucket_website_configuration" "main" {
  bucket = aws_s3_bucket.main.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }
  depends_on = [aws_s3_bucket.main]
}

resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.main.id
  key    = "index.html"
  source = "index.html"

  depends_on = [aws_s3_bucket.main]
}  


resource "aws_launch_template" "main" {

    name_prefix = "simonlt"
    image_id = "ami-0eb260c4d5475b901"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.main.id]
    key_name = "true"
    user_data = filebase64("script.sh")
    
    
    
}

resource "aws_autoscaling_group" "main" {
  desired_capacity   = 3
  max_size           = 5
  min_size           = 1
  vpc_zone_identifier = aws_subnet.public-subnets.*.id

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_attachment" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.id
  lb_target_group_arn    = aws_lb_target_group.main.arn
  
  



}
provider "aws" {
  region = var.region
}

resource "aws_vpc" "tf-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "tag-vpc"
    }
}

resource "aws_subnet" "tf-pub-a" {
    vpc_id = aws_vpc.tf-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-northeast-2a"
    tags = {
        Name = "tf-pub-a"
    }
    depends_on = [ aws_internet_gateway.tf-igw ]
}

resource "aws_subnet" "tf-pub-b" {
    vpc_id = aws_vpc.tf-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "ap-northeast-2b"
    tags = {
        Name = "tf-pub-b"
    }
    depends_on = [ aws_internet_gateway.tf-igw ]
}

resource "aws_subnet" "tf-priv-a" {
    vpc_id = aws_vpc.tf-vpc.id
    cidr_block = "10.0.10.0/24"
    availability_zone = "ap-northeast-2a"
    tags = {
        Name = "tf-priv-a"
    }
}

resource "aws_subnet" "tf-priv-b" {
    vpc_id = aws_vpc.tf-vpc.id
    cidr_block = "10.0.20.0/24"
    availability_zone = "ap-northeast-2b"
    tags = {
        Name = "tf-priv-b"
    }
}

resource "aws_eip" "tf-eip-1" {
  vpc = true
}

resource "aws_eip" "tf-eip-2" {
  vpc = true
}

resource "aws_internet_gateway" "tf-igw" {
    vpc_id = aws_vpc.tf-vpc.id
    tags = {
      Name = "tf-igw"
    }
}

resource "aws_nat_gateway" "tf-nat-a" {
  allocation_id = aws_eip.tf-eip-1.allocation_id
  subnet_id = aws_subnet.tf-priv-a.id
  tags = {
    Name = "tf-nat-a"
  }
}

resource "aws_nat_gateway" "tf-nat-b" {
  allocation_id = aws_eip.tf-eip-2.allocation_id
  subnet_id = aws_subnet.tf-priv-b.id
  tags = {
    Name = "tf-nat-b"
  }
}

locals {
  default_route_table_id = aws_vpc.tf-vpc.default_route_table_id
}

resource "aws_route" "default-rt-to-igw" {
  route_table_id = local.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.tf-igw.id
}

resource "aws_route_table" "tf-rtb-pub" {
  vpc_id = aws_vpc.tf-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }
  tags = {
    Name = "tf-rtb-pub"
  }
}

resource "aws_route_table_association" "tf-pub-a" {
    subnet_id = aws_subnet.tf-pub-a.id
    route_table_id = aws_route_table.tf-rtb-pub.id
}

resource "aws_route_table_association" "tf-pub-b" {
    subnet_id = aws_subnet.tf-pub-b.id
    route_table_id = aws_route_table.tf-rtb-pub.id
}

resource "aws_route_table" "tf-priv-a" {
  vpc_id = aws_vpc.tf-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tf-nat-a.id
  }
  tags = {
    Name = "tf-priv-a"
  }
}

resource "aws_route_table_association" "tf-priv-a" {
  subnet_id = aws_subnet.tf-priv-a.id
  route_table_id = aws_route_table.tf-priv-a.id
}

resource "aws_route_table" "tf-priv-b" {
  vpc_id = aws_vpc.tf-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tf-nat-b.id
  }
  tags = {
    Name = "tf-priv-b"
  }
}

resource "aws_route_table_association" "tf-priv-b" {
  subnet_id = aws_subnet.tf-priv-b.id
  route_table_id = aws_route_table.tf-priv-b.id
}

resource "aws_security_group" "tf-sg-pub" {
    name = "tf-sg-pub"
    description = "pub sg"
    vpc_id = aws_vpc.tf-vpc.id
    
    ingress {
        from_port = "22"
        to_port = "22"
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    ingress {
        from_port = "80"
        to_port = "80"
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    ingress {
        from_port = "443"
        to_port = "443"
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
}

resource "aws_security_group" "tf-sg-priv" {
  name = "tf-sg-priv"
  description = "priv sg"
  vpc_id = aws_vpc.tf-vpc.id
  ingress {
    to_port = 0
    from_port = 0
    protocol = "-1"
    cidr_blocks = [ "10.0.0.0/16" ]
  }
  egress {
    to_port = 0
    from_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_key_pair" "tf-kp-ec2" {
  key_name = "tf-kp-ec2"
  public_key = file("../kp/tf-ec2-kp.pem.pub")
  tags = {
    Name = "tf-kp-ec2"
    description = "kp pem"
  }
}

resource "aws_instance" "tf-ec2-example1" {
  ami = "ami-0a463f27534bdf246"
  instance_type = "t3.medium"
  key_name = aws_key_pair.tf-kp-ec2.key_name
  vpc_security_group_ids = [ aws_security_group.tf-sg-pub.id ]
  subnet_id = aws_subnet.tf-pub-a.id
  tags = {
    Name = "tf-ec2-example1"
  }
}

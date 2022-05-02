# Provider
provider "aws" {
  profile = "default"
  region  = var.aws_region
}

# VPC-1

resource "aws_vpc" "VPC1" {
  cidr_block       = var.vpc_cidr1
  instance_tenancy = "default"
  tags = {
    Name = "VPC1"
  }
}


# VPC-2

resource "aws_vpc" "VPC2" {
  cidr_block = var.vpc_cidr2
  instance_tenancy = "default"
  tags = {
    Name = "VPC2"
  }
}


# Subnets VPC 1

resource "aws_subnet" "SubnetVPC1" {
    vpc_id = aws_vpc.VPC1.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
    Name = "SubnetVPC1"
    }
}


# Create & Attach Internet Gateway to the VPC

resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.VPC1.id
  tags = {
    Name = "IGW_VPC1"
  }
  depends_on = [aws_internet_gateway.igw1]
}

# Crear Route tables y asociarla a la subnets:

resource "aws_route_table" "RouteTableVPC1" {
  vpc_id = aws_vpc.VPC1.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
    }
  route {
    cidr_block = "172.16.0.0/24"
    gateway_id = aws_vpc_peering_connection.DemoPeering.id
   }
    tags = {
      Name = "RouteTableVPC1"
    }
    depends_on = [aws_internet_gateway.igw1]
}

# Associate subnet to Route Table 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.SubnetVPC1.id
  route_table_id = aws_route_table.RouteTableVPC1.id
}

# VPC Peering

resource "aws_vpc_peering_connection" "DemoPeering" {
  peer_vpc_id = aws_vpc.VPC1.id
  vpc_id      = aws_vpc.VPC2.id
  auto_accept = true
}

# VPC2 Subnets

resource "aws_subnet" "SubnetVPC2" {
  vpc_id     = aws_vpc.VPC2.id
  cidr_block = "172.16.0.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "SubnetVPC2"
  }
}
resource "aws_subnet" "SubnetVPC21" {
  vpc_id     = aws_vpc.VPC2.id
  cidr_block = "172.16.16.0/20"
  availability_zone = "us-east-1b"
  tags = {
    Name = "SubnetVPC21"
  }
}


# Crear Route tables y asociarla a la subnets:

resource "aws_route_table" "RouteTableVPC2" {
  vpc_id = aws_vpc.VPC2.id
  route {
    cidr_block = "10.0.0.0/24"
    gateway_id = aws_vpc_peering_connection.DemoPeering.id
  }
    tags = {
      Name = "RouteTableVPC2"
  }
  depends_on = [aws_vpc_peering_connection.DemoPeering]
}

# Asociar la subnet 

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.SubnetVPC2.id
  route_table_id = aws_route_table.RouteTableVPC2.id
}

# Crear los Security groups

resource "aws_security_group" "SG_VPC1" {
  name        = "SG_VPC1"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.VPC1.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.VPC1.cidr_block]
    }
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_vpc.VPC1]
  tags = {
    Name = "Allow_ssh"
  }
}

resource "aws_security_group" "SG_VPC2" {
  name        = "SGDatabase"
  description = "Allow MySQL inbound traffic"
  vpc_id      = aws_vpc.VPC2.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.SG_VPC1.id}"]
  }
  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_vpc.VPC2]
  tags = {
    Name = "Allow_MySQL Connection"
  }
}


# Crear el Db subnet groups

resource "aws_db_subnet_group" "rds" {
  name       = "main"
  subnet_ids = [aws_subnet.SubnetVPC2.id, aws_subnet.SubnetVPC21.id]
  tags = {
    Name = "My DB subnet group"
  }
}


# Crear RDS MySQL DB

resource "aws_db_instance" "DB" {
  identifier = "mysql-db-01"
  engine = "mysql" 
  engine_version = "8.0.27"
  instance_class = "db.t2.micro"
  availability_zone = "us-east-1a"
  db_name = "demodb"
  username = "admin"
  password = "Abril.2022"
  multi_az =  false
  allocated_storage = 20
  port = "3306"
  skip_final_snapshot = true
  db_subnet_group_name   = "main"
  vpc_security_group_ids = [aws_security_group.SG_VPC2.id]
  tags = {
    Name = "MYSQL Database"
  }
}

resource "aws_instance" "demo" {
  ami = "ami-0f9fc25dd2506cf6d" #Ubuntu
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.SubnetVPC1.id
  security_groups = [aws_security_group.SG_VPC1.id]
  tags = {
    Name = "EC2-Demo"
  }
}

resource "aws_eip" "elasticip" {
  instance =  aws_instance.demo.id
}

output "EIP" {
  value = aws_eip.elasticip.public_ip
}

# Key pair

resource "aws_key_pair" "testkeypair" {
  key_name   = "testkeypair"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "testkeypair" {
    content  = tls_private_key.rsa.private_key_pem
    filename = "testkeypair"
}

#





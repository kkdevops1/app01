provider "aws" {
  region = "us-east-1"  # You can change the region as needed
}

resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "aws-examples"
  }
}

resource "aws_subnet" "example_subnet_1" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"  # You can change the availability zone as needed
  map_public_ip_on_launch = true
  tags = {
    Name = "aws-examples"
  }
}

resource "aws_subnet" "example_subnet_2" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"  # You can change the availability zone as needed
  map_public_ip_on_launch = true
  tags = {
    Name = "aws-examples"
  }
}


# Create Subnet 3
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-3"
  }
}

# Associate Route Table with Subnet 1
resource "aws_route_table_association" "subnet1_association" {
  subnet_id      = aws_subnet.example_subnet_1.id
  route_table_id = aws_route_table.my_route_table.id
}

# Associate Route Table with Subnet 2
resource "aws_route_table_association" "subnet2_association" {
  subnet_id      = aws_subnet.example_subnet_2.id
  route_table_id = aws_route_table.my_route_table.id
}

# Associate Route Table with Subnet 3
resource "aws_route_table_association" "subnet3_association" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.my_route_table.id
}



# Create Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.example_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}


variable key_name {}

resource "aws_key_pair" "test-keypair" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")  # Specify the path to your public key
}



# Create Route Table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.example_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "my-route-table"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.example_vpc.id

  tags = {
    Name = "my-igw"
  }
}
# Create Bastion Host in Subnet 3
resource "aws_instance" "bastion_host" {
  ami           = "ami-0fc5d935ebf8bc3bc" # Specify a valid AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet3.id
  key_name      = aws_key_pair.test-keypair.key_name
 
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "ssh-rsa ${aws_key_pair.test-keypair.public_key}" >> /home/ubuntu/.ssh/authorized_keys
              chmod 600 /home/ubuntu/.ssh/authorized_keys
              chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
              EOF

  tags = {
    Name = "bastion-host"
  }
}


resource "aws_subnet" "subnet4" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-4"
  }
}

resource "aws_security_group" "private_instance_sg" {
  vpc_id = aws_vpc.example_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.3.207/32"]
  }

  tags = {
    Name = "private-instance-sg"
  }
}

resource "aws_instance" "private_instance" {
  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet4.id
  key_name      = aws_key_pair.test-keypair.key_name
  vpc_security_group_ids = [aws_security_group.private_instance_sg.id]

  tags = {
    Name = "private-instance"
  }
}

resource "aws_eip" "nat_eip" {
  instance = aws_instance.bastion_host.id
}

resource "aws_eip" "new_nat_eip" {}


resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.new_nat_eip.id
  subnet_id     = aws_subnet.example_subnet_1.id

  tags = {
    Name = "my-nat-gateway"
  }
}

/*
resource "aws_route" "private_subnet_route" {
  route_table_id         = aws_route_table.my_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id          = aws_nat_gateway.my_nat_gateway.id
}*/

output "private_key_pem" {
  value       = aws_key_pair.test-keypair.key_name
  sensitive   = true
  description = "Private key in PEM format"
}


# Create Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.example_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

# Create a Route in the Private Route Table
resource "aws_route" "private_subnet_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id          = aws_nat_gateway.my_nat_gateway.id
}

# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.private_route_table.id
}

# Output the private key in PEM format
output "private_key_pem1" {
  value       = aws_key_pair.test-keypair.key_name
  sensitive   = true
  description = "Private key in PEM format"
}

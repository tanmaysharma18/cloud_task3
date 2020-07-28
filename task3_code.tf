provider "aws"{
  region  = "ap-south-1"
  profile = "tanmay2"
}



resource "aws_vpc" "myvpc" {
  cidr_block           = "192.168.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
}



resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "192.168.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_public"
  }
}



resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "subnet_private"
  }
}



resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "IGw"
  }
}



resource "aws_route_table" "route" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "route"
  }
}



resource "aws_route_table_association" "asso" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route.id
}



resource "aws_instance" "mysql" {
  ami               = "ami-0f443923b22ba17c3"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1b"
  subnet_id         = aws_subnet.subnet2.id
  key_name          = "mykey"
  
  vpc_security_group_ids = [ aws_security_group.sg1.id ]
  user_data = <<-EOF
      
	#!/bin/bash
	sudo docker run -dit -e MYSQL_ROOT_PASSWORD=***** -e MYSQL_DATABASE=data -e MYSQL_USER=tanmay -e MYSQL_PASSWORD=***** -p 8080:3306 --name dbos mysql:5.7
  EOF
  
  tags = {
    Name = "mysql1"
  }
}



resource "aws_security_group" "sg1" {
  name          = "sg1"
  description   = "Allow tcp inbound traffic"
  vpc_id        = aws_vpc.myvpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  
 
  ingress {
    description = "TLS from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }    
    
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysqlhttp"
  }
}



resource "aws_instance" "wordpress"{
  ami                         = "ami-0f443923b22ba17c3"
  instance_type               = "t2.micro"
  availability_zone           = "ap-south-1a"
  associate_public_ip_address = "true"
  subnet_id                   = aws_subnet.subnet1.id
  key_name                    = "mykey"
  vpc_security_group_ids      = [ aws_security_group.wp1.id ]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("C:/Users/dell/Downloads/mykey.pem")
    host        = aws_instance.wordpress.public_ip
  }


  provisioner "remote-exec" {
    inline = [
      "sudo yum install docker -y",
      "sudo service docker start",
      "sudo docker pull wordpress:5.1.1-php7.3-apache",
      "sudo docker run -dit -e WORDPRESS_DB_HOST=${aws_instance.mysql.private_ip}:8080 -e WORDPRESS_DB_USER=tanmay -e WORDPRESS_DB_PASSWORD=***** -e WORDPRESS_DB_NAME=data -p 8000:80 --name mywp wordpress:5.1.1-php7.3-apache"
    ]
  }

  tags = {
    Name = "wordpress1"
  }
}



resource "aws_security_group" "wp1" {
  name          = "wp1"
  description   = "Allow tcp inbound traffic"
  vpc_id        = aws_vpc.myvpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }    

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wphttp"
  }
}

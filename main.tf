### Module Main

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr_bloc
}

resource "aws_subnet" "public" {
  for_each = var.azs
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr_bloc, 4, each.value)
  availability_zone = "${var.aws_region}${each.key}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${var.aws_region}${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = var.azs
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr_bloc, 4, 15-each.value)
  availability_zone = "${var.aws_region}${each.key}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.vpc_name}-private-${var.aws_region}${each.key}"
  }
}

#TP en autonomie
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-gw"
  }
}

data "aws_ami" "ami" {
  most_recent = true
  name_regex = "amzn-ami-vpc-nat-2018.03.0.2021*"
  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-2018.03.0.2021*"]
  }
  owners = [
    "amazon"
  ]
}

resource "aws_security_group" "nat" {
  name = "nat"
  description = "Allow TLS inbound traffic"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "sgr-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.nat.id
  cidr_blocks      = [var.vpc_cidr_bloc]
}

resource "aws_key_pair" "mykey" {
  key_name   = "ma-vraie-clef"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDgy/D5TmgdyzH9qkcd1puB+WQ+nW0VNSvnUBhAJCWju tony"
}

resource "aws_instance" "nat" {
  for_each = var.azs
  ami           = data.aws_ami.ami.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public[each.key].id
  vpc_security_group_ids = [aws_security_group.nat.id]
  key_name = aws_key_pair.mykey.key_name
}

resource "aws_eip" "eip_pub" {
  for_each = var.azs
  domain   = "vpc"
}

resource "aws_eip_association" "eip_pub_assoc" {
  for_each = var.azs
  instance_id   = aws_instance.nat[each.key].id
  allocation_id = aws_eip.eip_pub[each.key].id
}

#Routage publique
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "public_route" {
  for_each = var.azs
  route_table_id            = aws_route_table.public_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_rta" {
  for_each = var.azs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public_route_table.id
}

#Routage privé
resource "aws_route_table" "private_route_table" {
  for_each = var.azs
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "private_route" {
  for_each = var.azs

  route_table_id     = aws_route_table.private_route_table[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id = aws_instance.nat[each.key].primary_network_interface_id
}

resource "aws_route_table_association" "private_rta" {
  for_each = var.azs
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private_route_table[each.key].id
}

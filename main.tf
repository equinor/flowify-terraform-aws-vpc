#######################################
# VPC Terraform Module                #
# Valid for both Tf 0.12.29 and 1.1.5 #
#######################################

provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.1.5"
}

# Creating new VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(
    var.common_tags,
    {
      "Name"                                              = "${var.env_name}-vpc"
      "kubernetes.io/cluster/${var.env_name}-eks-cluster" = "shared"
    },
  )
}

# Getting information about available AZ
data "aws_availability_zones" "available" {
}

locals {
  computed_zone_count = var.max_az_count == 0 ? 1 : var.max_az_count
}

# Ordering elastic IP for NAT Gateway
resource "aws_eip" "nat_static_ip" {
  vpc   = true
  count = var.include_nat_gateways == "true" ? local.computed_zone_count : 0

  tags = merge(
    var.common_tags,
    {
      "Name" = "${var.env_name}-vpc NAT IP ${element(data.aws_availability_zones.available.names, count.index)}"
    },
  )
}

# Creating Internet GW
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main_vpc.id

  tags = merge(
    var.common_tags,
    {
      "Name" = "${var.env_name}-vpc Internet Gateway"
    },
  )
}

# Creating NAT GW
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = element(aws_eip.nat_static_ip.*.id, count.index)
  count         = length(aws_eip.nat_static_ip)
  subnet_id     = element(aws_subnet.public_az_subnet.*.id, count.index)
  depends_on    = [aws_internet_gateway.gateway]

  tags = merge(
    var.common_tags,
    {
      "Name" = "${var.env_name}-vpc NAT Gateway-${element(data.aws_availability_zones.available.names, count.index)}"
    },
  )
}

#Creating Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  tags = merge(
    var.common_tags,
    {
      "Name" = "${var.env_name}-vpc Public Route Table"
    },
  )
}

# Creating Private NAT Route Table
resource "aws_route_table" "private_route_table_nat" {
  vpc_id = aws_vpc.main_vpc.id
  count  = length(aws_nat_gateway.nat_gateway)

  tags = merge(
    var.common_tags,
    {
      "Name" = "${var.env_name}-vpc Private NAT Route Table ${element(data.aws_availability_zones.available.names, count.index)}"
    },
  )
}

# Creating Public AZ Subnets
resource "aws_subnet" "public_az_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = cidrsubnet(
    signum(length(var.vpc_cidr)) == 1 ? var.vpc_cidr : var.vpc_cidr,
    ceil(
      log(
        length(data.aws_availability_zones.available.names) * var.newbits,
        var.netnum,
      ),
    ),
    local.computed_zone_count + count.index,
  )
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  count             = local.computed_zone_count

  tags = merge(
    var.common_tags,
    {
      "Name"                                              = "${var.env_name}-vpc Public AZ Subnet ${element(data.aws_availability_zones.available.names, count.index)}"
      "kubernetes.io/cluster/${var.env_name}-eks-cluster" = "owned"
      "kubernetes.io/role/elb"                            = "1"
    },
  )
}

# Creating Private AZ Subnets
resource "aws_subnet" "private_az_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = cidrsubnet(
    signum(length(var.vpc_cidr)) == 1 ? var.vpc_cidr : var.vpc_cidr,
    ceil(
      log(
        length(data.aws_availability_zones.available.names) * var.newbits,
        var.netnum,
      ),
    ),
    count.index,
  )
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  count             = local.computed_zone_count

  tags = merge(
    var.common_tags,
    {
      "Name"                                              = "${var.env_name}-vpc Private AZ Subnet ${element(data.aws_availability_zones.available.names, count.index)}"
      "kubernetes.io/cluster/${var.env_name}-eks-cluster" = "owned"
      "kubernetes.io/role/internal-elb"                   = "1"
    },
  )
}

# Association route tables with subnets
resource "aws_route_table_association" "public_az_subnet_route_table_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = element(aws_subnet.public_az_subnet.*.id, count.index)
  count          = local.computed_zone_count
}

resource "aws_route_table_association" "private_az_subnet_route_table_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = element(aws_subnet.private_az_subnet.*.id, count.index)
  count          = length(aws_route_table.private_route_table_nat) == 0 ? local.computed_zone_count : 0
}

resource "aws_route_table_association" "private_nat_az_subnet_route_table_association" {
  route_table_id = element(aws_route_table.private_route_table_nat.*.id, count.index)
  subnet_id      = element(aws_subnet.private_az_subnet.*.id, count.index)
  count          = length(aws_route_table.private_route_table_nat)
}

# Add default routes to Public subnets
resource "aws_route" "vpc_public_routes" {
  count                     = length(aws_route_table.public_route_table)
  route_table_id            = aws_route_table.public_route_table.id
  destination_cidr_block    = var.main_route_destination_cidr
  gateway_id                = aws_internet_gateway.gateway.id
  depends_on                = [aws_route_table.public_route_table]
}

# Add default routes to Private subnets
resource "aws_route" "vpc_private_routes" {
  count                     = length(aws_route_table.private_route_table_nat)
  route_table_id            = element(aws_route_table.private_route_table_nat.*.id, count.index)
  destination_cidr_block    = var.main_route_destination_cidr
  nat_gateway_id            = element(aws_nat_gateway.nat_gateway.*.id, count.index)
  depends_on                = [aws_route_table.private_route_table_nat]
}

locals {
  public_route_table_ids                = distinct(sort(aws_route_table.public_route_table.*.id))
  private_route_table_ids               = distinct(sort(aws_route_table.private_route_table_nat.*.id))

  vpc_peering_destination_cidr          = flatten(var.vpc_peering_destination_cidr)
  vpc_peering_destination_cidr_count    = length(local.vpc_peering_destination_cidr)
  vpc_peering_id                        = flatten(var.vpc_peering_id)

  vpc_tgw_destination_cidr              = flatten(var.vpc_tgw_destination_cidr)
  vpc_tgw_destination_cidr_count        = length(local.vpc_tgw_destination_cidr)
  vpc_tgw_id                            = flatten(var.vpc_tgw_id)
}

# Add routes to Public subnets for VPC Peering conection
resource "aws_route" "vpc_peering_routes_pub" {
  count                                 = local.vpc_peering_destination_cidr_count
  route_table_id                        = element(local.public_route_table_ids, ceil(count.index/local.vpc_peering_destination_cidr_count))
  destination_cidr_block                = element(local.vpc_peering_destination_cidr, ceil(count.index % local.vpc_peering_destination_cidr_count))
  vpc_peering_connection_id             = element(local.vpc_peering_id, ceil(count.index % local.vpc_peering_destination_cidr_count))
  depends_on                            = [aws_route_table.public_route_table]
}

# Add routes to Private subnets for VPC Peering conection
resource "aws_route" "vpc_peering_routes_private" {
  count                                 = local.computed_zone_count * local.vpc_peering_destination_cidr_count
  route_table_id                        = element(local.private_route_table_ids, ceil(count.index/local.vpc_peering_destination_cidr_count))
  destination_cidr_block                = element(local.vpc_peering_destination_cidr, ceil(count.index % local.vpc_peering_destination_cidr_count))
  vpc_peering_connection_id             = element(local.vpc_peering_id, ceil(count.index % local.vpc_peering_destination_cidr_count))
  depends_on                            = [aws_route_table.private_route_table_nat]
}

# Add routes to Public subnets for Transit Gateway conection
resource "aws_route" "vpc_tgw_routes_pub" {
  count                                 = local.vpc_tgw_destination_cidr_count
  route_table_id                        = element(local.public_route_table_ids, ceil(count.index/local.vpc_tgw_destination_cidr_count))
  destination_cidr_block                = element(local.vpc_tgw_destination_cidr, ceil(count.index % local.vpc_tgw_destination_cidr_count))
  transit_gateway_id                    = element(local.vpc_tgw_id, ceil(count.index %local.vpc_tgw_destination_cidr_count))
  depends_on                            = [aws_route_table.public_route_table]
}

# Add routes to Private subnets for Transit Gateway conection
resource "aws_route" "vpc_tgw_routes_private" {
  count                                 = local.computed_zone_count * local.vpc_tgw_destination_cidr_count
  route_table_id                        = element(local.private_route_table_ids, ceil(count.index/local.vpc_tgw_destination_cidr_count))
  destination_cidr_block                = element(local.vpc_tgw_destination_cidr, ceil(count.index % local.vpc_tgw_destination_cidr_count))
  transit_gateway_id                    = element(local.vpc_tgw_id, ceil(count.index % local.vpc_tgw_destination_cidr_count))
  depends_on                            = [aws_route_table.private_route_table_nat]
}

# Manages a Route53 Hosted Zone VPC association. VPC associations can only be made on private zones.
resource "aws_route53_zone_association" "assoc_main_vpc_to_private_zone" {
  count      = var.vpc_associate_to_private_zone_on ? 1 : 0
  vpc_id     = aws_vpc.main_vpc.id
  zone_id    = var.private_hosted_zone_id
  vpc_region = var.vpc_region
}

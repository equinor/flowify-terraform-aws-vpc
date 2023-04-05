# AWS VPC Terraform module 

Author: [Yurii Onuk](https://onuk.org.ua)

This module provides a generic public/private VPC Instance and associated subnets that can be included in 
your applications Terraform configuration allowing a standard "best practices" implementation without
requiring a specific implementation to be created within your applications source repository.

- the `variables.tf` file provides a list of required input variables. 
- the `outputs.tf` file provides variables that can be used to establish dependencies within your overall application deployment.

This module has a toggle to determine whether or not NAT Gateways are present in your VPC (`include_nat_gateways`). By enabling this option,
you will have a gateway with EIP in each public subnet that is created and routes added to the private subnets
that direct all internet bound traffic to the NAT gateway.

Setting this option to false will generate the public, private and db subnets however they will NOT be routable to the
internet. Resources placed in these subnets will still be accessible to instances internal to the VPC. All resources
placed in the public subnet should have public IP's associated with them to allow traffic to traverse the internet gateway for
the VPC.

## Terraform version compatibility

- 0.12.29
- 1.1.5

## Usage

main.tf:

```hcl-terraform

# Set up the VPC
module "vpc" {
  source                       = "git@github.com:equinor/flowify-terraform-aws-vpc.git/?ref=x.x.x"
  region                       = var.region
  max_az_count                 = var.max_az_count
  include_nat_gateways         = var.include_nat_gateways
  env_name                     = "${var.env_name}-${var.env_class}"
  vpc_cidr                     = var.vpc_cidr
  enable_dns_hostnames         = var.enable_dns_hostnames
  enable_dns_support           = var.enable_dns_support
  main_route_destination_cidr  = var.main_route_destination_cidr

  # Add AWS Transit GW routes in VPC (if values are empty the module skip creating routes for Transit GW)
  vpc_tgw_destination_cidr    = ["${var.tgw_route_destination_cidr}"] 
  vpc_tgw_id                  = ["${module.tgw.transit_gateway_id}"]

  # Add VPC Peering routes in VPC (if values are empty the module skip creating routes for VPC Peering)
  vpc_peering_destination_cidr = ["10.16.40.0/21","172.31.0.0/16"]
  vpc_peering_id               = ["${module.vpc_peering_from_euc101_mgmt_to_usw201_test.requester_connection_id}""]

  # Manages a Route53 Hosted Zone VPC association. VPC associations can only be made on private zones.
  vpc_associate_to_private_zone_on = var.vpc_associate_to_private_zone_on
  private_hosted_zone_id           = var.route53_hosted_zone_id

  common_tags = local.common_tags
}
```

variable.tf:

```hcl-terraform
variable "region" {
  type        = string
  default     = "us-west-1"
  description = "The region where AWS operations will take place"
}

variable "max_az_count" {
  default     = 2
  description = "The maximum number of availability zones to utilitize. Since EIP's and NAT gateways cost money, you many want to limit your usage. A value of 0 will use every available az in the region."
}

variable "enable_dns_hostnames" {
  type        = string
  description = "Either \"true\" or \"false\" to toggle dns hostname support on or off on the vpc connection"
  default     = "true"
}

variable "enable_dns_support" {
  type        = string
  description = "Either \"true\" or \"false\" to toggle dns support on or off on the vpc connection"
  default     = "true"
}

variable "main_route_destination_cidr" {
  type        = string
  description = "The cidr for the outgoing traffic to the internet gateway. By setting this is a more fine grained value, traffic will be dropped by the route."
  default     = "0.0.0.0/0"
}

variable "env_name" {
  type        = string
  description = "The description that will be applied to the tags for resources created in the vpc configuration"
  default     = "playground"
}

variable "common_tags" {
  type        = map(string)
  description = "The default tags that will be added to all taggable resources"

  default = {
    EnvClass    = "dev"
    Environment = "Playground"
    Owner       = "Ops"
    Terraform   = "true"
  }
}

variable "vpc_cidr" {
  type        = string
  description = "The internal CIDR for the app VPC connection"
  default     = "10.0.0.0/16" # will break in areas with more than 4 AZ (us-west?)
}

variable "include_nat_gateways" {
  type        = string
  description = "Specifies whether or not nat gateways should be generated in all az's and the private subnet routes using them as their default gateways"
  default     = "false"
}

variable "netnum" {
  type        = string
  default     = "2"
  description = "Full information can find via link https://www.terraform.io/docs/configuration/functions/cidrsubnet.html"
}

variable "newbits" {
  type        = string
  default     = "2"
  description = "Full information can find via link https://www.terraform.io/docs/configuration/functions/cidrsubnet.html"
}

variable "mgmt_vpc_flag" {
  default     = false
  description = "Variable which defines VPC type - Management or Client. Set true for Management"
}

variable "vpc_peering_destination_cidr" {
  type    = list(string)
  default  = []
  description = "The cidr for the outgoing traffic to the VPC Peering"
}

variable "vpc_peering_id" {
  type    = list(string)
  default = []
  description = "The VPC Peering connection ID"
}

variable "vpc_tgw_destination_cidr" {
  type    = list(string)
  default  = []
  description = "The cidr for the outgoing traffic to the Transit GW"
}

variable "vpc_tgw_id" {
  type    = list(string)
  default = []
  description = "The Transit Gateway connection ID"
}

variable "vpc_associate_to_private_zone_on" {
  type        = bool
  default     = true
  description = "Whether to associate VPC to Private hosted zone in Route53"
}

variable "private_hosted_zone_id" {
  type        = string
  default     = ""
  description = "The private hosted zonev id to associate"
}

variable "vpc_region" {
  type        = string
  default     = ""
  description = "(Optional) The VPC's region. Defaults to the region of the AWS provider."
}
```

output.tf:

```hcl-terraform
output "public_subnet_id_list" {
  description = "Public subnets IDs list in VPC"
  value = ["${aws_subnet.public_az_subnet.*.id}"]
}

output "private_subnet_id_list" {
  description = "Private subnets IDs list in VPC"
  value = ["${aws_subnet.private_az_subnet.*.id}"]
}

output "public_subnet_cidr_list" {
  value = ["${aws_subnet.public_az_subnet.*.cidr_block}"]
  description = "Public az subnet CIDR block"
}

output "privat_subnet_cidr_list" {
  value = ["${aws_subnet.private_az_subnet.*.cidr_block}"]
  description = "Privat az subnet CIDR block"
}

output "vpc_id" {
  description = "VPC ID"
  value = "${aws_vpc.main_vpc.id}"
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value = "${aws_vpc.main_vpc.cidr_block}"
}

```

terraform.tfvars:

```hcl-terraform
# The region where AWS operations will take place
region  = "us-west-1"

# Name to be used on all the resources as identifier
vpc_name = "usw201"

# Redefining default tags

common_tags = {
    EnvClass    = "dev"
    Environment = "usw201"
    Owner       = "Ops"
    Terraform   = "true"
  }

# Redefining default values for inputs variables
max_az_count = "2"
include_nat_gateways = "true"

```

## Inputs

 Variable                       | Type         | Default                               | Required | Purpose
:------------------------------ |:------------:| ------------------------------------- | -------- | :----------------------
max_az_count                    | boolean      | `0`                                   |   `no`   | The maximum number of availability zones to utilize, a value of 0 will use every available az in the region
enable_dns_hostnames            | string       | `true`                                |   `no`   | Toggle dns hostname support on or off on the vpc connection
enable_dns_support              | string       | `true`                                |   `no`   | Toggle dns support on or off on the vpc connection
main_route_destination_cidr     | string       | `0.0.0.0/0`                           |   `no`   | The cidr for the outgoing traffic to the internet gateway
env_name                        | string       | `playground`                          |   `no`   | The description that will be applied to the tags for resources created in the vpc configuration
common_tags                     | map          | `EnvClass    = "dev", etc.`           |   `no`   | The default tags that will be added to all taggable resources
vpc_cidr                        | string       | `10.0.0.0/16`                         |   `no`   | The internal CIDR for the VPC
include_nat_gateways            | string       | `false`                               |   `no`   | Specifies whether or not nat gateways should be generated in all az's and the private subnet routes using them as their default gateways
netnum                          | string       | `2`                                   |   `no`   | Full information can find via link https://www.terraform.io/docs/configuration/functions/cidrsubnet.html
newbits                         | string       | `2`                                   |   `no`   | Full information can find via link https://www.terraform.io/docs/configuration/functions/cidrsubnet.html
vpc_tgw_route_destination_cidr  | list(string) | `[]`                                  |   `no`   | The cidr for the outgoing traffic to the transit gateway
vpc_tgw_id                      | list(string) | `[]`                                  |   `no `  | ID of the Transit Gateway this VPC will be connected to
vpc_peering_destination_cidr    | list(string) | `[]`                                  |   `no`   | The cidr for the outgoing traffic to the VPC Peering
vpc_peering_id                  | list(string) | `[]`                                  |   `no `  | The VPC Peering connection ID
mgmt_vpc_flag                   | string       | -                                     |   `yes`  | Variable which defines VPC type - Management or Client. Set true for Management
vpc_associate_to_private_zone_on| boolean      | `false`                               |   `no`   | Whether to associate VPC to Private hosted zone in Route53
private_hosted_zone_id          | string       | `""`                                  |   `no`   | Required if `vpc_associate_to_private_zone_on = true`. The private hosted zone id to associate
vpc_region                      | string       | `""`                                  |   `no`   | The VPC's region. Defaults to the region of the AWS provider

## Outputs

| Name                        | Description                                                |
| --------------------------- | ---------------------------------------------------------- |
| public_subnet_id_list       | Public subnets IDs list in VPC                             |
| private_subnet_id_list      | Private subnets IDs list in VPC                            |
| database_subnet_id_list     | Database subnets IDs list in VPC                           |
| public_subnet_cidr_list     | Public az subnet CIDR block                                |
| private_subnet_cidr_list    | Privat az subnet CIDR block                                |
| database_subnet_cidr_list   | Database az subnet CIDR block                              |
| vpc_id                      | VPC ID                                                     |
| vpc_cidr_block              | VPC CIDR block                                             |

## Terraform Validate Action

Runs `terraform validate -var-file=validator` to validate the Terraform files 
in a module directory via CI/CD pipeline.
Validation includes a basic check of syntax as well as checking that all variables declared.

### Success Criteria

This action succeeds if `terraform validate -var-file=validator` runs without error.

### Validator

If some variables are not set as default, we should fill the file `validator` with these variables.

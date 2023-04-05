# Inputs

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
  default     = false
  description = "Whether to associate VPC to Private hosted zone in Route53"
}

variable "private_hosted_zone_id" {
  type        = string
  default     = ""
  description = "The private hosted zone id to associate"
}

variable "vpc_region" {
  type        = string
  default     = ""
  description = "(Optional) The VPC's region. Defaults to the region of the AWS provider."
}

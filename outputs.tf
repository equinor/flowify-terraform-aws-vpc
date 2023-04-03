# Outputs

output "public_subnet_id_list" {
  description = "Public subnets IDs list in VPC"
  value       = aws_subnet.public_az_subnet.*.id
}

output "private_subnet_id_list" {
  description = "Private subnets IDs list in VPC"
  value       = aws_subnet.private_az_subnet.*.id
}

output "public_subnet_cidr_list" {
  value       = aws_subnet.public_az_subnet.*.cidr_block
  description = "Public az subnet CIDR block"
}

output "private_subnet_cidr_list" {
  value       = aws_subnet.private_az_subnet.*.cidr_block
  description = "Privat az subnet CIDR block"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main_vpc.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.main_vpc.cidr_block
}


output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB + NAT ENIs only)."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (nodes + pods)."
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "IDs of the isolated database subnets (no NAT/IGW route)."
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of the RDS subnet group spanning the database subnets."
  value       = module.vpc.database_subnet_group_name
}

output "database_security_group_id" {
  description = "Security group ID for the isolated database tier."
  value       = aws_security_group.database.id
}

output "private_route_table_ids" {
  description = "IDs of the private subnets' route tables."
  value       = module.vpc.private_route_table_ids
}

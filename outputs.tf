output "default_region" {
  description = "The default region name"
  value       = local.default_region
}

output "account_id" {
  description = "The current account id"
  value       = local.current_account_id
}

# output "ntc_parameters" {
#   description = "Map of all ntc parameters"
#   value       = local.ntc_parameters
# }
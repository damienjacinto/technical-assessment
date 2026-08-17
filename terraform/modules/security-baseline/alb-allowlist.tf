# Consumed by alb-ip-restrict-sg.tf. The actual access control for both
# ALBs, not WAF. Auto-detected fallback when no explicit CIDRs given
# (same pattern as terraform/modules/eks/main.tf); set
# var.alb_allowlist_cidrs explicitly once real office/VPN ranges exist.
data "http" "my_ip" {
  count = length(var.alb_allowlist_cidrs) == 0 ? 1 : 0

  url = "https://checkip.amazonaws.com"
  request_headers = {
    Accept = "text/plain"
  }
}

locals {
  alb_allowlist_cidrs = length(var.alb_allowlist_cidrs) > 0 ? var.alb_allowlist_cidrs : ["${trimspace(data.http.my_ip[0].response_body)}/32"]
}

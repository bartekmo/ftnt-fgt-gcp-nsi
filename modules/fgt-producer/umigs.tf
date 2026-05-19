# 
# Instance groups are created in global producer module, so we can pass them as failback between different zones
# 
resource "google_compute_instance_group" "fgt_umigs" {
  for_each = toset(var.zones)
  name     = "${local.prefix}umig-${local.zones_short[each.key]}"
  zone     = each.key
}

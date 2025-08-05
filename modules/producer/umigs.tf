resource "google_compute_instance_group" "fgt_umigs" {
  for_each = toset(var.zones)
  name     = "${local.prefix}umig2-${local.zones_short[each.key]}"
  zone     = each.key
}

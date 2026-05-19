resource "google_network_security_intercept_deployment" "fgt" {
  provider = google-beta

  intercept_deployment_id    = "${local.prefix}id"
  location                   = var.zone
  forwarding_rule            = google_compute_forwarding_rule.ilb.id
  intercept_deployment_group = var.intercept_deployment_group_id
  labels                     = local.labels
}

# Resources building Internal Load Balancers

resource "google_compute_region_backend_service" "ilb" {
  provider = google-beta

  name     = "${local.prefix}bes-ilb-${local.zone_short}"
  region   = local.region
  network  = data.google_compute_subnetwork.connected[local.nsi_port].network
  protocol = "UDP"

  # Local UMIG(s) are preferred, all cross-zone backends are added as fallback
  dynamic "backend" {
    for_each = merge(
      { (var.fgt_umig) = {
        self_link = var.fgt_umig,
        failover  = false
        }
      },
      { for umig in var.xzone_fallback_umigs : umig => {
        self_link = umig,
        failover  = true
        }
      }
    )
    content {
      group          = backend.value.self_link
      failover       = backend.value.failover
      balancing_mode = "CONNECTION"
    }
  }

  health_checks = [google_compute_region_health_check.health_check.self_link]
  connection_tracking_policy {
    connection_persistence_on_unhealthy_backends = "NEVER_PERSIST"
  }
}

resource "google_compute_forwarding_rule" "ilb" {
  name                  = "${local.prefix}fwdrule-ilb-${local.zone_short}"
  region                = local.region
  network               = data.google_compute_subnetwork.connected[local.nsi_port].network
  subnetwork            = data.google_compute_subnetwork.connected[local.nsi_port].id
  ip_address            = var.ilb_address
  ip_protocol           = "UDP"
  ports                 = ["6081"]
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.ilb.self_link
  allow_global_access   = false # required for NSI
}

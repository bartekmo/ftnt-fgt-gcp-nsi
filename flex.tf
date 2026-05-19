/*
terraform {
  required_providers {
    fortiflexvm = {
      source  = "fortinetdev/fortiflexvm"
    }
  }
}
*/


locals {
  flex_serials = ["FGVMELTM23004026", "FGVMELTM23004027", "FGVMELTM23004048", "FGVMELTM23004049"]
}

data "google_secret_manager_secret_version" "flex_user" {
  secret = "bm-flex-user"
}

data "google_secret_manager_secret_version" "flex_pwd" {
  secret = "bm-flex-pwd"
}

provider "fortiflexvm" {
  username = data.google_secret_manager_secret_version.flex_user.secret_data
  password = data.google_secret_manager_secret_version.flex_pwd.secret_data
}


resource "fortiflexvm_entitlements_vm" "fgts" {
  for_each      = toset(local.flex_serials)
  config_id     = 1490
  serial_number = each.key
  status        = "ACTIVE"
}

resource "fortiflexvm_entitlements_vm_token" "fgts" {
  for_each = toset(local.flex_serials)

  config_id        = 1490
  serial_number    = each.key
  regenerate_token = true # If set as false, the provider would only provide the token and not regenerate the token.
  lifecycle {
    ignore_changes = [regenerate_token]
  }
}


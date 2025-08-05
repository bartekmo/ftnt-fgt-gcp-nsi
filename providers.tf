terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
    fortiflexvm = {
      source = "fortinetdev/fortiflexvm"
    }
  }
  cloud {
    organization = "40net"
    workspaces {
      name = "NSI"
    }
  }
}

provider "google" {
  project      = var.project_id
  region       = var.region
  access_token = var.access_token
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  access_token          = var.access_token
  user_project_override = true
  billing_project       = var.project_id
}

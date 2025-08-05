variable "project_id" {
  type    = string
  default = "forti-emea-se"
}

variable "region" {
  default = "europe-west1"
}

variable "prefix" {
  default = "bm-nsi"
}

variable "access_token" {
  type     = string
  default  = null
  nullable = true
}

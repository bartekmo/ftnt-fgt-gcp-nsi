variable "prod_project_id" {
  type    = string
  default = "forti-emea-se"
}

variable "cons_project_id" {
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

variable "cons_organization_id" {
  type        = string
  description = "ID of Google organization where NSI consumer security profiles will be created"
}

variable "fortimanager" {
  type = object({
    ip     = string
    serial = string
  })
  default = null
  nullable = true
  description = "FortiManager connection details. If not provided, the FortiManager integration will be skipped."
}
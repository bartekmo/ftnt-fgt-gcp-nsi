variable "networks" {
  type = object({
    data = object({
      subnet_name = string
      network_id  = string
    })
    mgmt = object({
      subnet_name = string
    })
  })
}

variable "project_id" {
  type = string
}

variable "prefix" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "cluster_size_per_zone" {
  type    = number
  default = 2
}

variable "mgmt_port_public" {
  type    = bool
  default = true
}

variable "flex_tokens" {
  type = list(string)
}

variable "fortimanager" {
  type = object({
    ip     = string
    serial = string
  })
}

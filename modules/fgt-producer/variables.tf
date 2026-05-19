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
  type        = string
  description = "ID of the project where to deploy the NSI producer"
}

variable "prefix" {
  type        = string
  description = "(optional) Prefix to attach to names of all created resources"
  default     = ""
}

variable "zones" {
  type        = list(string)
  description = "List of all zones to deploy to."
}

variable "cluster_size_per_zone" {
  type        = number
  description = "How many FortiGates to deploy per each zone"
  default     = 2
}

variable "mgmt_port_public" {
  type        = bool
  description = "Set to false to not attach a public IP for FortiGate instances management."
  default     = true
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

variable "fgt_image" {
  type = object({
    project = optional(string, "fortigcp-project-001")
    name    = optional(string, "")
    family  = optional(string, "fortigate-74-payg")
    version = optional(string, "")
    arch    = optional(string, "x64")
    lic     = optional(string, "payg")
  })
  description = "Indicate FortiOS image you want to deploy by specifying one of the following: image family name (as image.family); firmware version, architecture and licensing (as image.version, image.arch and image.lic); image name (as image.name) optionally with image project name for custom images (as image.project)."
  default = {
    version = "7.2.8"
  }
  validation {
    condition     = contains(["arm", "x64"], var.fgt_image.arch)
    error_message = "image.arch must be either 'arm' or 'x64' (default: 'x64')"
  }
  validation {
    condition     = contains(["payg", "byol"], var.fgt_image.lic)
    error_message = "image.lic can be either 'payg' or 'byol' (default: 'payg'). For FortiFlex use 'byol'"
  }
  validation {
    condition     = anytrue([length(split(".", var.fgt_image.version)) == 3, length(split(".", var.fgt_image.version)) == 2, var.fgt_image.version == ""])
    error_message = "image.version can be either null, contain FortiOS version in 3-digit format (eg. \"7.4.1\"), or major version in 2-digit format (eg. \"7.4\")"
  }
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "license_files" {
  type        = list(string)
  default     = []
  description = "List of license (.lic) files to be applied for BYOL instances."
}

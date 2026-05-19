variable "project_id" {
  type = string
}

variable "prefix" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "deployment_group_id" {
  type = string
}

variable "organization_id" {
  type        = string
  description = "ID of Google IAM organization where security profiles will be created"
}

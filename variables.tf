
variable "name" {
  description = "Arbitrary string used to name created resources."
  type        = string
  default     = "asset-feed"
}

variable "organization_id" {
  description = "Organization id that references existing organization."
  type        = string
}

variable "project_id" {
  description = "Project id that references existing project."
  type        = string
}

variable "region" {
  description = "Compute region used in the example."
  type        = string
  default     = "us-central1"
}

variable "folder_id" {
  description = "value of the folder id"
  type = string
}

variable "source_dir" {
  description = "value of the source dir where the Cloud function folder is"
  type = string
  default = "./cf"
}
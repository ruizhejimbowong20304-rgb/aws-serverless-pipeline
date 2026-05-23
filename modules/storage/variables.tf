variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type = string
  default = "dev"
}

variable "prefix" {
  description = "Prefix for naming resources"
  type = string
  default = "mimi"
}

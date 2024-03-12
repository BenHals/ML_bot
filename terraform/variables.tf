variable "DISCORD_PUBLIC_KEY" {
  description = "Public key for discord bot"
  type        = string
}

variable "root_name" {
  description = "Root name for the project"
  type        = string
  default     = "ben-halstead-ml-bot"
}

variable "archive_path" {
  description = "Root path for archive/build artifacts"
  type        = string
  default     = "archive"
}

variable "artifact_source_path" {
  description = "Root path for artifact source code"
  type        = string
  default     = "../src"
}

variable "lambda_layer_suffix" {
  description = "Lambda layer naming suffix"
  type        = string
  default     = "lambda-layer"
}

variable "lambda_source_suffix" {
  description = "Lambda source naming suffix"
  type        = string
  default     = "lambda-source"
}


variable "command_handler_name_prefix" {
  description = "Name prefix for command handler"
  type        = string
  default     = "command-handler"
}

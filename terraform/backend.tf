terraform {
  backend "s3" {
    bucket = "tfstate-backend-resize"
    key    = "terraform/state.tfstate"  # You can specify a path within the bucket
    region = "us-east-1"  # Set your region
  }
}



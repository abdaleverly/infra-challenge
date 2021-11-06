terraform {
  backend "s3" {
    bucket = "infra-challenge"
    key    = "webserver"
    region = "us-east-1"
  }
}
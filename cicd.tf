data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "artifact" {
  bucket_prefix = "${var.stack_name}-artifact-"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.key.arn
        sse_algorithm = "aws:kms"
      }
    }
  }
}

resource "aws_kms_key" "key" {
  description = "pipeline encryption"
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Id": "kms-key-policy",
    "Statement": [
      {
        "Sid": "Enable IAM User Permission",
        "Effect": "Allow",
        "Principal": {"AWS": "arn:aws:iam::${data.aws_caller_identity.current.id}:root"},
        "Action": "kms:*",
        "Resource": "*"
      },
      {
        "Sid": "AllowCodePipeline",
        "Effect": "Allow",
        "Action": "kms:*",
        "Resource": "*",
        "Principal": {"Service": "codepipeline.amazonaws.com"}
      }
    ]
  }
  EOF
}

resource "aws_codebuild_project" "web" {
  name          = "${var.stack_name}-web-project"
  description   = "Build job for ${var.stack_name} pipeline"
  build_timeout = "5"
  service_role  = aws_iam_role.build.arn
  encryption_key = aws_kms_key.key.id

  artifacts {
    encryption_disabled = false
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
      group_name  = "log-group"
      stream_name = "log-stream"
    }
  }

  source {
    type            = "CODEPIPELINE"
    git_clone_depth = 0

    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "master"

  tags = {
    Environment = "Test"
  }
}

# CodeDeploy
resource "aws_codedeploy_app" "web" {
  compute_platform = "Server"
  name             = "${var.stack_name}-web"
}

resource "aws_codedeploy_deployment_group" "web" {
  deployment_group_name = "${var.stack_name}-deployment-group"
  app_name = aws_codedeploy_app.web.name
  service_role_arn = aws_iam_role.codedeploy.arn

  ec2_tag_set {
    ec2_tag_filter {
      key = "Purpose"
      type = "KEY_AND_VALUE"
      value = "web"
    }
  }
}

# Codepipeline
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.stack_name}-connection"
  provider_type = "GitHub"
}


resource "aws_codepipeline" "this" {
  name = "${var.stack_name}-pipeline"
  role_arn = aws_iam_role.pipeline.arn
  artifact_store {
    location = aws_s3_bucket.artifact.bucket
    type = "S3"

    encryption_key {
      id = aws_kms_key.key.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name = "Source"
      category = "Source"
      owner = "AWS"
      provider = "CodeStarSourceConnection"
      version = "1"
      output_artifacts = ["code"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "abdaleverly/challenge-website"
        BranchName       = "master"
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      input_artifacts = ["code"]
      output_artifacts = ["build"]
      version = "1"

      configuration = {
        ProjectName = aws_codebuild_project.web.id
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name = "Deploy"
      category = "Deploy"
      owner = "AWS"
      provider = "CodeDeploy"
      input_artifacts = ["build"]
      version = "1"

      configuration = {
        ApplicationName = aws_codedeploy_app.web.name
        DeploymentGroupName = aws_codedeploy_deployment_group.web.deployment_group_name
      }
    }
  }
}
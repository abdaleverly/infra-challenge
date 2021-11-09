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
    location        = var.git_url
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "master"

  tags = {
    Environment = "Test"
  }
}

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
      version = "1"

      configuration = {
        ProjectName = aws_codebuild_project.web.id
      }
    }
  }
}

# resource "aws_codepipeline_webhook" "challenge" {
  
# }
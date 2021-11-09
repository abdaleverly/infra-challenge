# ec2 instance
resource "aws_iam_instance_profile" "web" {
  name = "${var.stack_name}-webserver-profile"
  role = aws_iam_role.web.name
}

resource "aws_iam_role" "web" {
  name = "${var.stack_name}-webserver-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

## codebuild
resource "aws_iam_role" "build" {
  name = "${var.stack_name}-build-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codebuild.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "build" {
  role = aws_iam_role.build.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.artifact.arn}",
        "${aws_s3_bucket.artifact.arn}/*"
      ]
    }
  ]
}
POLICY
}

# codepipeline
data "aws_iam_policy_document" "pipeline" {
  statement {
    sid = "artifactBucketAccess"
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.artifact.arn}", 
      "${aws_s3_bucket.artifact.arn}/*" 
    ]
  }
  statement {
    sid = "codebuildAccess"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = [aws_codebuild_project.web.arn]
  }
  statement {
    sid = "LogPermissions"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  role = aws_iam_role.pipeline.name

  policy = data.aws_iam_policy_document.pipeline.json
}

resource "aws_iam_role" "pipeline" {
  name = "${var.stack_name}-pipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codepipeline.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
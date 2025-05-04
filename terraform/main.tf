provider "aws" {
  region = var.region
}

# ✅ Source bucket (upload original images)
resource "aws_s3_bucket" "source_bucket" {
  bucket        = var.source_bucket_name
  force_destroy = true

  tags = {
    Name = "Source Bucket"
  }
}

# ✅ Destination bucket (store resized images)
resource "aws_s3_bucket" "dest_bucket" {
  bucket        = var.dest_bucket_name
  force_destroy = true

  tags = {
    Name = "Destination Bucket"
  }
}

# ✅ IAM role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# ✅ Attach basic logging policy to Lambda role
resource "aws_iam_policy_attachment" "lambda_basic" {
  name       = "${var.project_name}-lambda-basic"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ✅ Inline policy for S3 access
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-lambda-s3-access"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.source_bucket.arn}/*",
          "${aws_s3_bucket.dest_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetLayerVersion"
        ]
        Resource = "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-Pillow:12"
      }
    ]
  })
}

# ✅ Archive Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../lambda"
  output_path = "../lambda.zip"
}


# ✅ Lambda function
resource "aws_lambda_function" "resizer" {
  function_name = "${var.project_name}-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "resize.lambda_handler"
  runtime       = "python3.9"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.dest_bucket.bucket
    }
  }

  layers = [
    "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-Pillow:12"
  ]
}

# ✅ Permission to allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resizer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_bucket.arn
}

# ✅ S3 event to trigger Lambda on new image upload
resource "aws_s3_bucket_notification" "s3_trigger" {
  bucket = aws_s3_bucket.source_bucket.id

  lambda_function {
    events              = ["s3:ObjectCreated:*"]
    lambda_function_arn = aws_lambda_function.resizer.arn
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

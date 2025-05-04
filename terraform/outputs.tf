output "source_bucket_name" {
  value = aws_s3_bucket.source_bucket.bucket
}

output "destination_bucket_name" {
  value = aws_s3_bucket.dest_bucket.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.resizer.function_name
}

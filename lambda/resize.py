import boto3
from PIL import Image # type: ignore
import io
import os

def lambda_handler(event, context):
    # Initialize S3 client
    s3 = boto3.client('s3')

    # Extract bucket and object (image) key
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    destination_bucket = os.environ['DEST_BUCKET']

    # Download image to memory
    response = s3.get_object(Bucket=source_bucket, Key=object_key)
    image_content = response['Body'].read()

    # Open and resize the image
    image = Image.open(io.BytesIO(image_content))
    image = image.resize((128, 128))  # Resize to 128x128

    # Save the resized image to a buffer
    buffer = io.BytesIO()
    image.save(buffer, format='JPEG', optimize=True)
    buffer.seek(0)

    # Upload to destination bucket
    s3.put_object(Bucket=destination_bucket, Key=f"resized-{object_key}", Body=buffer, ContentType='image/jpeg')

    return {'statusCode': 200, 'body': f"Image resized and saved to {destination_bucket}/resized-{object_key}"}

import asyncio
from concurrent.futures import ThreadPoolExecutor

import boto3
import aioboto3
from loguru import logger

from zeta_voice.settings import settings


class S3Storage:
    """AWS S3 Storage class for storing and retrieving files."""

    def __init__(self) -> None:
        try:
            kwargs = self._client_kwargs()
            self.s3_client = boto3.client("s3", **kwargs)
            self.session = aioboto3.Session()
            self._async_kwargs = kwargs
        except Exception as e:
            logger.error(f"Failed to connect to AWS S3: {e}")
            raise

        self._executor = ThreadPoolExecutor(max_workers=4)

    def _client_kwargs(self) -> dict:
        """Build common boto3 / aioboto3 keyword arguments."""
        kwargs: dict = {
            "aws_access_key_id": settings.storage.AWS_ACCESS_KEY_ID,
            "aws_secret_access_key": settings.storage.AWS_SECRET_ACCESS_KEY,
            "region_name": settings.storage.AWS_REGION,
        }
        if settings.storage.AWS_S3_ENDPOINT_URL:
            # LocalStack or custom endpoint for local development
            kwargs["endpoint_url"] = settings.storage.AWS_S3_ENDPOINT_URL
        return kwargs

    def get_public_url(self, bucket_name: str, object_key: str) -> str:
        """Constructs a public URL for an S3 object."""
        if settings.storage.AWS_S3_ENDPOINT_URL:
            # LocalStack / custom endpoint — build URL manually
            endpoint = settings.storage.AWS_S3_ENDPOINT_URL.rstrip("/")
            return f"{endpoint}/{bucket_name}/{object_key}"
        region = settings.storage.AWS_REGION
        return f"https://{bucket_name}.s3.{region}.amazonaws.com/{object_key}"

    async def async_upload_to_blob(
        self, bytes_: bytes, bucket_name: str, object_key: str, content_type: str
    ) -> str:
        """Uploads bytes to S3 and returns the public URL (async version)."""
        async with self.session.client("s3", **self._async_kwargs) as s3:
            await s3.put_object(
                Bucket=bucket_name,
                Key=object_key,
                Body=bytes_,
                ContentType=content_type,
                ACL="public-read",
            )

        public_url = self.get_public_url(bucket_name, object_key)
        logger.info(f"Uploaded file to: {public_url}")
        return public_url

    async def async_upload_to_blob_audio(self, audio_bytes: bytes, bucket_name: str, object_key: str) -> str:
        """Uploads audio bytes and returns the public URL (async version)."""
        return await self.async_upload_to_blob(audio_bytes, bucket_name, object_key, "audio/mpeg")

    def upload_to_blob(self, bytes_: bytes, bucket_name: str, object_key: str, content_type: str) -> str:
        """Uploads bytes to S3 and returns the public URL."""
        self.s3_client.put_object(
            Bucket=bucket_name,
            Key=object_key,
            Body=bytes_,
            ContentType=content_type,
            ACL="public-read",
        )

        public_url = self.get_public_url(bucket_name, object_key)
        logger.info(f"Uploaded file to: {public_url}")
        return public_url

    def upload_to_blob_audio(self, audio_bytes: bytes, bucket_name: str, object_key: str) -> str:
        """Uploads audio bytes and returns the public URL."""
        return self.upload_to_blob(audio_bytes, bucket_name, object_key, "audio/mpeg")

    def create_container(self, bucket_name: str, public_access: bool = False) -> bool:
        """Create an S3 bucket.

        Args:
            bucket_name: Name of the bucket to create
            public_access: If True, disable the public access block so public-read ACLs work

        Returns:
            True if successful, False otherwise
        """
        try:
            region = settings.storage.AWS_REGION
            if region == "us-east-1":
                # us-east-1 does not accept a LocationConstraint
                self.s3_client.create_bucket(Bucket=bucket_name)
            else:
                self.s3_client.create_bucket(
                    Bucket=bucket_name,
                    CreateBucketConfiguration={"LocationConstraint": region},
                )
            logger.info(f"Bucket '{bucket_name}' created successfully")

            if public_access:
                self.s3_client.delete_public_access_block(Bucket=bucket_name)
                logger.info(f"Bucket '{bucket_name}' public access block removed")

            return True
        except self.s3_client.exceptions.BucketAlreadyOwnedByYou:
            logger.info(f"Bucket '{bucket_name}' already exists (owned by you)")
            return True
        except self.s3_client.exceptions.BucketAlreadyExists:
            logger.info(f"Bucket '{bucket_name}' already exists")
            return True
        except Exception as e:
            logger.error(f"Error creating bucket: {e}")
            return False

    def delete_container(self, bucket_name: str) -> bool:
        """Delete an S3 bucket.

        Args:
            bucket_name: Name of the bucket to delete

        Returns:
            True if successful, False otherwise
        """
        try:
            self.s3_client.delete_bucket(Bucket=bucket_name)
            logger.info(f"Bucket '{bucket_name}' deleted successfully")
            return True
        except self.s3_client.exceptions.NoSuchBucket:
            logger.warning(f"Bucket '{bucket_name}' does not exist")
            return False
        except Exception as e:
            logger.error(f"Error deleting bucket: {e}")
            return False

    async def cleanup(self) -> None:
        """Clean up resources."""
        self._executor.shutdown(wait=False)
        logger.debug("S3 storage client closed")

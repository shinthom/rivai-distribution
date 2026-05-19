#!/usr/bin/env python3
"""Upload a file to R2 via the S3 Compatibility API with multipart support.

Used by lib/r2.sh as the fallback when an artifact exceeds wrangler's
single-PUT 300 MiB ceiling. Credentials are pulled from environment variables
that lib/r2.sh sources from ~/.rivai/r2.env:

    R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET

Usage:
    r2_upload.py <key> <file> <content_type> [cache_control]
"""
import os
import sys

import boto3
from botocore.config import Config


def main() -> int:
    if len(sys.argv) < 4:
        print("usage: r2_upload.py <key> <file> <content_type> [cache_control]",
              file=sys.stderr)
        return 2

    key, file_path, content_type = sys.argv[1:4]
    cache_control = sys.argv[4] if len(sys.argv) > 4 else None

    required = ("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET")
    missing = [k for k in required if not os.environ.get(k)]
    if missing:
        print(f"missing env: {', '.join(missing)}", file=sys.stderr)
        return 2

    endpoint = f"https://{os.environ['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com"
    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )

    extra = {"ContentType": content_type}
    if cache_control:
        extra["CacheControl"] = cache_control

    size = os.path.getsize(file_path)
    print(f"boto3 upload: {os.environ['R2_BUCKET']}/{key} "
          f"({size / 1024 / 1024:.1f} MiB, {content_type})", file=sys.stderr)
    s3.upload_file(file_path, os.environ["R2_BUCKET"], key, ExtraArgs=extra)
    print("upload complete", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

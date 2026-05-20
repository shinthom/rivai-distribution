---
title: K01 — R2 Large File Upload (S3 API)
type: task
status: active
---

# K01. R2 대용량 업로드 — S3 Compatibility API

## 목적

R2에 **300 MiB 이상** 객체를 업로드한다. wrangler CLI와 Cloudflare Dashboard 모두 single-shot 300 MiB 한계가 있어, UE 게임 빌드(수백 MB ~ 수 GB) 업로드가 막혔다. R2의 **S3 Compatibility API + boto3 multipart**로 우회한다.

## 학습 목표

- R2의 두 인터페이스 — Cloudflare API(wrangler가 쓰는 것)와 S3 API(aws-cli/boto3 쓰는 것)의 차이
- **Multipart upload**가 무엇이고 왜 큰 파일에 필수인가 (HTTP 단일 PUT의 한계)
- R2 S3 Access Key는 Cloudflare API Token과 **별개의 자격증명**이라는 점
- 로컬 venv 격리로 시스템 Python에 부담 없이 boto3 사용

## 핵심 개념

### R2의 두 API

| 인터페이스 | 단일 PUT 한계 | 사용 도구 | 인증 |
|---|---|---|---|
| Cloudflare API (`api.cloudflare.com/.../r2/...`) | **300 MiB** | wrangler, Dashboard | Cloudflare API Token (`cfat_...`) |
| S3 Compatibility API (`<account>.r2.cloudflarestorage.com`) | 5 GiB (single) / 5 TiB (multipart) | aws-cli, boto3, rclone | R2 S3 Access Key (Access Key ID + Secret) |

큰 파일은 무조건 S3 API. wrangler는 manifest 같은 작은 파일에 적합.

### Multipart upload

S3 multipart는 큰 파일을 여러 part(보통 8 MiB)로 나눠 병렬 PUT → 마지막에 CompleteMultipartUpload로 합침. boto3의 `upload_file()`은 자동 multipart (default threshold ~8 MiB).

장점:
- 네트워크 끊겨도 part 단위 재시도
- 병렬 업로드로 속도 ↑
- 5 TiB까지 가능

### R2 S3 Access Key 발급

Cloudflare Dashboard → R2 → **Manage R2 API Tokens** → Create:
- **Permissions**: Object Read & Write
- **Bucket**: `rivai-dist` 한정
- 발급 시 **Access Key ID + Secret Access Key** 화면에 한 번만 표시 → 저장 필수
- **Endpoint**: `https://<account-id>.r2.cloudflarestorage.com`

## 결정 요약

| 항목 | 결정 |
|---|---|
| 큰 파일 클라이언트 | **boto3** (Python venv `/tmp/r2venv`) |
| 작은 파일·manifest | wrangler (기존 흐름 유지) |
| 자격 분리 | S3 Access Key는 R2 전용 (Cloudflare API Token과 별도 회전) |
| Region | `auto` (R2는 region-agnostic) |
| Signature | `s3v4` (S3 표준) |

## 구현 패턴 (boto3)

```python
import boto3, os
from botocore.config import Config

s3 = boto3.client('s3',
    endpoint_url='https://<account-id>.r2.cloudflarestorage.com',
    aws_access_key_id=os.environ['R2_KEY'],
    aws_secret_access_key=os.environ['R2_SECRET'],
    region_name='auto',
    config=Config(signature_version='s3v4'))

s3.upload_file('local.zip', 'rivai-dist', 'builds/dev/client/mac/file.zip',
               ExtraArgs={'ContentType': 'application/zip'})
```

`upload_file()`이 자동 multipart 처리. 500 MiB가 50~80 MiB/s 업로드 (~10초).

## 검증 기준

- [ ] 500 MiB 파일이 5분 안에 R2에 업로드된다.
- [ ] 업로드 후 R2 public URL HEAD → `Content-Length` 매칭, `Content-Type: application/zip`.
- [ ] sha256 round-trip 일치 (서버 측 계산 = 원본 sha256).
- [ ] manifest의 `client.<platform>.sha256` / `sizeBytes` 갱신 후 런처가 무결성 검증 통과.

## 산출물

| 자산 | 역할 |
|---|---|
| R2 S3 Access Key (Cloudflare Dashboard) | S3 API 자격 |
| `/tmp/r2venv` 격리 Python + boto3 | 업로드 클라이언트 |
| (장기) `release-game.sh` 의 zip 업로드 경로를 boto3로 교체 | wrangler 한계 영구 우회 |
| (장기) GitHub Actions workflow의 R2 업로드 step도 boto3 사용 | CI 자동화 |

## 운영 규칙

- **Access Key 노출 시 즉시 revoke**: Dashboard → R2 → Manage R2 API Tokens → Roll.
- Cloudflare API Token (wrangler용)과 R2 S3 Access Key는 **별도 회전 주기** 관리.
- CI에서 사용 시 GitHub Secrets에 두 자격을 모두 등록 (`CLOUDFLARE_API_TOKEN`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`).

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01]] — R2 manifest·zip 기본 구조
- [[G01-build-automation-draft|G01]] — `release-game.sh` 가 큰 zip 업로드 시 boto3로 분기
- [[L01-ue-source-build|L01]] — UE 게임 빌드(수백 MB) 업로드 시 본 task 패턴 사용

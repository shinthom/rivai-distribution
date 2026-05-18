### Step 1: Cloudflare 계정 및 R2 버킷 생성

1/ Cloudflare 대시보드 로그인 후 왼쪽 메뉴에서 'R2 -> 안전한 스토리지(Storage)'로 이동한다. R2 이용을 위해 결제 수단(신용카드) 등록이 필요하다. (기본 프리티어 범위가 매우 커서 테스트 단계에선 사실상 과금되지 않는다.)

2/ '버킷 생성(Create bucket)'을 누르고 버킷 이름을 입력한다. 프로젝트명을 반영해 `rivai-dist` 형태로 짓는 것을 권장한다. 지역(Location)은 자동(Automatic) 또는 아시아(Asia)로 지정한 뒤 생성을 완료한다.

---

### Step 2: R2 버킷 Public 액세스 허용 및 도메인 연결

1/ 생성된 버킷의 **'설정(Settings)'** 탭으로 이동한다. 기본적으로 R2의 모든 파일은 비공개 상태다. 외부 런처나 홈페이지가 접근할 수 있도록 하위의 **'Public 주소(Public Input)'** 항목을 찾아 활성화해야 한다.

2/ Cloudflare가 제공하는 기본 R2 dev 서브도메인을 사용해도 되지만, 실서비스 안정성을 위해 '도메인 연결(Connect Domain)'을 눌러 본인 소유의 서브도메인(예: `dist.rivai.example`)을 연결하는 것이 좋다. DNS 레코드가 자동으로 등록되며, 이후 이 도메인이 `downloadUrl`의 기반 주소가 된다.

---

### Step 3: API 자격 증명 (R2 Access Key) 발급

1/ 빌드 자동화 스크립트(CI/CD)나 CLI에서 R2에 파일을 업로드하려면 권한 키가 필요하다. R2 메인 화면 우측 상단의 'R2 API 토큰 관리(Manage R2 API Tokens)'를 클릭한다.

2/ '토큰 생성(Create token)'을 누르고, 권한을 '개정 및 쓰기(Object Read & Write)'로 설정한다. 생성이 완료되면 `Access Key ID`와 `Secret Access Key`, 그리고 S3 호환 `Endpoint URL`이 발급된다. 이 값들은 창을 닫으면 다시 볼 수 없으므로 안전한 곳에 메모해둔다.

---

### Step 4: Local 환경에 Wrangler CLI 설치 및 로그인

1/ 컴퓨터 터미널을 열고 Cloudflare 개발자 도구인 Wrangler를 글로벌 설치한다.

```bash
npm install -g wrangler

```

2/ 설치가 완료되면 다음 명령어를 입력해 Cloudflare 계정과 인증(로그인)을 진행한다. 브라우저 창이 뜨면 로그인을 승인한다.

```bash
wrangler login

```

---

### Step 5: 첫 빌드 Zip 및 Manifest 업로드 (더미 테스트)

1/ 테스트용 더미 파일(`rivai_client_0.0.1_dev.zip`)을 준비한다. 터미널(또는 파워쉘)에서 해당 파일의 sha256 해시값과 파일 크기(Bytes)를 뽑아낸다.

* Mac/Linux: `shasum -a 256 파일명` / `wc -c 파일명`
* Windows: `Get-FileHash -Algorithm SHA256 파일명` / `(Get-Item 파일명).Length`

2/ 확인한 해시와 크기 정보를 바탕으로 `manifest.json` 내용을 작성한다.

3/ Wrangler CLI를 사용해 R2 버킷에 규칙에 맞춰 업로드한다. 경로(Key) 구조를 그대로 유지하는 것이 핵심이다.

```bash
# 1. 빌드 파일 업로드
wrangler r2 object put rivai-dist/builds/dev/client/rivai_client_0.0.1_dev.zip --file=path/to/local.zip

# 2. Manifest 파일 업로드 (Content-Type 지정 필수)
wrangler r2 object put rivai-dist/manifest/dev.json --file=path/to/manifest.json --content-type=application/json

```

---

### Step 6: Cloudflare Pages로 홈페이지 및 수동 배포 환경 연결

1/ `manifest.json`이나 패치노트 웹페이지를 깔끔한 웹 호스팅으로 서비스하고 싶다면 **'Pages'** 기능을 연동한다. 대시보드에서 **'Workers & Pages' -> '생성(Create)' -> 'Pages'** 탭을 선택한다.

2/ GitHub 저장소를 연결하거나 빌드된 정적 자산(HTML/JS) 폴더를 직접 업로드하여 배포를 완료한다. 배포가 완료되면 `[https://project.pages.dev](https://project.pages.dev)` 형태의 고유 주소가 제공되며, 이 주소를 런처나 공식 홈페이지의 메인 기반 URL로 삼으면 모든 인프라 세팅이 끝난다.
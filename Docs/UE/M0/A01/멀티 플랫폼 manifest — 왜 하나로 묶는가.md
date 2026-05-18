1/ Windows와 Mac 두 클라이언트를 모두 배포할 때 manifest를 어떻게 설계할까? 직관적으로는 '플랫폼마다 manifest 분리'(`dev-win64.json`, `dev-mac.json`)가 떠오르지만, 한 manifest 안에 platform 분기로 묶는 게 정답이다.

2/ 만약 manifest를 분리하면 새 빌드 배포 때 두 파일을 동시에 갱신해야 한다. 한쪽 PUT은 성공하고 다른 쪽이 실패하는 짧은 순간 동안 두 manifest가 가리키는 `latestVersion`이 일치하지 않게 된다. **SSOT(Single Source of Truth) 원칙이 깨진다.**

3/ 한 파일 안에 `client.win64`와 `client.mac`을 두면 PUT 한 번으로 두 플랫폼이 원자적으로 함께 갱신된다. 런처는 자신의 OS를 확인하고 해당 키만 읽는다 — 있으면 그 빌드를 다운로드, 없으면 "이 빌드는 내 OS 미지원"으로 명확히 처리한다.

4/ 이 패턴의 또 다른 이득은 **누락의 명시화**다. 특정 빌드에서 Mac 컴파일이 실패했다면 그 빌드의 manifest에서 `client.mac` 키를 빼면 된다. "이 빌드는 Mac 미지원"이 manifest에 자명하게 표현되고, 런처가 잘못된 zip을 받을 일이 없다.

5/ 그렇다면 manifest를 분리해야 하는 경우는 언제인가? **채널(channel)이 다를 때**다. dev/qa/live는 배포 주기와 가시성이 완전히 달라 같은 파일에 두면 갱신 충돌이 잦다. 정리: '같은 빌드의 다른 플랫폼'은 한 manifest 안에서 분기로, '다른 채널'은 다른 manifest로.

1/ Mac의 `.app`은 Finder에서 '단일 파일'처럼 보이지만 실제로는 **디렉토리(번들)** 다. 그 안에 `Contents/MacOS/`(실행 파일), `Contents/Resources/`(아이콘·리소스), `Contents/Info.plist`(메타데이터) 같은 표준 구조가 들어 있다. 터미널에서 `ls Rivai.app/Contents/`로 들여다보면 확인된다.

2/ 일반 `zip`으로 `.app`을 압축하면 macOS 고유 메타데이터가 사라진다. 실행 권한(`chmod +x`), 확장 속성(xattr), 리소스 포크(Resource Fork), 심볼릭 링크 같은 것들이다. 이 정보가 빠지면 풀었을 때 앱이 실행조차 안 되거나 "권한 거부"로 죽는다.

3/ Apple이 권장하는 압축 도구는 `ditto`다. `ditto -c -k --sequesterRsrc --keepParent Rivai.app rivai.zip`으로 묶으면 모든 메타데이터가 보존된다. macOS Finder의 우클릭 "압축"도 내부적으로 ditto를 사용한다. 풀 때도 가능하면 `ditto -x -k rivai.zip 출력디렉토리`로 푸는 게 가장 안전하다.

4/ 윈도우 사용자가 받아서 windows의 `unzip`으로 풀면 다시 메타데이터가 깎인다. 다행히 런처는 Mac에서만 실행되므로 압축은 Mac에서, 해제도 Mac native 도구로 — 양쪽 모두 macOS가 책임지게 두면 문제없다.

5/ 추가로 사인되지 않은 `.app`은 macOS Gatekeeper가 첫 실행을 막는다. 정식 해법은 **코드 사인(Code Signing) + 공증(Notarization)** 이지만, 둘 다 Apple Developer 계정($99/년)과 별도 절차가 필요하다. M0 단계에서는 테스터에게 "우클릭 → 열기" 우회를 안내하고, 정식 사인은 후속 마일스톤으로 미룬다.

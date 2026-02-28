# YouTubeMusicMenuBar

Safari에서 YouTube Music 재생 상태를 읽어 메뉴바에 `가수 - 제목`을 표시하고, 클릭 시 팝업(앨범아트/재생바/컨트롤/가사/종료)을 제공하는 macOS 메뉴바 앱입니다.

## 구현된 기능
- 메뉴바 아이콘 + 재생 중일 때만 `가수 - 제목` 표시
- 재생 중이 아닐 때는 메뉴바에 아이콘만 표시
- 팝업 구성
  - 앨범 표지
  - 재생 진행바
  - 재생/앞/뒤 버튼
  - YouTube Music 페이지에서 읽어온 가사
  - 앱 종료 버튼
- Safari의 YouTube Music 탭 제어(AppleScript + JavaScript)
- 빌드 시 `.app` 번들 + 배포용 zip 생성

## 빌드
```bash
# 레포 루트 디렉토리에서 실행
./Scripts/build.sh
```

산출물:
- `Build/YouTubeMusicMenuBar.app`
- `Dist/YouTubeMusicMenuBar.zip`

## 설치
```bash
cp -R "./Build/YouTubeMusicMenuBar.app" /Applications/
```

## 권한
최초 실행 시 macOS에서 Apple Events 권한을 요청할 수 있습니다.
- System Settings > Privacy & Security > Automation에서 허용 필요

## 배포 검토(실배포)
현재는 ad-hoc 서명 상태이며 개인 사용에는 충분합니다. 외부 배포 시 아래가 추가로 필요합니다.
1. Apple Developer ID Application 인증서로 정식 서명
2. Hardened Runtime 옵션 적용
3. Notarization (`xcrun notarytool`) 통과
4. Stapling (`xcrun stapler`) 수행

## 아이콘 참고
- 런타임 시도: 공식 YouTube Music favicon(`music.youtube.com/img/favicon_144.png`)을 메뉴바 아이콘으로 로드 시도
- 오프라인/차단 환경 대비: 빌드 시 생성한 대체 아이콘 사용

# Multi-Agent Worktree Manager (MAWT) - 개발 로드맵

이 로드맵은 `mawt` (Multi-Agent Worktree) 프로젝트의 개발 계획을 요약한 것입니다. `mawt`는 GitLab 저장소를 Git Worktree로 관리하고 AI 에이전트(Gemini, ClaudeCode, Codex 등)를 격리된 워크트리 환경에서 효율적으로 실행할 수 있도록 설계된 CLI 도구입니다.

## 1. 프로젝트 초기화 및 설정
- [x] **저장소 구조**: 기본 디렉토리 구조 생성.
- [x] **라이선스**: MIT 라이선스 적용 (암시적, 파일 추가 필요).
- [x] **문서화**: `README.md` 작성 및 업데이트.
- [x] **CI/CD**: ShellCheck 등을 이용한 기본 쉘 스크립트 린트 자동화.

## 2. 설치 전략 (`install.sh`)
목표: 원라인 설치 (`curl ... | bash`)

- [x] **의존성 확인**:
    - `git`, `curl`, `unzip`, `tar` 필수 확인.
    - `jq`, `fzf` 확인 및 macOS/Linux 설치 안내 메시지 추가.
- [x] **경로 설정**:
    - 설치 디렉토리(`~/.mawt/bin`)를 `.bashrc` / `.zshrc` PATH에 자동 추가.
- [x] **자동 업데이트**: 설치 스크립트 재실행 시 기존 설정 유지하며 업데이트.
- [x] **macOS 지원**: `brew install` 안내 등 크로스 플랫폼 호환성 확보.

## 3. 핵심 로직: 작업 공간 및 저장소 관리

### 3.1. 작업 공간(Workspace) 선택
- [x] **사용자 입력**: 작업 공간 디렉토리 지정 (기본값: `~/workspace`).
- [x] **생성**: 디렉토리 없을 시 자동 생성.

### 3.2. 저장소 가져오기 (스마트 클론)
- [x] **입력**: GitLab 저장소 URL 또는 프로젝트 ID.
- [x] **프로토콜 선택**:
    - SSH / HTTPS 선택 지원.
    - **Private GitLab 인증**: HTTPS 클론 시 GitLab Token 자동 주입 기능 구현.
- [x] **중복 확인**:
    - 이미 존재하는 폴더 감지.
    - **Bare Clone**: 워크트리 사용을 위해 기본적으로 `git clone --bare` 수행.

### 3.3. 저장소 검사 및 변환 (Worktreeifier)
- [x] **상태 확인**: 일반 Git 저장소인지, 이미 Bare/Worktree 구조인지 감지.
- [x] **일반 저장소 변환**:
    - 기존 `.git` 폴더를 이동하여 Bare 저장소 구조로 변환하는 로직 구현.
    - 데이터 손실 방지를 위해 기존 브랜치를 워크트리로 재구성.
- [x] **워크트리 관리**:
    - 작업별/에이전트별 독립 워크트리 생성 (`worktrees/gemini-fix-bug-123`).
    - **브랜치 이름 자동완성**: Base Branch 이름 그대로 사용 기능 추가.

## 4. 에이전트 통합 래퍼 (`mawt` CLI)
사용자의 주요 진입점.

- [x] **에이전트 선택 메뉴**:
    1.  Gemini CLI
    2.  ClaudeCode CLI
    3.  Codex CLI
    4.  Shell (기본 쉘)
- [x] **컨텍스트 설정**:
    - 생성된 워크트리 디렉토리로 이동(`cd`).
- [x] **인증 관리**:
    - 에이전트별 API Key(`GEMINI_API_KEY` 등) 환경 변수 확인.
    - 키 미설정 시 대화형 입력 및 설정 파일(`config`) 저장 기능 구현.
- [x] **실행**: 격리된 워크트리 환경에서 선택한 에이전트 실행.
- [x] **초기화 명령 (`init`)**: 대화형 모드 없이 특정 저장소 바로 초기화 기능 추가.

## 5. 호환성 및 확장
- [x] **WSL 통합**: Ubuntu WSL 환경 테스트 완료.
- [x] **macOS 호환성**: `/proc/version` 체크 로직 개선 및 의존성 설치 안내 추가.
- [x] **브라우저 통합**: 인증 흐름에서 브라우저 열기(`open`, `wsl-open`) 지원 개선.

## 6. 배포
- [x] **릴리스 관리**: GitHub Release 태그 생성.
- [x] **설치 스크립트 호스팅**: GitHub Raw URL을 통한 배포 확인.

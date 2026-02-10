# Multi-Agent Worktree Manager (MAWT)

MAWT(Multi-Agent Worktree Manager)는 Git Worktree를 활용하여 GitLab 저장소를 관리하고, Gemini, ClaudeCode, Codex와 같은 AI 에이전트를 격리된 환경에서 효율적으로 실행할 수 있도록 돕는 CLI 도구입니다.

## 주요 기능

- **GitLab 통합**: GitLab 인스턴스(Private 포함)에서 프로젝트 목록을 자동으로 가져옵니다.
- **스마트 클론**: Git Worktree 사용을 위해 저장소를 기본적으로 "bare" 저장소로 클론합니다.
- **자동 변환**: 기존의 일반 Git 저장소를 감지하여 Worktree 구조로 변환할 수 있습니다.
- **에이전트 실행**: 각 AI 에이전트 도구를 독립된 워크트리 환경에서 실행하여 충돌을 방지합니다.
- **인증 관리**: Private 저장소 접근을 위한 GitLab 토큰 자동 주입 및 AI 에이전트(Gemini, Claude 등) API Key 관리를 지원합니다.
- **크로스 플랫폼**: Linux(WSL 포함), macOS, Windows(PowerShell)를 지원합니다.

## 필수 요구 사항

### Linux / macOS
- **도구**: `git`, `curl`, `jq`, `unzip`, `tar`
- **선택 사항**: `fzf` (대화형 선택 메뉴를 위해 강력 권장, 없으면 설치 스크립트가 안내)

### Windows
- **도구**: PowerShell 5.1+, `git`
- **선택 사항**: `fzf` (설치되어 있으면 사용, 없으면 `Out-GridView` 또는 텍스트 메뉴로 대체)

## 설치 및 업데이트

### Linux / macOS
터미널에서 아래 명령어를 실행하여 **mawt**를 설치하거나 최신 버전으로 업데이트할 수 있습니다.

```bash
curl -fsSL https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/install.sh | bash
```

**설치 후 적용:**
현재 터미널 세션에서 바로 사용하려면 다음을 실행하세요:
```bash
# Bash 사용자
source ~/.bashrc

# Zsh 사용자
source ~/.zshrc
```
또는 터미널을 재시작하면 됩니다.

### Windows (PowerShell)
PowerShell 터미널을 열고 아래 명령어를 실행하세요:

```powershell
irm https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/install.ps1 | iex
```

만약 **Command Prompt (cmd)**를 사용 중이라면 아래 명령어를 복사해 실행하세요:

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/install.ps1 | iex"
```

설치 후 터미널을 재시작하면 `mawt` 명령어를 사용할 수 있습니다.

### 초기 설정
첫 설치 시, 다음과 같은 설정을 대화형으로 진행합니다:
1.  **Workspace Directory**: 저장소를 보관할 작업 디렉토리 (기본값: `~/workspace`).
2.  **Git Protocol**: `SSH` (권장) 또는 `HTTPS` 중 선택.
3.  **GitLab Base URL**: GitLab 인스턴스 주소 (예: `http://gitlab.mycompany.com`).
4.  **GitLab Token**: Private GitLab 프로젝트 목록을 가져오기 위한 액세스 토큰.

*설정은 `~/.mawt/config` 파일에 저장됩니다.*

## 사용 방법

### 1. 대화형 모드 (기본)
아무런 인자 없이 실행하면 전체 워크플로우를 대화형으로 진행합니다.
1. 저장소 선택
2. 작업할 워크트리 선택 (새로 생성하거나 기존 것 선택)
3. 사용할 AI 에이전트 선택

```bash
mawt
```

### 2. 저장소 초기화 (`init`)
특정 저장소를 빠르게 초기화(클론 및 설정)합니다.

```bash
# 특정 그룹/프로젝트 초기화
mawt init group/project
```

### 3. 저장소 목록 확인 (`list`)
MAWT로 관리 중인 모든 저장소와 활성화된 워크트리 목록을 보여줍니다.

```bash
mawt list
```

### 4. 삭제 (`uninstall`)
MAWT CLI 도구와 설정 파일을 시스템에서 제거합니다.
*주의: 작업했던 Workspace 디렉토리와 저장소 파일은 삭제되지 않습니다.*

```bash
mawt uninstall
```

## 개발 로드맵

상세 개발 계획은 [ROADMAP.md](ROADMAP.md)를 참고하세요.
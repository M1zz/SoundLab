import SwiftUI

/// Which in-app tool performs a given task. `nil` means the work happens outside the app.
enum TaskTool: Equatable {
    case earTraining(DrillLevel)
    case synthLab(challenge: Int?)
    case referenceNotes
    case fieldRecorder
    case deliverables
    case external(String)   // label describing where the work actually happens
}

struct CurriculumTask: Identifiable {
    let id: String
    let title: String
    /// One line on why this task exists.
    let rationale: String
    /// Ordered, concrete steps. This is the "방법" the user asked for.
    let method: [String]
    /// What counts as done. Vague tasks never get finished.
    let doneWhen: String
    let tool: TaskTool
}

struct Phase: Identifiable {
    let id: String
    let title: String
    let weeks: String
    let why: String
    let tint: Color
    let deliverable: String
    let tasks: [CurriculumTask]
}

enum Curriculum {

    static let principles: [(String, String)] = [
        ("붙일 대상 없이 소리만 만들지 않는다",
         "화면, 영상, 게임 상태 중 하나는 항상 옆에 둡니다. 맥락 없는 소리는 좋고 나쁨을 판단할 기준이 없습니다."),
        ("파라미터는 한 번에 하나씩만 바꾼다",
         "극단까지 돌렸다가 되돌립니다. 변수 통제가 안 되면 인과관계를 배울 수 없습니다. 신스 랩의 집중 모드가 이걸 강제합니다."),
        ("6개월간 장비를 사지 않는다",
         "지금 있는 홈 레코딩 셋업과 무료 툴로 충분합니다. 장비 구매는 실력 부족을 가장 손쉽게 회피하는 경로입니다.")
    ]

    static let all: [Phase] = [phase0, phase1, phase2, phase3]

    // MARK: - Phase 0

    static let phase0 = Phase(
        id: "p0",
        title: "귀 만들기",
        weeks: "W1–4",
        why: "음정 감각과 음색·대역 청취는 서로 다른 근육입니다. 여기를 건너뛰면 이후 모든 작업을 귀가 아니라 EQ 그래프를 눈으로 보면서 하게 됩니다.",
        tint: .cyan,
        deliverable: "레퍼런스 20개 분석 노트 + 대역 식별 정답률 80% 이상",
        tasks: [
            CurriculumTask(
                id: "p0.t1",
                title: "매일 15분 대역 식별 훈련",
                rationale: "매일 짧게가 전부입니다. 주말에 몰아서 두 시간 하는 것보다 매일 15분이 낫습니다.",
                method: [
                    "귀 훈련 탭에서 난이도 '입문 3밴드'로 시작합니다.",
                    "핑크 노이즈가 흐르는 동안 A/B 버튼으로 원본과 부스트된 소리를 번갈아 듣습니다.",
                    "어느 대역이 달라졌는지 고릅니다. 한 세션은 10문제입니다.",
                    "정답률이 3일 연속 80%를 넘으면 다음 난이도로 올립니다.",
                    "난이도가 올라갈수록 밴드 수가 늘고 부스트 양이 ±12dB → ±6dB → ±3dB로 줄어듭니다."
                ],
                doneWhen: "28일 중 24일 이상 기록이 남아 있고, '중급 5밴드' 정답률이 80%를 넘음",
                tool: .earTraining(.starter)
            ),
            CurriculumTask(
                id: "p0.t2",
                title: "다섯 대역을 눈 감고 구분하기",
                rationale: "100Hz·250Hz·1kHz·3kHz·8kHz는 실무에서 가장 자주 만지는 지점입니다. 여기가 몸에 붙으면 나머지는 보간됩니다.",
                method: [
                    "난이도를 '중급 5밴드'로 고정합니다.",
                    "부스트뿐 아니라 컷도 섞여서 나옵니다. 방향까지 맞히세요.",
                    "틀린 대역은 결과 화면에서 따로 표시됩니다. 그 대역만 10번 더 들어 보세요.",
                    "3kHz가 가장 어렵습니다. 사람 목소리의 명료도 대역이라 평소에 인식하지 못한 채 듣고 있어서 그렇습니다."
                ],
                doneWhen: "중급 5밴드에서 정답률 80% 이상을 3세션 연속 기록",
                tool: .earTraining(.intermediate)
            ),
            CurriculumTask(
                id: "p0.t3",
                title: "앱·게임 소리 20개 채집하고 분석하기",
                rationale: "좋은 소리를 듣는 것과 왜 좋은지 말로 설명하는 것은 다릅니다. 언어가 없으면 재현도 못 합니다.",
                method: [
                    "평소 쓰는 앱과 게임에서 인상적인 소리 20개를 고릅니다. 화면 녹화로 오디오를 확보하세요.",
                    "기록 탭 → 레퍼런스 노트에서 하나씩 등록합니다.",
                    "네 축으로 점수를 매깁니다 — 어택 속도, 저역 존재감, 배음 거칠기, 테일 길이.",
                    "마지막에 '이 소리가 만드는 감정'을 한 줄로 씁니다. 형용사 말고 상황으로 쓰세요. ('밝다' ✗ → '일이 끝났다고 알려준다' ○)",
                    "20개가 모이면 네 축의 분포를 보세요. 성공음과 실패음이 어느 축에서 갈리는지 드러납니다."
                ],
                doneWhen: "레퍼런스 노트 20개 등록 완료",
                tool: .referenceNotes
            )
        ]
    )

    // MARK: - Phase 1

    static let phase1 = Phase(
        id: "p1",
        title: "신시사이스",
        weeks: "W5–10",
        why: "Minimoog가 너무 기술적으로 느껴졌던 건 실력 문제가 아니라 인터페이스 문제입니다. 아날로그 신스는 방금 돌린 노브가 무엇을 바꿨는지 보여주지 않습니다. 인과가 보이는 도구부터 시작합니다.",
        tint: .purple,
        deliverable: "재현 과제 6개 통과 + 각 소리의 파라미터 레시피 메모",
        tasks: [
            CurriculumTask(
                id: "p1.t1",
                title: "파라미터 한 개씩 극단까지 돌려보기",
                rationale: "신스를 못 배우는 가장 흔한 이유는 여러 노브를 동시에 만져서 무엇이 무엇을 바꿨는지 영영 모르게 되는 것입니다.",
                method: [
                    "신스 랩 탭 → 집중 모드에서 파라미터를 하나 고릅니다.",
                    "고른 파라미터 외에는 슬라이더가 잠깁니다. 의도한 제약입니다.",
                    "최솟값 → 최댓값 → 기준값 순으로 돌리면서 매번 트리거합니다.",
                    "'기준 패치로 되돌리기'를 누르고 다음 파라미터로 넘어갑니다.",
                    "컷오프 → 레조넌스 → 어택 → 디케이 → 필터 모드 → 피치 스윕 순서를 권합니다."
                ],
                doneWhen: "12개 파라미터 전부를 집중 모드로 한 바퀴 돌려봄",
                tool: .synthLab(challenge: nil)
            ),
            CurriculumTask(
                id: "p1.t2",
                title: "재현 과제 6개 — 킥·심벌·물방울·바람·레이저·심장박동",
                rationale: "물방울과 바람이 핵심입니다. 조성이 없는 소리를 다루는 훈련이고, 음악 훈련을 받은 귀가 가장 약한 지점입니다.",
                method: [
                    "신스 랩에서 과제를 고르면 목표 소리를 들을 수 있습니다.",
                    "먼저 힌트를 열지 말고 직접 만들어 봅니다. 최소 10분.",
                    "A/B 버튼으로 내 패치와 목표를 번갈아 들으며 차이를 좁힙니다.",
                    "막히면 힌트를 엽니다. 힌트에는 어떤 파라미터가 그 소리의 정체성을 만드는지 적혀 있습니다.",
                    "통과한 뒤에도 레시피를 손으로 다시 적으세요. 읽은 것과 적은 것은 다르게 남습니다."
                ],
                doneWhen: "6개 과제 모두 '통과' 표시 + 레시피 메모 6개",
                tool: .synthLab(challenge: 0)
            ),
            CurriculumTask(
                id: "p1.t3",
                title: "데스크톱 신스로 옮겨 타기",
                rationale: "이 앱의 신스는 인과관계 학습용입니다. 실제 작업은 더 큰 도구에서 합니다.",
                method: [
                    "Ableton Learning Synths(무료 웹)를 1주 안에 훑습니다. 개념만.",
                    "Vital(무료)을 설치하고 마음에 드는 프리셋 10개를 역설계합니다.",
                    "역설계 방법은 같습니다 — 모듈레이션을 하나씩 끄고 무엇이 사라지는지 확인.",
                    "이 앱에서 통과한 6개 소리를 Vital에서 다시 만들어 봅니다. 같은 원리가 어떻게 다른 UI로 표현되는지 확인하는 게 목적입니다.",
                    "여유가 있으면 Surge XT로 FM과 웨이브테이블이 감산 합성과 뭐가 다른지만 봅니다."
                ],
                doneWhen: "Vital 프리셋 6개를 직접 저장",
                tool: .external("Vital · Surge XT · Ableton Learning Synths")
            )
        ]
    )

    // MARK: - Phase 2

    static let phase2 = Phase(
        id: "p2",
        title: "녹음과 폴리",
        weeks: "W11–14",
        why: "소리의 출처와 의미를 분리하는 능력이 감정 조작의 핵심 기술입니다. 관객은 셀러리가 부러지는 소리를 듣고 뼈를 떠올립니다.",
        tint: .orange,
        deliverable: "태그 정리된 사운드 라이브러리 30개 + 재배치 데모 5개",
        tasks: [
            CurriculumTask(
                id: "p2.t1",
                title: "집 안 물건 30개 녹음",
                rationale: "재료가 없으면 편집 기술도 쓸 데가 없습니다. 그리고 장비는 추가로 사지 않습니다.",
                method: [
                    "기록 탭 → 필드 레코딩에서 바로 녹음합니다. 아이폰 마이크로 충분합니다.",
                    "가까이 대고 녹음하세요. 대부분의 초보 녹음 문제는 마이크가 너무 멀어서 생깁니다.",
                    "한 물건당 세 가지 방식으로 — 살살, 세게, 느리게.",
                    "녹음마다 '무엇을 녹음했는가'와 '무엇으로 쓸 수 있는가'를 따로 적습니다.",
                    "정식 작업은 홈 레코딩 셋업에서 다시 하되, 아이디어 수집은 이 앱으로 빠르게."
                ],
                doneWhen: "필드 레코딩 30개 등록, 각각 재배치 아이디어가 적혀 있음",
                tool: .fieldRecorder
            ),
            CurriculumTask(
                id: "p2.t2",
                title: "바이올린을 악기가 아닌 소재로 녹음",
                rationale: "이미 가진 재료 중 가장 독특한 것입니다. 다른 사운드 디자이너가 쉽게 못 만드는 라이브러리가 됩니다.",
                method: [
                    "활 스크래치 — 활털을 현에 눌러 천천히 끕니다. 쇳소리, 문 삐걱임으로 쓸 수 있습니다.",
                    "브리지 뒤 보잉 — 브리지와 테일피스 사이를 켭니다. 조성이 없는 금속성 노이즈가 납니다.",
                    "페그 돌리기 — 나무 마찰음. 오래된 기계 장치 소리로 좋습니다.",
                    "바디 노크와 하모닉스 글리산도도 각각 녹음합니다.",
                    "각 녹음에 '무엇으로 들리는가'를 적습니다. 바이올린으로 들리면 실패입니다."
                ],
                doneWhen: "바이올린 소재 녹음 8개 이상, 전부 비악기적 용도가 적혀 있음",
                tool: .fieldRecorder
            ),
            CurriculumTask(
                id: "p2.t3",
                title: "녹음 공간의 노이즈 플로어 정리",
                rationale: "노이즈 플로어를 모르면 나중에 노이즈 제거에 시간을 다 씁니다.",
                method: [
                    "아무 소리도 내지 않고 30초 녹음합니다.",
                    "냉장고, 에어컨, 공기청정기를 하나씩 끄면서 각각 다시 녹음합니다.",
                    "어느 기기가 얼마나 기여하는지 확인하고, 녹음 전 체크리스트를 만듭니다.",
                    "창문·문 여닫음, 시간대(새벽 vs 저녁)도 같은 방식으로 비교합니다."
                ],
                doneWhen: "녹음 전 체크리스트가 기록 탭에 주간 결과물로 저장됨",
                tool: .fieldRecorder
            )
        ]
    )

    // MARK: - Phase 3

    static let phase3 = Phase(
        id: "p3",
        title: "편집과 프로세싱",
        weeks: "W15–20",
        why: "원본 소리는 재료일 뿐입니다. 감정의 대부분은 처리 단계에서 결정됩니다. 여기부터는 앱이 아니라 DAW에서 합니다.",
        tint: .green,
        deliverable: "임팩트 사운드 10개 + 각 소리의 레이어 구조 문서",
        tasks: [
            CurriculumTask(
                id: "p3.t1",
                title: "DAW 하나 정해서 단축키 20개 외우기",
                rationale: "플러그인을 늘리는 것보다 도구 하나를 손에 붙이는 게 훨씬 큰 차이를 만듭니다.",
                method: [
                    "Reaper를 권합니다. 저렴하고 Lua 스크립팅이 됩니다.",
                    "이미 Logic을 쓰고 있다면 Logic으로 가세요. 바꾸는 비용이 더 큽니다.",
                    "자르기·페이드·리버스·정규화·리샘플·렌더 여섯 개부터 손에 붙입니다.",
                    "스톡 플러그인만 씁니다. 6개월간 유료 플러그인 금지."
                ],
                doneWhen: "마우스 없이 30초짜리 소리 하나를 편집해서 렌더까지 완료",
                tool: .external("Reaper 또는 Logic Pro")
            ),
            CurriculumTask(
                id: "p3.t2",
                title: "어택 + 바디 + 테일 3층 레이어링으로 임팩트 10개",
                rationale: "대부분의 '있어 보이는' 소리는 하나의 소리가 아니라 세 층의 합성입니다.",
                method: [
                    "어택 — 탁 하고 시작을 알리는 짧은 트랜지언트. 2단계에서 녹음한 타격음을 씁니다.",
                    "바디 — 소리의 정체성을 결정하는 음색. 신스나 바이올린 소재를 씁니다.",
                    "테일 — 공간과 여운. 리버브를 건 뒤 원본을 지우면 테일만 남습니다.",
                    "세 층을 따로 만들어 합칩니다. 각 층의 볼륨을 0까지 내려 보며 기여도를 확인하세요.",
                    "완성한 10개 각각에 대해 어느 층이 감정을 만들었는지 한 줄로 적습니다."
                ],
                doneWhen: "임팩트 10개 렌더 완료 + 레이어 구조 문서 작성",
                tool: .external("DAW")
            ),
            CurriculumTask(
                id: "p3.t3",
                title: "반복 작업 자동화 스크립트 1개",
                rationale: "개발자만 쓸 수 있는 지렛대입니다. 사운드 디자이너 대부분은 이걸 못 합니다.",
                method: [
                    "Reaper의 Lua 스크립팅으로 배치 렌더나 네이밍 규칙 적용을 자동화합니다.",
                    "예 — 선택한 아이템을 전부 개별 파일로 렌더하고 '카테고리_소재_변형_번호' 규칙으로 이름 붙이기.",
                    "라이브러리가 커지면 검색 가능성이 자산이 됩니다. 지금 규칙을 정해 두세요.",
                    "Logic을 쓴다면 Audio File 이름 규칙과 Smart Tempo 대신 셸 스크립트 + afconvert 조합을 고려하세요."
                ],
                doneWhen: "스크립트 1개가 실제 작업에서 동작",
                tool: .external("Reaper Lua 또는 셸 스크립트")
            )
        ]
    )

    // MARK: - Portfolio

    struct ShipItem: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let method: [String]
    }

    static let shipList: [ShipItem] = [
        ShipItem(
            id: 1,
            title: "본인 앱의 사운드 시스템",
            detail: "앱 하나를 골라 탭·성공·실패·알림·전환 사운드 10~15개를 하나의 세트로 만듭니다.",
            method: [
                "먼저 브랜드 톤을 한 문장으로 정의합니다. ('조용하고 단단하다' 같은)",
                "성공음과 실패음의 차이를 어느 축에서 만들지 정합니다. 피치 방향이 가장 읽히기 쉽습니다.",
                "전체를 한 번에 만들고, 한 번에 듣습니다. 낱개로 만들면 세트가 아니라 모음이 됩니다.",
                "로컬 알림 사운드는 Linear PCM 계열 30초 이내 .caf/.wav/.aiff만 됩니다. afconvert로 변환하세요.",
                "실제 기기 스피커로 검수합니다. 헤드폰에서만 좋은 소리는 UI 사운드로 실패입니다."
            ]
        ),
        ShipItem(
            id: 2,
            title: "사운드 리디자인",
            detail: "기존 게임이나 영화 트레일러 30~60초의 오디오를 전부 지우고 처음부터 다시 만듭니다.",
            method: [
                "원본 오디오를 완전히 음소거하고 시작합니다. 참고용으로도 듣지 마세요.",
                "레이어 순서 — 앰비언스 → 하드 이펙트 → 폴리 → 디자인된 소리 → 음악.",
                "컷 지점보다 2~3프레임 먼저 소리를 붙이면 훨씬 자연스럽습니다.",
                "다 만든 뒤 원본과 비교합니다. 비교는 마지막에만.",
                "업계 포트폴리오의 사실상 표준 관문입니다. 이게 없으면 지원 자체가 어렵습니다."
            ]
        ),
        ShipItem(
            id: 3,
            title: "절차적 사운드",
            detail: "AVAudioEngine 또는 AudioKit으로 앱 상태에 따라 실시간 합성되는 소리를 만듭니다.",
            method: [
                "이 앱의 MiniSynth.swift가 출발점입니다. 이미 동작하는 합성 코드가 들어 있습니다.",
                "파일 재생이 아니라 파라미터 생성이어야 합니다. 같은 소리가 두 번 나오지 않게.",
                "스크롤 속도, 남은 시간, 연속 성공 횟수 같은 실제 앱 상태를 파라미터에 매핑합니다.",
                "Andy Farnell의 Designing Sound가 이 프로젝트의 교과서입니다.",
                "대부분의 사운드 디자이너가 못 하는 영역입니다. 차별점이 여기에 있습니다."
            ]
        ),
        ShipItem(
            id: 4,
            title: "적응형 오디오 데모",
            detail: "FMOD 또는 Wwise로 상태 전이에 반응하는 짧은 데모를 만듭니다.",
            method: [
                "FMOD Studio가 개인 학습용으로는 무료이고 진입이 더 쉽습니다.",
                "상태 3개짜리 데모면 충분합니다 — 탐색 / 긴장 / 전투.",
                "전이가 핵심입니다. 상태 자체보다 상태가 바뀌는 순간에 시간을 쓰세요.",
                "게임 사운드로 확장할지 판단하는 시험대이기도 합니다."
            ]
        ),
        ShipItem(
            id: 5,
            title: "사운드팩 판매",
            detail: "Vital 프리셋 팩이나 UI SFX 팩을 Gumroad·itch.io에 올립니다.",
            method: [
                "수익이 목적이 아니라 제작–검증–판매 사이클을 한 번 완주하는 게 목적입니다.",
                "50~100개 묶음이 표준입니다. 네이밍 규칙과 미리듣기 데모가 품질보다 판매를 좌우합니다.",
                "라이선스 문구를 반드시 넣으세요. 상업적 사용 허용 범위를 명시합니다.",
                "첫 팩은 무료로 풀고 두 번째부터 유료로 가는 쪽이 초기 반응을 얻기 쉽습니다."
            ]
        )
    ]
}

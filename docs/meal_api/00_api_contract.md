# Meal API 계약 문서

## 기본 정보
- 기준 코드: Django backend (`mysite`)
- 인증: JWT Bearer (`Authorization: Bearer <access_token>`)
- 라우팅: 동일한 v1 URL이 `'/api/v1/'`와 `'/api/'` 두 prefix로 노출됨
- 참고: 테스트 코드 일부는 `'/api/v2/'`를 사용하지만, 현재 URLConf에는 `v2` 라우트가 없음

## 엔드포인트 전체 표

| Method | Path | Auth | Query / Body | Response 필드(요약) | 상태코드 | 페이지네이션/정렬/필터 |
|---|---|---|---|---|---|---|
| GET | `/api/v1/meals/my/summary/` (`/api/meals/my/summary/`) | `IsAuthenticated` + 활성 사용자 | Query: `ym`(선택, `YYYYMM`/`YYYY-MM`, 미입력 시 현재월) | `ym`, `total_amount`, `used_amount`, `balance`, `claim_count` | 200, 400, 401, 403 | 페이지네이션 없음, 필터=`ym` |
| GET | `/api/v1/meals/my/items/` (`/api/meals/my/items/`) | `IsAuthenticated` + 활성 사용자 | Query: `ym`(선택) | `ym`, `items[]` (`id`, `used_date`, `merchant_name`, `approval_no`, `total_amount`, `my_amount`, `participants_count`, `participant_sum`, `created_by`, `can_edit`, `can_delete`) | 200, 400, 401, 403 | 페이지네이션 없음, 정렬=`used_date ASC, id ASC`, 필터=`ym` + 참여자 본인 |
| GET | `/api/v1/meals/options/` (`/api/meals/options/`) | `IsAuthenticated` + 활성 사용자 | Query: `used_date`(선택, `YYYY-MM-DD`) 또는 `ym`(선택) | `ym`, `users[]`, `groups[]` | 200, 400, 401, 403 | 페이지네이션 없음, 필터=`used_date` 또는 `ym` |
| POST | `/api/v1/meals/claims/` (`/api/meals/claims/`) | `IsAuthenticated` + 활성 사용자 | Body: `used_date`, `merchant_name`, `approval_no`, `amount`, `participants[]` | 생성된 claim 상세 (`id`, `ym`, `used_date`, `merchant_name`, `approval_no`, `amount`, `created_by`, `participants[]`, `can_edit`, `can_delete`) | 201, 400, 401, 403 | 페이지네이션/정렬 없음 |
| GET | `/api/v1/meals/claims/{claim_id}/` (`/api/meals/claims/{claim_id}/`) | `IsAuthenticated` + 활성 사용자 + 해당 claim 참여자 | Path: `claim_id` | claim 상세(POST 응답과 동일 구조) | 200, 401, 403, 404 | 페이지네이션/정렬 없음 |
| PATCH | `/api/v1/meals/claims/{claim_id}/` (`/api/meals/claims/{claim_id}/`) | `IsAuthenticated` + 활성 사용자 + claim 작성자 | Body: POST와 동일(전체 payload 재검증) | 수정된 claim 상세 | 200, 400, 401, 403, 404 | 페이지네이션/정렬 없음 |
| DELETE | `/api/v1/meals/claims/{claim_id}/` (`/api/meals/claims/{claim_id}/`) | `IsAuthenticated` + 활성 사용자 + claim 작성자 | Path: `claim_id` | `{ "ok": true }` | 200, 401, 403, 404 | 페이지네이션/정렬 없음 |

## 인증 / 지점(branch) 규칙
- API는 `JWTAuthentication` 사용 (`Bearer` 타입).
- 모든 meal API는 `IsAuthenticated` 필요.
- `BranchGuardMiddleware`는 `'/api/'` prefix를 예외 처리하므로 API에서 `request.branch`가 항상 보장되지 않음.
- API 내부에서 `get_branch_or_error()`가 `request.branch` 우선, 없으면 `request.user.branch`를 사용.
- 둘 다 없으면 `400 branch_required`.
- 퇴사자(`out_date < today`)는 meal API 접근 시 `403 out_user`.

## 요청/응답 스키마 상세

### 1) GET my summary
- Query
  - `ym`: string, optional, format `YYYYMM` or `YYYY-MM`
- Response 200
  - `ym`: string
  - `total_amount`: number (월 식대 한도)
  - `used_amount`: number (본인 분배금 합)
  - `balance`: number (`total_amount - used_amount`)
  - `claim_count`: number (본인이 참여한 claim 개수)

### 2) GET my items
- Query
  - `ym`: string, optional
- Response 200
  - `ym`: string
  - `items`: array
    - `id`: integer
    - `used_date`: string (`YYYY-MM-DD`)
    - `merchant_name`: string
    - `approval_no`: string
    - `total_amount`: integer
    - `my_amount`: integer
    - `participants_count`: integer
    - `participant_sum`: integer
    - `created_by`: object (`id`, `emp_name`)
    - `can_edit`: boolean (작성자 본인 여부)
    - `can_delete`: boolean (작성자 본인 여부)

### 3) GET options
- Query
  - `used_date`: string, optional (`YYYY-MM-DD`) - 있으면 이것이 우선
  - `ym`: string, optional
- Response 200
  - `ym`: string
  - `users`: array (`id`, `emp_name`, `dept`, `position`)
  - `groups`: array
    - `dept`: string
    - `members`: array (`id`, `emp_name`, `position`)

### 4) POST/PATCH claim payload
- Body
  - `used_date`: string, required, `YYYY-MM-DD`
  - `merchant_name`: string, required, trim 후 빈값 불가
  - `approval_no`: string, required, 숫자 8자리
  - `amount`: integer, required, `> 0`
  - `participants`: array, required, 최소 1명
    - item: `{ "user_id": integer, "amount": integer(>0) }`

### 5) claim detail response
- `id`: integer
- `ym`: string
- `used_date`: string
- `merchant_name`: string
- `approval_no`: string
- `amount`: integer
- `created_by`: `{ "id": integer, "emp_name": string }`
- `participants`: array (`user_id`, `emp_name`, `dept`, `position`, `amount`)
- `can_edit`: boolean
- `can_delete`: boolean

## 요청/응답 예시 JSON

### 성공 예시 - POST `/api/meals/claims/`
```json
{
  "used_date": "2024-05-10",
  "merchant_name": "한식당",
  "approval_no": "12345678",
  "amount": 50000,
  "participants": [
    { "user_id": 10, "amount": 25000 },
    { "user_id": 11, "amount": 25000 }
  ]
}
```

```json
{
  "id": 77,
  "ym": "202405",
  "used_date": "2024-05-10",
  "merchant_name": "한식당",
  "approval_no": "12345678",
  "amount": 50000,
  "created_by": { "id": 10, "emp_name": "홍길동" },
  "participants": [
    { "user_id": 10, "emp_name": "홍길동", "dept": "개발", "position": "사원", "amount": 25000 },
    { "user_id": 11, "emp_name": "김영희", "dept": "개발", "position": "대리", "amount": 25000 }
  ],
  "can_edit": true,
  "can_delete": true
}
```

### 실패 예시 - 검증 오류(400)
```json
{
  "error": "validation_error",
  "message": "분배 합계가 총액과 일치해야 합니다.",
  "details": [
    "분배 합계가 총액과 일치해야 합니다."
  ]
}
```

### 실패 예시 - 권한 오류(403)
```json
{
  "error": "forbidden",
  "message": "권한이 없습니다."
}
```

### 실패 예시 - 조회 불가/미존재(404)
```json
{
  "error": "not_found",
  "message": "meal claim not found"
}
```

## 공통 에러 포맷 및 에러 코드 목록

### 공통 포맷
```json
{
  "error": "<error_code>",
  "message": "<human_readable_message>",
  "details": []
}
```
- `details`는 검증 오류 시 선택적으로 포함.

### 에러 코드
- `validation_error`
- `forbidden`
- `not_found`
- `branch_required`
- `out_user`
- `invalid_credentials` (토큰 발급 API)
- `token_expired` (토큰 발급/검증 과정 예외 처리)
- `unknown` (토큰 발급 API 예외 fallback)

## 비즈니스 규칙
- 월 마감(`BranchMonthClose.is_closed=True`)이면:
  - 생성 불가
  - 삭제 불가
  - 수정은 "기존 월" 또는 "변경 후 월" 중 하나라도 마감이면 불가
- 승인번호(`approval_no`):
  - 필수, 숫자만, 8자리
  - 같은 지점 + 같은 월 + 미삭제 claim 내 중복 불가
- 금액:
  - `amount > 0`
  - 각 participant `amount > 0`
  - participant 금액 합계 == `amount`
- 참여자:
  - 최소 1명
  - claim 내 중복 사용자 불가
  - 사용일 기준 지점 소속 활성 직원이어야 함 (`join_date <= used_date`, `out_date is null or >= used_date`)
- 삭제는 soft delete (`is_deleted=True`) 처리.
- 상세 조회(GET detail)는 참여자만 가능, 수정/삭제는 작성자만 가능.
- `ym` 미입력 시 현재 월로 기본 처리.

## Pagination / 정렬 / 필터 요약
- Pagination: 적용 없음 (전역/엔드포인트 모두 meal API에서 미사용)
- Ordering:
  - `GET my/items`: `used_date ASC, id ASC`
- Filters:
  - `summary`, `my/items`: `ym`
  - `options`: `used_date` 또는 `ym`

## 참조(코드 위치)
- `mysite/config/urls.py:25` (`urlpatterns`, `/api/v1/`, `/api/` 라우팅)
- `mysite/api/v1/urls.py:21` (`meals/*` endpoint 등록)
- `mysite/config/settings/base.py:75` (`REST_FRAMEWORK`, JWT auth)
- `mysite/config/settings/base.py:83` (`SIMPLE_JWT` 설정)
- `mysite/common/middleware.py:59` (`BranchGuardMiddleware`, `/api/` EXEMPT)
- `mysite/api/v1/views/common.py:28` (`get_branch_or_error`)
- `mysite/api/v1/views/common.py:36` (`ensure_active_employee_or_403`)
- `mysite/api/v1/views/meals.py:23` (`MealMySummaryAPIView`)
- `mysite/api/v1/views/meals.py:67` (`MealMyItemsAPIView`)
- `mysite/api/v1/views/meals.py:122` (`MealOptionsAPIView`)
- `mysite/api/v1/views/meals.py:178` (`MealClaimCreateAPIView`)
- `mysite/api/v1/views/meals.py:207` (`MealClaimDetailAPIView`)
- `mysite/wtm/services/date_utils.py:27` (`parse_used_date`)
- `mysite/wtm/services/date_utils.py:36` (`parse_amount`)
- `mysite/wtm/services/branch_access.py:11` (`get_branch_users`)
- `mysite/wtm/services/meal_claims.py:19` (`_parse_approval_no`)
- `mysite/wtm/services/meal_claims.py:165` (`parse_claim_payload`)
- `mysite/wtm/services/meal_claims.py:314` (`create_claim`)
- `mysite/wtm/services/meal_claims.py:335` (`update_claim`)
- `mysite/wtm/services/meal_claims.py:357` (`soft_delete_claim`)
- `mysite/wtm/services/meal_claims.py:367` (`serialize_claim_detail`)
- `mysite/wtm/models.py:236` (`MealClaim`)
- `mysite/wtm/models.py:275` (`MealClaimParticipant`)
- `mysite/api/v1/views/auth.py:40` (`CustomTokenObtainPairView`, `out_user`/`invalid_credentials` 등)
- `mysite/api/tests.py:87` (`MealClaimAPITests`, v2 경로 사용 흔적)

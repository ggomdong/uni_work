# Meal 도메인 규칙 (클라이언트 필수 인지)

## 1) 인증/지점
- 모든 meal API는 JWT 필요 (`Bearer access token`).
- API 호출 시 branch는 서버에서 `request.user.branch`로 최종 식별되는 흐름이 핵심.
- 퇴사자는 API 사용 불가(`403 out_user`).

## 2) 월 선택 규칙
- `ym`은 `YYYYMM` 또는 `YYYY-MM` 허용.
- `ym` 미입력 시 서버가 현재월로 자동 처리.
- `options` API는 `used_date`가 오면 `ym`보다 우선.

## 3) 등록/수정 입력 규칙
- 필수: `used_date`, `merchant_name`, `approval_no`, `amount`, `participants`.
- `used_date`: `YYYY-MM-DD`.
- `merchant_name`: trim 후 빈값 불가.
- `approval_no`: 숫자 8자리만 허용.
- `amount`: 0보다 큰 정수.
- `participants`:
  - 최소 1명
  - 각 item에 `user_id`, `amount` 필수
  - 사용자 중복 불가
  - 각 분배금은 0보다 큰 정수
  - 분배 합계는 총액과 반드시 동일

## 4) 참여자 유효성
- 참여자는 사용일 기준으로 "같은 지점의 활성 직원"이어야 함.
- 즉, `join_date <= used_date` 이고 `(out_date is null or out_date >= used_date)` 조건을 만족해야 함.

## 5) 마감 규칙
- 마감월(`BranchMonthClose.is_closed=True`)은:
  - 등록 불가
  - 삭제 불가
  - 수정 불가 (기존 월 또는 변경 후 월 중 하나라도 마감이면 실패)

## 6) 승인번호 중복 규칙
- 같은 지점 + 같은 월 + 미삭제 데이터 기준으로 승인번호 중복 불가.
- 수정 시 자기 자신(claim_id)은 중복 검사에서 제외.

## 7) 조회/수정/삭제 권한
- `my/items`: "내가 참여자"인 건만 보임.
- `claim detail` GET: 참여자만 조회 가능(비참여자는 404).
- PATCH/DELETE: 작성자만 가능(그 외 403).

## 8) UI 구현 시 주의점
- 리스트 응답에 pagination이 없어 월 데이터가 많으면 전량 수신됨.
- 정렬은 서버가 `used_date ASC, id ASC`로 고정.
- claim 응답의 `can_edit`, `can_delete`를 버튼 활성화 조건으로 사용 가능.
- soft delete(`is_deleted=true`) 방식이라 삭제 후 재조회 시 목록에서 사라짐.

## 참조(코드 위치)
- `mysite/api/v1/views/meals.py:79` (`ym` 정규화)
- `mysite/api/v1/views/meals.py:95` (`my/items` 정렬)
- `mysite/api/v1/views/meals.py:229` (detail 조회 참여자 제한)
- `mysite/api/v1/views/meals.py:248` (수정 작성자 제한)
- `mysite/api/v1/views/meals.py:288` (삭제 작성자 제한)
- `mysite/wtm/services/meal_claims.py:19` (승인번호 검증/월중복)
- `mysite/wtm/services/meal_claims.py:86` (participants 검증)
- `mysite/wtm/services/meal_claims.py:165` (claim payload 전체 검증)
- `mysite/wtm/services/meal_claims.py:206` (총액=분배합)
- `mysite/wtm/services/meal_claims.py:314` (등록 시 마감 검증)
- `mysite/wtm/services/meal_claims.py:341` (수정 시 마감 검증)
- `mysite/wtm/services/meal_claims.py:360` (삭제 시 마감 검증)
- `mysite/wtm/services/branch_access.py:11` (지점 사용자 유효 조건)

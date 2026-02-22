# Meal OpenAPI Draft (간이)

```yaml
openapi: 3.0.3
info:
  title: Meal API Draft
  version: 0.1.0
servers:
  - url: /api/v1
  - url: /api
security:
  - bearerAuth: []
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    ErrorResponse:
      type: object
      properties:
        error: { type: string }
        message: { type: string }
        details:
          type: array
          items: { type: string }
    ParticipantInput:
      type: object
      required: [user_id, amount]
      properties:
        user_id: { type: integer }
        amount: { type: integer, minimum: 1 }
    ClaimUpsertRequest:
      type: object
      required: [used_date, merchant_name, approval_no, amount, participants]
      properties:
        used_date: { type: string, format: date }
        merchant_name: { type: string }
        approval_no:
          type: string
          pattern: '^[0-9]{8}$'
        amount:
          type: integer
          minimum: 1
        participants:
          type: array
          minItems: 1
          items:
            $ref: '#/components/schemas/ParticipantInput'
    ClaimParticipant:
      type: object
      properties:
        user_id: { type: integer }
        emp_name: { type: string }
        dept: { type: string }
        position: { type: string }
        amount: { type: integer }
    ClaimDetail:
      type: object
      properties:
        id: { type: integer }
        ym: { type: string }
        used_date: { type: string, format: date }
        merchant_name: { type: string }
        approval_no: { type: string }
        amount: { type: integer }
        created_by:
          type: object
          properties:
            id: { type: integer }
            emp_name: { type: string }
        participants:
          type: array
          items:
            $ref: '#/components/schemas/ClaimParticipant'
        can_edit: { type: boolean }
        can_delete: { type: boolean }
paths:
  /meals/my/summary/:
    get:
      parameters:
        - in: query
          name: ym
          schema: { type: string }
          description: YYYYMM or YYYY-MM (optional)
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  ym: { type: string }
                  total_amount: { type: integer }
                  used_amount: { type: integer }
                  balance: { type: integer }
                  claim_count: { type: integer }
        '400': { description: validation/branch error }
        '401': { description: unauthenticated }
        '403': { description: out_user }

  /meals/my/items/:
    get:
      parameters:
        - in: query
          name: ym
          schema: { type: string }
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  ym: { type: string }
                  items:
                    type: array
                    items:
                      type: object
                      properties:
                        id: { type: integer }
                        used_date: { type: string, format: date }
                        merchant_name: { type: string }
                        approval_no: { type: string }
                        total_amount: { type: integer }
                        my_amount: { type: integer }
                        participants_count: { type: integer }
                        participants_sum: { type: integer }
                        created_by:
                          type: object
                          properties:
                            id: { type: integer }
                            emp_name: { type: string }
                        can_edit: { type: boolean }
                        can_delete: { type: boolean }

  /meals/my/created/:
    get:
      parameters:
        - in: query
          name: ym
          schema: { type: string }
          description: YYYYMM or YYYY-MM (optional, default=current month)
      responses:
        '200':
          description: OK (created_by 기준 목록; item schema is same as /meals/my/items/)
          content:
            application/json:
              schema:
                type: object
                properties:
                  ym: { type: string }
                  items:
                    type: array
                    items:
                      type: object
                      properties:
                        id: { type: integer }
                        used_date: { type: string, format: date }
                        merchant_name: { type: string }
                        approval_no: { type: string }
                        total_amount: { type: integer }
                        my_amount:
                          type: integer
                          description: 작성자가 참여자가 아니면 0
                        participants_count: { type: integer }
                        participants_sum: { type: integer }
                        created_by:
                          type: object
                          properties:
                            id: { type: integer }
                            emp_name: { type: string }
                        can_edit: { type: boolean }
                        can_delete: { type: boolean }
        '400': { description: validation/branch error }
        '401': { description: unauthenticated }
        '403': { description: out_user }

  /meals/options/:
    get:
      parameters:
        - in: query
          name: used_date
          schema: { type: string, format: date }
        - in: query
          name: ym
          schema: { type: string }
      responses:
        '200':
          description: OK

  /meals/claims/:
    post:
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ClaimUpsertRequest'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ClaimDetail'
        '400':
          description: validation_error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '403':
          description: forbidden/out_user/month_closed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'

  /meals/claims/{claim_id}/:
    parameters:
      - in: path
        name: claim_id
        required: true
        schema: { type: integer }
    get:
      description: 참여자 또는 작성자만 조회 가능 (둘 다 아니면 404)
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ClaimDetail'
        '404': { description: not_found }
    patch:
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ClaimUpsertRequest'
      responses:
        '200':
          description: OK
        '400': { description: validation_error }
        '403': { description: forbidden/month_closed }
        '404': { description: not_found }
    delete:
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  ok: { type: boolean }
        '403': { description: forbidden/month_closed }
        '404': { description: not_found }
```

## 에러 코드 메모
- 공통: `validation_error`, `forbidden`, `not_found`, `branch_required`, `out_user`
- 인증(토큰 발급): `invalid_credentials`, `token_expired`, `unknown`

## 참조(코드 위치)
- `mysite/api/v1/urls.py:34`
- `mysite/api/v1/views/meals.py:23`
- `mysite/api/v1/views/meals.py:122`
- `mysite/api/v1/views/meals.py:232`
- `mysite/wtm/services/meal_claims.py:165`
- `mysite/wtm/services/meal_claims.py:314`
- `mysite/api/v1/views/common.py:13`

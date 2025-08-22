
;; proof-of-skill.clar
;; Job marketplace that stores skill verifications from trusted sources for freelance matching.
;; Clarinet-compliant. Clarity v2.

(impl-trait .skill-verifier-trait.skill-verifier-trait)

;; =====================
;; Constants & Errors
;; =====================

(define-constant ERR-UNAUTHORIZED u1001)
(define-constant ERR-NOT-FOUND u1002)
(define-constant ERR-ALREADY-EXISTS u1003)
(define-constant ERR-INVALID-INPUT u1004)
(define-constant ERR-NOT-TRUSTED u1005)
(define-constant ERR-NOT-OWNER u1006)
(define-constant ERR-NOT-CLIENT u1007)
(define-constant ERR-CLOSED u1008)
(define-constant ERR-NOT-QUALIFIED u1009)

(define-data-var contract-owner principal tx-sender)

;; =====================
;; Trusted verifier registry
;; =====================
;; Both individual principals and verifier contracts can be trusted.

(define-map trusted-verifiers
  { verifier: principal }
  { active: bool })

(define-read-only (is-trusted-verifier (v principal))
  (default-to false (get active (map-get? trusted-verifiers { verifier: v }))))

(define-public (register-trusted-verifier (v principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
    (match (map-get? trusted-verifiers { verifier: v })
      some-existing (begin
        (map-set trusted-verifiers { verifier: v } { active: true })
        (ok true))
      none (begin
        (map-insert trusted-verifiers { verifier: v } { active: true })
        (ok true))))
)

(define-public (unregister-trusted-verifier (v principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
    (map-set trusted-verifiers { verifier: v } { active: false })
    (ok true)))

;; =====================
;; Skill storage
;; =====================
;; Keyed by (user, skill). Stores verifier, evidence, time, and active flag.

(define-map skills
  { user: principal, skill: (string-ascii 64) }
  { verified: bool, verifier: principal, evidence: (optional (string-ascii 64)), timestamp: uint })

;; Per-user skill index to allow basic enumeration by index.
(define-map user-skill-counts { user: principal } { count: uint })
(define-map skills-by-user
  { user: principal, idx: uint }
  { skill: (string-ascii 64) })

(define-read-only (get-skill (user principal) (skill (string-ascii 64)))
  (map-get? skills { user: user, skill: skill }))

(define-read-only (get-user-skill-count (user principal))
  (default-to u0 (get count (map-get? user-skill-counts { user: user }))))

(define-read-only (get-skill-by-index (user principal) (idx uint))
  (map-get? skills-by-user { user: user, idx: idx }))

;; Internal helper to index a skill if first time seen for user
(define-private (index-skill-if-new (user principal) (skill (string-ascii 64)))
  (let ((existing (map-get? skills { user: user, skill: skill })))
    (if (is-some existing)
        false
        (let ((count (default-to u0 (get count (map-get? user-skill-counts { user: user })))))
          (begin
            (map-set skills-by-user { user: user, idx: count } { skill: skill })
            (map-set user-skill-counts { user: user } { count: (+ count u1) })
            true)))))

;; =====================
;; Event helpers
;; =====================
(define-private (emit (what (string-ascii 32)) (payload (string-ascii 200)))
  (print { event: what, msg: payload }))

;; =====================
;; Owner controls
;; =====================
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
    (var-set contract-owner new-owner)
    (ok true)))

;; =====================
;; Trait implementation
;; =====================
(define-read-only (is-trusted (verifier principal))
  (ok (is-trusted-verifier verifier)))

(define-public (verify (user principal) (skill (string-ascii 64)) (evidence (optional (string-ascii 64))) (verifier principal))
  (begin
    (asserts! (is-trusted-verifier tx-sender) (err ERR-NOT-TRUSTED))
    (asserts! (> (len skill) u0) (err ERR-INVALID-INPUT))
    (index-skill-if-new user skill)
    (map-set skills { user: user, skill: skill }
      { verified: true, verifier: tx-sender, evidence: evidence, timestamp: block-height })
    (emit "SkillVerified" (as-max-len? (concat skill " verified") u200))
    (ok true)))

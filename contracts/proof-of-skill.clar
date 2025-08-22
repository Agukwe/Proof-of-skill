;; ProofOfSkill Contract
;; A job marketplace contract that stores skill verifications from trusted sources
;; for freelance matching and credential management.

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-SKILL-NOT-FOUND (err u101))
(define-constant ERR-INVALID-VERIFIER (err u102))
(define-constant ERR-ALREADY-VERIFIED (err u103))
(define-constant ERR-INVALID-SCORE (err u104))
(define-constant ERR-PROFILE-NOT-FOUND (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map user-profiles
  { user: principal }
  {
    username: (string-ascii 50),
    bio: (string-utf8 500),
    portfolio-url: (optional (string-ascii 200)),
    reputation-score: uint,
    total-verifications: uint,
    created-at: uint
  }
)

(define-map skill-categories
  { category-id: uint }
  {
    name: (string-ascii 50),
    description: (string-utf8 200),
    is-active: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map skill-verifications
  { user: principal, skill-id: uint }
  {
    skill-name: (string-ascii 100),
    category-id: uint,
    verifier: principal,
    verification-type: (string-ascii 50),
    score: uint,
    evidence-url: (optional (string-ascii 300)),
    verified-at: uint,
    expires-at: (optional uint),
    is-active: bool
  }
)

;; Trusted verifiers management
(define-map trusted-verifiers
  { verifier: principal }
  {
    name: (string-ascii 100),
    verification-types: (list 10 (string-ascii 50)),
    reputation: uint,
    total-verifications: uint,
    is-active: bool,
    added-by: principal,
    added-at: uint
  }
)

;; Counter variables
(define-data-var next-skill-id uint u1)
(define-data-var next-category-id uint u1)
(define-data-var total-users uint u0)
(define-data-var total-verifications uint u0)
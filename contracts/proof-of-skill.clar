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

;; ===== USER PROFILE FUNCTIONS =====

;; Create a new user profile
(define-public (create-user-profile (username (string-ascii 50)) (bio (string-utf8 500)) (portfolio-url (optional (string-ascii 200))))
  (let ((user tx-sender))
    (asserts! (is-none (map-get? user-profiles {user: user})) ERR-ALREADY-VERIFIED)
    (asserts! (> (len username) u0) ERR-INVALID-INPUT)
    
    (map-set user-profiles {user: user} {
      username: username,
      bio: bio,
      portfolio-url: portfolio-url,
      reputation-score: u0,
      total-verifications: u0,
      created-at: block-height
    })
    
    (var-set total-users (+ (var-get total-users) u1))
    (print {action: "profile-created", user: user, username: username})
    (ok user)
  )
)

;; Update user profile
(define-public (update-user-profile (username (string-ascii 50)) (bio (string-utf8 500)) (portfolio-url (optional (string-ascii 200))))
  (let ((user tx-sender))
    (match (map-get? user-profiles {user: user})
      profile (begin
        (asserts! (> (len username) u0) ERR-INVALID-INPUT)
        (map-set user-profiles {user: user} (merge profile {
          username: username,
          bio: bio,
          portfolio-url: portfolio-url
        }))
        (print {action: "profile-updated", user: user})
        (ok true)
      )
      ERR-PROFILE-NOT-FOUND
    )
  )
)

;; Get user profile
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles {user: user})
)

;; ===== SKILL CATEGORY FUNCTIONS =====

;; Create a new skill category (only contract owner)
(define-public (create-skill-category (name (string-ascii 50)) (description (string-utf8 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    
    (let ((category-id (var-get next-category-id)))
      (map-set skill-categories {category-id: category-id} {
        name: name,
        description: description,
        is-active: true,
        created-by: tx-sender,
        created-at: block-height
      })
      
      (var-set next-category-id (+ category-id u1))
      (print {action: "category-created", category-id: category-id, name: name})
      (ok category-id)
    )
  )
)

;; Update skill category status
(define-public (toggle-skill-category (category-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (match (map-get? skill-categories {category-id: category-id})
      category (begin
        (map-set skill-categories {category-id: category-id} 
          (merge category {is-active: (not (get is-active category))}))
        (print {action: "category-toggled", category-id: category-id})
        (ok true)
      )
      ERR-SKILL-NOT-FOUND
    )
  )
)

;; Get skill category
(define-read-only (get-skill-category (category-id uint))
  (map-get? skill-categories {category-id: category-id})
)

;; ===== TRUSTED VERIFIER FUNCTIONS =====

;; Add a trusted verifier (only contract owner)
(define-public (add-trusted-verifier 
  (verifier principal) 
  (name (string-ascii 100)) 
  (verification-types (list 10 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len verification-types) u0) ERR-INVALID-INPUT)
    
    (map-set trusted-verifiers {verifier: verifier} {
      name: name,
      verification-types: verification-types,
      reputation: u100,
      total-verifications: u0,
      is-active: true,
      added-by: tx-sender,
      added-at: block-height
    })
    
    (print {action: "verifier-added", verifier: verifier, name: name})
    (ok true)
  )
)

;; Toggle verifier status
(define-public (toggle-verifier-status (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (match (map-get? trusted-verifiers {verifier: verifier})
      verifier-data (begin
        (map-set trusted-verifiers {verifier: verifier}
          (merge verifier-data {is-active: (not (get is-active verifier-data))}))
        (print {action: "verifier-toggled", verifier: verifier})
        (ok true)
      )
      ERR-INVALID-VERIFIER
    )
  )
)

;; Check if a principal is a trusted verifier
(define-read-only (is-trusted-verifier (verifier principal))
  (match (map-get? trusted-verifiers {verifier: verifier})
    verifier-data (get is-active verifier-data)
    false
  )
)

;; Get trusted verifier info
(define-read-only (get-trusted-verifier (verifier principal))
  (map-get? trusted-verifiers {verifier: verifier})
)
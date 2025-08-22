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

;; ===== SKILL VERIFICATION FUNCTIONS =====

;; Verify a skill for a user (only trusted verifiers)
(define-public (verify-user-skill 
  (user principal)
  (skill-name (string-ascii 100))
  (category-id uint)
  (verification-type (string-ascii 50))
  (score uint)
  (evidence-url (optional (string-ascii 300)))
  (expires-at (optional uint)))
  (let ((verifier tx-sender)
        (skill-id (var-get next-skill-id)))
    
    ;; Validate inputs
    (asserts! (is-trusted-verifier verifier) ERR-INVALID-VERIFIER)
    (asserts! (> (len skill-name) u0) ERR-INVALID-INPUT)
    (asserts! (<= score u100) ERR-INVALID-SCORE)
    (asserts! (is-some (map-get? skill-categories {category-id: category-id})) ERR-SKILL-NOT-FOUND)
    
    ;; Check if skill already exists for this user
    (asserts! (is-none (map-get? skill-verifications {user: user, skill-id: skill-id})) ERR-ALREADY-VERIFIED)
    
    ;; Add skill verification
    (map-set skill-verifications {user: user, skill-id: skill-id} {
      skill-name: skill-name,
      category-id: category-id,
      verifier: verifier,
      verification-type: verification-type,
      score: score,
      evidence-url: evidence-url,
      verified-at: block-height,
      expires-at: expires-at,
      is-active: true
    })
    
    ;; Update counters and user profile
    (var-set next-skill-id (+ skill-id u1))
    (var-set total-verifications (+ (var-get total-verifications) u1))
    
    ;; Update user profile stats
    (match (map-get? user-profiles {user: user})
      profile (begin
        (let ((new-total (+ (get total-verifications profile) u1))
              (new-reputation (calculate-reputation-score user new-total)))
          (map-set user-profiles {user: user} (merge profile {
            total-verifications: new-total,
            reputation-score: new-reputation
          }))
        )
      )
      ;; If no profile exists, create basic one
      (map-set user-profiles {user: user} {
        username: "User",
        bio: u"",
        portfolio-url: none,
        reputation-score: (min score u50),
        total-verifications: u1,
        created-at: block-height
      })
    )
    
    ;; Update verifier stats
    (match (map-get? trusted-verifiers {verifier: verifier})
      verifier-data (map-set trusted-verifiers {verifier: verifier}
        (merge verifier-data {
          total-verifications: (+ (get total-verifications verifier-data) u1)
        }))
      false ;; This shouldn't happen if verifier is trusted
    )
    
    (print {action: "skill-verified", user: user, skill-id: skill-id, verifier: verifier, score: score})
    (ok skill-id)
  )
)

;; Revoke a skill verification (verifier or contract owner only)
(define-public (revoke-skill-verification (user principal) (skill-id uint))
  (match (map-get? skill-verifications {user: user, skill-id: skill-id})
    verification (begin
      (asserts! (or (is-eq tx-sender (get verifier verification)) 
                    (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
      
      (map-set skill-verifications {user: user, skill-id: skill-id}
        (merge verification {is-active: false}))
      
      ;; Update user reputation
      (match (map-get? user-profiles {user: user})
        profile (let ((new-total (- (get total-verifications profile) u1)))
          (map-set user-profiles {user: user} (merge profile {
            total-verifications: new-total,
            reputation-score: (calculate-reputation-score user new-total)
          }))
        )
        false
      )
      
      (print {action: "skill-revoked", user: user, skill-id: skill-id})
      (ok true)
    )
    ERR-SKILL-NOT-FOUND
  )
)

;; Get user's skill verification
(define-read-only (get-skill-verification (user principal) (skill-id uint))
  (map-get? skill-verifications {user: user, skill-id: skill-id})
)

;; ===== UTILITY FUNCTIONS =====

;; Helper function to find minimum of two values
(define-read-only (min (a uint) (b uint))
  (if (<= a b) a b)
)

;; ===== JOB MATCHING AND SEARCH FUNCTIONS =====

;; Calculate reputation score based on verifications
(define-read-only (calculate-reputation-score (user principal) (user-verifications uint))
  (let ((base-score u50))
    (+ base-score (min (* user-verifications u10) u450)) ;; Max reputation 500
  )
)

;; Search users by skill category
(define-read-only (get-users-by-skill-category (category-id uint))
  ;; This would typically return a list of users, but Clarity doesn't have 
  ;; native query functions. In a real implementation, you'd need to maintain
  ;; additional data structures or use indexing
  (ok "Use off-chain indexing for complex queries")
)

;; Check if user has specific skill verification
(define-read-only (user-has-skill (user principal) (skill-name (string-ascii 100)))
  ;; This is a simplified check - in practice you'd iterate through user's skills
  ;; For now, just check if user has any verifications
  (match (map-get? user-profiles {user: user})
    profile (> (get total-verifications profile) u0)
    false
  )
)

;; Get user's verification count by category
(define-read-only (get-user-skill-count-by-category (user principal) (category-id uint))
  ;; Simplified implementation - would need iteration in real scenario
  (match (map-get? user-profiles {user: user})
    profile (get total-verifications profile)
    u0
  )
)

;; ===== MARKETPLACE UTILITY FUNCTIONS =====

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-users: (var-get total-users),
    total-verifications: (var-get total-verifications),
    total-categories: (var-get next-category-id),
    total-skills: (var-get next-skill-id)
  }
)

;; Check if verification is still valid (not expired)
(define-read-only (is-verification-valid (user principal) (skill-id uint))
  (match (map-get? skill-verifications {user: user, skill-id: skill-id})
    verification (match (get expires-at verification)
      expiry (< block-height expiry)
      true ;; No expiry means always valid
    )
    false
  )
)

;; Get top-rated users (simplified version)
(define-read-only (get-user-reputation-rank (user principal))
  (match (map-get? user-profiles {user: user})
    profile (get reputation-score profile)
    u0
  )
)

;; ===== JOB POSTING AND MATCHING SYSTEM =====

;; Job posting data structure
(define-map job-postings
  { job-id: uint }
  {
    employer: principal,
    title: (string-ascii 100),
    description: (string-utf8 1000),
    required-skills: (list 10 (string-ascii 100)),
    skill-categories: (list 5 uint),
    min-reputation: uint,
    max-budget: uint,
    deadline: uint,
    is-active: bool,
    created-at: uint,
    applications: uint
  }
)

;; Job applications
(define-map job-applications
  { job-id: uint, applicant: principal }
  {
    cover-letter: (string-utf8 500),
    proposed-budget: uint,
    estimated-completion: uint,
    applied-at: uint,
    status: (string-ascii 20) ;; "pending", "accepted", "rejected"
  }
)

(define-data-var next-job-id uint u1)

;; Post a new job
(define-public (post-job
  (title (string-ascii 100))
  (description (string-utf8 1000))
  (required-skills (list 10 (string-ascii 100)))
  (required-categories (list 5 uint))
  (min-reputation uint)
  (max-budget uint)
  (deadline uint))
  (let ((employer tx-sender)
        (job-id (var-get next-job-id)))
    
    ;; Validate inputs
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> (len required-skills) u0) ERR-INVALID-INPUT)
    (asserts! (> deadline block-height) ERR-INVALID-INPUT)
    (asserts! (> max-budget u0) ERR-INVALID-INPUT)
    
    ;; Create job posting
    (map-set job-postings {job-id: job-id} {
      employer: employer,
      title: title,
      description: description,
      required-skills: required-skills,
      skill-categories: required-categories,
      min-reputation: min-reputation,
      max-budget: max-budget,
      deadline: deadline,
      is-active: true,
      created-at: block-height,
      applications: u0
    })
    
    (var-set next-job-id (+ job-id u1))
    (print {action: "job-posted", job-id: job-id, employer: employer, title: title})
    (ok job-id)
  )
)

;; Apply for a job
(define-public (apply-for-job
  (job-id uint)
  (cover-letter (string-utf8 500))
  (proposed-budget uint)
  (estimated-completion uint))
  (let ((applicant tx-sender))
    
    ;; Validate job exists and is active
    (match (map-get? job-postings {job-id: job-id})
      job (begin
        (asserts! (get is-active job) ERR-SKILL-NOT-FOUND)
        (asserts! (> (get deadline job) block-height) ERR-INVALID-INPUT)
        (asserts! (not (is-eq applicant (get employer job))) ERR-UNAUTHORIZED)
        
        ;; Check if applicant meets minimum reputation
        (asserts! (match (map-get? user-profiles {user: applicant})
          profile (>= (get reputation-score profile) (get min-reputation job))
          false
        ) ERR-UNAUTHORIZED)
        
        ;; Check if already applied
        (asserts! (is-none (map-get? job-applications {job-id: job-id, applicant: applicant})) ERR-ALREADY-VERIFIED)
        
        ;; Create application
        (map-set job-applications {job-id: job-id, applicant: applicant} {
          cover-letter: cover-letter,
          proposed-budget: proposed-budget,
          estimated-completion: estimated-completion,
          applied-at: block-height,
          status: "pending"
        })
        
        ;; Update application count
        (map-set job-postings {job-id: job-id} (merge job {
          applications: (+ (get applications job) u1)
        }))
        
        (print {action: "job-application", job-id: job-id, applicant: applicant})
        (ok true)
      )
      ERR-SKILL-NOT-FOUND
    )
  )
)

;; Accept/reject job application (employer only)
(define-public (update-application-status (job-id uint) (applicant principal) (status (string-ascii 20)))
  (match (map-get? job-postings {job-id: job-id})
    job (begin
      (asserts! (is-eq tx-sender (get employer job)) ERR-UNAUTHORIZED)
      (asserts! (or (is-eq status "accepted") (is-eq status "rejected")) ERR-INVALID-INPUT)
      
      (match (map-get? job-applications {job-id: job-id, applicant: applicant})
        application (begin
          (map-set job-applications {job-id: job-id, applicant: applicant}
            (merge application {status: status}))
          
          ;; If accepted, mark job as inactive
          (if (is-eq status "accepted")
            (map-set job-postings {job-id: job-id} (merge job {is-active: false}))
            true
          )
          
          (print {action: "application-updated", job-id: job-id, applicant: applicant, status: status})
          (ok true)
        )
        ERR-SKILL-NOT-FOUND
      )
    )
    ERR-SKILL-NOT-FOUND
  )
)

;; ===== ADVANCED MARKETPLACE FEATURES =====

;; Skill endorsement system
(define-map skill-endorsements
  { endorser: principal, user: principal, skill-name: (string-ascii 100) }
  {
    endorsed-at: uint,
    comment: (optional (string-utf8 200))
  }
)

;; Endorse a user's skill
(define-public (endorse-user-skill
  (user principal)
  (skill-name (string-ascii 100))
  (comment (optional (string-utf8 200))))
  (let ((endorser tx-sender))
    (asserts! (not (is-eq endorser user)) ERR-UNAUTHORIZED)
    (asserts! (> (len skill-name) u0) ERR-INVALID-INPUT)
    
    ;; Check if endorser has profile and reputation
    (asserts! (match (map-get? user-profiles {user: endorser})
      profile (> (get reputation-score profile) u100)
      false
    ) ERR-UNAUTHORIZED)
    
    (map-set skill-endorsements {endorser: endorser, user: user, skill-name: skill-name} {
      endorsed-at: block-height,
      comment: comment
    })
    
    (print {action: "skill-endorsed", endorser: endorser, user: user, skill: skill-name})
    (ok true)
  )
)

;; Dispute system for verification issues
(define-map verification-disputes
  { dispute-id: uint }
  {
    disputer: principal,
    target-user: principal,
    skill-id: uint,
    reason: (string-utf8 300),
    status: (string-ascii 20), ;; "pending", "resolved", "dismissed"
    created-at: uint,
    resolved-by: (optional principal),
    resolution: (optional (string-utf8 300))
  }
)

(define-data-var next-dispute-id uint u1)

;; File a dispute against a skill verification
(define-public (file-verification-dispute
  (target-user principal)
  (skill-id uint)
  (reason (string-utf8 300)))
  (let ((disputer tx-sender)
        (dispute-id (var-get next-dispute-id)))
    
    (asserts! (> (len reason) u0) ERR-INVALID-INPUT)
    (asserts! (not (is-eq disputer target-user)) ERR-UNAUTHORIZED)
    
    ;; Check if verification exists
    (asserts! (is-some (map-get? skill-verifications {user: target-user, skill-id: skill-id})) ERR-SKILL-NOT-FOUND)
    
    (map-set verification-disputes {dispute-id: dispute-id} {
      disputer: disputer,
      target-user: target-user,
      skill-id: skill-id,
      reason: reason,
      status: "pending",
      created-at: block-height,
      resolved-by: none,
      resolution: none
    })
    
    (var-set next-dispute-id (+ dispute-id u1))
    (print {action: "dispute-filed", dispute-id: dispute-id, target: target-user})
    (ok dispute-id)
  )
)

;; Resolve dispute (contract owner only)
(define-public (resolve-dispute
  (dispute-id uint)
  (resolution (string-utf8 300))
  (uphold-dispute bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (match (map-get? verification-disputes {dispute-id: dispute-id})
      dispute (begin
        (asserts! (is-eq (get status dispute) "pending") ERR-INVALID-INPUT)
        
        (map-set verification-disputes {dispute-id: dispute-id} (merge dispute {
          status: "resolved",
          resolved-by: (some tx-sender),
          resolution: (some resolution)
        }))
        
        ;; If dispute is upheld, revoke the verification
        (if uphold-dispute
          (map-set skill-verifications 
            {user: (get target-user dispute), skill-id: (get skill-id dispute)}
            (merge (unwrap-panic (map-get? skill-verifications 
              {user: (get target-user dispute), skill-id: (get skill-id dispute)}))
              {is-active: false}))
          true
        )
        
        (print {action: "dispute-resolved", dispute-id: dispute-id, upheld: uphold-dispute})
        (ok true)
      )
      ERR-SKILL-NOT-FOUND
    )
  )
)

;; ===== FINAL READ-ONLY QUERY FUNCTIONS =====

;; Get job posting details
(define-read-only (get-job-posting (job-id uint))
  (map-get? job-postings {job-id: job-id})
)

;; Get job application details  
(define-read-only (get-job-application (job-id uint) (applicant principal))
  (map-get? job-applications {job-id: job-id, applicant: applicant})
)

;; Get skill endorsement
(define-read-only (get-skill-endorsement (endorser principal) (user principal) (skill-name (string-ascii 100)))
  (map-get? skill-endorsements {endorser: endorser, user: user, skill-name: skill-name})
)

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
  (map-get? verification-disputes {dispute-id: dispute-id})
)

;; Get comprehensive marketplace statistics
(define-read-only (get-marketplace-stats)
  {
    total-users: (var-get total-users),
    total-verifications: (var-get total-verifications),
    total-categories: (- (var-get next-category-id) u1),
    total-skills: (- (var-get next-skill-id) u1),
    total-jobs: (- (var-get next-job-id) u1),
    total-disputes: (- (var-get next-dispute-id) u1)
  }
)
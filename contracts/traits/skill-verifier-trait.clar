;; Skill Verifier Trait
;; Defines the interface that trusted skill verifiers must implement

(define-trait skill-verifier-trait
  (
    ;; Verify a skill for a user
    (verify-skill (principal (string-ascii 100) uint (string-ascii 50) (optional (string-ascii 300))) (response uint uint))
    
    ;; Get verifier information
    (get-verifier-info () (response {name: (string-ascii 100), types: (list 10 (string-ascii 50))} uint))
    
    ;; Check if verifier can verify a specific skill type
    (can-verify-skill ((string-ascii 50)) (response bool uint))
  )
)

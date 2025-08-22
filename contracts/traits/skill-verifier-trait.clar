;; skill-verifier-trait.clar
;; A trait for external verifier contracts to plug into the marketplace.

(define-trait skill-verifier-trait
  (
    ;; Returns (ok true) if `verifier` considers itself trusted by the registry/owner
    ;; Implementers may check internal allowlists or signatures.
    (is-trusted (verifier principal) (response bool uint))

    ;; Verify a user's skill with an optional evidence hash (ascii-hex or CID short)
    ;; Returns (ok true) on success; should emit events via `print`.
    (verify (user principal) (skill (string-ascii 64)) (evidence (optional (string-ascii 64))) (verifier principal)
            (response bool uint))
  )
)

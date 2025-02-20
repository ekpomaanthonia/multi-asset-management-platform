;; Enhanced Multi-Asset Management Platform

;; ========== Contract Administration ==========

;; Define the contract administrator
(define-data-var contract-admin principal tx-sender)

;; Asset ID counter
(define-data-var next-asset-id uint u0)

;; Contract status (active/paused)
(define-data-var contract-status (string-ascii 10) "active")

;; ========== Data Structures ==========

;; Asset definition with extended metadata
(define-map registered-assets
  { id: uint }
  {
    name: (string-ascii 64),
    category: (string-ascii 32),
    total-supply: uint,
    current-price: uint,
    created-at: uint,
    metadata-uri: (optional (string-utf8 256))
  }
)

;; User holdings registry
(define-map user-holdings
  { user: principal, asset-id: uint }
  { 
    balance: uint,
    last-updated: uint 
  }
)

;; Delegation permissions
(define-map spending-authorizations
  { asset-owner: principal, authorized-spender: principal, asset-id: uint }
  { 
    authorized-amount: uint,
    expiration-height: (optional uint)
  }
)

;; ========== Error Definitions ==========

(define-constant ERR_ADMIN_ONLY (err u100))
(define-constant ERR_ASSET_EXISTS (err u101))
(define-constant ERR_ASSET_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_INVALID_NAME (err u104))
(define-constant ERR_INVALID_CATEGORY (err u105))
(define-constant ERR_INVALID_SUPPLY (err u106))
(define-constant ERR_INVALID_PRICE (err u107))
(define-constant ERR_INVALID_RECIPIENT (err u108))
(define-constant ERR_INVALID_AMOUNT (err u109))
(define-constant ERR_UNAUTHORIZED (err u110))
(define-constant ERR_INVALID_SPENDER (err u111))
(define-constant ERR_CONTRACT_PAUSED (err u112))
(define-constant ERR_AUTHORIZATION_EXPIRED (err u113))

;; ========== Administrative Functions ==========

;; Function to change contract administrator
(define-public (update-contract-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_ADMIN_ONLY)
    (asserts! (not (is-eq new-admin (var-get contract-admin))) ERR_INVALID_RECIPIENT)
    (ok (var-set contract-admin new-admin))
  )
)

;; Function to pause/unpause contract operations
(define-public (set-contract-status (new-status (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_ADMIN_ONLY)
    (asserts! (or (is-eq new-status "active") (is-eq new-status "paused")) ERR_INVALID_AMOUNT)
    (ok (var-set contract-status new-status))
  )
)

;; ========== Asset Management Functions ==========

;; Function to register a new asset with extended metadata
(define-public (register-asset 
    (name (string-ascii 64)) 
    (category (string-ascii 32)) 
    (total-supply uint) 
    (initial-price uint)
    (metadata-uri (optional (string-utf8 256))))
  (let
    (
      (asset-id (+ (var-get next-asset-id) u1))
      (block-height block-height)
    )
    ;; Authorization check
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_ADMIN_ONLY)
    (asserts! (is-eq (var-get contract-status) "active") ERR_CONTRACT_PAUSED)
    
    ;; Asset validation
    (asserts! (is-none (map-get? registered-assets { id: asset-id })) ERR_ASSET_EXISTS)
    (asserts! (> (len name) u0) ERR_INVALID_NAME)
    (asserts! (> (len category) u0) ERR_INVALID_CATEGORY)
    (asserts! (> total-supply u0) ERR_INVALID_SUPPLY)
    (asserts! (> initial-price u0) ERR_INVALID_PRICE)
    
    ;; Register asset
    (map-set registered-assets
      { id: asset-id }
      { 
        name: name, 
        category: category, 
        total-supply: total-supply, 
        current-price: initial-price,
        created-at: block-height,
        metadata-uri: metadata-uri
      }
    )
    
    ;; Assign initial balance to admin
    (map-set user-holdings
      { user: (var-get contract-admin), asset-id: asset-id }
      { balance: total-supply, last-updated: block-height }
    )
    
    ;; Update asset counter
    (var-set next-asset-id asset-id)
    (ok asset-id)
  )
)

;; Function to update asset price
(define-public (update-asset-price (asset-id uint) (new-price uint))
  (let ((asset-data (map-get? registered-assets { id: asset-id })))
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_ADMIN_ONLY)
    (asserts! (is-eq (var-get contract-status) "active") ERR_CONTRACT_PAUSED)
    (asserts! (is-some asset-data) ERR_ASSET_NOT_FOUND)
    (asserts! (> new-price u0) ERR_INVALID_PRICE)
    
    (map-set registered-assets
      { id: asset-id }
      (merge (unwrap-panic asset-data) { current-price: new-price })
    )
    (ok true)
  )
)


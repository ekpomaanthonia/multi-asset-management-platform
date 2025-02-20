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
(define-constant ERR_INVALID_METADATA (err u114))
(define-constant ERR_INVALID_ASSET_ID (err u115))
(define-constant ERR_INVALID_EXPIRATION (err u116))

;; ========== Validation Functions ==========

;; Function to validate asset-id
(define-read-only (is-valid-asset-id (asset-id uint))
  (and 
    (> asset-id u0)
    (<= asset-id (var-get next-asset-id))
    (is-some (map-get? registered-assets { id: asset-id }))
  )
)

;; Function to validate metadata URI
(define-read-only (is-valid-metadata-uri (uri (optional (string-utf8 256))))
  (match uri
    uri-string (> (len uri-string) u0)
    true
  )
)

;; Function to validate expiration height
(define-read-only (is-valid-expiration (expiry (optional uint)))
  (match expiry
    height (> height block-height)
    true
  )
)

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
      (validated-metadata metadata-uri)
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
    (asserts! (is-valid-metadata-uri metadata-uri) ERR_INVALID_METADATA)
    
    ;; Register asset
    (map-set registered-assets
      { id: asset-id }
      { 
        name: name, 
        category: category, 
        total-supply: total-supply, 
        current-price: initial-price,
        created-at: block-height,
        metadata-uri: validated-metadata
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
    (asserts! (is-valid-asset-id asset-id) ERR_INVALID_ASSET_ID)
    (asserts! (is-some asset-data) ERR_ASSET_NOT_FOUND)
    (asserts! (> new-price u0) ERR_INVALID_PRICE)
    
    (map-set registered-assets
      { id: asset-id }
      (merge (unwrap-panic asset-data) { current-price: new-price })
    )
    (ok true)
  )
)

;; ========== User Operation Functions ==========

;; Function to authorize a spender with expiration
(define-public (authorize-spender 
    (spender principal) 
    (asset-id uint) 
    (amount uint) 
    (expiration-height (optional uint)))
  (let
    (
      (owner tx-sender)
      (current-height block-height)
      (validated-expiration expiration-height)
    )
    (asserts! (is-eq (var-get contract-status) "active") ERR_CONTRACT_PAUSED)
    (asserts! (is-valid-asset-id asset-id) ERR_ASSET_NOT_FOUND)
    (asserts! (not (is-eq spender owner)) ERR_INVALID_SPENDER)
    (asserts! (>= amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-expiration expiration-height) ERR_INVALID_EXPIRATION)
    
    ;; Set or update authorization
    (map-set spending-authorizations
      { asset-owner: owner, authorized-spender: spender, asset-id: asset-id }
      { 
        authorized-amount: amount,
        expiration-height: validated-expiration
      }
    )
    (ok true)
  )
)

;; Function to transfer tokens
(define-public (transfer-asset (to principal) (asset-id uint) (amount uint))
  (let
    (
      (sender tx-sender)
    )
    (asserts! (is-eq (var-get contract-status) "active") ERR_CONTRACT_PAUSED)
    (asserts! (is-valid-asset-id asset-id) ERR_ASSET_NOT_FOUND)
    (asserts! (not (is-eq to sender)) ERR_INVALID_RECIPIENT)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (execute-transfer sender to asset-id amount)
  )
)

;; Function to transfer tokens on behalf of another user
(define-public (transfer-from (from principal) (to principal) (asset-id uint) (amount uint))
  (let
    (
      (sender tx-sender)
      (authorization (get-authorization-details from sender asset-id))
      (current-height block-height)
    )
    (asserts! (is-eq (var-get contract-status) "active") ERR_CONTRACT_PAUSED)
    (asserts! (is-valid-asset-id asset-id) ERR_ASSET_NOT_FOUND)
    (asserts! (not (is-eq to from)) ERR_INVALID_RECIPIENT)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Check authorization
    (asserts! (>= (get authorized-amount authorization) amount) ERR_UNAUTHORIZED)
    
    ;; Check expiration if set
    (match (get expiration-height authorization)
      expiry (asserts! (< current-height expiry) ERR_AUTHORIZATION_EXPIRED)
      true
    )
    
    ;; Update remaining authorization
    (map-set spending-authorizations
      { asset-owner: from, authorized-spender: sender, asset-id: asset-id }
      { 
        authorized-amount: (- (get authorized-amount authorization) amount),
        expiration-height: (get expiration-height authorization)
      }
    )
    
    (execute-transfer from to asset-id amount)
  )
)

;; ========== Helper Functions ==========

;; Helper function to get authorization details
(define-read-only (get-authorization-details (owner principal) (spender principal) (asset-id uint))
  (default-to 
    { authorized-amount: u0, expiration-height: none } 
    (map-get? spending-authorizations { asset-owner: owner, authorized-spender: spender, asset-id: asset-id })
  )
)

;; Helper function to perform asset transfer
(define-private (execute-transfer (from principal) (to principal) (asset-id uint) (amount uint))
  (let
    (
      (sender-data (default-to { balance: u0, last-updated: u0 } 
                   (map-get? user-holdings { user: from, asset-id: asset-id })))
      (receiver-data (default-to { balance: u0, last-updated: u0 } 
                     (map-get? user-holdings { user: to, asset-id: asset-id })))
      (current-height block-height)
    )
    (asserts! (>= (get balance sender-data) amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update sender balance
    (map-set user-holdings
      { user: from, asset-id: asset-id }
      { 
        balance: (- (get balance sender-data) amount),
        last-updated: current-height
      }
    )
    
    ;; Update receiver balance
    (map-set user-holdings
      { user: to, asset-id: asset-id }
      { 
        balance: (+ (get balance receiver-data) amount),
        last-updated: current-height
      }
    )
    (ok true)
  )
)

;; ========== Read-Only Functions ==========

;; Function to get asset details
(define-read-only (get-asset-details (asset-id uint))
  (map-get? registered-assets { id: asset-id })
)

;; Function to get user balance for an asset
(define-read-only (get-user-holdings (user principal) (asset-id uint))
  (default-to 
    { balance: u0, last-updated: u0 } 
    (map-get? user-holdings { user: user, asset-id: asset-id })
  )
)

;; Function to get contract status
(define-read-only (get-contract-status)
  (var-get contract-status)
)

;; Function to get current administrator
(define-read-only (get-contract-admin)
  (var-get contract-admin)
)
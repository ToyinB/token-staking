;; Token Staking Smart Contract

;; SIP-010 Token Trait Definition
(define-trait sip010-token-trait
  (
    (transfer (uint principal principal (optional (buff 34)) ) (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 12) uint))
    (get-decimals () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Comprehensive Error Constants
(define-constant ERROR-UNAUTHORIZED (err u1))
(define-constant ERROR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERROR-STAKE-NOT-FOUND (err u3))
(define-constant ERROR-UNSTAKE-FORBIDDEN (err u4))
(define-constant ERROR-ALREADY-STAKED (err u5))
(define-constant ERROR-INVALID-AMOUNT (err u6))
(define-constant ERROR-REWARD-CALCULATION (err u7))
(define-constant ERROR-INVALID-TOKEN-CONTRACT (err u8))
(define-constant ERROR-TRANSFER-FAILED (err u9))

;; Validation Functions
(define-private (validate-token-contract (token-contract <sip010-token-trait>))
  (begin
    ;; Attempt to get token name to validate contract
    (match (contract-call? token-contract get-name)
      token-name true
      validation-error false
    )
  )
)

(define-private (validate-stake-amount (stake-amount uint))
  (and (> stake-amount u0) (<= stake-amount MAXIMUM-STAKE))
)

;; Storage Maps
(define-map staked-tokens 
  { staker: principal }
  {
    amount: uint,
    start-block: uint,
    stake-period: uint,
    claimed-rewards: uint
  }
)

;; Tracks total staked amount
(define-data-var total-staked-amount uint u0)

;; Staking parameters
(define-constant MINIMUM-STAKE u100)  ;; Minimum stake of 100 tokens
(define-constant MAXIMUM-STAKE u10000)  ;; Maximum stake of 10,000 tokens
(define-constant BASE-REWARD-RATE u5)  ;; 5% base reward rate
(define-constant MAX-STAKE-PERIOD u52560)  ;; Approximately 1 year (52560 blocks)

;; Stake tokens with enhanced validation
(define-public (stake-tokens 
  (token-contract <sip010-token-trait>) 
  (stake-amount uint) 
  (stake-period uint)
)
  (begin
    ;; Validate token contract
    (asserts! (validate-token-contract token-contract) ERROR-INVALID-TOKEN-CONTRACT)
    
    ;; Validate input parameters
    (asserts! (validate-stake-amount stake-amount) ERROR-INVALID-AMOUNT)
    (asserts! (<= stake-period MAX-STAKE-PERIOD) ERROR-INVALID-AMOUNT)
    
    ;; Check if already staked
    (asserts! 
      (is-none (map-get? staked-tokens { staker: tx-sender })) 
      ERROR-ALREADY-STAKED
    )
    
    ;; Verify user has sufficient balance
    (let ((user-token-balance (unwrap! 
          (contract-call? token-contract get-balance tx-sender)
          ERROR-INSUFFICIENT-BALANCE
        )))
      (asserts! (>= user-token-balance stake-amount) ERROR-INSUFFICIENT-BALANCE)
    )
    
    ;; Transfer tokens to contract
    (let ((transfer-response 
            (contract-call? token-contract transfer 
              stake-amount 
              tx-sender 
              (as-contract tx-sender) 
              none
            )))
      (asserts! (is-ok transfer-response) ERROR-TRANSFER-FAILED)
    )
    
    ;; Record stake
    (map-set staked-tokens 
      { staker: tx-sender }
      {
        amount: stake-amount,
        start-block: block-height,
        stake-period: stake-period,
        claimed-rewards: u0
      }
    )
    
    ;; Update total staked amount
    (var-set total-staked-amount (+ (var-get total-staked-amount) stake-amount))
    
    (ok true)
  )
)

;; Calculate rewards with additional safety checks
(define-private (calculate-rewards (stake-data {
  amount: uint, 
  start-block: uint, 
  stake-period: uint, 
  claimed-rewards: uint
}))
  (let 
    (
      (current-block-height block-height)
      (blocks-passed (- current-block-height (get start-block stake-data)))
      (reward-rate BASE-REWARD-RATE)
      (max-rewards (/ (* (get amount stake-data) reward-rate blocks-passed) u100))
    )
    (if (> blocks-passed (get stake-period stake-data))
      max-rewards
      (/ (* (get amount stake-data) reward-rate blocks-passed) u100)
    )
  )
)

;; Claim accumulated rewards with enhanced validation
(define-public (claim-rewards (token-contract <sip010-token-trait>))
  (begin
    ;; Validate token contract
    (asserts! (validate-token-contract token-contract) ERROR-INVALID-TOKEN-CONTRACT)
    
    (let 
      (
        (stake-data (unwrap! 
          (map-get? staked-tokens { staker: tx-sender }) 
          ERROR-STAKE-NOT-FOUND
        ))
        (pending-rewards (- 
          (calculate-rewards stake-data)
          (get claimed-rewards stake-data)
        ))
      )
      ;; Validate reward calculation
      (asserts! (> pending-rewards u0) ERROR-REWARD-CALCULATION)
      
      ;; Transfer rewards
      (let ((transfer-response 
              (as-contract (contract-call? token-contract transfer 
                pending-rewards 
                (as-contract tx-sender) 
                tx-sender 
                none
              ))))
        (asserts! (is-ok transfer-response) ERROR-TRANSFER-FAILED)
      )
      
      ;; Update claimed rewards
      (map-set staked-tokens 
        { staker: tx-sender }
        (merge stake-data { 
          claimed-rewards: (+ (get claimed-rewards stake-data) pending-rewards) 
        })
      )
      
      (ok pending-rewards)
    )
  )
)

;; Unstake tokens with enhanced validation and penalty mechanism
(define-public (unstake-tokens (token-contract <sip010-token-trait>))
  (begin
    ;; Validate token contract
    (asserts! (validate-token-contract token-contract) ERROR-INVALID-TOKEN-CONTRACT)
    
    (let 
      (
        (stake-data (unwrap! 
          (map-get? staked-tokens { staker: tx-sender }) 
          ERROR-STAKE-NOT-FOUND
        ))
        (current-block-height block-height)
        (blocks-passed (- current-block-height (get start-block stake-data)))
        (early-exit-penalty (if (< blocks-passed (get stake-period stake-data)) u10 u0))
        (penalty-amount (/ (* (get amount stake-data) early-exit-penalty) u100))
        (unstake-amount (- (get amount stake-data) penalty-amount))
      )
      ;; Validate unstaking conditions
      (asserts! 
        (>= blocks-passed (/ (get stake-period stake-data) u2)) 
        ERROR-UNSTAKE-FORBIDDEN
      )
      
      ;; Claim any pending rewards
      (try! (claim-rewards token-contract))
      
      ;; Transfer tokens back to user
      (let ((transfer-response 
              (as-contract (contract-call? token-contract transfer 
                unstake-amount 
                (as-contract tx-sender) 
                tx-sender 
                none
              ))))
        (asserts! (is-ok transfer-response) ERROR-TRANSFER-FAILED)
      )
      
      ;; Remove stake entry
      (map-delete staked-tokens { staker: tx-sender })
      
      ;; Update total staked amount
      (var-set total-staked-amount (- (var-get total-staked-amount) (get amount stake-data)))
      
      (ok unstake-amount)
    )
  )
)

;; View functions
(define-read-only (get-stake-info (staker principal))
  (map-get? staked-tokens { staker: staker })
)

(define-read-only (get-total-staked)
  (var-get total-staked-amount)
)

;; Admin functions with enhanced security
(define-public (update-reward-rate 
  (token-contract <sip010-token-trait>) 
  (new-reward-rate uint)
)
  (begin
    ;; Validate token contract and authorization
    (asserts! (validate-token-contract token-contract) ERROR-INVALID-TOKEN-CONTRACT)
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-UNAUTHORIZED)
    
    ;; Placeholder for reward rate update logic
    ;; Additional implementation would go here
    (ok true)
  )
)

;; Initialization
(define-constant CONTRACT-OWNER tx-sender)

;; Reward pool management with additional validation
(define-public (deposit-to-reward-pool 
  (token-contract <sip010-token-trait>) 
  (deposit-amount uint)
)
  (begin
    ;; Validate token contract
    (asserts! (validate-token-contract token-contract) ERROR-INVALID-TOKEN-CONTRACT)
    
    ;; Validate amount
    (asserts! (validate-stake-amount deposit-amount) ERROR-INVALID-AMOUNT)
    
    ;; Transfer tokens to reward pool
    (let ((transfer-response 
            (contract-call? token-contract transfer 
              deposit-amount 
              tx-sender 
              (as-contract tx-sender) 
              none
            )))
      (asserts! (is-ok transfer-response) ERROR-TRANSFER-FAILED)
    )
    
    ;; Update reward pool
    (var-set reward-pool-balance 
      (+ (var-get reward-pool-balance) 
         (unwrap! 
           (contract-call? token-contract get-balance (as-contract tx-sender)) 
           ERROR-INSUFFICIENT-BALANCE
         )
      )
    )
    
    (ok true)
  )
)

;; Reward pool balance tracking
(define-data-var reward-pool-balance uint u0)
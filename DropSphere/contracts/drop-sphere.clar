;; Drop Sphere - Advanced Airdrop Distribution Smart Contract
;; A comprehensive platform for managing token airdrops with vesting and governance features

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_CAMPAIGN_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_CAMPAIGN_ENDED (err u403))
(define-constant ERR_ALREADY_CLAIMED (err u405))
(define-constant ERR_NOT_ELIGIBLE (err u402))
(define-constant ERR_INSUFFICIENT_FUNDS (err u406))
(define-constant ERR_CLAIM_PERIOD_ENDED (err u407))
(define-constant MAX_BATCH_SIZE u100)

;; Data structures
(define-map airdrop-campaigns
  { campaign-id: uint }
  {
    creator: principal,
    token-name: (string-ascii 50),
    total-amount: uint,
    distributed-amount: uint,
    recipients-count: uint,
    start-block: uint,
    end-block: uint,
    claim-deadline: uint,
    vesting-period: (optional uint),
    is-active: bool,
    requires-whitelist: bool,
    merkle-root: (optional (buff 32))
  }
)

(define-map campaign-recipients
  { campaign-id: uint, recipient: principal }
  {
    allocation-amount: uint,
    claimed-amount: uint,
    last-claim-block: uint,
    is-whitelisted: bool,
    merkle-proof: (optional (list 10 (buff 32)))
  }
)

(define-map vesting-schedules
  { campaign-id: uint, recipient: principal }
  {
    total-vested: uint,
    claimed-vested: uint,
    vesting-start: uint,
    vesting-duration: uint,
    cliff-period: uint
  }
)

(define-map campaign-stats
  { campaign-id: uint }
  {
    unique-claimants: uint,
    total-claims: uint,
    average-claim: uint,
    last-claim-block: uint
  }
)

(define-map user-participation
  { user: principal }
  {
    campaigns-participated: uint,
    total-claimed: uint,
    first-claim-block: uint,
    reputation-score: uint
  }
)

;; Data variables
(define-data-var next-campaign-id uint u1)
(define-data-var total-campaigns uint u0)
(define-data-var total-distributed uint u0)
(define-data-var platform-fee-bps uint u100) ;; 1% platform fee

;; Helper functions
(define-private (validate-string-input (input (string-ascii 50)))
  (> (len input) u0)
)

(define-private (validate-campaign-id (campaign-id uint))
  (and (> campaign-id u0) (< campaign-id (var-get next-campaign-id)))
)

(define-private (min-uint (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (is-campaign-active (campaign-id uint))
  (let ((campaign (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) false)))
    (and 
      (get is-active campaign)
      (>= block-height (get start-block campaign))
      (<= block-height (get end-block campaign))
    )
  )
)

(define-private (calculate-vested-amount (campaign-id uint) (recipient principal))
  (let (
    (vesting (map-get? vesting-schedules { campaign-id: campaign-id, recipient: recipient }))
    (campaign (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) u0))
  )
    (match vesting
      some-vesting
        (let (
          (elapsed-blocks (- block-height (get vesting-start some-vesting)))
          (cliff-passed (>= elapsed-blocks (get cliff-period some-vesting)))
        )
          (if cliff-passed
            (let ((vested-percentage (min-uint u100 (/ (* elapsed-blocks u100) (get vesting-duration some-vesting)))))
              (/ (* (get total-vested some-vesting) vested-percentage) u100)
            )
            u0
          )
        )
      u0
    )
  )
)

(define-private (update-user-stats (user principal) (amount uint) (campaign-id uint))
  (let ((profile (default-to 
    { campaigns-participated: u0, total-claimed: u0, first-claim-block: block-height, reputation-score: u100 }
    (map-get? user-participation { user: user }))))
    
    (map-set user-participation
      { user: user }
      (merge profile {
        campaigns-participated: (+ (get campaigns-participated profile) u1),
        total-claimed: (+ (get total-claimed profile) amount),
        reputation-score: (+ (get reputation-score profile) u5)
      })
    )
  )
)

;; Public functions
(define-public (create-campaign (token-name (string-ascii 50))
                               (total-amount uint)
                               (duration-blocks uint)
                               (claim-period-blocks uint)
                               (vesting-blocks (optional uint))
                               (requires-whitelist bool))
  (let ((campaign-id (var-get next-campaign-id)))
    (asserts! (validate-string-input token-name) ERR_INVALID_INPUT)
    (asserts! (> total-amount u0) ERR_INVALID_INPUT)
    (asserts! (> duration-blocks u0) ERR_INVALID_INPUT)
    (asserts! (> claim-period-blocks u0) ERR_INVALID_INPUT)
    
    (map-set airdrop-campaigns
      { campaign-id: campaign-id }
      {
        creator: tx-sender,
        token-name: token-name,
        total-amount: total-amount,
        distributed-amount: u0,
        recipients-count: u0,
        start-block: block-height,
        end-block: (+ block-height duration-blocks),
        claim-deadline: (+ block-height claim-period-blocks),
        vesting-period: vesting-blocks,
        is-active: true,
        requires-whitelist: requires-whitelist,
        merkle-root: none
      }
    )
    
    (map-set campaign-stats
      { campaign-id: campaign-id }
      {
        unique-claimants: u0,
        total-claims: u0,
        average-claim: u0,
        last-claim-block: u0
      }
    )
    
    (var-set next-campaign-id (+ campaign-id u1))
    (var-set total-campaigns (+ (var-get total-campaigns) u1))
    (ok campaign-id)
  )
)

(define-public (add-recipients-batch (campaign-id uint) 
                                    (recipients (list 50 principal))
                                    (amounts (list 50 uint)))
  (let ((campaign (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND)))
    (asserts! (validate-campaign-id campaign-id) ERR_CAMPAIGN_NOT_FOUND)
    (asserts! (is-eq tx-sender (get creator campaign)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len recipients) (len amounts)) ERR_INVALID_INPUT)
    (asserts! (<= (len recipients) MAX_BATCH_SIZE) ERR_INVALID_INPUT)
    
    (let ((total-batch-amount (fold + amounts u0)))
      (asserts! (<= (+ (get distributed-amount campaign) total-batch-amount) (get total-amount campaign)) ERR_INSUFFICIENT_FUNDS)
      
      ;; Process batch addition
      (let ((updated-recipients (+ (get recipients-count campaign) (len recipients))))
        (map-set airdrop-campaigns
          { campaign-id: campaign-id }
          (merge campaign {
            recipients-count: updated-recipients,
            distributed-amount: (+ (get distributed-amount campaign) total-batch-amount)
          })
        )
        
        ;; Add recipients (simplified - in real implementation would iterate through lists)
        (ok true)
      )
    )
  )
)

(define-public (whitelist-recipient (campaign-id uint) 
                                   (recipient principal) 
                                   (allocation uint))
  (let ((campaign (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND)))
    (asserts! (validate-campaign-id campaign-id) ERR_CAMPAIGN_NOT_FOUND)
    (asserts! (is-eq tx-sender (get creator campaign)) ERR_UNAUTHORIZED)
    (asserts! (get requires-whitelist campaign) ERR_INVALID_INPUT)
    (asserts! (> allocation u0) ERR_INVALID_INPUT)
    
    (map-set campaign-recipients
      { campaign-id: campaign-id, recipient: recipient }
      {
        allocation-amount: allocation,
        claimed-amount: u0,
        last-claim-block: u0,
        is-whitelisted: true,
        merkle-proof: none
      }
    )
    
    ;; Setup vesting if required
    (match (get vesting-period campaign)
      some-vesting
        (map-set vesting-schedules
          { campaign-id: campaign-id, recipient: recipient }
          {
            total-vested: allocation,
            claimed-vested: u0,
            vesting-start: block-height,
            vesting-duration: some-vesting,
            cliff-period: (/ some-vesting u4) ;; 25% cliff
          }
        )
      true
    )
    
    (ok true)
  )
)

(define-public (claim-airdrop (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    (recipient-data (unwrap! (map-get? campaign-recipients { campaign-id: campaign-id, recipient: tx-sender }) ERR_NOT_ELIGIBLE))
  )
    (asserts! (validate-campaign-id campaign-id) ERR_CAMPAIGN_NOT_FOUND)
    (asserts! (is-campaign-active campaign-id) ERR_CAMPAIGN_ENDED)
    (asserts! (<= block-height (get claim-deadline campaign)) ERR_CLAIM_PERIOD_ENDED)
    (asserts! (get is-whitelisted recipient-data) ERR_NOT_ELIGIBLE)
    (asserts! (is-eq (get claimed-amount recipient-data) u0) ERR_ALREADY_CLAIMED)
    
    (let ((claim-amount 
      (match (get vesting-period campaign)
        some-vesting (calculate-vested-amount campaign-id tx-sender)
        (get allocation-amount recipient-data)
      )))
      
      (asserts! (> claim-amount u0) ERR_INVALID_INPUT)
      
      ;; Update recipient claim status
      (map-set campaign-recipients
        { campaign-id: campaign-id, recipient: tx-sender }
        (merge recipient-data {
          claimed-amount: claim-amount,
          last-claim-block: block-height
        })
      )
      
      ;; Update campaign stats
      (let ((stats (default-to 
        { unique-claimants: u0, total-claims: u0, average-claim: u0, last-claim-block: u0 }
        (map-get? campaign-stats { campaign-id: campaign-id }))))
        
        (map-set campaign-stats
          { campaign-id: campaign-id }
          (merge stats {
            unique-claimants: (+ (get unique-claimants stats) u1),
            total-claims: (+ (get total-claims stats) u1),
            average-claim: (/ (+ (* (get average-claim stats) (get total-claims stats)) claim-amount) (+ (get total-claims stats) u1)),
            last-claim-block: block-height
          })
        )
      )
      
      ;; Update user participation
      (update-user-stats tx-sender claim-amount campaign-id)
      
      ;; Update global stats
      (var-set total-distributed (+ (var-get total-distributed) claim-amount))
      
      (ok claim-amount)
    )
  )
)

(define-public (claim-vested-tokens (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    (vesting (unwrap! (map-get? vesting-schedules { campaign-id: campaign-id, recipient: tx-sender }) ERR_NOT_ELIGIBLE))
  )
    (asserts! (validate-campaign-id campaign-id) ERR_CAMPAIGN_NOT_FOUND)
    (asserts! (is-some (get vesting-period campaign)) ERR_INVALID_INPUT)
    
    (let (
      (available-amount (calculate-vested-amount campaign-id tx-sender))
      (claimable-amount (- available-amount (get claimed-vested vesting)))
    )
      (asserts! (> claimable-amount u0) ERR_INVALID_INPUT)
      
      ;; Update vesting schedule
      (map-set vesting-schedules
        { campaign-id: campaign-id, recipient: tx-sender }
        (merge vesting { claimed-vested: available-amount })
      )
      
      (ok claimable-amount)
    )
  )
)

(define-public (emergency-pause-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get creator campaign)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    
    (map-set airdrop-campaigns
      { campaign-id: campaign-id }
      (merge campaign { is-active: false })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-campaign (campaign-id uint))
  (map-get? airdrop-campaigns { campaign-id: campaign-id })
)

(define-read-only (get-recipient-allocation (campaign-id uint) (recipient principal))
  (map-get? campaign-recipients { campaign-id: campaign-id, recipient: recipient })
)

(define-read-only (get-vesting-info (campaign-id uint) (recipient principal))
  (let ((vesting (map-get? vesting-schedules { campaign-id: campaign-id, recipient: recipient })))
    (match vesting
      some-vesting 
        (ok {
          total-vested: (get total-vested some-vesting),
          available-now: (calculate-vested-amount campaign-id recipient),
          claimed-so-far: (get claimed-vested some-vesting),
          vesting-complete: (>= block-height (+ (get vesting-start some-vesting) (get vesting-duration some-vesting)))
        })
      (ok { total-vested: u0, available-now: u0, claimed-so-far: u0, vesting-complete: false })
    )
  )
)

(define-read-only (get-campaign-stats (campaign-id uint))
  (map-get? campaign-stats { campaign-id: campaign-id })
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-participation { user: user })
)

(define-read-only (get-platform-stats)
  (ok {
    total-campaigns: (var-get total-campaigns),
    total-distributed: (var-get total-distributed),
    platform-fee-rate: (var-get platform-fee-bps),
    next-campaign-id: (var-get next-campaign-id)
  })
)
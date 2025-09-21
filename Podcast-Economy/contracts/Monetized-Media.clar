;; Decentralized Podcast Monetization Smart Contract
;; This contract manages podcast subscriptions, ad revenue distribution, and creator monetization

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-PODCAST-NOT-FOUND (err u101))
(define-constant ERR-SUBSCRIPTION-NOT-FOUND (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-ALREADY-SUBSCRIBED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-INVALID-DURATION (err u106))
(define-constant ERR-SUBSCRIPTION-EXPIRED (err u107))
(define-constant ERR-AD-CAMPAIGN-NOT-FOUND (err u108))
(define-constant ERR-INVALID-PERCENTAGE (err u109))
(define-constant ERR-CAMPAIGN-ENDED (err u110))
(define-constant ERR-INVALID-TIER (err u111))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Platform fee (5%)
(define-constant PLATFORM-FEE u5)

;; Data structures

;; Podcast information
(define-map podcasts 
  { podcast-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    subscription-price: uint,
    total-subscribers: uint,
    total-revenue: uint,
    created-at: uint,
    is-active: bool
  }
)

;; Subscription tiers for different access levels
(define-map subscription-tiers
  { podcast-id: uint, tier-id: uint }
  {
    name: (string-ascii 50),
    price: uint,
    duration-blocks: uint,
    benefits: (string-ascii 200)
  }
)

;; User subscriptions
(define-map subscriptions
  { subscriber: principal, podcast-id: uint }
  {
    tier-id: uint,
    start-block: uint,
    end-block: uint,
    amount-paid: uint,
    auto-renew: bool
  }
)

;; Ad campaigns
(define-map ad-campaigns
  { campaign-id: uint }
  {
    advertiser: principal,
    title: (string-ascii 100),
    target-podcast-id: (optional uint),
    budget: uint,
    spent: uint,
    cpm: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool
  }
)

;; Ad impressions tracking
(define-map ad-impressions
  { campaign-id: uint, podcast-id: uint, block: uint }
  {
    impressions: uint,
    revenue-generated: uint
  }
)

;; Creator earnings tracking
(define-map creator-earnings
  { creator: principal }
  {
    total-subscription-revenue: uint,
    total-ad-revenue: uint,
    pending-withdrawal: uint,
    last-withdrawal-block: uint
  }
)

;; Counters for IDs
(define-data-var next-podcast-id uint u1)
(define-data-var next-campaign-id uint u1)

;; Helper functions

;; Get current block height
(define-read-only (get-current-block)
  block-height
)

;; Check if subscription is active
(define-read-only (is-subscription-active (subscriber principal) (podcast-id uint))
  (match (map-get? subscriptions { subscriber: subscriber, podcast-id: podcast-id })
    subscription (>= (get end-block subscription) block-height)
    false
  )
)

;; Calculate platform fee
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM-FEE) u100)
)

;; Podcast management functions

;; Create a new podcast
(define-public (create-podcast (title (string-ascii 100)) (description (string-ascii 500)) (base-price uint))
  (let 
    (
      (podcast-id (var-get next-podcast-id))
    )
    (asserts! (> (len title) u0) ERR-INVALID-AMOUNT)
    (asserts! (> base-price u0) ERR-INVALID-AMOUNT)
    
    (map-set podcasts 
      { podcast-id: podcast-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        subscription-price: base-price,
        total-subscribers: u0,
        total-revenue: u0,
        created-at: block-height,
        is-active: true
      }
    )
    
    ;; Create default subscription tier
    (map-set subscription-tiers
      { podcast-id: podcast-id, tier-id: u1 }
      {
        name: "Basic",
        price: base-price,
        duration-blocks: u1440, ;; Approximately 30 days (assuming 30 second blocks)
        benefits: "Access to all episodes"
      }
    )
    
    (var-set next-podcast-id (+ podcast-id u1))
    (ok podcast-id)
  )
)

;; Add subscription tier to podcast
(define-public (add-subscription-tier (podcast-id uint) (tier-id uint) (name (string-ascii 50)) (price uint) (duration-blocks uint) (benefits (string-ascii 200)))
  (let
    (
      (podcast (unwrap! (map-get? podcasts { podcast-id: podcast-id }) ERR-PODCAST-NOT-FOUND))
    )
    (asserts! (is-eq (get creator podcast) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
    
    (map-set subscription-tiers
      { podcast-id: podcast-id, tier-id: tier-id }
      {
        name: name,
        price: price,
        duration-blocks: duration-blocks,
        benefits: benefits
      }
    )
    (ok true)
  )
)

;; Subscription management functions

;; Subscribe to a podcast with specific tier
(define-public (subscribe-to-podcast (podcast-id uint) (tier-id uint))
  (let
    (
      (podcast (unwrap! (map-get? podcasts { podcast-id: podcast-id }) ERR-PODCAST-NOT-FOUND))
      (tier (unwrap! (map-get? subscription-tiers { podcast-id: podcast-id, tier-id: tier-id }) ERR-INVALID-TIER))
      (subscription-price (get price tier))
      (duration (get duration-blocks tier))
      (platform-fee (calculate-platform-fee subscription-price))
      (creator-revenue (- subscription-price platform-fee))
      (existing-sub (map-get? subscriptions { subscriber: tx-sender, podcast-id: podcast-id }))
    )
    (asserts! (get is-active podcast) ERR-PODCAST-NOT-FOUND)
    (asserts! (is-none existing-sub) ERR-ALREADY-SUBSCRIBED)
    (asserts! (> subscription-price u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer payment
    (try! (stx-transfer? subscription-price tx-sender (get creator podcast)))
    
    ;; Create subscription
    (map-set subscriptions
      { subscriber: tx-sender, podcast-id: podcast-id }
      {
        tier-id: tier-id,
        start-block: block-height,
        end-block: (+ block-height duration),
        amount-paid: subscription-price,
        auto-renew: false
      }
    )
    
    ;; Update podcast stats
    (map-set podcasts
      { podcast-id: podcast-id }
      (merge podcast {
        total-subscribers: (+ (get total-subscribers podcast) u1),
        total-revenue: (+ (get total-revenue podcast) subscription-price)
      })
    )
    
    ;; Update creator earnings
    (match (map-get? creator-earnings { creator: (get creator podcast) })
      earnings (map-set creator-earnings
        { creator: (get creator podcast) }
        (merge earnings {
          total-subscription-revenue: (+ (get total-subscription-revenue earnings) creator-revenue),
          pending-withdrawal: (+ (get pending-withdrawal earnings) creator-revenue)
        })
      )
      (map-set creator-earnings
        { creator: (get creator podcast) }
        {
          total-subscription-revenue: creator-revenue,
          total-ad-revenue: u0,
          pending-withdrawal: creator-revenue,
          last-withdrawal-block: u0
        }
      )
    )
    
    (ok true)
  )
)

;; Renew subscription
(define-public (renew-subscription (podcast-id uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions { subscriber: tx-sender, podcast-id: podcast-id }) ERR-SUBSCRIPTION-NOT-FOUND))
      (tier (unwrap! (map-get? subscription-tiers { podcast-id: podcast-id, tier-id: (get tier-id subscription) }) ERR-INVALID-TIER))
      (podcast (unwrap! (map-get? podcasts { podcast-id: podcast-id }) ERR-PODCAST-NOT-FOUND))
      (renewal-price (get price tier))
      (duration (get duration-blocks tier))
      (platform-fee (calculate-platform-fee renewal-price))
      (creator-revenue (- renewal-price platform-fee))
    )
    ;; Transfer payment
    (try! (stx-transfer? renewal-price tx-sender (get creator podcast)))
    
    ;; Extend subscription
    (map-set subscriptions
      { subscriber: tx-sender, podcast-id: podcast-id }
      (merge subscription {
        end-block: (+ (get end-block subscription) duration),
        amount-paid: (+ (get amount-paid subscription) renewal-price)
      })
    )
    
    ;; Update creator earnings
    (match (map-get? creator-earnings { creator: (get creator podcast) })
      earnings (map-set creator-earnings
        { creator: (get creator podcast) }
        (merge earnings {
          total-subscription-revenue: (+ (get total-subscription-revenue earnings) creator-revenue),
          pending-withdrawal: (+ (get pending-withdrawal earnings) creator-revenue)
        })
      )
      false ;; Should exist if they have a podcast
    )
    
    (ok true)
  )
)

;; Ad campaign management

;; Create ad campaign
(define-public (create-ad-campaign (title (string-ascii 100)) (target-podcast-id (optional uint)) (budget uint) (cpm uint) (duration-blocks uint))
  (let
    (
      (campaign-id (var-get next-campaign-id))
    )
    (asserts! (> budget u0) ERR-INVALID-AMOUNT)
    (asserts! (> cpm u0) ERR-INVALID-AMOUNT)
    (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
    
    (map-set ad-campaigns
      { campaign-id: campaign-id }
      {
        advertiser: tx-sender,
        title: title,
        target-podcast-id: target-podcast-id,
        budget: budget,
        spent: u0,
        cpm: cpm,
        start-block: block-height,
        end-block: (+ block-height duration-blocks),
        is-active: true
      }
    )
    
    ;; Lock campaign budget
    (try! (stx-transfer? budget tx-sender (as-contract tx-sender)))
    
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

;; Record ad impression and distribute revenue
(define-public (record-ad-impression (campaign-id uint) (podcast-id uint) (impressions uint))
  (let
    (
      (campaign (unwrap! (map-get? ad-campaigns { campaign-id: campaign-id }) ERR-AD-CAMPAIGN-NOT-FOUND))
      (podcast (unwrap! (map-get? podcasts { podcast-id: podcast-id }) ERR-PODCAST-NOT-FOUND))
      (revenue-per-impression (/ (get cpm campaign) u1000))
      (total-revenue (* impressions revenue-per-impression))
      (platform-fee (calculate-platform-fee total-revenue))
      (creator-revenue (- total-revenue platform-fee))
      (new-spent (+ (get spent campaign) total-revenue))
    )
    (asserts! (is-eq tx-sender (get creator podcast)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (get is-active campaign) ERR-CAMPAIGN-ENDED)
    (asserts! (<= (get end-block campaign) block-height) ERR-CAMPAIGN-ENDED)
    (asserts! (> impressions u0) ERR-INVALID-AMOUNT)
    (asserts! (<= new-spent (get budget campaign)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Check if campaign targets this podcast or is general
    (match (get target-podcast-id campaign)
      target-id (asserts! (is-eq target-id podcast-id) ERR-UNAUTHORIZED-ACCESS)
      true ;; General campaign, any podcast can participate
    )
    
    ;; Update campaign spent amount
    (map-set ad-campaigns
      { campaign-id: campaign-id }
      (merge campaign { spent: new-spent })
    )
    
    ;; Record impression data
    (match (map-get? ad-impressions { campaign-id: campaign-id, podcast-id: podcast-id, block: block-height })
      existing (map-set ad-impressions
        { campaign-id: campaign-id, podcast-id: podcast-id, block: block-height }
        {
          impressions: (+ (get impressions existing) impressions),
          revenue-generated: (+ (get revenue-generated existing) total-revenue)
        }
      )
      (map-set ad-impressions
        { campaign-id: campaign-id, podcast-id: podcast-id, block: block-height }
        {
          impressions: impressions,
          revenue-generated: total-revenue
        }
      )
    )
    
    ;; Transfer ad revenue to creator
    (try! (as-contract (stx-transfer? creator-revenue tx-sender (get creator podcast))))
    
    ;; Update creator earnings
    (match (map-get? creator-earnings { creator: (get creator podcast) })
      earnings (map-set creator-earnings
        { creator: (get creator podcast) }
        (merge earnings {
          total-ad-revenue: (+ (get total-ad-revenue earnings) creator-revenue),
          pending-withdrawal: (+ (get pending-withdrawal earnings) creator-revenue)
        })
      )
      (map-set creator-earnings
        { creator: (get creator podcast) }
        {
          total-subscription-revenue: u0,
          total-ad-revenue: creator-revenue,
          pending-withdrawal: creator-revenue,
          last-withdrawal-block: u0
        }
      )
    )
    
    (ok total-revenue)
  )
)

;; Withdraw creator earnings
(define-public (withdraw-earnings)
  (let
    (
      (earnings (unwrap! (map-get? creator-earnings { creator: tx-sender }) ERR-UNAUTHORIZED-ACCESS))
      (withdrawal-amount (get pending-withdrawal earnings))
    )
    (asserts! (> withdrawal-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer earnings to creator
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender)))
    
    ;; Update earnings record
    (map-set creator-earnings
      { creator: tx-sender }
      (merge earnings {
        pending-withdrawal: u0,
        last-withdrawal-block: block-height
      })
    )
    
    (ok withdrawal-amount)
  )
)

;; Read-only functions

;; Get podcast information
(define-read-only (get-podcast (podcast-id uint))
  (map-get? podcasts { podcast-id: podcast-id })
)

;; Get subscription information
(define-read-only (get-subscription (subscriber principal) (podcast-id uint))
  (map-get? subscriptions { subscriber: subscriber, podcast-id: podcast-id })
)

;; Get subscription tier information
(define-read-only (get-subscription-tier (podcast-id uint) (tier-id uint))
  (map-get? subscription-tiers { podcast-id: podcast-id, tier-id: tier-id })
)

;; Get ad campaign information
(define-read-only (get-ad-campaign (campaign-id uint))
  (map-get? ad-campaigns { campaign-id: campaign-id })
)

;; Get creator earnings
(define-read-only (get-creator-earnings (creator principal))
  (map-get? creator-earnings { creator: creator })
)

;; Get ad impression data
(define-read-only (get-ad-impressions (campaign-id uint) (podcast-id uint) (block uint))
  (map-get? ad-impressions { campaign-id: campaign-id, podcast-id: podcast-id, block: block })
)

;; Check subscription access
(define-read-only (check-subscription-access (subscriber principal) (podcast-id uint))
  (match (map-get? subscriptions { subscriber: subscriber, podcast-id: podcast-id })
    subscription 
      {
        has-access: (>= (get end-block subscription) block-height),
        tier-id: (get tier-id subscription),
        expires-at: (get end-block subscription)
      }
    {
      has-access: false,
      tier-id: u0,
      expires-at: u0
    }
  )
)
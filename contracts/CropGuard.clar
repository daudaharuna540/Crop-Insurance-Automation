;; title: CropGuard

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-POLICY-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-POLICY-EXPIRED (err u103))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u104))
(define-constant ERR-INVALID-ORACLE-DATA (err u105))
(define-constant ERR-POLICY-ALREADY-EXISTS (err u106))
(define-constant ERR-INVALID-PREMIUM (err u107))
(define-constant ERR-INVALID-COVERAGE (err u108))
(define-constant ERR-WEATHER-CONDITIONS-NOT-MET (err u109))
(define-constant ERR-YIELD-THRESHOLD-NOT-MET (err u110))
(define-constant ERR-POLICY-STILL-ACTIVE (err u111))
(define-constant ERR-NO-PREVIOUS-POLICY (err u112))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-PREMIUM u1000000)
(define-constant MAX-COVERAGE u100000000)
(define-constant MIN-COVERAGE u5000000)
(define-constant BLOCKS-PER-SEASON u52560)
(define-constant ORACLE-VALIDITY-BLOCKS u144)

(define-data-var total-policies-issued uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var contract-balance uint u0)
(define-data-var oracle-address (optional principal) none)
(define-data-var total-renewals uint u0)

(define-map policies
  { farmer: principal }
  {
    policy-id: uint,
    crop-type: (string-ascii 50),
    coverage-amount: uint,
    premium-paid: uint,
    start-block: uint,
    end-block: uint,
    latitude: int,
    longitude: int,
    yield-threshold: uint,
    weather-threshold: uint,
    is-active: bool,
    renewal-count: uint
  }
)

(define-map claims
  { policy-id: uint }
  {
    farmer: principal,
    claim-amount: uint,
    weather-data: uint,
    yield-data: uint,
    claim-block: uint,
    is-processed: bool,
    is-approved: bool
  }
)

(define-map oracle-data
  { block-height: uint, location-hash: (buff 32) }
  {
    temperature: int,
    rainfall: uint,
    humidity: uint,
    wind-speed: uint,
    yield-estimate: uint,
    timestamp: uint,
    verified: bool
  }
)

(define-map authorized-oracles principal bool)

(define-public (set-oracle-address (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set oracle-address (some new-oracle))
    (map-set authorized-oracles new-oracle true)
    (ok true)
  )
)

(define-public (purchase-policy 
  (crop-type (string-ascii 50))
  (coverage-amount uint)
  (premium-amount uint)
  (latitude int)
  (longitude int)
  (yield-threshold uint)
  (weather-threshold uint))
  (let (
    (current-block stacks-block-height)
    (policy-id (+ (var-get total-policies-issued) u1))
    (end-block (+ current-block BLOCKS-PER-SEASON))
  )
    (asserts! (>= premium-amount MIN-PREMIUM) ERR-INVALID-PREMIUM)
    (asserts! (and (>= coverage-amount MIN-COVERAGE) (<= coverage-amount MAX-COVERAGE)) ERR-INVALID-COVERAGE)
    (asserts! (is-none (map-get? policies { farmer: tx-sender })) ERR-POLICY-ALREADY-EXISTS)
    (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
    (map-set policies
      { farmer: tx-sender }
      {
        policy-id: policy-id,
        crop-type: crop-type,
        coverage-amount: coverage-amount,
        premium-paid: premium-amount,
        start-block: current-block,
        end-block: end-block,
        latitude: latitude,
        longitude: longitude,
        yield-threshold: yield-threshold,
        weather-threshold: weather-threshold,
        is-active: true,
        renewal-count: u0
      }
    )
    (var-set total-policies-issued policy-id)
    (var-set contract-balance (+ (var-get contract-balance) premium-amount))
    (ok policy-id)
  )
)

(define-public (submit-oracle-data
  (location-hash (buff 32))
  (temperature int)
  (rainfall uint)
  (humidity uint)
  (wind-speed uint)
  (yield-estimate uint))
  (let (
    (current-block stacks-block-height)
  )
    (asserts! (default-to false (map-get? authorized-oracles tx-sender)) ERR-NOT-AUTHORIZED)
    (map-set oracle-data
      { block-height: current-block, location-hash: location-hash }
      {
        temperature: temperature,
        rainfall: rainfall,
        humidity: humidity,
        wind-speed: wind-speed,
        yield-estimate: yield-estimate,
        timestamp: (unwrap-panic (get-stacks-block-info? time current-block)),
        verified: true
      }
    )
    (ok true)
  )
)

(define-public (file-claim)
  (let (
    (farmer-policy (unwrap! (map-get? policies { farmer: tx-sender }) ERR-POLICY-NOT-FOUND))
    (policy-id (get policy-id farmer-policy))
    (current-block stacks-block-height)
    (location-hash (sha256 (concat (unwrap-panic (to-consensus-buff? (get latitude farmer-policy))) (unwrap-panic (to-consensus-buff? (get longitude farmer-policy))))))
  )
    (asserts! (get is-active farmer-policy) ERR-POLICY-EXPIRED)
    (asserts! (< current-block (get end-block farmer-policy)) ERR-POLICY-EXPIRED)
    (asserts! (is-none (map-get? claims { policy-id: policy-id })) ERR-CLAIM-ALREADY-PROCESSED)
    (let (
      (weather-data (get-recent-oracle-data location-hash))
      (yield-data (get yield-estimate weather-data))
      (rainfall-amount (get rainfall weather-data))
    )
      (asserts! (get verified weather-data) ERR-INVALID-ORACLE-DATA)
      (map-set claims
        { policy-id: policy-id }
        {
          farmer: tx-sender,
          claim-amount: (get coverage-amount farmer-policy),
          weather-data: rainfall-amount,
          yield-data: yield-data,
          claim-block: current-block,
          is-processed: false,
          is-approved: false
        }
      )
      (try! (process-claim-automatically policy-id))
      (ok policy-id)
    )
  )
)

(define-private (process-claim-automatically (policy-id uint))
  (let (
    (claim-data (unwrap! (map-get? claims { policy-id: policy-id }) ERR-CLAIM-ALREADY-PROCESSED))
    (farmer-policy (unwrap! (map-get? policies { farmer: (get farmer claim-data) }) ERR-POLICY-NOT-FOUND))
    (weather-threshold (get weather-threshold farmer-policy))
    (yield-threshold (get yield-threshold farmer-policy))
    (actual-weather (get weather-data claim-data))
    (actual-yield (get yield-data claim-data))
  )
    (if (or 
          (< actual-weather weather-threshold)
          (< actual-yield yield-threshold))
      (begin
        (map-set claims
          { policy-id: policy-id }
          (merge claim-data { is-processed: true, is-approved: true })
        )
        (try! (as-contract (stx-transfer? (get claim-amount claim-data) tx-sender (get farmer claim-data))))
        (var-set total-claims-paid (+ (var-get total-claims-paid) (get claim-amount claim-data)))
        (var-set contract-balance (- (var-get contract-balance) (get claim-amount claim-data)))
        (map-set policies
          { farmer: (get farmer claim-data) }
          (merge farmer-policy { is-active: false })
        )
        (ok true)
      )
      (begin
        (map-set claims
          { policy-id: policy-id }
          (merge claim-data { is-processed: true, is-approved: false })
        )
        (ok false)
      )
    )
  )
)

(define-private (get-recent-oracle-data (location-hash (buff 32)))
  (let (
    (current-block stacks-block-height)
    (search-block (- current-block u1))
  )
    (default-to
      { temperature: 0, rainfall: u0, humidity: u0, wind-speed: u0, yield-estimate: u0, timestamp: u0, verified: false }
      (map-get? oracle-data { block-height: search-block, location-hash: location-hash })
    )
  )
)

(define-public (renew-policy
  (coverage-amount uint)
  (premium-amount uint)
  (yield-threshold uint)
  (weather-threshold uint))
  (let (
    (existing-policy (unwrap! (map-get? policies { farmer: tx-sender }) ERR-NO-PREVIOUS-POLICY))
    (current-block stacks-block-height)
    (new-policy-id (+ (var-get total-policies-issued) u1))
    (new-end-block (+ current-block BLOCKS-PER-SEASON))
  )
    (asserts! (not (get is-active existing-policy)) ERR-POLICY-STILL-ACTIVE)
    (asserts! (>= premium-amount MIN-PREMIUM) ERR-INVALID-PREMIUM)
    (asserts! (and (>= coverage-amount MIN-COVERAGE) (<= coverage-amount MAX-COVERAGE)) ERR-INVALID-COVERAGE)
    (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
    (map-set policies
      { farmer: tx-sender }
      {
        policy-id: new-policy-id,
        crop-type: (get crop-type existing-policy),
        coverage-amount: coverage-amount,
        premium-paid: premium-amount,
        start-block: current-block,
        end-block: new-end-block,
        latitude: (get latitude existing-policy),
        longitude: (get longitude existing-policy),
        yield-threshold: yield-threshold,
        weather-threshold: weather-threshold,
        is-active: true,
        renewal-count: (+ (get renewal-count existing-policy) u1)
      }
    )
    (var-set total-policies-issued new-policy-id)
    (var-set total-renewals (+ (var-get total-renewals) u1))
    (var-set contract-balance (+ (var-get contract-balance) premium-amount))
    (ok new-policy-id)
  )
)

(define-public (cancel-policy)
  (let (
    (farmer-policy (unwrap! (map-get? policies { farmer: tx-sender }) ERR-POLICY-NOT-FOUND))
    (refund-amount (/ (get premium-paid farmer-policy) u2))
  )
    (asserts! (get is-active farmer-policy) ERR-POLICY-EXPIRED)
    (map-set policies
      { farmer: tx-sender }
      (merge farmer-policy { is-active: false })
    )
    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
    (var-set contract-balance (- (var-get contract-balance) refund-amount))
    (ok refund-amount)
  )
)

(define-public (fund-contract (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok true)
  )
)

(define-public (withdraw-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get contract-balance)) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    (var-set contract-balance (- (var-get contract-balance) amount))
    (ok true)
  )
)

(define-read-only (get-policy (farmer principal))
  (map-get? policies { farmer: farmer })
)

(define-read-only (get-claim (policy-id uint))
  (map-get? claims { policy-id: policy-id })
)

(define-read-only (get-contract-stats)
  {
    total-policies: (var-get total-policies-issued),
    total-claims-paid: (var-get total-claims-paid),
    contract-balance: (var-get contract-balance),
    oracle-address: (var-get oracle-address),
    total-renewals: (var-get total-renewals)
  }
)

(define-read-only (get-oracle-data-at (target-block uint) (location-hash (buff 32)))
  (map-get? oracle-data { block-height: target-block, location-hash: location-hash })
)

(define-read-only (is-policy-eligible-for-claim (farmer principal))
  (match (map-get? policies { farmer: farmer })
    policy-data
    (let (
      (current-block stacks-block-height)
      (location-hash (sha256 (concat (unwrap-panic (to-consensus-buff? (get latitude policy-data))) (unwrap-panic (to-consensus-buff? (get longitude policy-data))))))
      (oracle-info (get-recent-oracle-data location-hash))
    )
      {
        is-active: (get is-active policy-data),
        not-expired: (< current-block (get end-block policy-data)),
        has-oracle-data: (get verified oracle-info),
        weather-triggered: (< (get rainfall oracle-info) (get weather-threshold policy-data)),
        yield-triggered: (< (get yield-estimate oracle-info) (get yield-threshold policy-data))
      }
    )
    { is-active: false, not-expired: false, has-oracle-data: false, weather-triggered: false, yield-triggered: false }
  )
)

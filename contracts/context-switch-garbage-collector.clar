;; title: context-switch-garbage-collector
;; version: 1.0.0
;; summary: Sweeps away mental cache eviction storms
;; description: Tracks context switches, identifies patterns of cognitive overhead,
;;              and helps users minimize the cost of task-switching through
;;              focus restoration mechanisms and attention fragmentation metrics.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SWITCH (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-INVALID-COST (err u104))
(define-constant ERR-SESSION-ACTIVE (err u105))

;; Maximum cognitive cost per switch (1-100 scale)
(define-constant MAX-COGNITIVE-COST u100)

;; Minimum focus restoration points to claim
(define-constant MIN-RESTORATION-POINTS u10)

;; Data Variables
(define-data-var total-switches-tracked uint u0)
(define-data-var total-cognitive-cost uint u0)
(define-data-var active-users uint u0)
(define-data-var global-efficiency-score uint u100)

;; Data Maps

;; Track individual context switches
(define-map context-switches
  { switch-id: uint }
  {
    user: principal,
    from-context: (string-ascii 64),
    to-context: (string-ascii 64),
    cognitive-cost: uint,
    timestamp: uint,
    restoration-earned: uint
  }
)

;; Track user statistics and metrics
(define-map user-stats
  { user: principal }
  {
    total-switches: uint,
    total-cost: uint,
    restoration-points: uint,
    average-cost: uint,
    active-session: bool,
    last-switch-time: uint,
    efficiency-rating: uint
  }
)

;; Track high-cost patterns for optimization
(define-map switching-patterns
  { pattern-hash: (buff 32) }
  {
    from-context: (string-ascii 64),
    to-context: (string-ascii 64),
    occurrence-count: uint,
    average-cost: uint,
    is-high-cost: bool
  }
)

;; Track focus restoration claims
(define-map restoration-claims
  { user: principal, claim-id: uint }
  {
    points-claimed: uint,
    timestamp: uint,
    efficiency-bonus: uint
  }
)

;; Public Functions

;; Record a context switch event
(define-public (record-context-switch 
  (from-context (string-ascii 64))
  (to-context (string-ascii 64))
  (cognitive-cost uint))
  (let
    (
      (switch-id (var-get total-switches-tracked))
      (user-data (default-to 
        { total-switches: u0, total-cost: u0, restoration-points: u0, 
          average-cost: u0, active-session: false, last-switch-time: u0, efficiency-rating: u100 }
        (map-get? user-stats { user: tx-sender })))
      (new-total-switches (+ (get total-switches user-data) u1))
      (new-total-cost (+ (get total-cost user-data) cognitive-cost))
      (new-average (/ new-total-cost new-total-switches))
      (restoration-earned (calculate-restoration-points cognitive-cost))
      (new-restoration (+ (get restoration-points user-data) restoration-earned))
    )
    ;; Validate cognitive cost
    (asserts! (<= cognitive-cost MAX-COGNITIVE-COST) ERR-INVALID-COST)
    (asserts! (> cognitive-cost u0) ERR-INVALID-COST)
    
    ;; Record the switch
    (map-set context-switches
      { switch-id: switch-id }
      {
        user: tx-sender,
        from-context: from-context,
        to-context: to-context,
        cognitive-cost: cognitive-cost,
        timestamp: stacks-block-height,
        restoration-earned: restoration-earned
      }
    )
    
    ;; Update user stats
    (map-set user-stats
      { user: tx-sender }
      {
        total-switches: new-total-switches,
        total-cost: new-total-cost,
        restoration-points: new-restoration,
        average-cost: new-average,
        active-session: true,
        last-switch-time: stacks-block-height,
        efficiency-rating: (calculate-efficiency-rating new-average)
      }
    )
    
    ;; Update global stats
    (var-set total-switches-tracked (+ switch-id u1))
    (var-set total-cognitive-cost (+ (var-get total-cognitive-cost) cognitive-cost))
    
    ;; Record pattern
    (record-switching-pattern from-context to-context cognitive-cost)
    
    (ok switch-id)
  )
)

;; Claim focus restoration points
(define-public (claim-restoration-points (points-to-claim uint))
  (let
    (
      (user-data (unwrap! (map-get? user-stats { user: tx-sender }) ERR-NOT-FOUND))
      (available-points (get restoration-points user-data))
      (claim-count (get-claim-count tx-sender))
      (efficiency-bonus (/ (get efficiency-rating user-data) u10))
    )
    ;; Validate claim
    (asserts! (>= available-points points-to-claim) ERR-NOT-AUTHORIZED)
    (asserts! (>= points-to-claim MIN-RESTORATION-POINTS) ERR-INVALID-COST)
    
    ;; Record claim
    (map-set restoration-claims
      { user: tx-sender, claim-id: claim-count }
      {
        points-claimed: points-to-claim,
        timestamp: stacks-block-height,
        efficiency-bonus: efficiency-bonus
      }
    )
    
    ;; Deduct points
    (map-set user-stats
      { user: tx-sender }
      (merge user-data { restoration-points: (- available-points points-to-claim) })
    )
    
    (ok true)
  )
)

;; End active session and calculate final metrics
(define-public (end-focus-session)
  (let
    (
      (user-data (unwrap! (map-get? user-stats { user: tx-sender }) ERR-NOT-FOUND))
    )
    ;; Verify active session
    (asserts! (get active-session user-data) ERR-SESSION-ACTIVE)
    
    ;; Update session status
    (map-set user-stats
      { user: tx-sender }
      (merge user-data { active-session: false })
    )
    
    (ok (get efficiency-rating user-data))
  )
)

;; Private Functions

;; Calculate restoration points based on cognitive cost
(define-private (calculate-restoration-points (cost uint))
  (if (<= cost u20)
    u5
    (if (<= cost u50)
      u10
      (if (<= cost u80)
        u15
        u25
      )
    )
  )
)

;; Calculate efficiency rating (inverse of average cost)
(define-private (calculate-efficiency-rating (average-cost uint))
  (if (is-eq average-cost u0)
    u100
    (let ((rating (- u100 (/ average-cost u2))))
      (if (> rating u100) u100 rating)
    )
  )
)

;; Record switching pattern for analysis
(define-private (record-switching-pattern 
  (from-ctx (string-ascii 64))
  (to-ctx (string-ascii 64))
  (cost uint))
  (let
    (
      (pattern-hash (hash-pattern from-ctx to-ctx))
      (existing-pattern (map-get? switching-patterns { pattern-hash: pattern-hash }))
    )
    (match existing-pattern
      pattern-data
        (let
          (
            (new-count (+ (get occurrence-count pattern-data) u1))
            (new-total-cost (+ (* (get average-cost pattern-data) (get occurrence-count pattern-data)) cost))
            (new-avg (/ new-total-cost new-count))
          )
          (map-set switching-patterns
            { pattern-hash: pattern-hash }
            {
              from-context: from-ctx,
              to-context: to-ctx,
              occurrence-count: new-count,
              average-cost: new-avg,
              is-high-cost: (>= new-avg u60)
            }
          )
          true)
      ;; Create new pattern
      (begin
        (map-set switching-patterns
          { pattern-hash: pattern-hash }
          {
            from-context: from-ctx,
            to-context: to-ctx,
            occurrence-count: u1,
            average-cost: cost,
            is-high-cost: (>= cost u60)
          }
        )
        true)
    )
  )
)

;; Generate pattern hash
(define-private (hash-pattern (from (string-ascii 64)) (to (string-ascii 64)))
  (keccak256 (unwrap-panic (to-consensus-buff? (concat (unwrap-panic (as-max-len? (concat from "->") u130)) to))))
)

;; Get claim count for user
(define-private (get-claim-count (user principal))
  (let
    ((check-claim (map-get? restoration-claims { user: user, claim-id: u0 })))
    (if (is-some check-claim)
      u1
      u0
    )
  )
)

;; Read-Only Functions

;; Get user statistics
(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-stats { user: user }))
)

;; Get specific context switch details
(define-read-only (get-switch-details (switch-id uint))
  (ok (map-get? context-switches { switch-id: switch-id }))
)

;; Get pattern analysis
(define-read-only (get-pattern-data (pattern-hash (buff 32)))
  (ok (map-get? switching-patterns { pattern-hash: pattern-hash }))
)

;; Get global statistics
(define-read-only (get-global-stats)
  (ok {
    total-switches: (var-get total-switches-tracked),
    total-cognitive-cost: (var-get total-cognitive-cost),
    active-users: (var-get active-users),
    global-efficiency: (var-get global-efficiency-score)
  })
)

;; Check if user has active session
(define-read-only (has-active-session (user principal))
  (match (map-get? user-stats { user: user })
    user-data (ok (get active-session user-data))
    (ok false)
  )
)

;; Get restoration claim history
(define-read-only (get-claim-details (user principal) (claim-id uint))
  (ok (map-get? restoration-claims { user: user, claim-id: claim-id }))
)



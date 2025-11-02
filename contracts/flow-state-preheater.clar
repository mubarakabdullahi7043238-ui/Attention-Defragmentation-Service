;; title: flow-state-preheater
;; version: 1.0.0
;; summary: Warms up tasks to reduce cognitive cold starts
;; description: Pre-loads task contexts, schedules focus sessions with optimal timing,
;;              tracks flow state achievements, and builds momentum through
;;              progressive task warming techniques.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-TASK (err u201))
(define-constant ERR-TASK-EXISTS (err u202))
(define-constant ERR-TASK-NOT-FOUND (err u203))
(define-constant ERR-INVALID-DURATION (err u204))
(define-constant ERR-SESSION-NOT-ACTIVE (err u205))
(define-constant ERR-WARMUP-INCOMPLETE (err u206))

;; Flow state intensity levels (1-10 scale)
(define-constant MIN-FLOW-INTENSITY u1)
(define-constant MAX-FLOW-INTENSITY u10)

;; Warmup phases
(define-constant PHASE-COLD u0)
(define-constant PHASE-WARMING u1)
(define-constant PHASE-HOT u2)
(define-constant PHASE-FLOW u3)

;; Minimum blocks for warmup completion
(define-constant MIN-WARMUP-BLOCKS u10)

;; Data Variables
(define-data-var total-tasks-created uint u0)
(define-data-var total-flow-sessions uint u0)
(define-data-var total-flow-minutes uint u0)
(define-data-var active-flow-sessions uint u0)

;; Data Maps

;; Track task definitions and their warmup states
(define-map tasks
  { task-id: uint }
  {
    creator: principal,
    title: (string-ascii 128),
    context-data: (string-ascii 256),
    complexity-level: uint,
    warmup-phase: uint,
    warmup-start-block: uint,
    is-active: bool,
    total-flow-time: uint,
    best-flow-intensity: uint
  }
)

;; Track user task associations
(define-map user-tasks
  { user: principal, task-id: uint }
  {
    owned: bool,
    last-accessed: uint,
    total-sessions: uint,
    average-flow-intensity: uint
  }
)

;; Track active flow sessions
(define-map flow-sessions
  { session-id: uint }
  {
    user: principal,
    task-id: uint,
    start-block: uint,
    end-block: uint,
    flow-intensity: uint,
    momentum-score: uint,
    warmup-quality: uint,
    is-complete: bool
  }
)

;; Track user flow statistics
(define-map user-flow-stats
  { user: principal }
  {
    total-sessions: uint,
    total-flow-time: uint,
    average-intensity: uint,
    peak-intensity: uint,
    current-streak: uint,
    best-streak: uint,
    momentum-points: uint
  }
)

;; Track task dependencies for context loading
(define-map task-dependencies
  { task-id: uint, dependency-index: uint }
  {
    dependency-name: (string-ascii 64),
    is-loaded: bool,
    load-priority: uint
  }
)

;; Public Functions

;; Create a new task with context
(define-public (create-task 
  (title (string-ascii 128))
  (context-data (string-ascii 256))
  (complexity-level uint))
  (let
    (
      (task-id (var-get total-tasks-created))
    )
    ;; Validate complexity
    (asserts! (and (>= complexity-level u1) (<= complexity-level u10)) ERR-INVALID-TASK)
    
    ;; Create task
    (map-set tasks
      { task-id: task-id }
      {
        creator: tx-sender,
        title: title,
        context-data: context-data,
        complexity-level: complexity-level,
        warmup-phase: PHASE-COLD,
        warmup-start-block: u0,
        is-active: true,
        total-flow-time: u0,
        best-flow-intensity: u0
      }
    )
    
    ;; Associate task with user
    (map-set user-tasks
      { user: tx-sender, task-id: task-id }
      {
        owned: true,
        last-accessed: stacks-block-height,
        total-sessions: u0,
        average-flow-intensity: u0
      }
    )
    
    ;; Update global counter
    (var-set total-tasks-created (+ task-id u1))
    
    (ok task-id)
  )
)

;; Start warming up a task
(define-public (start-warmup (task-id uint))
  (let
    (
      (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
      (user-task (unwrap! (map-get? user-tasks { user: tx-sender, task-id: task-id }) ERR-NOT-AUTHORIZED))
    )
    ;; Verify task is active
    (asserts! (get is-active task-data) ERR-INVALID-TASK)
    
    ;; Start warmup
    (map-set tasks
      { task-id: task-id }
      (merge task-data {
        warmup-phase: PHASE-WARMING,
        warmup-start-block: stacks-block-height
      })
    )
    
    (ok true)
  )
)

;; Begin a flow session (requires completed warmup)
(define-public (begin-flow-session (task-id uint))
  (let
    (
      (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
      (user-task (unwrap! (map-get? user-tasks { user: tx-sender, task-id: task-id }) ERR-NOT-AUTHORIZED))
      (session-id (var-get total-flow-sessions))
      (warmup-quality (calculate-warmup-quality task-data))
      (user-stats (default-to
        { total-sessions: u0, total-flow-time: u0, average-intensity: u0,
          peak-intensity: u0, current-streak: u0, best-streak: u0, momentum-points: u0 }
        (map-get? user-flow-stats { user: tx-sender })))
    )
    ;; Check warmup completion
    (asserts! (>= warmup-quality u50) ERR-WARMUP-INCOMPLETE)
    
    ;; Create flow session
    (map-set flow-sessions
      { session-id: session-id }
      {
        user: tx-sender,
        task-id: task-id,
        start-block: stacks-block-height,
        end-block: u0,
        flow-intensity: u0,
        momentum-score: (get momentum-points user-stats),
        warmup-quality: warmup-quality,
        is-complete: false
      }
    )
    
    ;; Update task phase
    (map-set tasks
      { task-id: task-id }
      (merge task-data { warmup-phase: PHASE-FLOW })
    )
    
    ;; Update counters
    (var-set total-flow-sessions (+ session-id u1))
    (var-set active-flow-sessions (+ (var-get active-flow-sessions) u1))
    
    (ok session-id)
  )
)

;; End flow session and record metrics
(define-public (end-flow-session (session-id uint) (flow-intensity uint))
  (let
    (
      (session-data (unwrap! (map-get? flow-sessions { session-id: session-id }) ERR-TASK-NOT-FOUND))
      (task-data (unwrap! (map-get? tasks { task-id: (get task-id session-data) }) ERR-TASK-NOT-FOUND))
      (user-stats (default-to
        { total-sessions: u0, total-flow-time: u0, average-intensity: u0,
          peak-intensity: u0, current-streak: u0, best-streak: u0, momentum-points: u0 }
        (map-get? user-flow-stats { user: tx-sender })))
      (duration (- stacks-block-height (get start-block session-data)))
      (momentum-gained (calculate-momentum-gain flow-intensity duration))
    )
    ;; Validate
    (asserts! (is-eq (get user session-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-complete session-data)) ERR-INVALID-TASK)
    (asserts! (and (>= flow-intensity MIN-FLOW-INTENSITY) (<= flow-intensity MAX-FLOW-INTENSITY)) ERR-INVALID-DURATION)
    
    ;; Update session
    (map-set flow-sessions
      { session-id: session-id }
      (merge session-data {
        end-block: stacks-block-height,
        flow-intensity: flow-intensity,
        is-complete: true
      })
    )
    
    ;; Update task stats
    (map-set tasks
      { task-id: (get task-id session-data) }
      (merge task-data {
        total-flow-time: (+ (get total-flow-time task-data) duration),
        best-flow-intensity: (if (> flow-intensity (get best-flow-intensity task-data))
          flow-intensity
          (get best-flow-intensity task-data)),
        warmup-phase: PHASE-HOT
      })
    )
    
    ;; Update user stats
    (let
      (
        (new-total-sessions (+ (get total-sessions user-stats) u1))
        (new-total-time (+ (get total-flow-time user-stats) duration))
        (new-avg-intensity (/ (+ (* (get average-intensity user-stats) (get total-sessions user-stats)) flow-intensity) new-total-sessions))
        (new-peak (if (> flow-intensity (get peak-intensity user-stats)) flow-intensity (get peak-intensity user-stats)))
        (new-streak (+ (get current-streak user-stats) u1))
        (new-best-streak (if (> new-streak (get best-streak user-stats)) new-streak (get best-streak user-stats)))
      )
      (map-set user-flow-stats
        { user: tx-sender }
        {
          total-sessions: new-total-sessions,
          total-flow-time: new-total-time,
          average-intensity: new-avg-intensity,
          peak-intensity: new-peak,
          current-streak: new-streak,
          best-streak: new-best-streak,
          momentum-points: (+ (get momentum-points user-stats) momentum-gained)
        }
      )
    )
    
    ;; Update global stats
    (var-set total-flow-minutes (+ (var-get total-flow-minutes) duration))
    (var-set active-flow-sessions (- (var-get active-flow-sessions) u1))
    
    (ok duration)
  )
)

;; Add a dependency for task context loading
(define-public (add-task-dependency 
  (task-id uint)
  (dependency-name (string-ascii 64))
  (load-priority uint))
  (let
    (
      (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
      (user-task (unwrap! (map-get? user-tasks { user: tx-sender, task-id: task-id }) ERR-NOT-AUTHORIZED))
      (dep-index (get-dependency-count task-id))
    )
    ;; Verify ownership
    (asserts! (get owned user-task) ERR-NOT-AUTHORIZED)
    
    ;; Add dependency
    (map-set task-dependencies
      { task-id: task-id, dependency-index: dep-index }
      {
        dependency-name: dependency-name,
        is-loaded: false,
        load-priority: load-priority
      }
    )
    
    (ok dep-index)
  )
)

;; Mark dependency as loaded
(define-public (mark-dependency-loaded (task-id uint) (dependency-index uint))
  (let
    (
      (dep-data (unwrap! (map-get? task-dependencies { task-id: task-id, dependency-index: dependency-index }) ERR-TASK-NOT-FOUND))
      (user-task (unwrap! (map-get? user-tasks { user: tx-sender, task-id: task-id }) ERR-NOT-AUTHORIZED))
    )
    ;; Verify ownership
    (asserts! (get owned user-task) ERR-NOT-AUTHORIZED)
    
    ;; Mark as loaded
    (map-set task-dependencies
      { task-id: task-id, dependency-index: dependency-index }
      (merge dep-data { is-loaded: true })
    )
    
    (ok true)
  )
)

;; Private Functions

;; Calculate warmup quality based on time and phase
(define-private (calculate-warmup-quality (task-data (tuple (creator principal) (title (string-ascii 128)) (context-data (string-ascii 256)) (complexity-level uint) (warmup-phase uint) (warmup-start-block uint) (is-active bool) (total-flow-time uint) (best-flow-intensity uint))))
  (let
    (
      (warmup-duration (- stacks-block-height (get warmup-start-block task-data)))
      (phase (get warmup-phase task-data))
      (complexity (get complexity-level task-data))
    )
    (if (is-eq phase PHASE-COLD)
      u0
      (if (< warmup-duration MIN-WARMUP-BLOCKS)
        (/ (* warmup-duration u100) MIN-WARMUP-BLOCKS)
        (if (< warmup-duration (* MIN-WARMUP-BLOCKS u2))
          u100
          (- u100 (/ (- warmup-duration (* MIN-WARMUP-BLOCKS u2)) u2))
        )
      )
    )
  )
)

;; Calculate momentum gain from session
(define-private (calculate-momentum-gain (intensity uint) (duration uint))
  (let
    (
      (base-momentum (* intensity duration))
      (bonus (if (>= intensity u8) u50 u0))
    )
    (/ (+ base-momentum bonus) u10)
  )
)

;; Get dependency count for a task
(define-private (get-dependency-count (task-id uint))
  (let
    ((check-dep (map-get? task-dependencies { task-id: task-id, dependency-index: u0 })))
    (if (is-some check-dep)
      u1
      u0
    )
  )
)

;; Read-Only Functions

;; Get task details
(define-read-only (get-task-info (task-id uint))
  (ok (map-get? tasks { task-id: task-id }))
)

;; Get user's task association
(define-read-only (get-user-task (user principal) (task-id uint))
  (ok (map-get? user-tasks { user: user, task-id: task-id }))
)

;; Get flow session details
(define-read-only (get-session-info (session-id uint))
  (ok (map-get? flow-sessions { session-id: session-id }))
)

;; Get user flow statistics
(define-read-only (get-user-flow-stats (user principal))
  (ok (map-get? user-flow-stats { user: user }))
)

;; Get task dependency
(define-read-only (get-task-dependency (task-id uint) (dependency-index uint))
  (ok (map-get? task-dependencies { task-id: task-id, dependency-index: dependency-index }))
)

;; Get global statistics
(define-read-only (get-global-flow-stats)
  (ok {
    total-tasks: (var-get total-tasks-created),
    total-sessions: (var-get total-flow-sessions),
    total-flow-minutes: (var-get total-flow-minutes),
    active-sessions: (var-get active-flow-sessions)
  })
)

;; Check if task is ready for flow
(define-read-only (is-ready-for-flow (task-id uint))
  (match (map-get? tasks { task-id: task-id })
    task-data
      (let
        ((warmup-quality (calculate-warmup-quality task-data)))
        (ok (>= warmup-quality u50))
      )
    (ok false)
  )
)



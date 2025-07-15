;; Scheduling Coordination Contract
;; Manages volunteer availability and project scheduling

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-SCHEDULE-NOT-FOUND (err u301))
(define-constant ERR-TIME-CONFLICT (err u302))
(define-constant ERR-INVALID-TIME (err u303))
(define-constant ERR-INVALID-INPUT (err u304))
(define-constant ERR-SCHEDULE-FULL (err u305))

;; Data Variables
(define-data-var next-schedule-id uint u1)
(define-data-var next-booking-id uint u1)

;; Data Maps
(define-map volunteer-availability
  { volunteer: principal, date: uint }
  {
    start-time: uint,
    end-time: uint,
    status: (string-ascii 20),
    max-commitments: uint,
    current-commitments: uint,
    created-at: uint
  }
)

(define-map project-schedules
  { schedule-id: uint }
  {
    project-creator: principal,
    opportunity-id: uint,
    date: uint,
    start-time: uint,
    end-time: uint,
    required-volunteers: uint,
    confirmed-volunteers: uint,
    status: (string-ascii 20),
    location: (string-ascii 100),
    created-at: uint
  }
)

(define-map schedule-bookings
  { booking-id: uint }
  {
    schedule-id: uint,
    volunteer: principal,
    start-time: uint,
    end-time: uint,
    status: (string-ascii 20),
    confirmed-at: (optional uint),
    completed-at: (optional uint)
  }
)

(define-map volunteer-bookings
  { volunteer: principal }
  { booking-ids: (list 100 uint) }
)

(define-map schedule-volunteers
  { schedule-id: uint }
  { volunteer-bookings: (list 50 uint) }
)

(define-map time-conflicts
  { volunteer: principal, date: uint }
  { conflicting-bookings: (list 20 uint) }
)

;; Read-only functions
(define-read-only (get-volunteer-availability (volunteer principal) (date uint))
  (map-get? volunteer-availability { volunteer: volunteer, date: date })
)

(define-read-only (get-project-schedule (schedule-id uint))
  (map-get? project-schedules { schedule-id: schedule-id })
)

(define-read-only (get-schedule-booking (booking-id uint))
  (map-get? schedule-bookings { booking-id: booking-id })
)

(define-read-only (get-volunteer-bookings (volunteer principal))
  (default-to { booking-ids: (list) }
    (map-get? volunteer-bookings { volunteer: volunteer }))
)

(define-read-only (get-schedule-volunteers (schedule-id uint))
  (default-to { volunteer-bookings: (list) }
    (map-get? schedule-volunteers { schedule-id: schedule-id }))
)

(define-read-only (check-time-conflict (volunteer principal) (date uint) (start-time uint) (end-time uint))
  (match (get-volunteer-availability volunteer date)
    availability (and
      (>= start-time (get start-time availability))
      (<= end-time (get end-time availability))
      (< (get current-commitments availability) (get max-commitments availability)))
    false)
)

(define-read-only (get-available-volunteers (date uint) (start-time uint) (end-time uint))
  ;; This would need to be implemented with a more complex query system
  ;; For now, returns empty list as placeholder
  (list)
)

;; Public functions
(define-public (set-availability
  (date uint)
  (start-time uint)
  (end-time uint)
  (max-commitments uint))
  (begin
    (asserts! (> end-time start-time) ERR-INVALID-TIME)
    (asserts! (> max-commitments u0) ERR-INVALID-INPUT)
    (asserts! (>= date block-height) ERR-INVALID-TIME)

    (map-set volunteer-availability
      { volunteer: tx-sender, date: date }
      {
        start-time: start-time,
        end-time: end-time,
        status: "available",
        max-commitments: max-commitments,
        current-commitments: u0,
        created-at: block-height
      }
    )

    (ok true)
  )
)

(define-public (create-project-schedule
  (opportunity-id uint)
  (date uint)
  (start-time uint)
  (end-time uint)
  (required-volunteers uint)
  (location (string-ascii 100)))
  (let ((schedule-id (var-get next-schedule-id)))
    (asserts! (> end-time start-time) ERR-INVALID-TIME)
    (asserts! (> required-volunteers u0) ERR-INVALID-INPUT)
    (asserts! (>= date block-height) ERR-INVALID-TIME)

    (map-set project-schedules
      { schedule-id: schedule-id }
      {
        project-creator: tx-sender,
        opportunity-id: opportunity-id,
        date: date,
        start-time: start-time,
        end-time: end-time,
        required-volunteers: required-volunteers,
        confirmed-volunteers: u0,
        status: "open",
        location: location,
        created-at: block-height
      }
    )

    (var-set next-schedule-id (+ schedule-id u1))
    (ok schedule-id)
  )
)

(define-public (book-schedule
  (schedule-id uint)
  (start-time uint)
  (end-time uint))
  (let ((schedule (unwrap! (get-project-schedule schedule-id) ERR-SCHEDULE-NOT-FOUND))
        (booking-id (var-get next-booking-id)))

    (asserts! (is-eq (get status schedule) "open") ERR-INVALID-INPUT)
    (asserts! (< (get confirmed-volunteers schedule) (get required-volunteers schedule)) ERR-SCHEDULE-FULL)
    (asserts! (>= start-time (get start-time schedule)) ERR-INVALID-TIME)
    (asserts! (<= end-time (get end-time schedule)) ERR-INVALID-TIME)
    (asserts! (check-time-conflict tx-sender (get date schedule) start-time end-time) ERR-TIME-CONFLICT)

    ;; Create booking
    (map-set schedule-bookings
      { booking-id: booking-id }
      {
        schedule-id: schedule-id,
        volunteer: tx-sender,
        start-time: start-time,
        end-time: end-time,
        status: "pending",
        confirmed-at: none,
        completed-at: none
      }
    )

    ;; Add to volunteer bookings
    (let ((current-bookings (get booking-ids (get-volunteer-bookings tx-sender))))
      (map-set volunteer-bookings
        { volunteer: tx-sender }
        { booking-ids: (unwrap! (as-max-len? (append current-bookings booking-id) u100) ERR-INVALID-INPUT) }
      )
    )

    ;; Add to schedule volunteers
    (let ((current-schedule-bookings (get volunteer-bookings (get-schedule-volunteers schedule-id))))
      (map-set schedule-volunteers
        { schedule-id: schedule-id }
        { volunteer-bookings: (unwrap! (as-max-len? (append current-schedule-bookings booking-id) u50) ERR-INVALID-INPUT) }
      )
    )

    (var-set next-booking-id (+ booking-id u1))
    (ok booking-id)
  )
)

(define-public (confirm-booking (booking-id uint))
  (let ((booking (unwrap! (get-schedule-booking booking-id) ERR-SCHEDULE-NOT-FOUND))
        (schedule (unwrap! (get-project-schedule (get schedule-id booking)) ERR-SCHEDULE-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get project-creator schedule)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status booking) "pending") ERR-INVALID-INPUT)

    ;; Update booking status
    (map-set schedule-bookings
      { booking-id: booking-id }
      (merge booking {
        status: "confirmed",
        confirmed-at: (some block-height)
      })
    )

    ;; Update schedule confirmed volunteers count
    (map-set project-schedules
      { schedule-id: (get schedule-id booking) }
      (merge schedule {
        confirmed-volunteers: (+ (get confirmed-volunteers schedule) u1)
      })
    )

    ;; Update volunteer availability
    (let ((availability (unwrap! (get-volunteer-availability (get volunteer booking) (get date schedule)) ERR-SCHEDULE-NOT-FOUND)))
      (map-set volunteer-availability
        { volunteer: (get volunteer booking), date: (get date schedule) }
        (merge availability {
          current-commitments: (+ (get current-commitments availability) u1)
        })
      )
    )

    (ok true)
  )
)

(define-public (complete-booking (booking-id uint))
  (let ((booking (unwrap! (get-schedule-booking booking-id) ERR-SCHEDULE-NOT-FOUND))
        (schedule (unwrap! (get-project-schedule (get schedule-id booking)) ERR-SCHEDULE-NOT-FOUND)))

    (asserts! (or (is-eq tx-sender (get project-creator schedule)) (is-eq tx-sender (get volunteer booking))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status booking) "confirmed") ERR-INVALID-INPUT)

    (map-set schedule-bookings
      { booking-id: booking-id }
      (merge booking {
        status: "completed",
        completed-at: (some block-height)
      })
    )

    (ok true)
  )
)

(define-public (cancel-booking (booking-id uint))
  (let ((booking (unwrap! (get-schedule-booking booking-id) ERR-SCHEDULE-NOT-FOUND))
        (schedule (unwrap! (get-project-schedule (get schedule-id booking)) ERR-SCHEDULE-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get volunteer booking)) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq (get status booking) "pending") (is-eq (get status booking) "confirmed")) ERR-INVALID-INPUT)

    ;; Update booking status
    (map-set schedule-bookings
      { booking-id: booking-id }
      (merge booking { status: "cancelled" })
    )

    ;; If booking was confirmed, update counters
    (if (is-eq (get status booking) "confirmed")
      (begin
        (map-set project-schedules
          { schedule-id: (get schedule-id booking) }
          (merge schedule {
            confirmed-volunteers: (- (get confirmed-volunteers schedule) u1)
          })
        )

        (let ((availability (unwrap! (get-volunteer-availability (get volunteer booking) (get date schedule)) ERR-SCHEDULE-NOT-FOUND)))
          (map-set volunteer-availability
            { volunteer: (get volunteer booking), date: (get date schedule) }
            (merge availability {
              current-commitments: (- (get current-commitments availability) u1)
            })
          )
        )
      )
      true
    )

    (ok true)
  )
)

(define-public (update-schedule-status (schedule-id uint) (new-status (string-ascii 20)))
  (let ((schedule (unwrap! (get-project-schedule schedule-id) ERR-SCHEDULE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get project-creator schedule)) ERR-NOT-AUTHORIZED)

    (map-set project-schedules
      { schedule-id: schedule-id }
      (merge schedule { status: new-status })
    )

    (ok true)
  )
)

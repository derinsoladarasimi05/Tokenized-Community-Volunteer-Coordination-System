;; Skill Utilization Contract
;; Manages volunteer skills and matches them with organizational needs

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-SKILL-NOT-FOUND (err u201))
(define-constant ERR-VOLUNTEER-NOT-FOUND (err u202))
(define-constant ERR-INVALID-RATING (err u203))
(define-constant ERR-INVALID-INPUT (err u204))
(define-constant ERR-SKILL-ALREADY-EXISTS (err u205))

;; Data Variables
(define-data-var next-skill-id uint u1)
(define-data-var next-endorsement-id uint u1)

;; Data Maps
(define-map skills
  { skill-id: uint }
  {
    name: (string-ascii 50),
    category: (string-ascii 30),
    description: (string-ascii 200),
    created-by: principal,
    created-at: uint,
    verified: bool
  }
)

(define-map volunteer-skills
  { volunteer: principal, skill-id: uint }
  {
    proficiency-level: uint,
    years-experience: uint,
    last-used: uint,
    self-rating: uint,
    verified-rating: uint,
    endorsement-count: uint,
    added-at: uint
  }
)

(define-map skill-endorsements
  { endorsement-id: uint }
  {
    skill-id: uint,
    volunteer: principal,
    endorser: principal,
    rating: uint,
    comment: (string-ascii 200),
    created-at: uint
  }
)

(define-map volunteer-skill-list
  { volunteer: principal }
  { skill-ids: (list 50 uint) }
)

(define-map skill-volunteers
  { skill-id: uint }
  { volunteers: (list 1000 principal) }
)

(define-map skill-demand
  { skill-id: uint }
  {
    current-demand: uint,
    total-requests: uint,
    fulfilled-requests: uint,
    average-rating: uint,
    last-updated: uint
  }
)

;; Read-only functions
(define-read-only (get-skill (skill-id uint))
  (map-get? skills { skill-id: skill-id })
)

(define-read-only (get-volunteer-skill (volunteer principal) (skill-id uint))
  (map-get? volunteer-skills { volunteer: volunteer, skill-id: skill-id })
)

(define-read-only (get-volunteer-skills (volunteer principal))
  (default-to { skill-ids: (list) }
    (map-get? volunteer-skill-list { volunteer: volunteer }))
)

(define-read-only (get-skill-volunteers (skill-id uint))
  (default-to { volunteers: (list) }
    (map-get? skill-volunteers { skill-id: skill-id }))
)

(define-read-only (get-skill-demand (skill-id uint))
  (map-get? skill-demand { skill-id: skill-id })
)

(define-read-only (get-endorsement (endorsement-id uint))
  (map-get? skill-endorsements { endorsement-id: endorsement-id })
)

(define-read-only (calculate-skill-match-score (volunteer principal) (required-skills (list 10 uint)))
  (let ((volunteer-skills-data (get-volunteer-skills volunteer)))
    (fold calculate-individual-skill-score required-skills u0)
  )
)

;; Private functions
(define-private (calculate-individual-skill-score (skill-id uint) (current-score uint))
  (match (get-volunteer-skill tx-sender skill-id)
    skill-data (+ current-score (* (get verified-rating skill-data) u10))
    current-score)
)

;; Public functions
(define-public (create-skill
  (name (string-ascii 50))
  (category (string-ascii 30))
  (description (string-ascii 200)))
  (let ((skill-id (var-get next-skill-id)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len category) u0) ERR-INVALID-INPUT)

    (map-set skills
      { skill-id: skill-id }
      {
        name: name,
        category: category,
        description: description,
        created-by: tx-sender,
        created-at: block-height,
        verified: false
      }
    )

    (var-set next-skill-id (+ skill-id u1))
    (ok skill-id)
  )
)

(define-public (add-volunteer-skill
  (skill-id uint)
  (proficiency-level uint)
  (years-experience uint)
  (self-rating uint))
  (let ((skill (unwrap! (get-skill skill-id) ERR-SKILL-NOT-FOUND)))
    (asserts! (<= proficiency-level u5) ERR-INVALID-RATING)
    (asserts! (<= self-rating u5) ERR-INVALID-RATING)
    (asserts! (> self-rating u0) ERR-INVALID-RATING)
    (asserts! (is-none (get-volunteer-skill tx-sender skill-id)) ERR-SKILL-ALREADY-EXISTS)

    (map-set volunteer-skills
      { volunteer: tx-sender, skill-id: skill-id }
      {
        proficiency-level: proficiency-level,
        years-experience: years-experience,
        last-used: block-height,
        self-rating: self-rating,
        verified-rating: self-rating,
        endorsement-count: u0,
        added-at: block-height
      }
    )

    ;; Add to volunteer skill list
    (let ((current-skills (get skill-ids (get-volunteer-skills tx-sender))))
      (map-set volunteer-skill-list
        { volunteer: tx-sender }
        { skill-ids: (unwrap! (as-max-len? (append current-skills skill-id) u50) ERR-INVALID-INPUT) }
      )
    )

    ;; Add to skill volunteers list
    (let ((current-volunteers (get volunteers (get-skill-volunteers skill-id))))
      (map-set skill-volunteers
        { skill-id: skill-id }
        { volunteers: (unwrap! (as-max-len? (append current-volunteers tx-sender) u1000) ERR-INVALID-INPUT) }
      )
    )

    (ok true)
  )
)

(define-public (endorse-skill
  (volunteer principal)
  (skill-id uint)
  (rating uint)
  (comment (string-ascii 200)))
  (let ((endorsement-id (var-get next-endorsement-id))
        (volunteer-skill (unwrap! (get-volunteer-skill volunteer skill-id) ERR-SKILL-NOT-FOUND)))

    (asserts! (<= rating u5) ERR-INVALID-RATING)
    (asserts! (> rating u0) ERR-INVALID-RATING)
    (asserts! (not (is-eq tx-sender volunteer)) ERR-NOT-AUTHORIZED)

    (map-set skill-endorsements
      { endorsement-id: endorsement-id }
      {
        skill-id: skill-id,
        volunteer: volunteer,
        endorser: tx-sender,
        rating: rating,
        comment: comment,
        created-at: block-height
      }
    )

    ;; Update volunteer skill with new endorsement
    (let ((new-endorsement-count (+ (get endorsement-count volunteer-skill) u1))
          (current-verified-rating (get verified-rating volunteer-skill))
          (new-verified-rating (/ (+ (* current-verified-rating (get endorsement-count volunteer-skill)) rating) new-endorsement-count)))

      (map-set volunteer-skills
        { volunteer: volunteer, skill-id: skill-id }
        (merge volunteer-skill {
          verified-rating: new-verified-rating,
          endorsement-count: new-endorsement-count
        })
      )
    )

    (var-set next-endorsement-id (+ endorsement-id u1))
    (ok endorsement-id)
  )
)

(define-public (update-skill-usage (skill-id uint))
  (let ((volunteer-skill (unwrap! (get-volunteer-skill tx-sender skill-id) ERR-SKILL-NOT-FOUND)))
    (map-set volunteer-skills
      { volunteer: tx-sender, skill-id: skill-id }
      (merge volunteer-skill { last-used: block-height })
    )
    (ok true)
  )
)

(define-public (update-skill-demand (skill-id uint) (demand-change int))
  (let ((current-demand-data (default-to
    { current-demand: u0, total-requests: u0, fulfilled-requests: u0, average-rating: u0, last-updated: u0 }
    (get-skill-demand skill-id))))

    (let ((new-demand (if (> demand-change 0)
                        (+ (get current-demand current-demand-data) (to-uint demand-change))
                        (if (>= (get current-demand current-demand-data) (to-uint (- 0 demand-change)))
                          (- (get current-demand current-demand-data) (to-uint (- 0 demand-change)))
                          u0))))

      (map-set skill-demand
        { skill-id: skill-id }
        (merge current-demand-data {
          current-demand: new-demand,
          total-requests: (+ (get total-requests current-demand-data) u1),
          last-updated: block-height
        })
      )
    )

    (ok true)
  )
)

(define-public (verify-skill (skill-id uint))
  (let ((skill (unwrap! (get-skill skill-id) ERR-SKILL-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set skills
      { skill-id: skill-id }
      (merge skill { verified: true })
    )

    (ok true)
  )
)

(define-public (remove-volunteer-skill (skill-id uint))
  (let ((volunteer-skill (unwrap! (get-volunteer-skill tx-sender skill-id) ERR-SKILL-NOT-FOUND)))
    (map-delete volunteer-skills { volunteer: tx-sender, skill-id: skill-id })

    ;; Remove from volunteer skill list
    (let ((current-skills (get skill-ids (get-volunteer-skills tx-sender))))
      (map-set volunteer-skill-list
        { volunteer: tx-sender }
        { skill-ids: (filter remove-skill-from-list current-skills) }
      )
    )

    (ok true)
  )
)

;; Helper function for filtering
(define-private (remove-skill-from-list (skill-id-to-check uint))
  (not (is-eq skill-id-to-check skill-id-to-check))
)

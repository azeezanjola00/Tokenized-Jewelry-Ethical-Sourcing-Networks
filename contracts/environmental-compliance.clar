;; Environmental Compliance Contract
;; Ensures environmental compliance standards

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_SITE_NOT_FOUND (err u401))
(define-constant ERR_INVALID_METRIC (err u402))

;; Compliance ratings
(define-constant RATING_POOR u1)
(define-constant RATING_FAIR u2)
(define-constant RATING_GOOD u3)
(define-constant RATING_EXCELLENT u4)

;; Data structures
(define-map environmental-sites
  { site-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    operator: principal,
    water-usage-score: uint,
    waste-management-score: uint,
    carbon-footprint-score: uint,
    biodiversity-impact-score: uint,
    overall-rating: uint,
    certification-date: uint,
    next-audit-date: uint,
    auditor: principal
  }
)

(define-map site-counter { id: uint } { count: uint })

;; Initialize counter
(map-set site-counter { id: u0 } { count: u0 })

;; Read-only functions
(define-read-only (get-site (site-id uint))
  (map-get? environmental-sites { site-id: site-id })
)

(define-read-only (get-site-count)
  (default-to u0 (get count (map-get? site-counter { id: u0 })))
)

(define-read-only (is-site-compliant (site-id uint))
  (match (get-site site-id)
    site (>= (get overall-rating site) RATING_GOOD)
    false
  )
)

(define-read-only (get-environmental-rating (site-id uint))
  (match (get-site site-id)
    site (get overall-rating site)
    u0
  )
)

;; Public functions
(define-public (register-site
  (name (string-ascii 100))
  (location (string-ascii 100))
  (operator principal)
)
  (let ((current-count (get-site-count))
        (new-id (+ current-count u1)))
    (map-set environmental-sites
      { site-id: new-id }
      {
        name: name,
        location: location,
        operator: operator,
        water-usage-score: u0,
        waste-management-score: u0,
        carbon-footprint-score: u0,
        biodiversity-impact-score: u0,
        overall-rating: u0,
        certification-date: block-height,
        next-audit-date: (+ block-height u52560), ;; ~1 year
        auditor: tx-sender
      }
    )
    (map-set site-counter { id: u0 } { count: new-id })
    (ok new-id)
  )
)

(define-public (conduct-environmental-audit
  (site-id uint)
  (water-usage-score uint)
  (waste-management-score uint)
  (carbon-footprint-score uint)
  (biodiversity-impact-score uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= water-usage-score u100) ERR_INVALID_METRIC)
    (asserts! (<= waste-management-score u100) ERR_INVALID_METRIC)
    (asserts! (<= carbon-footprint-score u100) ERR_INVALID_METRIC)
    (asserts! (<= biodiversity-impact-score u100) ERR_INVALID_METRIC)
    (match (get-site site-id)
      site (let ((avg-score (/ (+ water-usage-score waste-management-score carbon-footprint-score biodiversity-impact-score) u4))
                 (rating (if (>= avg-score u85)
                           RATING_EXCELLENT
                           (if (>= avg-score u70)
                             RATING_GOOD
                             (if (>= avg-score u50)
                               RATING_FAIR
                               RATING_POOR)))))
        (map-set environmental-sites
          { site-id: site-id }
          (merge site {
            water-usage-score: water-usage-score,
            waste-management-score: waste-management-score,
            carbon-footprint-score: carbon-footprint-score,
            biodiversity-impact-score: biodiversity-impact-score,
            overall-rating: rating,
            certification-date: block-height,
            next-audit-date: (+ block-height u52560),
            auditor: tx-sender
          })
        )
        (ok rating)
      )
      ERR_SITE_NOT_FOUND
    )
  )
)

(define-public (schedule-next-audit (site-id uint) (audit-date uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (get-site site-id)
      site (begin
        (map-set environmental-sites
          { site-id: site-id }
          (merge site { next-audit-date: audit-date })
        )
        (ok true)
      )
      ERR_SITE_NOT_FOUND
    )
  )
)

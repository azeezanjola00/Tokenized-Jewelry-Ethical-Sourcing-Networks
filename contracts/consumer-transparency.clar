;; Consumer Transparency Contract
;; Provides consumer transparency for jewelry products

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_PRODUCT_NOT_FOUND (err u501))
(define-constant ERR_INVALID_DATA (err u502))

;; Product status
(define-constant STATUS_CREATED u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SOLD u2)

;; Data structures
(define-map jewelry-products
  { product-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    supplier-id: uint,
    mine-id: uint,
    facility-id: uint,
    site-id: uint,
    materials: (list 5 (string-ascii 50)),
    creation-date: uint,
    verification-date: uint,
    status: uint,
    price: uint,
    owner: principal,
    transparency-score: uint
  }
)

(define-map product-counter { id: uint } { count: uint })

;; Initialize counter
(map-set product-counter { id: u0 } { count: u0 })

;; Read-only functions
(define-read-only (get-product (product-id uint))
  (map-get? jewelry-products { product-id: product-id })
)

(define-read-only (get-product-count)
  (default-to u0 (get count (map-get? product-counter { id: u0 })))
)

(define-read-only (get-transparency-score (product-id uint))
  (match (get-product product-id)
    product (get transparency-score product)
    u0
  )
)

(define-read-only (is-product-verified (product-id uint))
  (match (get-product product-id)
    product (>= (get status product) STATUS_VERIFIED)
    false
  )
)

;; Public functions
(define-public (create-product
  (name (string-ascii 100))
  (description (string-ascii 200))
  (supplier-id uint)
  (mine-id uint)
  (facility-id uint)
  (site-id uint)
  (materials (list 5 (string-ascii 50)))
  (price uint)
)
  (let ((current-count (get-product-count))
        (new-id (+ current-count u1)))
    (map-set jewelry-products
      { product-id: new-id }
      {
        name: name,
        description: description,
        supplier-id: supplier-id,
        mine-id: mine-id,
        facility-id: facility-id,
        site-id: site-id,
        materials: materials,
        creation-date: block-height,
        verification-date: u0,
        status: STATUS_CREATED,
        price: price,
        owner: tx-sender,
        transparency-score: u0
      }
    )
    (map-set product-counter { id: u0 } { count: new-id })
    (ok new-id)
  )
)

(define-public (verify-product (product-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (get-product product-id)
      product (begin
        ;; Calculate transparency score based on linked entities
        (let ((transparency-score (calculate-transparency-score
                                   (get supplier-id product)
                                   (get mine-id product)
                                   (get facility-id product)
                                   (get site-id product))))
          (map-set jewelry-products
            { product-id: product-id }
            (merge product {
              status: STATUS_VERIFIED,
              verification-date: block-height,
              transparency-score: transparency-score
            })
          )
          (ok transparency-score)
        )
      )
      ERR_PRODUCT_NOT_FOUND
    )
  )
)

(define-public (transfer-product (product-id uint) (new-owner principal))
  (match (get-product product-id)
    product (begin
      (asserts! (is-eq tx-sender (get owner product)) ERR_UNAUTHORIZED)
      (map-set jewelry-products
        { product-id: product-id }
        (merge product {
          owner: new-owner,
          status: STATUS_SOLD
        })
      )
      (ok true)
    )
    ERR_PRODUCT_NOT_FOUND
  )
)

;; Private functions
(define-private (calculate-transparency-score
  (supplier-id uint)
  (mine-id uint)
  (facility-id uint)
  (site-id uint)
)
  ;; Simple scoring algorithm - in practice, this would call other contracts
  ;; For now, return a base score that can be enhanced
  (let ((base-score u60)
        (supplier-bonus (if (> supplier-id u0) u10 u0))
        (mine-bonus (if (> mine-id u0) u10 u0))
        (facility-bonus (if (> facility-id u0) u10 u0))
        (site-bonus (if (> site-id u0) u10 u0)))
    (+ base-score supplier-bonus mine-bonus facility-bonus site-bonus)
  )
)

(define-public (update-product-price (product-id uint) (new-price uint))
  (match (get-product product-id)
    product (begin
      (asserts! (is-eq tx-sender (get owner product)) ERR_UNAUTHORIZED)
      (map-set jewelry-products
        { product-id: product-id }
        (merge product { price: new-price })
      )
      (ok true)
    )
    ERR_PRODUCT_NOT_FOUND
  )
)

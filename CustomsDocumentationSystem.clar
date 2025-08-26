;; Customs Documentation System
;; Automated trade documentation and customs clearance with smart contract validation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-data (err u102))
(define-constant err-document-not-found (err u103))
(define-constant err-already-processed (err u104))

;; Document status constants
(define-constant status-pending u0)
(define-constant status-approved u1)
(define-constant status-rejected u2)

;; Data structures
(define-map trade-documents 
  uint 
  {
    importer: principal,
    exporter: principal,
    document-hash: (buff 32),
    goods-description: (string-ascii 100),
    value: uint,
    status: uint,
    processed-at: uint,
    customs-officer: (optional principal)
  })

(define-data-var next-document-id uint u1)
(define-data-var total-processed-documents uint u0)

;; Submit trade document for customs clearance
(define-public (submit-trade-document 
    (exporter principal)
    (document-hash (buff 32))
    (goods-description (string-ascii 100))
    (value uint))
  (begin
    ;; Validate input parameters
    (asserts! (> value u0) err-invalid-data)
    (asserts! (> (len goods-description) u0) err-invalid-data)
    
    ;; Get current document ID
    (let ((document-id (var-get next-document-id)))
      ;; Store the trade document
      (map-set trade-documents document-id
        {
          importer: tx-sender,
          exporter: exporter,
          document-hash: document-hash,
          goods-description: goods-description,
          value: value,
          status: status-pending,
          processed-at: u0,
          customs-officer: none
        })
      
      ;; Increment document ID for next submission
      (var-set next-document-id (+ document-id u1))
      
      ;; Return success with document ID
      (ok document-id))))

;; Process customs clearance (approve or reject)
(define-public (process-customs-clearance (document-id uint) (approve bool))
  (begin
    ;; Only contract owner (customs authority) can process documents
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Get the document
    (match (map-get? trade-documents document-id)
      document
      (begin
        ;; Check if document is still pending
        (asserts! (is-eq (get status document) status-pending) err-already-processed)
        
        ;; Update document status
        (map-set trade-documents document-id
          (merge document {
            status: (if approve status-approved status-rejected),
            processed-at: stacks-block-height,
            customs-officer: (some tx-sender)
          }))
        
        ;; Increment total processed documents counter
        (var-set total-processed-documents (+ (var-get total-processed-documents) u1))
        
        ;; Return success with approval status
        (ok approve))
      ;; Document not found
      err-document-not-found)))

;; Read-only function to get document details
(define-read-only (get-document (document-id uint))
  (map-get? trade-documents document-id))

;; Read-only function to get total processed documents
(define-read-only (get-total-processed-documents)
  (var-get total-processed-documents))

;; Read-only function to get next document ID
(define-read-only (get-next-document-id)
  (var-get next-document-id))
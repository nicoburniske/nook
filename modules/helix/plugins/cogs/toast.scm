;; Lightweight global toast notifications for Steel components.

(require "helix/components.scm")
(require "helix/misc.scm")

(provide toast-push!
         toast-push-ms!
         toast-success
         toast-error)

(define TOAST-COMPONENT-NAME "seni-toast-stack")
(define TOAST-MAX-COUNT 6)
(define TOAST-SUCCESS-MS 1800)
(define TOAST-ERROR-MS 2600)
(define TOAST-BOX-HEIGHT 3)

(struct ToastItem (id level message))

(define *toast-items* (box '()))
(define *toast-next-id* (box 1))
(define *toast-component-active?* (box #f))

(define (toast-clamp value lower upper)
  (max lower (min upper value)))

(define (toast-truncate text max-length)
  (if (<= max-length 0)
      ""
      (if (> (string-length text) max-length)
          (substring text 0 max-length)
          text)))

(define (toast-for-each-index func lst index)
  (if (null? lst)
      void
      (begin
        (func index (car lst))
        (toast-for-each-index func (cdr lst) (+ index 1)))))

(define (toast-next-id!)
  (define id (unbox *toast-next-id*))
  (set-box! *toast-next-id* (+ id 1))
  id)

(define (toast-message-from-args args fallback)
  (if (null? args)
      fallback
      (string-join args " ")))

(define (toast-item-text item)
  (string-append
   (if (equal? (ToastItem-level item) 'success)
       "OK "
       "ERR ")
   (ToastItem-message item)))

(define (toast-item-style item)
  (define base-style (theme-scope "ui.text"))
  (if (equal? (ToastItem-level item) 'success)
      (style-with-bold (style-fg base-style Color/LightGreen))
      (style-with-bold (style-fg base-style Color/LightRed))))

(define (toast-max-visible available-height)
  (min TOAST-MAX-COUNT
       (max 0 (quotient available-height TOAST-BOX-HEIGHT))))

(define (toast-max-line-length items)
  (if (null? items)
      0
      (max (string-length (toast-item-text (car items)))
           (toast-max-line-length (cdr items)))))

(define (toast-handle-event _state _event)
  event-result/ignore)

(define (toast-render _state rect frame)
  (define items (unbox *toast-items*))
  (when (not (null? items))
    (define width (area-width rect))
    (define height (area-height rect))
    (define available-height (max 0 (- height 1)))
    (define max-visible (toast-max-visible available-height))
    (define visible (slice items 0 max-visible))

    (when (not (null? visible))
      (define max-inner-width (max 12 (- width 6)))
      (define toast-inner-width
        (toast-clamp
         (toast-max-line-length visible)
         12
         max-inner-width))

      (define toast-box-width (+ toast-inner-width 2))
      (define x (+ (area-x rect) (max 0 (- width toast-box-width 1))))
      (define y0 (+ (area-y rect) 1))
      (define clear-style (style))

      (define blank-line (make-string toast-inner-width #\space))

      (toast-for-each-index
       (lambda (index item)
         (define y (+ y0 (* index TOAST-BOX-HEIGHT)))
         (define box-area (area x y toast-box-width TOAST-BOX-HEIGHT))
         (define text (toast-truncate (toast-item-text item) toast-inner-width))
         (define item-style (toast-item-style item))

         (buffer/clear-with frame box-area clear-style)
         (block/render frame box-area (make-block clear-style item-style "all" "rounded"))
         (frame-set-string! frame (+ x 1) (+ y 1) blank-line clear-style)
         (frame-set-string! frame (+ x 1) (+ y 1) text item-style))
       visible
       0))))

(define (toast-ensure-component!)
  (when (not (unbox *toast-component-active?*))
    (set-box! *toast-component-active?* #t)
    (push-component!
     (new-component! TOAST-COMPONENT-NAME
                     #f
                     toast-render
                     (hash "handle_event" toast-handle-event)))))

(define (toast-clear-component-if-empty!)
  (when (null? (unbox *toast-items*))
    (pop-last-component-by-name! TOAST-COMPONENT-NAME)
    (set-box! *toast-component-active?* #f)))

(define (toast-remove-id! id)
  (set-box! *toast-items*
            (filter (lambda (item) (not (= (ToastItem-id item) id)))
                    (unbox *toast-items*)))
  (toast-clear-component-if-empty!))

(define (toast-schedule-removal! id delay-ms)
  (enqueue-thread-local-callback-with-delay
   delay-ms
   (lambda ()
     (toast-remove-id! id))))

(define (toast-default-delay level)
  (if (equal? level 'error)
      TOAST-ERROR-MS
      TOAST-SUCCESS-MS))

(define (toast-push-ms! level message delay-ms)
  (define normalized-level
    (if (equal? level 'error)
        'error
        'success))

  (define normalized-message
    (if (and (string? message) (not (equal? message "")))
        message
        (if (equal? normalized-level 'error)
            "Error"
            "Success")))

  (define id (toast-next-id!))
  (define item (ToastItem id normalized-level normalized-message))
  (define normalized-delay
    (if (and (number? delay-ms) (> delay-ms 0))
        delay-ms
        (toast-default-delay normalized-level)))

  (toast-ensure-component!)

  (set-box! *toast-items* (slice (cons item (unbox *toast-items*)) 0 TOAST-MAX-COUNT))

  (toast-schedule-removal! id normalized-delay))

(define (toast-push! level message)
  (toast-push-ms! level message #f))

(define (toast-success . args)
  (toast-push! 'success (toast-message-from-args args "Success")))

(define (toast-error . args)
  (toast-push! 'error (toast-message-from-args args "Error")))

(require "helix/components.scm")
(require "helix/misc.scm")

(provide show-splash)

(define SPLASH-FRAME-MS 70)
(define SPLASH-SHIMMER-SLANT-ROW-STEP 2)

(define (splash-for-each-index func lst index)
  (if (null? lst)
      void
      (begin
        (func index (car lst))
        (splash-for-each-index func (cdr lst) (+ index 1)))))


                                        
(define splash-logo
  "
 .
 ###x.        .|
 d#####x,   ,v||
  '+#####v||||||       ██                ██ ██           
     ,v|||||+'.        ██                ██               
  ,v|||||^'>####       ███████◣ ◢██████◣ ██ ██ ██◣  ◢██ 
 |||||^'  .v####       ██    ██ ██    ██ ██ ██  ◥█◣◢█◤  
 ||||=..v#####P'       ██    ██ ███████◤ ██ ██   ████   
 ''v'>#####P'          ██    ██ ██       ██ ██  ◢█◤◥█◣  
 ,######/P||x.         ██    ██ ◥██████  ██ ██ ██◤  ◥██ 
 ####P' \"x|||||,
 |/'       'x|||    (A (post-modern (modal (text editor)))).
  '           '|")

(define splash-logo-lines (split-many splash-logo "\n"))
(define splash-logo-width (apply max (map string-length splash-logo-lines)))
(define splash-logo-depth (length splash-logo-lines))

(struct SplashState (tick running?))

(define (splash-truncate text max-length)
  (if (<= max-length 0)
      ""
      (if (> (string-length text) max-length)
          (substring text 0 max-length)
          text)))

(define (splash-shimmer-column tick)
  (- (modulo tick (+ splash-logo-width 14)) 7))

(define (splash-paint-shimmer-char! frame x row visible-line column style)
  (when (and (>= column 0)
             (< column (string-length visible-line))
             (not (equal? (substring visible-line column (+ column 1)) " ")))
    (frame-set-string! frame
                       (+ x column)
                       row
                       (substring visible-line column (+ column 1))
                       style)))

(define (splash-render-logo! frame rect x y shimmer-column base-style soft-shimmer-style strong-shimmer-style)
  (define right (+ (area-x rect) (area-width rect)))
  (splash-for-each-index
   (lambda (index line)
     (define row (+ y index))
     (when (< row (+ (area-y rect) (area-height rect)))
       (define available-width (max 0 (- right x)))
       (when (> available-width 0)
         (define visible-line (splash-truncate line available-width))
         (define shimmer-center (- shimmer-column (quotient index SPLASH-SHIMMER-SLANT-ROW-STEP)))
         (frame-set-string! frame x row visible-line base-style)
         (splash-paint-shimmer-char! frame x row visible-line (- shimmer-center 1) soft-shimmer-style)
         (splash-paint-shimmer-char! frame x row visible-line shimmer-center strong-shimmer-style)
         (splash-paint-shimmer-char! frame x row visible-line (+ shimmer-center 1) soft-shimmer-style))))
   splash-logo-lines
   0))

(define (splash-render state rect frame)
  (define left (area-x rect))
  (define top (area-y rect))
  (define width (area-width rect))
  (define height (area-height rect))
  (define tick (unbox (SplashState-tick state)))

  (define logo-style (theme-scope "string"))
  (define shimmer-soft-style (style-fg logo-style Color/LightBlue))
  (define shimmer-strong-style (style-with-bold (style-fg logo-style Color/LightCyan)))

  (define layout-height splash-logo-depth)
  (define x (+ left (max 0 (exact (round (/ (- width splash-logo-width) 2))))))
  (define y (+ top (max 0 (exact (round (/ (- height layout-height) 2.6))))))

  (splash-render-logo! frame
                       rect
                       x
                       y
                       (splash-shimmer-column tick)
                       logo-style
                       shimmer-soft-style
                       shimmer-strong-style))

(define (splash-schedule-next-frame! state)
  (when (unbox (SplashState-running? state))
    (enqueue-thread-local-callback-with-delay
     SPLASH-FRAME-MS
     (lambda ()
       (when (unbox (SplashState-running? state))
         (set-box! (SplashState-tick state) (+ (unbox (SplashState-tick state)) 1))
         (splash-schedule-next-frame! state))))))

(define (splash-event-handler state event)
  (if (key-event? event)
      (begin
        (set-box! (SplashState-running? state) #f)
        event-result/ignore-and-close)
      event-result/ignore))

(define (show-splash)
  (define state (SplashState (box 0) (box #t)))
  (splash-schedule-next-frame! state)
  (push-component! (new-component! "splash-screen"
                                   state
                                   splash-render
                                   (hash "handle_event" splash-event-handler))))


(define-alias Sys java.lang.System)
(define-alias Thread java.lang.Thread)
(define-alias Twitter twitter4j.Twitter)
(define-alias Status twitter4j.Status)
(define-alias TwStream twitter4j.TwitterStream)
(define-alias TwitterStreamFactory twitter4j.TwitterStreamFactory)
(define-alias Exception java.lang.Exception)
(define-alias LinkedList java.util.LinkedList)

(import (rnrs hashtables))

;for (int i = 0; i < 5; i ++) {
;try { Thread.sleep(1000); } catch (InterruptedException e) {}
;	KWorker.kmain();
;}
(define (show x)
	(invoke (static-field Sys 'out) 'println x) )

(define (set-keys t::twitter4j.auth.OAuthSupport)::void
    ;; load the OAuth keys
    ;; the (real) file containing these should not be made public
    (let* ((keys (with-input-from-file "scheme/oauth-keys.scm" read))
           (tok (twitter4j.auth.AccessToken (list-ref keys 0) (list-ref keys 1))) )
        (t:setOAuthConsumer (list-ref keys 2) (list-ref keys 3))
        (t:setOAuthAccessToken tok) ))

(define (get-twitter)::Twitter
    (let ((tw::Twitter ((twitter4j.TwitterFactory):getInstance)))
        (set-keys tw)
        tw) )

(define (get-stream)::TwStream
    (let ((s::TwStream ((TwitterStreamFactory):getInstance)))
        (set-keys s)
        s) )

(define (get-last-post-id tw::Twitter)::long
    ;; get the id of the last bot post
    ;; create one if necessary
    (let* ((stats::Object[] ((tw:getUserTimeline):toArray))
           (post::Status (if (= stats:length 0)
                             (tw:updateStatus "replbot wakeup")
                             (stats 0) )))
        (post:getId) ))


;; synchronized access methods
(define (access-db DB actn key val)
    (synchronized DB
        (case actn
            ((set) (hashtable-set! DB key val) val)
            ((get) (hashtable-ref DB key val)) )))
(define (access-queue q::LinkedList actn val)
    (synchronized q
        (case actn
            ((set) (q:add val) val)
            ((get) (if (q:isEmpty) #f (q:remove))) )))
            

;(show "attempting to update status...")
;(let ((status::Status (tw:updateStatus "replbot wakeup test")))
;	(show (string-append "updated status [" (status:getText) "]"))
;	(show (status:getId)) )

;(define since_id::long 605148649941807105)

;(show "mentions timeline")
;(let ((statuses::Object[] ((tw:getMentionsTimeline):toArray)))
;	(do ((i 0 (+ 1 i)))
;		((= i statuses:length) #t)
;		(let ((s::Status (statuses i)))
;			(show (s:getText)) ))
;	#!void)

;(show "mentions since wakeup")
;(let ((statuses::Object[] ((tw:getMentionsTimeline (twitter4j.Paging 1 20 since_id)):toArray)))
;	(do ((i 0 (+ 1 i)))
;		((= i statuses:length) #t)
;		(let ((s::Status (statuses i)))
;			(show (s:getText)) ))
;	#!void)

(show "image test")
(define-alias ImageIO javax.imageio.ImageIO)
(define-alias File java.io.File)
(define-alias Int java.lang.Integer)
(define-alias BufImg java.awt.image.BufferedImage)

(define f::File (File "out.png"))
(define buf::BufImg (BufImg 512 512 BufImg:TYPE_INT_ARGB))

(do ((x 0 (+ x 1)))
    ((= x 512) #t)
  (do ((y 0 (+ y 1)))
      ((= y 512) #t)
    (let* ((col (logand #xff (logxor x y))) (argb (+ #xff000000 (ash col 16) (ash col 8) col))) (buf:setRGB x y argb)) ))
(ImageIO:write buf "PNG" f)


(show "done.")
(exit)

;; actual app workflow
(show "starting replbot")

;; get app start time (current time)
(define start-time::long (Sys:currentTimeMillis))
;; create DB table (hash table keyed by user id)
(define DB #f)  ;later
;; create action queue (FIFO)
(define action-queue::LinkedList (LinkedList))

;; startup twitter connection
(define tw::Twitter (get-twitter))
;; get since_id of bot's last post
(define since-id::long (get-last-post-id tw))
(show since-id)
;; replbot's user id
(define replbot-id (tw:getId))
(show replbot-id)

;; get the @mentions for the last 65-70 minutes
;;   populate the DB with all of them
;;   populate the queue with any action statuses posted since since_id

;; listener:
;;   on receiving any status, add it to the DB
;;   on receiving any status that looks like an action, add it to the queue
(define-simple-class REPLlistener (twitter4j.StatusListener)
    ((onStatus (st ::Status)) ::void access: 'public
        (unless (= ((st:getUser):getId) replbot-id)  ;don't want to act on our own updates
            (begin
                ;(access-db DB 'set ((st:getUser):getId) (st:getText))
                (when ((st:getText):contains "!") (access-queue action-queue 'set st))
                (show (string-append "listener (" ((st:getUser):getScreenName) ": " (st:getText) ")"))
                )))
    
    ((onTrackLimitationNotice i::int) ::void #!void)
    ((onDeletionNotice n::twitter4j.StatusDeletionNotice) ::void #!void)
    ((onScrubGeo i::long j::long) ::void #!void)
    ((onStallWarning w::twitter4j.StallWarning) ::void #!void)
    ((onException e::Exception) ::void #!void)
    )

;; create listener
(define stream::TwStream (get-stream))
;; launch listener
(stream:addListener (REPLlistener))
(stream:user)

;; main loop
;;   until time_now >= start_time + max_run - safety_buffer - action_timeout * queue_length
;;     sleep for 1000-5000 ms (to avoid being rate-limited)
;;     FIFO off any items in the queue and act on them
(do ()
    (#f)
    (Thread:sleep 2000)
    (show "woke up")
    (let loop ((st (access-queue action-queue 'get #f)))
        (when st
            (let ((st::Status st))
                (show (string-append "handler (" ((st:getUser):getScreenName) ": " (st:getText) ")"))
                (let* ((s (string-append "(" (st:getText) ")"))
                       (l (call-with-input-string s read)) )
                    (for-each
                        (lambda (e)
                            (show e)
                            (when (and (pair? e) (not (eq? (car e) '$splice$)))
                                (let ((v (eval e)))
                                    (show v)
                                    (tw:updateStatus (string-append "@" ((st:getUser):getScreenName) " " (v:toString)))
                                    )))
                        l))
                )
            (loop (access-queue action-queue 'get #f)) ))
    )

;; close stream / kill listener
;; act on all remaining items in the queue
;; post a sleep status to use as since_id for the next run

;; done
(show "done.")


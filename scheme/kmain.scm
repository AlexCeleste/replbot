
;; class defined for access from Java stub
;; passthrough to actual app code in scm
(define-simple-class <KWorker> ()
	((kmain (scm ::String)) ::void access: 'public allocation: 'static
		;(invoke (static-field java.lang.System 'out) 'println scm)
		(kawa.standard.Scheme:registerEnvironment)
		(load scm (interaction-environment))
		#!void)
)


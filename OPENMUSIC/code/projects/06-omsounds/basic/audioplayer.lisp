(in-package :om)


;===================
;==== INIT ====
;===================

(defvar *audio-player* nil)

(defvar *audio-vol* 100)
(defvar *audio-pan* 64)

; (audio-close)
; (audio-open)

(defun audio-open ()
 (if (om-start-audio)
     (progn
       ;(setq *audio-player* (om-open-audio-player))
       ;(add-assoc-player *general-player* 'libaudio)
       (oa::instanciate-players)
       (oa::start-global-audio-context)
       )
   (om-message-dialog (format nil (om-str :lib-error) "Audio"))))

(defun audio-close ()
 (when *audio-player*
   (ignore-errors (om-close-audio-player *audio-player*))
   ;(remove-assoc-player *general-player* 'libaudio)
   ;(setf *audio-player* nil)
   (oa::destroy-global-audio-context)
   ))

(defun audio-reset ()
  (ignore-errors (om-close-audio-player *audio-player*))
  ;(setq *audio-player* (om-open-audio-player))  
  (oa::destroy-global-audio-context)
  (oa::instanciate-players)
  (oa::start-global-audio-context)
  )

(om-add-init-func 'audio-open)  
(om-add-exit-cleanup-func 'audio-close t)





;===================
;==== AUDIO PLAY ====
;===================


(defmethod Preparetoplay ((player t) (s sound) at &key approx port interval voice)
  (when (and (om-sound-file-name s)
             (or (null (car interval))
                 (< (- (car interval) at)  (sound-dur-ms s))))
      (if *audio-player*
          (om-add-sound-to-player *audio-player* s at (first interval) (second interval) (tracknum s) (float (/ (vol s) 100)) (- 1.0 (float (/ (+ (pan s) 100) 200))))
        (call-next-method)
        )))
  

;;;===============
;;; ca c'est pour quand ya pas de player
;;;===============

;; start end en ms
(defmethod DoPlay ((s sound) start end)
   (call-next-method)
   ;;;(play-from-to s (/ start 1000.0) (/ end 1000.0))
   ;(om-play-sound s start end)
   (om-beep-msg "Play: no audio player")
   )

(defmethod DoStop ((s sound))
   ;(om-stop-sound s)
  (om-beep-msg "Stop: no audio player"))

(defmethod DoPause ((s sound))
  ;(om-pause-sound s)
  (om-beep-msg "Pause: no audio player")
  )

(defmethod DoContinue ((s sound))
   (om-continue-sound s)
   (om-beep-msg "Continue: no audio player")
   )



;;;===============
;;; quand il y a un player
;;;===============

(defmethod Play-player ((self (eql 'libaudio)))
   (when *audio-player* 
     (om-start-player *audio-player*)))

(defmethod Continue-Player ((self (eql 'libaudio)))
   (when *audio-player* 
     (om-continue-player *audio-player*)))

(defmethod Pause-Player ((self (eql 'libaudio)))
   (when *audio-player* 
     (om-pause-player *audio-player*)))

(defmethod Stop-Player ((self (eql 'libaudio)) &optional view)
   (declare (ignore view))
   (when *audio-player* 
     (om-stop-player *audio-player*)))

(defmethod Reset-Player ((self (eql 'libaudio)) &optional view)
   (declare (ignore view))
   (when *audio-player* 
     (om-reset-player *audio-player*)))

(defmethod audio-record-start ((self (eql 'libaudio)))
  (las-start-audio-record))

(defmethod audio-record-stop ((self (eql 'libaudio)))
  (las-stop-audio-record))
















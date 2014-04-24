(in-package :om)


(defclass ReceiveBox (OMBoxCall) 
  ((etat :initform nil :initarg :etat :accessor etat)
   (process :initform nil :initarg :process :accessor process)))

(defmethod start-receive-fun ((self t)) nil)
(defmethod stop-receive-fun ((self t)) nil)

(defmethod allow-lock-button ((self ReceiveBox))  nil)

(defmethod set-delivered-value ((box ReceiveBox) msg)
  (setf (value box) (list msg)))


;(defmethod call-gen-code ((self ReceiveBox) numout)
;   (declare (ignore numout))
;   `(if ,(gen-code (first (inputs self)) 0) ,(gen-code (second (inputs self)) 0) ,(gen-code (third (inputs self)) 0)))

;(defmethod gen-code-call ((self ReceiveBox))
;   (call-gen-code self 0))
 
(defmethod omNG-box-value ((self ReceiveBox) &optional (numout 0))
  (value self))


(defclass ReceiveBoxFrame (boxframe) ())

(defmethod get-frame-class ((self ReceiveBox)) 'ReceiveBoxFrame)

(defmethod om-get-menu-context ((self ReceiveBoxFrame))
  (append (list (list 
                 (if (etat (object self)) 
                     (om-new-leafmenu  "STOP RECEIVE THREAD" #'(lambda () (when (stop-receive-fun (reference (object self)))
                                                                            (funcall (stop-receive-fun (reference (object self))) (object self)))))
                   (om-new-leafmenu  "START RECEIVE THREAD" #'(lambda () (when (start-receive-fun (reference (object self)))
                                                                            (funcall (start-receive-fun (reference (object self))) (object self))))))))
          (call-next-method)))

(defmethod draw-after-box ((self ReceiveBoxFrame)) 
   (when (etat (object self))
     (om-with-focused-view self
       (om-draw-hilite-rect 0 0 (w self) (h self)))))

(defmethod OpenEditorframe ((self ReceiveBox)) (om-beep))



;==========================
; Common utilities to process incoming messages
;==========================
(defmethod deliver-message (message (fun OMPatch))
  (apply (intern (string (code fun)) :om) (list message)))

(defmethod deliver-message (message (fun null)) message)

(defmethod deliver-message (message (fun function)) 
  (apply fun (list message)))

(defmethod deliver-message (message (fun symbol))
  (when (fboundp fun) (apply fun (list message))))
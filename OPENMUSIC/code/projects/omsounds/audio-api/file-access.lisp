;;==================================
;;; AUDIO FILE ACCESS TOOLS (R/W)
;;==================================

(in-package :cl-user)

;;; genertal package for low-level audio features
(defpackage :audio-io
  (:use cl-user common-lisp))

(in-package :audio-io)

(export '(
          om-sound-get-info
          om-get-sound-buffer
          om-get-sound-display-array
          om-get-sound-display-array-slice
          om-fill-sound-display-array
          om-save-sound-in-file
          resample-audio-buffer

          ) :audio-io)

;======================
; FORMAT HANDLERS
;======================

(defvar *additional-audio-formats* nil)

(defun try-other-file-support (path ext)
  (let ((format-id (car (find ext *additional-audio-formats* :key 'cdr 
                              :test #'(lambda (ext list) (find ext list :test 'string-equal))))))
    (and format-id 
         (audio-file-get-info format-id path))))
   
;;; MUST RETURN (values format channels sr ss size skip)
(defmethod audio-file-get-info (type path) nil)

;;==================================
;;; FILE I/O
;;==================================

(defun convert-filename-encoding (path)
  #+cocoa (external-format::decode-external-string (external-format::encode-lisp-string (namestring path) :utf-8) :latin-1)
  #-cocoa (namestring path))

;;; USE LIBSNDFILE
;;; READ

#+libsndfile
(defun om-sound-get-info (path)
  ;; RETURNS format n-channels sample-rate sample-size size skip
  (let* ((cool-path (convert-filename-encoding path))
         (sf-info  (multiple-value-list (sf::sndfile-get-info cool-path))))
    (if (car sf-info) (values-list sf-info)
      (try-other-file-support cool-path (pathname-type path)))))
 
#+libsndfile
(defun om-get-sound-buffer (path &optional (format :double))
  ;; RETURNS buffer format n-channels sample-rate sample-size size skip
  (sf::sndfile-get-sound-buffer (convert-filename-encoding path) format))


;;;Function used to get the display array from the file path (and choosed max window)

#+libsndfile
(defun om-get-sound-display-array (path &optional (window 128))
  ;;;Ouverture d'un descripteur libsndfile
  (cffi:with-foreign-object (sfinfo '(:struct |libsndfile|::sf_info))
    ;;;Initialisation du descripteur
    (setf (cffi:foreign-slot-value sfinfo '(:struct |libsndfile|::sf_info) 'sf::format) 0)
    (let* (;;;Remplissage du descripteur et affectation aux variables temporaires
           (sndfile-handle (sf::sf_open path sf::SFM_READ sfinfo))
           (size (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::frames) :type :int :index #+powerpc 1 #-powerpc 0))
           (channels (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::channels) :type :int :index #+powerpc 1 #-powerpc 0))
           ;(sr (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::samplerate) :type :int :index #+powerpc 1 #-powerpc 0))
           ;(format (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::format) :type :int :index #+powerpc 1 #-powerpc 0))
           ;(skip (cffi:foreign-slot-value sfinfo '(:struct |libsndfile|::sf_info) 'sf::seekable))
           ;;;Variables li�es au calcul de waveform
           (buffer-size (* window channels))
           (buffer (fli::allocate-foreign-object :type :float :nelems buffer-size))   ;Fen�trage du son
           (MaxArray (make-array (list channels (ceiling size window)) :element-type 'single-float :initial-element 0.0))   ;Tableau pour stocker les max
           (indxmax (1- (ceiling size window)))
           (frames-read 0)
           maxi)
      (loop for indx from 0 do ;(print (list indx "/" (ceiling size window)))
            (setq frames-read (sf::sf-readf-float sndfile-handle buffer window))
            (dotimes (n channels)
              (dotimes (i window)
                (setq maxi (max (abs (fli:dereference buffer :type :float :index (+ n (* channels i)))) (or maxi 0.0))))
              (setf (aref MaxArray n (min indx indxmax)) maxi)
              (setq maxi 0.0))
            while (= frames-read window))
      (fli:free-foreign-object buffer)
      (sf::sf_close sndfile-handle)
      MaxArray)))


;;;Function used to FILL the display array of a sound (and choosed max window)
(defmethod om-fill-sound-display-array ((format t) path ptr channels size &optional (window 128))
  ;(print (list channels size window))
  ;;;Ouverture d'un descripteur libsndfile

#+libsndfile
(cffi:with-foreign-object (sfinfo '(:struct |libsndfile|::sf_info))
    ;;;Initialisation du descripteur
    (setf (cffi:foreign-slot-value sfinfo '(:struct |libsndfile|::sf_info) 'sf::format) 0)
    (let* (;;;Remplissage du descripteur et affectation aux variables temporaires
           (sndfile-handle (sf::sf_open path sf::SFM_READ sfinfo))
           (size (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::frames) :type :int :index #+powerpc 1 #-powerpc 0))
           (channels (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::channels) :type :int :index #+powerpc 1 #-powerpc 0))
           ;(sr (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::samplerate) :type :int :index #+powerpc 1 #-powerpc 0))
           ;(format (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::format) :type :int :index #+powerpc 1 #-powerpc 0))
           ;(skip (cffi:foreign-slot-value sfinfo '(:struct |libsndfile|::sf_info) 'sf::seekable))
           ;;;Variables li�es au calcul de waveform
           (buffer-size (* window channels))
           (buffer (fli::allocate-foreign-object :type :float :nelems buffer-size))   ;Fen�trage du son
           ;(MaxArray (make-array (list channels (ceiling size window)) :element-type 'single-float :initial-element 0.0))   ;Tableau pour stocker les max
           (indxmax (1- (ceiling size window)))
           (frames-read 0)
           maxi)
      (loop for indx from 0 do ;(print (list indx "/" (ceiling size window)))
            (setq frames-read (sf::sf-readf-float sndfile-handle buffer window))
            (dotimes (n channels)
              (dotimes (i window)
                (setq maxi (max (abs (fli:dereference buffer :type :float :index (+ n (* channels i)))) (or maxi 0.0))))
              ;(setf (aref MaxArray n (min indx indxmax)) maxi)
              (setf (fli:dereference ptr :index (+ (min indx indxmax) (* n (ceiling size window)))) maxi)
              (setq maxi 0.0))
            while (= frames-read window))
      (fli:free-foreign-object buffer)
      (sf::sf_close sndfile-handle))))


#+libsndfile
(defmethod om-get-sound-display-array-slice ((format t) path size nchannels start-time end-time)
  ;;;Ouverture d'un descripteur libsndfile
  (cffi:with-foreign-object (sfinfo '(:struct |libsndfile|::sf_info))
    ;;;Initialisation du descripteur
    (setf (cffi:foreign-slot-value sfinfo '(:struct |libsndfile|::sf_info) 'sf::format) 0)
    (let* (;;;Remplissage du descripteur et affectation aux variables temporaires
           (sndfile-handle (sf::sf_open path sf::SFM_READ sfinfo))
           (sr (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::samplerate) :type :int :index #+powerpc 1 #-powerpc 0))
           (sr-ratio (* sr 0.001))
           (start-smp (floor (* start-time sr-ratio)))
           (end-smp (ceiling (* end-time sr-ratio)))
           (dur-smp (- end-smp start-smp))
           ;;; use nchannels !
           (channels (fli::dereference (cffi:foreign-slot-pointer sfinfo '(:struct |libsndfile|::sf_info) 'sf::channels) :type :int :index #+powerpc 1 #-powerpc 0))
           (window (/ dur-smp size 1.0))
           (window-adaptive (round window))
           ;;;Variables li�es au calcul de waveform
           (buffer-size (* (ceiling window) channels))
           (buffer (fli::allocate-foreign-object :type :float :nelems buffer-size))   ;Fen�trage du son
           (MaxArray (make-array (list channels (min size dur-smp)) :element-type 'single-float :initial-element 0.0))   ;Tableau pour stocker les max
           (indxmax (1- (min size dur-smp)))
           (frames-read 0)
           (frames-count 0)
           (winsum 0)
           maxi throw-buffer)
      (when (> start-smp 0)
        (setq throw-buffer (fli::allocate-foreign-object :type :float :nelems (* start-smp channels)))
        (sf::sf-readf-float sndfile-handle throw-buffer start-smp)
        (fli:free-foreign-object throw-buffer))
      (if (> dur-smp size)
          (loop for indx from 0 do
                (setq winsum (+ winsum window-adaptive))
                (if (> indx 0) (setq window-adaptive (- (round (* (+ 2 indx) window)) (round winsum))))
                (setq frames-read (sf::sf-readf-float sndfile-handle buffer window-adaptive)
                      frames-count (+ frames-count frames-read))
                (dotimes (n channels)
                  (dotimes (i window-adaptive)
                    (setq maxi (max (abs (fli:dereference buffer :type :float :index (+ n (* channels i)))) (or maxi 0.0))))
                  (setf (aref MaxArray n (min indx indxmax)) maxi)
                  (setq maxi 0.0))
                while (and (< frames-count dur-smp) (= frames-read window-adaptive)))
        (loop for indx from 0 do
              (setq window-adaptive (max window-adaptive 1)
                    frames-read (sf::sf-readf-float sndfile-handle buffer window-adaptive)
                    frames-count (+ frames-count frames-read))
              (dotimes (n channels)
                (setf (aref MaxArray n (min indx indxmax)) (fli:dereference buffer :type :float :index n)))
              while (and (< frames-count size) (= frames-read window-adaptive))))
      (fli:free-foreign-object buffer)
      (sf::sf_close sndfile-handle)
      MaxArray)))

#+libsndfile
(defun om-save-sound-in-file (buffer filename size nch sr resolution format)
  (sf::sndfile-save-sound-in-file buffer filename size nch sr resolution format))




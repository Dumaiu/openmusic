;;===========================================================================;OM API ;Multiplatform API for OpenMusic;Macintosh version (Digitool Macintosh Common Lisp - MCL);;Copyright (C) 2004 IRCAM-Centre Georges Pompidou, Paris, France.; ;This program is free software; you can redistribute it and/or;modify it under the terms of the GNU General Public License;as published by the Free Software Foundation; either version 2;of the License, or (at your option) any later version.;;See file LICENSE for further informations on licensing terms.;;This program is distributed in the hope that it will be useful,;but WITHOUT ANY WARRANTY; without even the implied warranty of;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the;GNU General Public License for more details.;;You should have received a copy of the GNU General Public License;along with this program; if not, write to the Free Software;Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.;;Authors: Jean Bresson and Augusto Agon;;===========================================================================;;===========================================================================; DocFile ; MIDI functions called by OpenMusic; Use MIDISHARE ;;===========================================================================(in-package :om-midi); (midishare-startup); (midishare-open-player "");;;==============================;;; LOAD FRAMEWORK - INIT/EXIT MIDI;;;==============================;; midishare::*midishare* and midishare::*player-framework*;; can be tested to see if the libaries are loaded(defvar *midishare-loaded?* nil)(defvar *midishare-def-player* nil);; renvoie t ou nil en fonction;; du chargement(defun midishare-startup ()   (setf midishare::*midishare* nil)  (setf midishare::*player-framework* nil)  #+win32(setf cl-user::*libmidishare* (om-lib-pathname cl-user::*libmidishare*))  (setf *midishare-loaded?*        (if (ms::midishare-framework)      (progn        #+win32(setf cl-user::*libplayer* (om-lib-pathname cl-user::*libplayer*))        (when *midishare-def-player*           (setf *midishare-def-player* (midishare-close-player *midishare-def-player*)))        (if (ms::player-framework)            (progn               ;;; test apparently a player must be started..              (setf *midishare-def-player* (midishare-open-player "MSPLAYER"))              ms::*player-framework* ;;; FINAL RETURN IF EVERYTHING OK              )          (progn (print "MIDISHARE PLAYER LOAD ERROR") NIL)          ))    (progn (print "MIDISHARE LOAD ERROR") NIL))));(defun midishare-exit ();(ms::close-player-framework);(ms::remove-midishare-interface);)(defun midishare-extend (&optional (rate 1))  (let* ((size (ms::MidiTotalSpace))         (more (round (* size rate))))    (print (format nil "Increasing MIDI space ~D => ~D" size (+ size more)))    (ms::MidiGrowSpace more)))    (defmacro midishare-get-time ()  `(midishare::MidiGetTime));;; TO BE REDEFINED BY THE MS CLIENT WITH ITS OWN PLAYER(S)(defun midishare-restart-players () nil)(defun midishare-restart ()  (midishare-close-player *midishare-def-player*)  (setf *midishare-def-player* (midishare-open-player "MSPLAYER"))  (midishare-restart-players));;;==============================;;; MIDI UTILS;;;==============================(defun midishare-get-num-from-type (type)  (when type (eval (read-from-string (concatenate 'string "ms::type" (string type))))));=== Converts an event name symbol to MS event type format;=== eg: KeyOn --> typeKeyOn(defun midishare-symb2mtype (sym)  (eval (intern (concatenate 'string "TYPE" (STRING sym)) :midishare)));(midishare-new-event-safe 1)(defun midishare-new-event-safe (type)  (let ((tnum (midishare-get-num-from-type type)))    (if tnum         (let ((event (midishare::MidiNewEv tnum)))          (when (or (not event) (ms::nullptrp event))            (midishare-extend 0.5)            (setf event (midishare::MidiNewEv tnum)))          event)      (progn         (print (format nil "MIDI event type : ~A" type))        nil)      )))(defun midishare-new-evt (type &key port ref chan date vals pgm pitch kpress dur ctrlchange bend param tempo bytes)  (let ((event (om-midi-new-event-safe type)))    (unless (ms::nullptrp event)      (when chan (midishare::chan event chan))                        (when port (midishare::port event port))      (when date (midishare::date event date))      (when ref (midishare::ref event ref))      (cond (vals             (if (listp vals)                 (loop for v in vals for i = 0 then (+ i 1) do                        (midishare::field event i v))               (midishare::field event 0 vals)))            (ctrlchange             (progn (midishare::ctrl event (car ctrlchange))               (midishare::val event (cadr ctrlchange))))            (bytes             (dolist (byte (if (consp bytes) bytes (list bytes)))               (midishare::midiaddfield event byte)))          (t            (when param (midishare::param event param))           (when pgm (midishare::pgm event pgm))           (when bend (midishare::bend event bend))           (when dur (midishare::dur event dur))           (when kpress (midishare::kpress event kpress))           (when pitch (midishare::pitch event pitch))           (when tempo (midishare::tempo event tempo))           )          )      event)))(defun midishare-copy-evt (event)  (ms::MidiCopyEv event))(defun midishare-evt-get (msevent slot)  (case slot    (:type (ms::evtype msevent))    (:date (ms::date msevent))    (:ref (ms::ref msevent))    (:port (ms::port msevent))    (:chan (ms::chan msevent))    (:fields (ms::fields msevent))    (:dur (ms::dur msevent))    (:pitch (ms::pitch msevent))    (:vel (ms::vel msevent))    (:kpress (ms::kpress msevent))    (:tempo (ms::tempo msevent))    (:text (ms::text msevent))    ))(defun midishare-get-evt-text (msevent)  (ms::text msevent));;; many ways to set the attributes of a midi event...(defun midishare-evt-set (evt &key dur date port ref chan pgm param kpress bend tempo ctrlchange vals bytes field text)  (when dur (ms::dur evt dur))  (when date (ms::date evt date))  (when port (ms::port evt port))  (when chan (ms::chan evt chan))  (when ref (ms::ref evt ref))  (when pgm (ms::pgm evt pgm))  (when param (ms::param evt param))  (when kpress (ms::kpress evt kpress))  (when bend (ms::bend evt bend))  (when tempo (ms::tempo evt tempo))  (when text (ms::text evt text))  (when ctrlchange     (midishare::ctrl evt (car ctrlchange))    (midishare::val evt (cadr ctrlchange)))  (when bytes (dolist (byte (if (consp bytes) bytes (list bytes)))                (midishare::midiaddfield evt byte)))  (when vals    (if (listp vals)        (loop for v in vals for i = 0 then (+ i 1) do               (midishare::field evt i v))      (midishare::field evt 0 vals)))  (when field (midishare::field evt (car field) (cadr field)))  )   (defun midishare-next-evt (evt)  (let ((evt (ms::link evt)))    (unless (ms::nullptrp evt) evt)));;;===================;;; MIDISHARE SEQUENCES;;;===================(defun midishare-new-seq ()  (midishare::midinewseq))(defun midishare-seq-concat-evt (seq evt &optional (end t))  (when (and evt seq)    (if end        (progn          (midishare::link (midishare::lastEv seq) evt)          (midishare::lastEv seq evt))      (progn        (midishare::link evt (midishare::firstEv seq))        (midishare::firstEv seq evt)))    ))(defun midishare-seq-add-evt (seq evt) (midishare::MidiAddSeq seq evt))(defun midishare-free-seq (seq)  (midishare::midifreeseq seq))(defun midishare-seq-first-evt (seq)  (let ((evt (ms::firstEv seq)))    (unless (ms::nullptrp evt) evt)))(defun midishare-copy-seq (seq &optional filtertest)  (let ((event (ms::firstEv seq))        (newseq (ms::MidiNewSeq)))    (loop while (not (ms::nullptrp event)) do          (let ((newevent (ms::MidiCopyEv event)))            (unless (or (ms::nullptrp event)                         (and filtertest (cond ((equal (car filtertest) :type)                                               (= (cadr filtertest) (midishare::evtype event)))                                              (t nil))))              (ms::MidiAddSeq newseq newevent))            (setf event (ms::link event))))    newseq));;;===================;;; EVENTS / OM CONVERSION;;;===================(defun msevent-to-midievt (msevent)  (unless (ms::nullptrp msevent)    (make-midi-evt        :type (nth (midishare-evt-get msevent :type) *midi-event-types*)     :date (midishare-evt-get msevent :date)      :ref (midishare-evt-get msevent :ref)      :port (midishare-evt-get msevent :port)     :chan (+ (midishare-evt-get msevent :chan) 1)     :fields (midishare-evt-get msevent :fields))))(defun midievt-to-msevent (midievt)  (let* ((msevent (midishare-new-event-safe (midi-evt-type midievt)))         (params (midi-evt-fields midievt))         (type (midi-evt-type midievt)))    (if (or (not msevent) (ms::nullptrp msevent))        (progn          (format nil (format nil "MidiShare can not create a new event of type ~D" type))          nil)      (progn        (midishare-evt-set msevent :chan (if (midi-evt-chan midievt) (- (midi-evt-chan midievt) 1) 0))			        (midishare-evt-set msevent :port (midi-evt-port midievt))        (midishare-evt-set msevent :ref (midi-evt-ref midievt))        (midishare-evt-set msevent :date (midi-evt-date midievt))        (cond         ((equal type 'PitchBend)          (if (or (numberp params) (= 1 (length params)))              (midishare-evt-set msevent :bend params)            (progn               (midishare-evt-set msevent :field (list 0 (car params)))               (midishare-evt-set msevent :field (list 1 (cadr params))))            ))         ((equal type 'ProgChange)          (midishare-evt-set msevent :pgm (car params)))         ((equal type 'ChanPress)          (midishare-evt-set msevent :param (car params)))         ((equal type 'KeyPress)          (midishare-evt-set msevent :kpress (cadr params))          (midishare-evt-set msevent :pitch (car params)))         ((equal type 'CtrlChange)          (midishare-evt-set msevent :ctrlchange params))         ((equal type 'Tempo)          (midishare-evt-set msevent :tempo (car params)))   ;; (bpm2mstempo (car params))         ((equal type 'SysEx)           (midishare-evt-set msevent :bytes (car params)))         (t (if (stringp (car params))                (midishare-evt-set msevent :text (car params))              (midishare-evt-set msevent :vals params)))         )        msevent        ))))(defun sequenceToevents (seq)  (let ((msevent (midishare-seq-first-evt seq)))    (loop while msevent collect          (prog1              (msevent-to-midievt msevent)            (setf msevent (midishare-next-evt msevent))            ))))(defun eventsTosequence (evtlist seq)  (loop for evt in evtlist do        (let ((msevent (midievt-to-msevent evt)))          (when msevent (midishare-seq-add-evt seq msevent))          ))  seq);;;===================;;; MIDI SEND;;;===================(defun midishare-send-evt (event)  (when *midishare-def-player*    (ms::MidiSendIm *midishare-def-player* (midievt-to-msevent event))));;;(ms::midishare)                                           	; <== EVALUATE THIS EXPRESSION.;;;(defparameter *refnum* (ms::midiopen "Common Lisp"))     	; <== EVALUATE THIS EXPRESSION.;;;;;;;;;(ms::MidiConnect *refnum* 0 -1);;;(defun midishare-send-note (pitch)  (let ((event (ms::MidiNewEv ms::typeNote)))	; ask for a new note event    (ms::date event 0)    (ms::chan event 0)			; set the midi channel to 0 (means channel 1)    (ms::port event 0)			; set the destination port to 0    (ms::field event 0 pitch)		; set the pitch field    (ms::field event 1 100)		; set the velocity field    (ms::field event 2 1000)		; set the duration field to 1 second    (ms::MidiSendIm *midishare-def-player* event))	; send the note immediatly  )						; <== EVALUATE THIS DEFINITION;;;;;;;;;;;;(midishare-send-note 60);;;===================;;; FILE I/O;;;===================(defun midishare-load-file (pathname)   (let ((seq (midishare::midinewseq))          (info (ms::MidiNewMidiFileInfos))         err tracks clicks format timedef events)     (setf err (ms::MidiFileLoad pathname seq info))     (when (zerop err)       (setf tracks (ms::mf-tracks info)             clicks (ms::mf-clicks info)             format (ms::mf-format info)             timedef (ms::mf-timedef info))       (setf events (sequenceToevents seq))       )     (ms::MidiFreeMidiFileInfos info)     (ms::MidiFreeSeq seq)     (values events tracks clicks format)))(defun midishare-save-file (evtlist filename fileformat clicks)  (let ((myInfo (ms::MidiNewMidiFileInfos))        (msseq (midishare::midinewseq))        (err 0))    (eventsTosequence evtlist msseq)    #+lispworks(sys::ENSURE-DIRECTORIES-EXIST filename :verbose t)  ;;; !!! LW specific    (ms::mf-format myInfo fileformat)    (ms::mf-timedef myInfo 0)    (ms::mf-clicks myInfo clicks)    (ms::mf-tracks myInfo 1)    (setf err (midishare::MidiFileSave (namestring filename) msseq myInfo))    (loop while (and (not (zerop err))                      (om-y-or-n-dialog "Error at saving MIDI file: try to extend memory ?"))          do           (progn            (midishare-extend)            (setf err (midishare::MidiFileSave filename msseq myInfo))))    (midishare::midifreeseq msseq)    (if (zerop err)        filename        (progn (print "ERROR saving MIDI file") nil))));;;===================;;; PLAYER;;;===================(defun midishare-open-player (name)  (let ((newplayer (ms::openplayer name)))    (midishare::MidiConnect newplayer 0 -1)    (midishare::MidiConnect  0 newplayer -1)    newplayer    ))(defun midishare-close-player (player)  (midishare::closeplayer player)  ;;; (supposed to call MidiClose automatically)  ); (setq *test* (ms::openplayer "test-name")); (midishare::closeplayer *test*)(defvar *playing-midi-seq* nil)(defun midishare-set-player (player evtlist &optional (ticks 1000))  (handler-bind ((error #'(lambda (e)                               (print "Error setting Midi player sequence...")                              (capi::beep-pane)                              ;(midiplay-reset)                              ;(oa::om-midi-extend) ;;; restarts with more memory...                              (abort e))))  ;(midishare::setalltrackplayer player (midishare::midinewseq) ticks)  (setf *playing-midi-seq* (eventsTosequence evtlist (midishare::midinewseq)))  ;(ms::MidiClearSeq *playing-midi-seq*)  (midishare::setalltrackplayer player *playing-midi-seq* ticks)    ;)  ));;; ???(defun midishare-stop-player (player)   (midishare::StopPlayer player)   ;(when *playing-midi-seq*    ;(midishare::setalltrackplayer player (midishare::midinewseq) 1000)    ;(midishare::midifreeseq *playing-midi-seq*)  ;))(defun midishare-start-player (player) (midishare::startplayer player))(defun midishare-pause-player (player) (midishare::PausePlayer player))(defun midishare-cont-player (player) (midishare::contplayer player))(defun midishare-record-player (player track) (midishare::recordplayer player track))(defun midishare-player-get-seq (player) (midishare::getAllTrackplayer player))(defun midishare-set-loop-player (player start end)  (midishare::SetLoopStartMsPlayer player start)  (midishare::SetLoopEndMsPlayer player end)  (midishare::SetLoopPlayer player midishare::kloopon))(defun midishare-connect (src dest)  (midishare::MidiConnect src dest 1))(defun midishare-disconnect (src dest)  (midishare::MidiConnect src dest 0));;;===================;;; DRIVERS;;;===================(defun midishare-get-drivers ()  (let ((n (ms::MidiCountDrivers)))    (loop for i = 1 then (+ i 1) while (<= i n) collect          (ms::MidiGetIndDriver i)))); (midi-get-drivers); (midi-driver-info 127)(defun midishare-driver-info (ref)  (let ((di (ms::MidiNewMidiDriverInfos))        (si (ms::MidiNewMidiSlotInfos))        (in nil) (out nil) (rep nil))    (ms::MidiGetDriverInfos ref di)    (loop for k = 1 then (+ k 1) while (<= k (ms::md-slots di)) do          (let ((slotref (ms::MidiGetIndSlot ref k))                info)            (ms::MidiGetSlotInfos (ms::MidiGetIndSlot ref k) si)            (setf info (list slotref (ms::ms-name si)))          (cond ((= (ms::ms-direction si) 2) (push info out))                ((= (ms::ms-direction si) 1) (push info in))                ((= (ms::ms-direction si) 3) (push info out) (push info in)))          ))    (setf rep (list (ms::md-name di) (reverse in) (reverse out)))    (ms::MidiFreeMidiDriverInfos di)    (ms::MidiFreeMidiSlotInfos si)    rep))(defun midishare-get-connections (port)  (let ((di (ms::MidiNewMidiDriverInfos))        (si (ms::MidiNewMidiSlotInfos))        (in nil) (out nil))    (loop for ref in (midishare-get-drivers) do          (ms::MidiGetDriverInfos ref di)          (loop for k = 1 then (+ k 1) while (<= k (ms::md-slots di)) do                (let* ((slotref (ms::MidiGetIndSlot ref k))                       (connect (ms::MidiIsSlotConnected port slotref))                       info)                  (when (and (numberp connect) (> connect 0))                    (ms::MidiGetSlotInfos slotref si)                    (setf info (list slotref (ms::ms-name si)))                    (cond ((= (ms::ms-direction si) 2) (push info out))                          ((= (ms::ms-direction si) 1) (push info in))                          ((= (ms::ms-direction si) 3) (push info out) (push info in))                          )))                ))    (ms::MidiFreeMidiDriverInfos di)    (ms::MidiFreeMidiSlotInfos si)    (list (reverse in) (reverse out)))); (midishare-get-connections 1)(defun midishare-list-of-drivers ()  (let ((n (ms::MidiCountDrivers))        (ref nil)        (di (ms::MidiNewMidiDriverInfos))        (si (ms::MidiNewMidiSlotInfos)))    (print (format nil "NB DRIVERS: ~D" n))    (loop for i = 1 then (+ i 1) while (<= i n) do          (setf ref (ms::MidiGetIndDriver i))          (print (format nil "  DRIVER ~D: ~D" i ref))          (ms::MidiGetDriverInfos ref di)          (print (format nil "      ~A (v. ~D)" (ms::md-name di) (ms::md-version di)))          (print (format nil "          ~D slots: " (ms::md-slots di)))          (loop for k = 1 then (+ k 1) while (<= k (ms::md-slots di)) do                (ms::MidiGetSlotInfos (ms::MidiGetIndSlot ref k) si)                (print (format nil "             ~D: ~A (~D)" k (ms::ms-name si) (ms::ms-direction si)))          ))    (ms::MidiFreeMidiDriverInfos di)    (ms::MidiFreeMidiSlotInfos si)))(defun midishare-connect-slot (slotref port)  (ms::MidiConnectSlot port slotref 1))(defun midishare-unconnect-slot (slotref port)  (ms::MidiConnectSlot port slotref 0))
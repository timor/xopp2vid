USING: accessors audio.wav calendar combinators combinators.short-circuit endian
formatting io io.encodings.binary io.encodings.utf8 io.launcher kernel libc math
math.functions models models.arrow models.model-slots sequences system threads
timers ui.gadgets ui.gadgets.buttons ui.gadgets.labels ui.gadgets.packs unix.ffi
unix.process ;

IN: audio.recorder

HOOK: list-devices os ( -- str )
HOOK: record-audio os ( device duration -- audio )
HOOK: record-audio-file-process os ( device max-duration filename -- process )

! requires arecord

M: unix list-devices
    "arecord -L" utf8 [ contents ] with-process-reader ;

HOOK: arecord-format endianness ( -- str )
M: little-endian arecord-format "S16_LE" ;
M: big-endian arecord-format "S16_BE" ;

: arecord-command ( device max-duration -- str )
    duration>seconds ceiling >integer arecord-format "arecord -D %s -d %s -N -f %s -r 48000 -c 2" sprintf ;

: read-wav-stream ( -- audio )
    little-endian [ read-riff-chunk verify-wav (read-wav) ] with-endianness ;

: read-arecord ( command -- audio )
    binary [ read-wav-stream ] with-process-reader ;

M: unix record-audio
    arecord-command read-arecord ;

M: unix record-audio-file-process
    [ arecord-command ] dip " %s" sprintf append >process ;

! Can be stopped using kill-process

! Small gadget for recording

TUPLE: recorder-gadget < pack timer process time-m device ;
MODEL-SLOT: recorder-gadget [ time-m>> ] time


<PRIVATE
: label-gadget ( gadget -- gadget )
    gadget-child ;

: reset-recorder ( gadget -- )
    [ timer>> [ stop-timer ] when* ]
    [ 0 swap time<< ] bi ;

: signal-process ( process signal -- )
    '[ handle>> _ ] [ group>> ] bi {
        { +same-group+ [ kill ] }
        { +new-group+ [ killpg ] }
        { +new-session+ [ killpg ] }
    } case io-error ;

: when-process* ( process quot -- )
    over { [ process? ] [ process-running? ] } 1&& [ call ] [ 2drop ] if ; inline

: stop-recording ( gadget -- )
    process>> [ SIGINT signal-process ] when-process* ;

:: start-with-sentinel ( gadget -- )
    gadget process>>
    '[ _ run-detached :> process
       process gadget process<<
       process wait-for-process "Process Status: %u" sprintf :> status-string
       gadget reset-recorder
       status-string gadget label-gadget string<<
    ] "Audio-Recorder-Sentinel" spawn drop
    gadget timer>> start-timer ;

: prepare-recording ( max-duration filename gadget -- process )
    device>> -rot record-audio-file-process ;

: record-to-file ( max-duration filename gadget -- )
    [ prepare-recording ]
    [ swap >>process start-with-sentinel ] bi ;

PRIVATE>
M: recorder-gadget ungraft*
    [ call-next-method ] keep
    [ stop-recording ]
    [ timer>> [ stop-timer ] when* ] bi ;

:: <recorder-gadget> ( device -- gadget )
    recorder-gadget new dup :> gadget
    horizontal >>orientation
    device >>device
    0 <model> dup :> time-model >>time-m
    [ gadget [ 1 + ] change-time drop ] f 1 seconds <timer> >>timer
    time-model [ device swap "Recording Device: %s %ds" sprintf ] <arrow> <label-control>
    add-gadget
    "Stop" [ drop gadget stop-recording ] <roll-button> add-gadget
    { 10 10 } >>gap ;

: start-recorder ( max-duration filename gadget -- )
    record-to-file ;

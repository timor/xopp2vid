USING: accessors animators arrays audio.engine calendar combinators
combinators.short-circuit continuations formatting grouping io.backend
io.directories io.encodings.binary io.files io.files.temp io.launcher
io.pathnames kernel math math.rectangles models models.arrow models.model-slots
models.selection namespaces prettyprint sequences serialize
stroke-unit.clip-renderer stroke-unit.clips stroke-unit.clips.clip-maker
stroke-unit.elements stroke-unit.models.clip-display
stroke-unit.models.page-parameters stroke-unit.page.canvas
stroke-unit.page.clip-timeline stroke-unit.page.renderer stroke-unit.util timers
ui.gadgets ui.gadgets.colon-wrapper ui.gadgets.glass ui.gadgets.labels
ui.gadgets.model-children ui.gadgets.packs ui.gadgets.scrollers
ui.gadgets.sliders ui.gadgets.timeline ui.gadgets.tracks ui.gestures
ui.tools.inspector vectors xopp.file ;

IN: stroke-unit.page
FROM: namespaces => set ;


! Initial, assume default stroke speed, return sequence of clip-display models
: connect-all-displays ( seq -- seq )
    dup 2 <clumps> [ first2 connect-clip-displays ] each ;

: initialize-clips ( clips -- seq )
    stroke-speed get
    [ <clip-display> ] curry map >vector
    connect-all-displays ;

: <page-slider> ( range-model -- gadget )
    horizontal <slider> fps get recip >>line ;

! * Main editor gadget

! clip-displays is a model
TUPLE: page-editor < track
    page-parameters clip-displays-m timescale-observer
    animator playback selection kill-stack xopp-file page filename output-dir ;
MODEL-SLOT: page-editor [ clip-displays-m>> ] clip-displays
INSTANCE: page-editor has-selection

:: <page-editor-from-clips> ( clips -- gadget )
    clips initialize-clips :> clip-displays
    vertical page-editor new-track
    clip-displays <range-page-parameters> :> ( range-model page-parameters )
    fps get recip [ seconds ] keep range-model <range-animator> >>animator
    V{ } clone >>kill-stack
    clip-displays <model> :> cds
    cds >>clip-displays-m
    cds <selection> :> selection-model
    selection-model >>selection
    selection-model [ first2 ?first swap index ] <arrow> :> index-model
    page-parameters cds <page-canvas> 0.85 track-add
    page-parameters cds <page-timeline> <scroller> 0.15 track-add
    range-model <page-slider> f track-add
    "stroke-unit-" temp-file now timestamp>filename-component append <model> dup :> filename-model
    >>filename
    <shelf>
    filename-model <label-control> add-gadget
    index-model [ unparse ] <arrow> <label-control> add-gadget
    f track-add
    page-parameters >>page-parameters ;

: <page-editor> ( page -- gadget )
    dup page-clips <page-editor-from-clips> swap >>page
    \ page-editor swap <colon-wrapper>
    ;

: canvas-gadget ( editor -- gadget ) children>> first ;
: timeline-gadget ( editor -- gadget ) children>> second viewport>> gadget-child ;

M: page-editor graft*
    { [ call-next-method ]
      [ page-parameters>> timescale>> [ [ set-timescale ] keepd ] ]
      [ timeline-gadget swap curry <arrow> [ activate-model ] keep ]
      [ timescale-observer<< ]
    } cleave ;

M: page-editor focusable-child* timeline-gadget ;

: find-page-parameters ( gadget -- paramters )
    [ page-editor? ] find-parent dup [ page-parameters>> ] when ;

! ** Audio playback scheduling
! return a sequence of { delay clip/f } pairs
: clip-playback-schedule ( current-time clip-displays -- seq )
    [ has-audio? ] filter
    [ [ start-time!>> ] [ clip>> ] bi
      compute-audio-clip
      [ [| delay clip |
         [ clip play-clip ] delay f <timer>
        ] keep 2array ]
      [ drop f ] if*
    ] with map sift ;

! TODO: replace whole index thing with selection model content?
: selected-clip-index ( gadget -- index/f )
    selection>> [ selected>> ?first ] [ items>> ] bi index ;

ERROR: no-focused-clip ;

: get-focused-clip ( gadget -- clip-display ) selection>> selected>> ?first
    dup [ no-focused-clip ] unless ;

! Debug
: current-clip-audio-schedule ( gadget -- seq )
    [ page-parameters>> current-time>> compute-model ]
    [ clip-displays>> [ has-audio? ] filter ] bi
    [ [ clip>> audio-path>> ] keep swapd [ start-time!>> ] [ clip>> ] bi audio-clip-schedule 3array ] with map ;

: editor-stop-playback ( gadget -- )
    [ [ first2
      [ stop-timer ] [ stop-clip ] bi*
      ] each f ] change-playback drop ;

: editor-prepare-playback ( gadget -- )
    dup
    [ page-parameters>> current-time>> compute-model ]
    [ clip-displays>> ] bi clip-playback-schedule
    >>playback drop ;

: editor-start-schedule ( gadget -- )
    playback>> [ first start-timer ] each ;

: editor-start-playback ( gadget -- )
    [ editor-prepare-playback ]
    [ editor-start-schedule ] bi ;

! ** Manipulating the clip-display model value

: make-2-clip-displays ( clip-display quot: ( clip -- clip1 clip2 ) -- obj1 obj2 )
    [ [ clip>> ] dip call ] keepd
    stroke-speed!>> [ <clip-display> ] curry bi@ ; inline

:: <split-clip-display> ( clip-display position -- obj1 obj2 )
    clip-display clip>> :> clip
    clip-display stroke-speed!>> :> speed
    speed stroke-speed [ clip position clip-split-at ] with-variable
    [ speed <clip-display> ] bi@ ;

: <half-clip-display> ( clip-display -- d1 d2 )
    [ clip>> clip-split-half ]
    [ stroke-speed!>> [ <clip-display> ] curry bi@ ] bi
    ;

! ** Doing that in editor context

:: change-clips-with-focused ( gadget quot: ( ..a clip-display seq -- ..b seq ) -- gadget )
    gadget [ gadget get-focused-clip swap quot call ] change-clip-displays ; inline

: select-clip ( clip gadget -- )
    selection>> select-item ;

: after-kill-focused ( gadget -- clip/f )
    [ get-focused-clip ] [ clip-displays>> ] bi
    { [ find-successor ]
      [ drop prev>> ]
    } 2|| dup first-clip? [ drop f ] when ;

: push-kill ( clip gadget -- )
    kill-stack>> push ;

: push-focused ( gadget -- )
    [ get-focused-clip ] [ push-kill ] bi ;

: editor-kill-focused ( gadget -- )
    dup push-focused
    dup after-kill-focused
    [ [ remove-clip ] change-clips-with-focused ] dip
    swap select-clip ;

: kill-pop ( gadget -- clip/f )
    kill-stack>> [ f ] [ pop ] if-empty ;

: editor-yank-before ( gadget -- )
    [ kill-pop ] keep over
    [| new gadget |
     gadget [ [ new ] 2dip insert-clip-before ] change-clips-with-focused
     new swap select-clip ]
    [ 2drop ] if ;

: editor-yank-after ( gadget -- )
    [ kill-pop ] keep over
    [| new gadget |
     gadget [ [ new ] 2dip insert-clip-after ] change-clips-with-focused
     new swap select-clip ]
    [ 2drop ] if ;

: editor-copy-focused ( gadget -- )
    [ get-focused-clip clone-clip-display ]
    [ push-kill ] bi ;

: <merged-clip-display> ( d1 d2 -- d )
    [ [ clip>> ] bi@ clip-merge ]
    [ [ draw-duration!>> ] bi@ + ] 2bi
    <duration-clip-display> ;

: editor-merge-left ( gadget -- )
    dup get-focused-clip first-clip?
    [ drop ]
    [ [| clip seq | clip prev>> :> prev
       prev clip <merged-clip-display> :> new
       clip seq remove-clip
       [ new dup prev ] dip replace-clip
      ] change-clips-with-focused select-clip ] if ;

:: ensure-focused-clip ( gadget -- clip-display )
    gadget clip-displays>> first :> clip1
    [ gadget get-focused-clip ]
    [ dup no-focused-clip?
      [ drop clip1 gadget select-clip
        clip1
      ] [ rethrow ] if
    ] recover ;

: editor-focus-next ( gadget -- )
    [ ensure-focused-clip ]
    [ clip-displays>> find-successor ]
    [ over [ select-clip ] [ 2drop ] if ] tri ;

: editor-focus-prev ( gadget -- )
    [ ensure-focused-clip ]
    [ over first-clip?
      [ 2drop ]
      [ [ prev>> ] dip select-clip ] if
    ] bi ;

: editor-change-timescale ( gadget factor -- )
    over page-parameters>> timescale>> compute-model *
    swap page-parameters>> timescale>> set-model ;

: global-time>clip-position ( time clip-display -- position )
    [ start-time!>> ] [ draw-duration>> ] bi (clip-position) ;

: focused-clip-position ( gadget -- position )
    [ page-parameters>> current-time>> compute-model ]
    [ get-focused-clip global-time>clip-position ] bi ;

! TODO: inline if we need to reach below stack
:: replace-clip-2 ( gadget quot: ( gadget clip-display -- cd1 cd2 ) -- )
    gadget dup get-focused-clip dup :> clip quot call( x x -- x x ) :> ( cd1 cd2 )
    gadget [| clip seq |
            cd1 clip seq replace-clip
            [ cd2 cd1 ] dip insert-clip-after
            cd2 swap
    ] change-clips-with-focused
    select-clip ;

: editor-split-focused-clip ( gadget -- )
    [ [ focused-clip-position ] dip swap <split-clip-display> ]
    replace-clip-2 ;

: can-split-focused-clip? ( gadget -- ? )
    get-focused-clip clip>> clip-can-split? ;

: editor-half-focused-clip ( gadget -- )
    dup can-split-focused-clip?
    [ [ nip <half-clip-display> ] replace-clip-2 ] [ drop ] if ;

:: editor-split-action ( gadget quot: ( clip -- clip1 clip2 ) -- )
    gadget can-split-focused-clip?
    [
        gadget [ nip quot make-2-clip-displays ] replace-clip-2
    ] when ; inline

: editor-divide-focused-clip-vertical ( gadget -- )
    [ clip-divide-vertical ] editor-split-action ;

: editor-divide-focused-clip-horizontal ( gadget -- )
    [ clip-divide-horizontal ] editor-split-action ;

: editor-toggle-playback ( gadget -- )
    [ animator>> toggle-animation ]
    [ dup playback>>
      [ editor-stop-playback ]
      [ editor-start-playback ] if
    ] bi ;

: editor-wind-to-focused ( gadget -- )
    [ get-focused-clip start-time>> ]
    [ page-parameters>> current-time>> set-model ] bi ;

: editor-wind-to-focused-end ( gadget -- )
    [ get-focused-clip [ start-time>> ] [ draw-duration>> ] bi + ]
    [ page-parameters>> current-time>> set-model ] bi ;

: editor-wind-by ( gadget frames -- )
    fps get /
    swap page-parameters>> current-time>> [ compute-model + ] [ set-model ] bi ;

: editor-insert-pause ( gadget duration -- )
    <pause-display> over kill-stack>> push editor-yank-before ;

M: page-editor ungraft*
    { [ timescale-observer>> deactivate-model ]
      ! [ index-observer>> deactivate-model ]
      [ editor-stop-playback ]
      [ call-next-method ]
    } cleave ;

! * Save File Handling
TUPLE: save-record xopp-file page clip/durations output-path ;

: bake-clips ( seq -- seq )
    [ [ clip>> ] [ draw-duration>> ] bi [ f >>audio ] dip 2array ] map ;

: make-save-record ( gadget -- obj )
    {
        [ xopp-file>> ]
        [ page>> ]
        [ clip-displays>> bake-clips ]
        [ output-dir>> ]
    } cleave save-record boa ;

: set-filename ( gadget path -- )
    swap filename>> set-model ;

: ensure-filename ( gadget -- path )
    filename>> compute-model dup [ "no savefile set" throw ] unless normalize-path ;

: save-clips ( clip-displays filename --  )
    binary [ bake-clips serialize ] with-file-writer ;

! TODO inline?
: editor-save-to ( gadget filename -- )
    [ make-save-record ] dip binary [ serialize ] with-file-writer ;
    ! [ clip-displays>> compute-model ] dip save-clips ;

: editor-save ( gadget -- )
    dup ensure-filename editor-save-to ;

: editor-import-xopp-page ( gadget xopp-file-path page-no -- )
    over file>xopp pages nth dup page-clips initialize-clips
    [ >>xopp-file ] [ >>page ] [ swap clip-displays<< ] tri* ;

: unbake-clips ( seq -- seq )
    [ first2 maybe-convert-time <duration-clip-display> ] map
    connect-all-displays ;

: load-clip-displays ( filename -- clip-displays )
    binary [ deserialize ] with-file-reader unbake-clips ;

SYMBOL: quicksave-path
quicksave-path [ "~/tmp/stroke-unit-quicksave" ] initialize

: editor-quicksave ( gadget --  )
    clip-displays>> quicksave-path get save-clips ;
    ! quicksave-path get editor-save-to ;

: clear-caches ( gadget -- )
    [ timeline-gadget clear-gadget-cache ]
    [ canvas-gadget clear-gadget-cache ] bi
    ;

: load-save-record ( gadget -- )
    dup clear-caches
    dup ensure-filename binary [ deserialize ] with-file-reader
    { [ xopp-file>> >>xopp-file ]
      [ page>> >>page ]
      [ output-path>> >>output-dir ]
      [ clip/durations>> unbake-clips swap clip-displays<< ]
    } cleave ;

: editor-load ( gadget path -- )
    [ set-filename ] keepd load-save-record ;
    ! load-clip-displays swap [ clip-displays>> set-model ] [ relayout ] bi ;

: editor-quickload ( gadget -- )
    dup clear-caches
    quicksave-path get load-clip-displays swap
    [ clip-displays<< ] [ relayout ] bi ;

! TODO Replace with something better
: editor-update-range ( gadget -- )
    [ clip-displays>> recompute-page-duration ]
    [ children>> but-last-slice last model>> set-range-max-value ] bi ;

: editor-update-display ( gadget -- )
    dup get-focused-clip [ f >>audio ] change-clip drop
    [ [ ] change-clip-displays drop ]
    [ editor-update-range ]
    [ relayout ] tri ;

:: render-page-editor-clips ( editor page dim path --  )
    path ensure-empty-path :> path
    page dim editor clip-displays>> compute-model path
    render-page-clip-frames drop ;

: render-page-to-path ( gadget dim path -- )
    [ dup page>> ] 2dip render-page-editor-clips ;

: editor-render-page ( gadget dim -- )
    over output-dir>> "clips" append-path render-page-to-path ;

: editor-new-pause-after ( gadget -- )
    [ 1 <pause-display> swap push-kill ]
    [ editor-yank-after ] bi ;

: focus-pause-after/create ( gadget -- clip-display )
    dup dup [ get-focused-clip ] [ clip-displays>> find-successor ] bi
    dup pause-display?
    [ swap select-clip ]
    [ drop editor-new-pause-after ] if
    get-focused-clip ;

! Add/extend pause after current clip to match clip's audio length without
! changing draw speed
: editor-add-pause-to-audio ( gadget -- )
    [ get-focused-clip fit-audio-pause ]
    [ over [ focus-pause-after/create draw-duration<< ] [ 2drop ] if ] bi ;

: editor-set-stroke-speed-factor ( gadget factor -- )
    stroke-speed get *
    swap get-focused-clip set-stroke-speed ;

! Set current clip duration to audio duration
: editor-match-audio ( gadget -- )
    dup '[ _ get-focused-clip dup has-audio? [
              [ clip>> clip-audio-duration ]
              [ draw-duration<< ] bi
      ] [ drop ] if ] change-clip-displays drop ;

:: copy-clip-audio-to-project ( clip-display path i -- )
    clip-display clip>> audio-path>> :> src
    path i "clip-%02d.ogg" sprintf append-path :> dst
    src dst copy-file
    clip-display dst assign-clip-audio ;

ERROR: no-output-dir ;

: page-copy-audio ( gadget -- )
    [ output-dir>> [ "audio" append-path ensure-empty-path ] [ no-output-dir ] if* ]
    [ clip-displays>> compute-model [ has-audio? ] filter
      [ copy-clip-audio-to-project ] with each-index
    ] bi ;

! Set the audio from current clip on kill-stack.
:: editor-set-audio ( gadget --  )
    gadget kill-stack>> ?last :> tos
    tos
    [ gadget
        [| clip seq |
         tos clip>> audio-path>> :> new
         clip new assign-clip-audio
         seq
        ] change-clips-with-focused drop
     ] when ;

: extend-end-to-current-time ( gadget clip-display -- )
    swap page-parameters>> current-time>> compute-model extend-end-to ;

: editor-stretch-focused-end-to-current-time ( gadget -- )
    dup get-focused-clip extend-end-to-current-time ;

: first-clip-display? ( clip-display -- ? )
    prev>> clip>> not ;

: editor-move-focused-start-to-current-time ( gadget -- )
    dup get-focused-clip dup first-clip-display?
    [ 2drop ]
    [ prev>> extend-end-to-current-time ] if ;

: editor-edit-audio ( gadget -- )
    get-focused-clip has-audio?
    [ "audacity %s" sprintf run-detached drop ] when* ;

: editor-change-draw-scale ( gadget inc/dec -- )
    swap page-parameters>> draw-scale>>
    [ compute-model + ] [ set-model ] bi ;

! * Open clip-maker to select strokes which to split off into a new clip

:: clip-maker-callback ( clip-display gadget -- quot )
    [| strokes | clip-display strokes remove-strokes gadget push-kill ] ;

: <current-clip-maker> ( gadget -- obj )
    [ get-focused-clip ] keep
    [ drop clip>> clip-strokes ]
    [ clip-maker-callback ] 2bi <clip-maker> ;

: show-clip-display-editor ( clip-maker gadget -- )
    canvas-gadget swap <zero-rect> show-glass ;
    ! [ canvas-gadget ]
    ! [ <current-clip-maker> ]
    ! bi <zero-rect> show-glass ;

: editor-extract-clip-strokes ( gadget -- )
    [ <current-clip-maker> ]
    [ show-clip-display-editor ] bi ;

: visible-strokes ( gadget -- seq )
    [ page-parameters>> current-time>> compute-model ]
    [ clip-displays>> ] bi
    [ [ nip clip>> ] [ global-time>clip-position ] 2bi clip-elements-until-position ] with gather ;

:: page-extract-callback ( gadget -- obj )
    [| strokes | gadget clip-displays>> strokes extract-strokes gadget push-kill ] ;

: <page-clip-maker> ( gadget -- obj )
    [ visible-strokes ]
    [ page-extract-callback ] bi <clip-maker> ;

: editor-extract-page-strokes ( gadget -- )
    [ <page-clip-maker> ]
    [ show-clip-display-editor ] bi ;

: editor-reorder-clip-horizontal ( gadget -- )
    get-focused-clip [ clip-reorder-horizontal ] change-clip drop ;

: editor-reorder-clip-vertical ( gadget -- )
    get-focused-clip [ clip-reorder-vertical ] change-clip drop ;

! * Editor Keybindings

page-editor H{
    { T{ key-down f f "h" } [ editor-focus-prev ] }
    { T{ key-down f f "l" } [ editor-focus-next ] }
    { T{ key-down f f "x" } [ editor-kill-focused ] }
    { T{ key-down f f "y" } [ editor-copy-focused ] }
    { T{ key-down f f "P" } [ editor-yank-before ] }
    { T{ key-down f f "p" } [ editor-yank-after ] }
    { T{ key-down f f "m" } [ editor-merge-left ] }
    { T{ key-down f f "s" } [ editor-half-focused-clip ] }
    { T{ key-down f f "S" } [ editor-split-focused-clip ] }
    { T{ key-down f f "d" } [ editor-divide-focused-clip-vertical ] }
    { T{ key-down f f "D" } [ editor-divide-focused-clip-horizontal ] }
    { T{ key-down f f "-" } [ 1/2 editor-change-timescale ] }
    { T{ key-down f f "=" } [ 2 editor-change-timescale ] }
    { T{ key-down f f " " } [ editor-toggle-playback ] }
    { T{ key-down f { C+ } "h" } [ editor-wind-to-focused ] }
    { T{ key-down f { C+ } "l" } [ editor-wind-to-focused-end ] }
    { T{ key-down f f "H" } [ dup editor-focus-prev editor-wind-to-focused ] }
    { T{ key-down f f "L" } [ dup editor-focus-next editor-wind-to-focused-end ] }
    { T{ key-down f f "[" } [ -1 editor-wind-by ] }
    { T{ key-down f f "]" } [ 1 editor-wind-by ] }
    { T{ key-down f f "{" } [ -10 editor-wind-by ] }
    { T{ key-down f f "}" } [ 10 editor-wind-by ] }
    { T{ key-down f f "n" } [ 2 editor-insert-pause ] }
    { T{ key-down f { C+ } "s" } [ editor-quicksave ] }
    { T{ key-down f { C+ } "o" } [ editor-quickload ] }
    { T{ key-down f { C+ } "w" } [ editor-save ] }
    { T{ key-down f f "g" } [ editor-update-display ] }
    { T{ key-down f f "e" } [ editor-match-audio ] }
    { T{ key-down f f "E" } [ editor-add-pause-to-audio ] }
    { T{ key-down f { C+ } "A" } [ editor-set-audio ] }
    { T{ key-down f f "A" } [ editor-edit-audio ] }
    { T{ key-down f f "1" } [ 0.5 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "2" } [ 0.75 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "3" } [ 1 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "4" } [ 2 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "5" } [ 4 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "<" } [ editor-move-focused-start-to-current-time ] }
    { T{ key-down f f ">" } [ editor-stretch-focused-end-to-current-time ] }
    { T{ key-down f { C+ } "=" } [ 0.1 editor-change-draw-scale ] }
    { T{ key-down f { C+ } "-" } [ -0.1 editor-change-draw-scale ] }
    { T{ key-down f { C+ } "d" } [ drop hand-gadget get ui.tools.inspector:inspector ] }
    { T{ key-down f f "i" } [ editor-extract-clip-strokes ] }
    { T{ key-down f f "I" } [ editor-extract-page-strokes ] }
    { T{ key-down f f "r" } [ editor-reorder-clip-horizontal ] }
    { T{ key-down f f "R" } [ editor-reorder-clip-vertical ] }
} set-gestures

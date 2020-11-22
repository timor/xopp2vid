USING: accessors animators arrays audio.engine calendar combinators formatting
grouping io.backend io.directories io.encodings.binary io.files io.files.temp
io.pathnames kernel math models models.arrow models.selection namespaces
prettyprint sequences serialize stroke-unit.clip-renderer stroke-unit.clips
stroke-unit.elements stroke-unit.models.clip-display
stroke-unit.models.page-parameters stroke-unit.page.canvas
stroke-unit.page.clip-timeline stroke-unit.page.renderer stroke-unit.page.syntax
stroke-unit.util timers ui.gadgets ui.gadgets.labels ui.gadgets.model-children
ui.gadgets.packs ui.gadgets.scrollers ui.gadgets.sliders ui.gadgets.timeline
ui.gadgets.tracks ui.gestures ui.tools.inspector vectors xopp.file ;

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
    page-parameters clip-displays timescale-observer
    animator playback index kill-stack xopp-file page filename output-dir ;

:: <page-editor-from-clips> ( clips -- gadget )
    clips initialize-clips :> clip-displays
    vertical page-editor new-track
    clip-displays <range-page-parameters> :> ( range-model page-parameters )
    fps get recip [ seconds ] keep range-model <range-animator> >>animator
    V{ } clone >>kill-stack
    0 <model> dup :> index-model >>index
    ! 0 <model> >>current-index
    clip-displays <model> [ >>clip-displays ] keep
    ! [ <selection> >>selection ] keep
    [ page-parameters swap <page-canvas> 0.85 track-add ]
    [ page-parameters swap <page-timeline> <scroller> 0.15 track-add ] bi
    range-model <page-slider> f track-add
    "stroke-unit-" temp-file now timestamp>filename-component append <model> dup :> filename-model
    >>filename
    <shelf>
    filename-model <label-control> add-gadget
    index-model [ unparse ] <arrow> <label-control> add-gadget
    f track-add
    page-parameters >>page-parameters ;

: <page-editor> ( page -- gadget )
    dup page-clips <page-editor-from-clips> swap >>page ;

: canvas-gadget ( editor -- gadget ) children>> first ;
: timeline-gadget ( editor -- gadget ) children>> second viewport>> gadget-child ;

! May not change if only index changes
! : <index-change--> ( clip-displays-model index-model -- model )
!     [ [ ] <?arrow> ] bi@ [ clamp-index ] <smart-arrow> ;

! :: <focus-index--> ( editor clip-displays-model index-model -- model )
!     editor timeline-gadget :> timeline
!     clip-displays-model index-model <index-change--> [ timeline swap [ focus-clip-index ] keep ]
!     <arrow> ;

    ! [ ]
    ! ! editor timeline-gadget :> timeline
    ! ! index-model [ ] <?arrow> clip-displays-model [ ] <?arrow>
    ! ! [| i s | timeline i focus-clip-index i ] <smart-arrow> ;
    ! [ [ ] <?arrow> ] bi@ rot timeline-gadget [ nip swap [ focus-clip-index ] keep ] curry
    ! <smart-arrow> ;

M: page-editor graft*
    { [ call-next-method ]
      [ page-parameters>> timescale>> [ [ set-timescale ] keepd ] ]
      [ timeline-gadget swap curry <arrow> [ activate-model ] keep ]
      [ timescale-observer<< ]

      ! [ dup [ clip-displays>> ] [ index>> ] bi <focus-index--> [ activate-model ] keep ]
      ! [ index-observer<< ]

      ! [ index>> [ ] <?arrow> [ [ swap focus-clip-index ] keepd ] ]
      ! [ timeline-gadget swap curry <arrow> [ activate-model ] keep ]
      ! [ index-observer<< ]
    } cleave ;

M: page-editor focusable-child* timeline-gadget ;

: find-page-parameters ( gadget -- paramters )
    [ page-editor? ] find-parent dup [ page-parameters>> ] when ;

: ensure-index ( editor -- index )
    [ clip-displays>> compute-model ]
    [ index>> compute-model clamp-index ]
    [ [ index>> set-model ] keepd ] tri ;

: editor-refocus ( editor -- )
    [ ensure-index ]
    [ timeline-gadget swap focus-clip-index ] bi ;

M: page-editor handles-selection? drop t ;
M: page-editor handle-selection index>> set-model ;

! : find-selection ( gadget -- model )
!     [ page-editor? ] find-parent dup [ selection>> ] when ;

! : set-focus ( gadget clip-display -- )
!     [ find-selection ] dip select-item ;
    ! gadget [ page-editor? ] find-parent clip-displays>> compute-model
    ! seq index gadget find-page-parameters focused-index>> set-model ;
    ! swap [ page-editor? ] find-parent
    ! [ clip-displays>> compute-model index focused-clip-index set ]
    ! [ drop ] if* ;


    ! dup clip-displays>> compute-model focused-clip-index get clamp-index
    ! [ timeline-gadget ] dip focus-clip-index ;

! ** Audio playback scheduling
! return a sequence of { delay clip/f } pairs
: clip-playback-schedule ( current-time clip-displays -- seq )
    [ [ start-time!>> ] [ clip>> ] bi
      compute-audio-clip
      [ [| delay clip |
         [ clip play-clip ] delay seconds f <timer>
        ] keep 2array ]
      [ drop f ] if*
    ] with map sift ;

: editor-stop-playback ( gadget -- )
    [ [ first2
      [ stop-timer ] [ stop-clip ] bi*
      ] each f ] change-playback drop ;

: editor-prepare-playback ( gadget -- )
    dup
    [ page-parameters>> current-time>> compute-model ]
    [ clip-displays>> compute-model ] bi clip-playback-schedule
    >>playback drop ;

: editor-start-schedule ( gadget -- )
    playback>> [ first start-timer ] each ;

: editor-start-playback ( gadget -- )
    [ editor-prepare-playback ]
    [ editor-start-schedule ] bi ;

! ** Manipulating the clip-display model value

! Following things need to be done:
! 1. Connect the predecessor and the successor
! 2. Deactivate the model-model
! 2. Remove the clip from the clip-displays list
! 3. Remove the gadget from the canvas
! 4. Remove the gadget from the timeline

: this/next ( seq index -- elt elt/f )
    [ swap nth ] [ 1 + swap ?nth ] 2bi ;

: this/prev ( seq index -- elt elt/f )
    [ swap nth ] [ 1 - swap ?nth ] 2bi ;

: connect-neighbours ( clip-displays index -- )
    this/next
    [ [ prev>> ] dip
      connect-clip-displays  ]
    [ drop ] if* ;

! : kill-nth-clip-display ( clip-displays index -- seq )
!     swap [ nth kill-stack get push ] [ remove-nth ] 2bi ;

: delete-nth-clip-display ( seq index -- seq display )
    swap [ nth ] [ remove-nth ] 2bi swap ;

    ! [  ]
    ! kill-nth-clip-display kill-stack get pop ;

! before manipulating the sequence
: connect-insert-before ( clip-displays index clip-display -- )
    [ swap nth dup prev>> ] dip
    [ connect-clip-displays ]
    [ swap connect-clip-displays ] bi ;

: insert-clip-before ( clip-displays index clip-display -- seq )
    3dup connect-insert-before
    spin insert-nth ;

: connect-insert-after ( clip-displays index clip-display -- )
    [ [ swap nth ] dip connect-clip-displays ]
    [ -rot 1 + swap ?nth [ connect-clip-displays ] [ drop ] if* ] 3bi ;

: insert-clip-after ( clip-displays index clip-display -- seq )
    3dup connect-insert-after
    [ 1 + ] dip spin insert-nth ;

: clone-clip-display ( clip-display -- clip-display' )
    [ clip>> ] [ stroke-speed!>> ] bi
    <clip-display> ;

: make-2-clip-displays ( clip-display quot: ( clip -- clip1 clip2 ) -- obj1 obj2 )
    [ [ clip>> ] dip call ] keepd
    stroke-speed!>> [ <clip-display> ] curry bi@ ; inline

:: <split-clip-display> ( clip-display position -- obj1 obj2 )
    clip-display clip>> :> clip
    clip-display stroke-speed!>> :> speed
    speed stroke-speed [ clip position clip-split-at ] with-variable
    [ speed <clip-display> ] bi@ ;
    ! [ [ clip>> ] dip clip-split-at ]
    ! [ drop stroke-speed!>> ] 2bi
    ! [ <clip-display> ] curry bi@ ;

: <half-clip-display> ( clip-display -- d1 d2 )
    [ clip>> clip-split-half ]
    [ stroke-speed!>> [ <clip-display> ] curry bi@ ] bi
    ;

! ** Doing that in editor context

: selected-clip-index ( gadget -- index )
    index>> compute-model ;
    ! compute-model ;
    ! find-selection selected-index ;

! ! TODO: use combinator
! : editor-kill-clip ( gadget index -- )
!     over clip-displays>> compute-model
!     2dup swap connect-neighbours
!     swap kill-nth-clip-display swap clip-displays>> set-model ;

:: change-clip-displays ( gadget quot: ( value -- new-value/f ) -- gadget )
    gadget clip-displays>> dup :> model compute-model
    quot call [ model set-model ] when* gadget ; inline

: change-clip-displays-focused ( gadget quot: ( value index -- new-value ) -- gadget )
    [ dup selected-clip-index ] dip curry change-clip-displays ; inline

: with-clips/index ( gadget quot: ( clips index -- ) -- )
    [ [ clip-displays>> compute-model ] [ selected-clip-index ] bi ] dip call ; inline

:: editor-kill-clip ( gadget index -- )
    gadget [
            dup index connect-neighbours
            index over nth no-predecessor-clip get over prev<<
            gadget kill-stack>> push
            index swap remove-nth
            ! dup index swap [ nth kill-stack get push ] [ remove-nth ] 2bi
    ] change-clip-displays drop ;

E:: editor-yank-before ( gadget -- )
    gadget kill-stack>>
    [
        pop :> to-insert
        gadget [
            to-insert insert-clip-before
        ] change-clip-displays-focused drop
    ] unless-empty ;

:: editor-yank-after ( gadget -- )
    gadget kill-stack>>
    [
        pop :> to-insert
        gadget [
            to-insert insert-clip-after
        ] change-clip-displays-focused drop
    ] unless-empty ;

: editor-kill-focused ( gadget -- )
    dup selected-clip-index editor-kill-clip  ;
    ! [ editor-refocus ] bi ;

: get-focused-clip ( gadget -- clip-display/f )
    [ selected-clip-index ] [ clip-displays>> compute-model nth ] bi ;

: push-kill ( clip gadget -- )
    kill-stack>> push ;

: editor-copy-focused ( gadget -- )
    [ get-focused-clip clone-clip-display ]
    [ push-kill ] bi ;

: <merged-clip-display> ( d1 d2 -- d )
    [ [ clip>> ] bi@ clip-merge ]
    [ [ draw-duration!>> ] bi@ + ] 2bi
    <duration-clip-display> ;

:: replace-nth-clip ( seq n clip -- seq )
    n seq nth prev!>> :> prev
    n 1 + seq ?nth :> next
    prev clip connect-clip-displays
    clip next [ connect-clip-displays ] [ drop ] if*
    clip n seq set-nth
    seq ;

: editor-merge-left ( gadget -- )
    [| seq i |
     i 1 - seq ?nth [
         seq i delete-nth-clip-display :> this
         i 1 - over nth :> prev
         prev this <merged-clip-display> :> new
         i 1 - new replace-nth-clip
     ] [ f ] if
    ] change-clip-displays-focused drop ;

E: editor-move ( gadget offset -- )
    [ drop ]
    [ swap [ selected-clip-index + ] [ index>> set-model ] bi ] if-zero ;
    ! offset zero?
    ! [ gadget selected-clip-index offset + gadget index>> set-model ] unless ;
    ! [ swap  ]
    ! [ drop ]
    ! [ [ [ timeline-gadget ] [ selected-clip-index ] bi ] dip + focus-clip-index ]
    ! if-zero ;

! find-selection selected-item ;
! clip-displays>> compute-model focused-clip-index get [ swap nth ] [ drop f ] if* ;


E: editor-change-timescale ( gadget factor -- )
    over page-parameters>> timescale>> compute-model *
    swap page-parameters>> timescale>> set-model ;

: nth-clip-display-position ( gadget clip-displays n -- position )
    [ page-parameters>> current-time>> compute-model ] 2dip swap nth
    [ start-time!>> ] [ draw-duration>> ] bi
    (clip-position) ;

: selected-clip-position ( gadget -- position )
    dup [ clip-displays>> compute-model ] [ selected-clip-index ] bi nth-clip-display-position ;

: editor-split-focused-clip ( gadget -- )
    {
        [ selected-clip-position ]
        [ editor-kill-focused ]
        [ kill-stack>> pop swap <split-clip-display> ]
        [ kill-stack>> [ push ] curry bi@ ]
        [ -1 editor-move ]
        [ editor-yank-after ]
        [ editor-yank-after ]
    } cleave ;

: can-split-focused-clip? ( gadget -- ? )
    get-focused-clip [ clip>> clip-can-split? ] [ f ] if* ;

: kill-pop ( gadget -- clip )
    [ editor-kill-focused ]
    [ kill-stack>> pop ] bi ;

: editor-half-focused-clip ( gadget -- )
    dup can-split-focused-clip?
    [ {
        [ kill-pop <half-clip-display> ]
        ! [ kill-stack>> pop <half-clip-display> ]
        ! [ kill-stack>> [ push ] curry bi@ ]
        [ [ push-kill ] curry bi@ ]
        [ -1 editor-move ]
        [ editor-yank-after ]
        [ editor-yank-after ]
    } cleave ] [ drop ] if ;

:: editor-split-action ( gadget quot: ( clip -- clip1 clip2 ) -- )
    gadget can-split-focused-clip?
    [ gadget { [ kill-pop
          quot make-2-clip-displays swap ]
         [ [ push-kill ] curry bi@ ]
         [ editor-yank-before ]
         [ editor-yank-before ]
       } cleave ] when ; inline

: editor-divide-focused-clip-vertical ( gadget -- )
    [ clip-divide-vertical ] editor-split-action ;

: editor-divide-focused-clip-horizontal ( gadget -- )
    [ clip-divide-horizontal ] editor-split-action ;

! : editor-divide-focused-clip-vertical ( gadget -- )
!     dup can-split-focused-clip?
!     [ { [ kill-pop
!           [ clip-divide-vertical ] make-2-clip-displays swap ]
!         [ [ push-kill ] curry bi@ ]
!         [ editor-yank-before ]
!         [ editor-yank-before ]
!       } cleave ]  [ drop ] if ;

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

! : clip>preview ( editor clip-display -- preview-gadget/f )
!     over clip-displays>> index
!     [ swap timeline-gadget children>> nth ]
!     [ 2drop f ] if* ;

! * Editor Keybindings

! clip-timeline H{
!     { T{ key-down f f "h" } [ timeline-focus-left ] }
!     { T{ key-down f f "l" } [ timeline-focus-right ] }
! } set-gestures

TUPLE: save-record xopp-file page clip/durations output-path ;

: bake-clips ( seq -- seq )
    [ [ clip>> ] [ draw-duration>> ] bi [ f >>audio ] dip 2array ] map ;

: make-save-record ( gadget -- obj )
    {
        [ xopp-file>> ]
        [ page>> ]
        [ clip-displays>> compute-model bake-clips ]
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
    [ >>xopp-file ] [ >>page ] [ swap clip-displays>> set-model ] tri* ;

: unbake-clips ( seq -- seq )
    [ first2 maybe-convert-time <duration-clip-display> ] map
    connect-all-displays ;

: load-clip-displays ( filename -- clip-displays )
    binary [ deserialize ] with-file-reader unbake-clips ;

SYMBOL: quicksave-path
quicksave-path [ "~/tmp/stroke-unit-quicksave" ] initialize

: editor-quicksave ( gadget --  )
    clip-displays>> compute-model quicksave-path get save-clips ;
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
      [ clip/durations>> unbake-clips swap clip-displays>> set-model ]
    } cleave ;

: editor-load ( gadget path -- )
    [ set-filename ] keepd load-save-record ;
    ! load-clip-displays swap [ clip-displays>> set-model ] [ relayout ] bi ;

: editor-quickload ( gadget -- )
    dup clear-caches
    quicksave-path get load-clip-displays swap
    [ clip-displays>> set-model ] [ relayout ] bi ;

! Replace with something better
: editor-update-range ( gadget -- )
    [ clip-displays>> compute-model recompute-page-duration ]
    [ children>> but-last-slice last model>> set-range-max-value ] bi ;

: editor-update-display ( gadget -- )
    ! dup get-focused-clip [ f >>audio ] change-clip drop
    ! [ clip>> model f >>audio ] [ clip>> set-model ] bi
    [ clip-displays>> [ compute-model ] [ set-model ] bi ]
    [ editor-update-range ]
    [ relayout ] tri ;

:: render-page-editor-clips ( editor page dim path --  )
    path ensure-empty-path :> path
    page dim editor clip-displays>> compute-model path
    render-page-clip-frames drop ;
    ! editor clip-displays>> compute-model [ clip>> compute-model empty-clip? ] reject
    ! [| c i |
    !  path i "clip-%02d" sprintf append-path dup make-directories :> clip-dir
    !  page dim c clip-dir render-page-clip-display
    !  ! [ clip-dir
    !  !  save-graphic-image
    !  ! ] each-index
    ! ] each-index ;

: render-page-to-path ( gadget dim path -- )
    [ dup page>> ] 2dip render-page-editor-clips ;

: editor-render-page ( gadget dim -- )
    over output-dir>> "clips" append-path render-page-to-path ;

:: find-pause-create ( gadget -- clip-display )
    gadget get-focused-clip prev>> :> prev-clip
    prev-clip pause-display?
    [ prev-clip ]
    [ gadget 1 editor-insert-pause
      gadget get-focused-clip ] if ;

:: editor-add-pause-to-audio ( gadget -- )
    gadget [ this/next :> ( this next )
             this fit-audio-pause :> pause
             pause
             [
                 next clip>> empty-clip?
                 [ pause next draw-duration<< ]
                 [ pause <pause-display> gadget push-kill gadget editor-yank-after ] if
                 gadget clip-displays>> notify-connections
             ] when
    ] with-clips/index ;

: editor-set-stroke-speed-factor ( gadget factor -- )
    [
        stroke-speed get *
        [ over nth ] dip swap set-stroke-speed
    ] curry change-clip-displays-focused drop ;

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
        [| seq i |
         tos clip>> audio-path>> :> new
         i seq nth new assign-clip-audio
         seq
        ] change-clip-displays-focused drop
     ] when ;

: editor-stretch-focused-end-to-current-time ( gadget -- )
    [ get-focused-clip ]
    [ page-parameters>> current-time>> compute-model ] bi
    extend-end-to ;


! : editor-extend-prev ( gadget -- )

!     gadget [ this/prev :> ( this prev )
!              prev
!              [ gadget find-pause-create :> pause
!                prev [ stroke-speed get swap set-stroke-speed ]
!                [ fit-audio-pause ] bi
!                pause draw-duration>> set-model
!              ] when
!     ] with-clips/index ;

page-editor H{
    { T{ key-down f f "h" } [ -1 editor-move ] }
    { T{ key-down f f "l" } [ 1 editor-move ] }
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
    { T{ key-down f f "H" } [ dup -1 editor-move editor-wind-to-focused ] }
    { T{ key-down f f "L" } [ dup 1 editor-move editor-wind-to-focused-end ] }
    { T{ key-down f f "[" } [ -1 editor-wind-by ] }
    { T{ key-down f f "]" } [ 1 editor-wind-by ] }
    { T{ key-down f f "{" } [ -10 editor-wind-by ] }
    { T{ key-down f f "}" } [ 10 editor-wind-by ] }
    { T{ key-down f f "n" } [ 1 editor-insert-pause ] }
    { T{ key-down f { C+ } "s" } [ editor-quicksave ] }
    { T{ key-down f { C+ } "o" } [ editor-quickload ] }
    { T{ key-down f { C+ } "w" } [ editor-save ] }
    { T{ key-down f f "g" } [ editor-update-display ] }
    { T{ key-down f f "e" } [ editor-match-audio ] }
    { T{ key-down f f "E" } [ editor-add-pause-to-audio ] }
    { T{ key-down f { C+ } "A" } [ editor-set-audio ] }
    { T{ key-down f f "1" } [ 0.25 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "2" } [ 0.5 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "3" } [ 1 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "4" } [ 2 editor-set-stroke-speed-factor ] }
    { T{ key-down f f "5" } [ 4 editor-set-stroke-speed-factor ] }
    { T{ key-down f f ">" } [ editor-stretch-focused-end-to-current-time ] }
    { T{ key-down f { C+ } "d" } [ drop hand-gadget get ui.tools.inspector:inspector ] }
} set-gestures

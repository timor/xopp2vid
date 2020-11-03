USING: accessors arrays assocs base64 cairo cairo-gadgets cairo.ffi
classes.struct colors.constants colors.hex combinators combinators.short-circuit
continuations destructors formatting fry grouping images images.loader
images.memory.private images.normalization images.png io io.backend
io.directories io.encodings.utf8 io.files io.files.info io.files.temp
io.launcher io.pathnames kernel locals math math.functions math.parser
math.rectangles math.vectors memoize namespaces sequences sequences.extras
sequences.zipped splitting strings ui.images vectors xml.data xml.syntax
xml.traversal ;

IN: xopp

! * Xournal++ file loader

SYMBOL: audio-path
TUPLE: element ;
TUPLE: stroke < element color segments audio ;
TUPLE: image-elt < element left top right bottom png-data ;
TUPLE: clip audio elements ;

TAGS: >element ( elt -- obj )

GENERIC: draw-element ( element -- )
: <clip> ( audio -- obj ) clip new swap >>audio V{ } clone >>elements ;

: pages ( xml -- seq )
    "page" tags-named ;

! TBR
: all-page-strokes ( xml-page -- seq )
    "stroke" deep-tags-named ;

: string>numbers ( str -- seq )
    " " split [ string>number ] map ;

: stroke-points ( stroke -- seq )
    children>string string>numbers 2 <groups> ;

: stroke-segments ( stroke -- seq )
    [ "width" attr string>numbers ] [ stroke-points 2 <clumps> ] bi <zipped> ;

: stroke>color/seg ( stroke -- color segments )
    [ "color" attr 1 tail hex>rgba ] [ stroke-segments ] bi ;

: <stroke> ( xml -- obj )
    [ stroke>color/seg ]
    [ "fn" attr [ f ] when-empty ] bi stroke boa ;

TAG: stroke >element <stroke> ;

:: <image-elt> ( xml -- obj )
    image-elt new :> img
    xml { [ "left" attr string>number img left<< ]
          [ "top" attr string>number img top<< ]
          [ "right" attr string>number img right<< ]
          [ "bottom" attr string>number img bottom<< ]
          [ children>string base64> img png-data<< ]
    } cleave img ;

TAG: image >element <image-elt> ;

: with-factor-image-surface ( image quot: ( surface -- ) -- )
    '[
        _ [ bitmap>> ] [ dim>> ] bi <image-surface> &cairo_surface_destroy
        @
    ] with-destructors ; inline

: image-elt-width ( image-elt -- n ) [ right>> ] [ left>> ] bi - ;
: image-elt-height ( image-elt -- n ) [ bottom>> ] [ top>> ] bi - ;

M:: image-elt draw-element ( img -- )
    img png-data>> png-image load-image* BGRA reorder-components [| img-surface |
     cairo_matrix_t <struct> :> matrix
     cr matrix cairo_get_matrix
     img-surface cairo_image_surface_get_width :> width
     img-surface cairo_image_surface_get_height :> height
     cr CAIRO_OPERATOR_OVER cairo_set_operator
     img image-elt-width width /f :> xFactor
     img image-elt-height height /f :> yFactor
     cr xFactor yFactor cairo_scale
     cr img-surface img left>> xFactor /f img top>> yFactor /f cairo_set_source_surface
     cr cairo_paint
     cr matrix cairo_set_matrix
    ] with-factor-image-surface ;

: segment-length ( segment -- n )
    second first2 distance ;

:: (draw-segment) ( width start end -- )
    cr width cairo_set_line_width
    cr start first2 cairo_move_to
    cr end first2 cairo_line_to
    cr cairo_stroke ;

: draw-segment ( segment -- ) first2 first2 (draw-segment) ; inline

: draw-segments ( color segments -- )
    [ cr swap set-source-color ] [ [ draw-segment ] each ] bi* ;

: draw-stroke ( stroke -- )
    [ color>> ] [ segments>> ] bi draw-segments ;
    ! stroke>color/seg draw-segments ;
    ! [ cr swap "color" attr 1 tail hex>rgba set-source-color ]
    ! [ stroke-segments [ first2 draw-segment ] assoc-each ] bi ;
M: stroke draw-element draw-stroke ;

! : draw-layer ( layer -- ) "stroke" tags-named [ draw-stroke ] each ;

! : draw-page ( page -- ) "layer" tags-named [ draw-layer ] each ;

: even-integer ( number -- int )
    ceiling >integer dup even? [ 1 + ] unless ;

: page-dim ( page -- dim )
    [ "width" attr string>number even-integer ] [ "height" attr string>number even-integer 2array ] bi ;

! : make-page-image ( page quot: ( -- ) -- image )
!     [ page-dim ] dip
!     [ current-cairo set ] prepose make-bitmap-image ; inline

! : page>bitmap-image ( page -- image )
!     ! [ "width" attr string>number ceiling >integer ] [ "height" attr string>number ceiling >integer 2array ] [ ] tri
!     ! [ swap current-cairo set draw-page ] curry make-bitmap-image ;
!     dup [ draw-page ] curry make-page-image ;


SYMBOL: current-clips
! SYMBOL: last-audio-file
SINGLETON: +no-audio+

: with-current-clips ( quot -- )
    [ V{ } clone current-clips ] dip [
        ! +no-audio+ last-audio-file set
        +no-audio+ <clip> current-clips get push
    ] prepose with-variable ; inline

PREDICATE: longlongattr < string 2 tail-slice* "ll" sequence= ;
GENERIC: attr>number ( str -- number )
M: longlongattr attr>number 2 head-slice* string>number ;

! : stroke-clip-info ( stroke -- clip timestamp )
!     [ "fn" attr f or ] [ "ts" attr attr>number ] bi ;

: current-audio ( -- audio )
    current-clips get last audio>> ;

: update-current-clip ( audio -- )
    current-audio 2dup =
    [ 2drop ]
    [ +no-audio+?
      [ current-clips get last audio<< ]
      [ ! f
          dup f =
          [ drop ]
          [ <clip> current-clips get push ] if
      ] if
    ] if ;

    ! dup last-audio-file get
    ! { { [ 2dup = ] [ 2drop ] }
    !   { [ dup +no-clip+? ] [ current-clip ] }
    ! }

    ! = [ dup <clip> current-clips get push ] unless
    ! last-audio-file set ;

GENERIC: change-clip ( stroke -- )

! : ensure-clip ( -- )
!     current-clips get empty?
!     [ last-audio-file get <clip> current-clips get push ] when ;

! M: stroke change-clip  stroke-clip-info drop update-current-clip ;
M: stroke change-clip audio>> update-current-clip ;
M: image-elt change-clip drop ;

: all-layer-elements ( page -- seq )
    "layer" tags-named
    [ children-tags [ >element ] map ] map concat ;

: page-clips ( page -- seq )
    [
        ! all-page-strokes
        all-layer-elements
        [ [ change-clip ] [ current-clips get last elements>> push ] bi ] each
        current-clips get
    ] with-current-clips ;

SYMBOL: path-suffix
! pts/second
SYMBOL: stroke-speed
stroke-speed [ 70 ] initialize
! fps/second
SYMBOL: fps
fps [ 30 ] initialize

MEMO: (frame-time) ( fps -- seconds ) recip ;
: frame-time ( -- seconds ) fps get (frame-time) ;

: segment-time ( segment -- seconds )
    segment-length stroke-speed get /f ;

SYMBOL: segment-timer

:: with-image-surface ( dim quot -- )
    [
    dim malloc-bitmap-data :> bitmap-data
    bitmap-data dim <image-surface> &cairo_surface_destroy :> surface
    surface <cairo> &cairo_destroy dup check-cairo current-cairo set
    surface quot curry call
    ] with-destructors ; inline

:: write-frame ( path-prefix surface -- )
    surface dup cairo_surface_flush path-prefix path-suffix [ 0 or 1 + dup ] change "%s-%05d.png" sprintf cairo_surface_write_to_png (check-cairo) ;

:: (write-stroke-frames) ( path-prefix stroke surface -- )
    stroke [ color>> ] [ segments>> ] bi :> ( color segments )
    cr color set-source-color
    segments reverse clone >vector :> segments
    [ { [ segments empty? not ] [ segment-timer get 0 < ] } 0|| ]
    [
        segment-timer get 0 >=
        [ segments pop [ draw-segment ] [ segment-time segment-timer [ swap - ] change ] bi
        ] when
        segment-timer get 0 <=
        [ path-prefix surface write-frame
          segment-timer [ frame-time + ] change
        ] when
    ] while ;

SYMBOL: transparent-bg

:: draw-white-bg ( dim -- )
    cr COLOR: white set-source-color
    cr { 0 0 } dim <rect> fill-rect ;

! Create frames for one stroke only.
:: write-stroke-frames ( path-prefix dim stroke -- )
    path-prefix normalize-path :> path-prefix
    dim
    [| surface |
     dim draw-white-bg
     0 segment-timer set
     0 path-suffix set
     path-prefix stroke surface (write-stroke-frames)
    ] with-image-surface ;

: travel-speed ( -- pt/sec ) stroke-speed get 0.2 * ;

: inter-stroke-time ( stroke1 stroke2 -- seconds )
    [ segments>> last ] [ segments>> first ] bi* [ second ] bi@
    [ second ] [ first ] bi*
    distance travel-speed /f ;

SYMBOL: last-stroke
:: write-stroke-pause ( path-prefix surface stroke -- )
    last-stroke get
    [
        stroke inter-stroke-time fps get /f ceiling round >integer
        [ path-prefix surface write-frame ] times
    ] when* ;

: clip-strokes ( clip -- strokes ) elements>> [ stroke? ] filter ;
: clip-images ( clip -- image-elts ) elements>> [ image-elt? ] filter ;

:: (write-clip-frames) ( path-prefix clip surface -- )
    0 segment-timer set
    0 path-suffix set
    clip clip-images [ draw-element ] each
    clip clip-strokes
    [| stroke |
     path-prefix :> dir
     dir make-directories
     dir "/frame" append :> frame-prefix
     frame-prefix stroke surface (write-stroke-frames)
     frame-prefix surface stroke write-stroke-pause
     stroke last-stroke set
    ] each ;

! TBR
:: write-clip-frames ( path-prefix dim clip -- )
    path-prefix normalize-path :> path-prefix
    dim [| surface |
     dim draw-white-bg
     path-prefix clip surface (write-clip-frames)
    ] with-image-surface ;

! Relies ffmpeg
: render-frame-video ( fps in-pattern out-file -- )
    "ffmpeg -y -r %d -f image2 -i %s -vcodec mpeg2video -qscale 1 -qmin 1 -intra -an %s"
    sprintf try-process ;

: clip-frames>video ( frames-path outfile -- )
    [ fps get ] 2dip [ "/frame-%05d.png" append ] dip render-frame-video ;

:: (clip>video) ( outfile clip surface -- )
    "clip" temp-file :> dir
    dir make-directories
    dir qualified-directory-files [ delete-file ] each
    dir clip surface (write-clip-frames)
    dir outfile clip-frames>video ;

! TBR
:: clip>video ( outfile dim clip -- )
    "clip" temp-file :> dir
    dir make-directories
    dir qualified-directory-files [ delete-file ] each
    dim [| surface | outfile clip surface (clip>video) ] with-image-surface ;
    ! fps get dir "/frame-%05d.png" append outfile render-frame-video ;

: clip-audio ( clip -- path/f )
    audio>>
    [ f ] [ audio-path get prepend-path ] if-empty ;

: add-audio ( videofile audiofile outpath -- )
    "ffmpeg -y -i %s -i %s -c:v libx264 -c:a aac -crf 20 -preset:v veryslow %s" sprintf try-process ;

: append-to-file ( file str -- )
    [ print ] curry utf8 swap with-file-appender ;

! TODO: non-brain-amputated names and paths handling...
:: write-page-clips ( outpath page -- )
    outpath make-directories
    page [ page-dim ] [ page-clips ] bi :> ( dim clips )
    outpath "%s/clips.txt" sprintf :> list-file
    dim [| surface |
         transparent-bg get [ dim draw-white-bg ] unless
         clips [| clip i |
                outpath "%s/video" sprintf dup :> video-path make-directories
                outpath "%s/audio" sprintf dup :> audio-path make-directories
                outpath "%s/combined" sprintf dup :> combined-path make-directories
                i "clip%03d" sprintf :> clip-name
                outpath clip-name append-path "%s-frames" sprintf :> frames-dir
                video-path clip-name append-path "%s-video.mpg" sprintf :> clip-video-path
                audio-path clip-name append-path "%s-audio.ogg" sprintf :> clip-audio-path
                combined-path clip-name append-path "%s-combined.mp4" sprintf :> clip-final
                ! outpath i "%s/clip%03d-combined.mp4" sprintf :> clip-final
                ! outpath i "%s/clip%03d-audio.ogg" sprintf :> clip-audio-path
                frames-dir make-directories
                frames-dir clip surface (write-clip-frames)
                frames-dir clip-video-path clip-frames>video
                ! clip-video-path clip surface (clip>video)
                clip clip-audio [
                    clip-audio-path copy-file
                    clip-video-path clip-audio-path clip-final add-audio
                 ] when*
                list-file clip-final "file %s" sprintf append-to-file
               ] each-index
    ] with-image-surface ;

: rm-r ( path -- )
     dup file-info directory?
    [ [ qualified-directory-files [ rm-r ] each ] [ delete-directory ] bi ]
    [ delete-file ] if ;

ERROR: not-an-empty-directory path ;
: ensure-empty-path ( path -- path )
    normalize-path dup dup exists?
    [ dup { [ file-info directory? ] [ directory-files empty? ] } 1&&
      [ drop ]
      [
          dup \ not-an-empty-directory boa { { "Overwrite Contents" t } } throw-restarts
          [ [ rm-r ] [ make-directories ] bi ] [ drop ] if
      ] if
    ] [ make-directories ] if ;

: combine-clips ( page-dir page-num -- )
    [ drop "clips.txt" append-path ]
    [ "page%02d.mp4" sprintf append-path ] 2bi
    "ffmpeg -y -f concat -safe 0 -i %s -c copy %s" sprintf try-process ;

: make-project ( xml path -- )
    [ pages ] [ ensure-empty-path ] bi*
    swap [| page path i |
          path i "page%02d" sprintf append-path :> page-dir
          page-dir make-directories
          page-dir page write-page-clips
          page-dir i combine-clips
    ] with each-index ;

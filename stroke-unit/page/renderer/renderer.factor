USING: accessors arrays audio cairo-gadgets cairo.ffi calendar formatting
io.directories io.launcher io.pathnames kernel locals make math math.functions
math.parser models namespaces sequences stroke-unit.clip-renderer
stroke-unit.clips stroke-unit.models.clip-display stroke-unit.strokes
stroke-unit.util vectors xml.data ;

IN: stroke-unit.page.renderer


! * Render clips to page frames, no translation

: even-integer ( number -- int )
    ceiling >integer dup even? [ 1 + ] unless ;

: page-dim ( page -- dim )
    [ "width" attr string>number even-integer ] [ "height" attr string>number even-integer 2array ] bi ;

: render-frame-video ( fps in-pattern out-file -- )
    "ffmpeg -y -r %d -f image2 -i %s -vcodec mpeg2video -qscale 1 -qmin 1 -intra -an %s"
    sprintf try-process ;

: add-audio ( videofile audiofile outpath -- )
    "ffmpeg -y -i %s -i %s -c:v libx264 -c:a aac -crf 20 -preset:v veryslow %s" sprintf try-process ;

TUPLE: render-pause pause ;
C: <render-pause> render-pause
TUPLE: speed-change speed ;
C: <speed-change> speed-change

TUPLE: render-entry elements audio ;
C: <render-entry> render-entry

:: make-render-list ( clip-displays -- seq )
    ! V{ } clone +no-audio+ <render-entry> 1vector :> accum
    V{ } clone :> accum
    clip-displays [ dup :> display
                    [ clip>> ] [ stroke-speed>> ] [ draw-duration>> ] tri [ compute-model ] tri@ :> ( clip speed duration )
                    clip audio-path>> +no-audio+ or :> this-audio
                    accum ?last [ audio>> ] [ this-audio ] if* :> last-audio
                    this-audio +no-audio+? not :> has-audio?
                    accum empty?
                    has-audio? last-audio this-audio = not and
                    or [ V{ } clone this-audio <render-entry> accum push ] when
                    display pause-display?
                    [ duration duration>seconds <render-pause> accum last elements>> push ]
                    [ speed <speed-change> accum last elements>> push
                      clip elements>> accum last elements>> push-all
                    ] if
     ] each accum ;

! : make-render-list ( clip-displays -- seq )
!     render-entry
!     V{ } clone swap
!     [ dup pause-display?
!       [ draw-duration>> compute-model duration>seconds over last [ + ] change-pause drop ]
!       [ [ clip>> ] [ stroke-speed>> ] bi [ compute-model ] bi@
!         0 render-entry boa over push
!       ] if
!     ] each ;

GENERIC: render-element ( surface element -- )
M: stroke render-element
    [ nip add-inter-stroke-pause ]
    [ swap render-stroke-frames ]
    [ nip last-stroke set ] 2tri ;

M: render-pause render-element
    pause>> fps get * ceiling >integer
    swap [ add-frame ] curry times
    last-stroke off ;

M: speed-change render-element
    nip speed>> stroke-speed set ;

:: render-page-clip-frames ( page dim clip-displays path -- frames )
    dim page page-dim fit-to-scale :> scale
    ! clip clip-rect rect-bounds ceiling-dim :> ( loc dim )
    ! V{ } clone stroke-nums set
    ! 0 stroke-num set
    [ dim [| surface |
           ! cr loc first2 [ neg ] bi@ cairo_translate
           ! cr scale-factor get dup cairo_scale
           cr scale dup cairo_scale
           dim draw-white-bg
           clip-displays make-render-list
           [| entry i |
            ! entry clip>> :> clip
            ! ! clip-display clip>> compute-model :> clip
            ! entry stroke-speed>> :> speed
            ! clip-display stroke-speed>> compute-model :> speed
            path i "clip-%02d" sprintf append-path dup :> clip-dir
            frame-output-path set
            clip-dir make-directories
            0 path-suffix set
            0 segment-timer set
            last-stroke off
            entry elements>>
            [ surface swap render-element yield ] each
            ! clip clip-strokes :> strokes
            ! clip clip-images :> images
            ! images [ render-cairo* surface add-frame ] each
            ! speed stroke-speed [
            !     strokes [
            !         ! stroke-num inc
            !     ] each
            !     entry
            ! ] with-variable
            fps get clip-dir "frame-%05d.png" append-path
            clip-dir ".mpg" append dup :> video-file render-frame-video
            entry audio>> dup +no-audio+?
            [ drop ]
            [ video-file swap clip-dir ".mp4" append add-audio ] if
           ] each-index
          ] with-image-surface
    ] { } make ;

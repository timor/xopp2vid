USING: accessors arrays cairo-gadgets cairo.ffi formatting io.directories
io.pathnames kernel locals make math math.functions math.parser models
namespaces sequences stroke-unit.clip-renderer stroke-unit.util xml.data ;

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

TUPLE: render-entry clip stroke-speed pause ;

: make-render-list ( clip-displays -- seq )
    V{ } clone swap
    [ dup pause-display?
      [ draw-duration>> compute-model duration>seconds over last [ + ] change-pause drop ]
      [ [ clip>> ] [ stroke-speed>> ] bi [ compute-model ] bi@
        0 render-entry boa over push
      ] if
    ] each ;

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
            entry clip>> :> clip
            ! clip-display clip>> compute-model :> clip
            entry stroke-speed>> :> speed
            ! clip-display stroke-speed>> compute-model :> speed
            path i "clip-%02d" sprintf append-path dup :> clip-dir
            frame-output-path set
            clip-dir make-directories
            0 path-suffix set
            0 segment-timer set
            last-stroke off
            clip clip-strokes :> strokes
            clip clip-images :> images
            images [ render-cairo* surface add-frame ] each
            speed stroke-speed [
                strokes [
                    [ add-inter-stroke-pause ]
                    [ surface render-stroke-frames ]
                    [ last-stroke set ] tri
                    ! stroke-num inc
                ] each
                entry pause>> fps get * ceiling >integer
                [ surface add-frame ] times
            ] with-variable
            fps get clip-dir "frame-%05d.png" append-path
            clip-dir ".mpg" append dup :> video-file render-frame-video
            clip audio-path>> dup +no-audio+?
            [ drop ]
            [ video-file swap clip-dir ".mp4" append add-audio ] if
           ] each-index
          ] with-image-surface
    ] { } make ;

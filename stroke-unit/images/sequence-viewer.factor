USING: accessors animators calendar images.viewer kernel locals math
math.functions models.arrow models.range sequences ui.gadgets ui.gadgets.buttons
ui.gadgets.labels ui.gadgets.packs ui.gadgets.sliders ;

IN: images.sequence-viewer

:: <image-sequence-viewer> ( seq -- model gadget )
    0 0 0 seq length 1 - 1 <range> :> model
    model dup [ first floor >integer seq nth ] <arrow> <image-control> ;

! Animation is controlled using the animator slot

TUPLE: image-player < pack range animator ;

: <paused-label> ( model -- gadget )
    [ "⯈" "⏸" ? ] <arrow> <label-control> ;

:: <image-player> ( seq fps -- gadget )
    image-player new vertical >>orientation :> player
    seq <image-sequence-viewer> :> ( range viewer )
    range horizontal <slider> 1 >>line :> slider
    fps recip seconds 1 range <range-animator> :> animator
    player range >>range animator >>animator
    animator paused>> <paused-label> [ drop animator toggle-animation ] <button> :> play/pause
    viewer add-gadget
    <shelf> play/pause add-gadget slider add-gadget
    add-gadget ;

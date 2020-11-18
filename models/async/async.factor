USING: accessors kernel locals models models.arrow threads ;

IN: models.async


TUPLE: arrow& < arrow ;

M:: arrow& model-changed ( model observer -- )
    [ model observer compute-arrow-value observer set-model ] "Async Arrow" spawn drop ;

: <arrow&> ( model quot initial -- arrow )
    [ arrow& new-arrow ] dip >>value ;

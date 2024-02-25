module MyElements exposing (button)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input


button : List (Attribute msg) -> String -> msg -> Element msg
button attrs label onPress =
    Input.button
        ([ Background.color (rgb 0.5 0.5 1)
         , Border.width 1
         , Element.focused [ Background.color (rgb 1 1 0) ]
         , Element.mouseOver [ Background.color (rgb 1 1 0) ]
         ]
            ++ attrs
        )
        { onPress = Just onPress
        , label = text label
        }

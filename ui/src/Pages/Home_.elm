module Pages.Home_ exposing (page)

import Element exposing (..)
import View exposing (View)


page : View msg
page =
    { title = "Elm on Shuttle"
    , attributes = []
    , element = el [ centerX, centerY ] (text "Hello, Elm UI ✨!")
    }

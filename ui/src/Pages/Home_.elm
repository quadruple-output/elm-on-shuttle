module Pages.Home_ exposing (Model, Msg, page)

import Element exposing (..)
import Http
import Page exposing (Page)
import Platform.Cmd as Cmd
import View exposing (View)


page : Page Model Msg
page =
    Page.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- INIT


type alias Model =
    { greeting : Maybe (Result Http.Error String) }


init : ( Model, Cmd Msg )
init =
    ( { greeting = Nothing }
    , server_api_get_greeting { onResponse = ReceivedGreeting }
    )


server_api_get_greeting : { onResponse : Result Http.Error String -> msg } -> Cmd msg
server_api_get_greeting params =
    Http.get
        { url = "/api/greet"
        , expect = Http.expectString params.onResponse
        }



-- UPDATE


type Msg
    = NoOp
    | ReceivedGreeting (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Cmd.none
            )

        ReceivedGreeting greeting ->
            ( { model | greeting = Just greeting }
            , Cmd.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Elm on Shuttle"
    , attributes = []
    , element =
        el [ centerX, centerY ] <| show_greeting model.greeting
    }


show_greeting : Maybe (Result Http.Error String) -> Element msg
show_greeting maybe_result_string =
    case maybe_result_string of
        Nothing ->
            text "<wait...>"

        Just (Ok greeting) ->
            text greeting

        Just (Err _) ->
            text "<could not get greeting from server>"

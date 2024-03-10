module Pages.Home_ exposing (Model, Msg, page)

import Dict
import Effect exposing (Effect)
import Element exposing (..)
import Http
import MyElements
import Page exposing (Page)
import Route exposing (Route)
import Route.Path exposing (Path)
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page _ _ =
    Page.new
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }


type alias Model =
    { greeting : Maybe (Result Http.Error String) }


type Msg
    = NoOp
    | ReceivedGreeting (Result Http.Error String)
    | Navigate Path


init : () -> ( Model, Effect Msg )
init _ =
    ( { greeting = Nothing }
    , Effect.sendCmd <|
        Http.get
            { url = "/api/greet"
            , expect = Http.expectString ReceivedGreeting
            }
    )


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )

        ReceivedGreeting greeting ->
            ( { model | greeting = Just greeting }, Effect.none )

        Navigate path ->
            ( model, Effect.pushRoute { path = path, query = Dict.empty, hash = Nothing } )


view : Model -> View Msg
view model =
    { title = "Elm on Shuttle"
    , attributes = []
    , element =
        el [ centerX, centerY ] <|
            column []
                [ show_greeting model.greeting
                , MyElements.button [ centerX ] "Sign-In" (Navigate Route.Path.SignIn)

                -- , Element.link [] { url = "/sign-in", label = text "Sign-In" }
                ]
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

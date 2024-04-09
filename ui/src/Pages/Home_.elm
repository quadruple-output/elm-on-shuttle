module Pages.Home_ exposing (Model, Msg, page)

import Api.Greeting exposing (Greeting)
import Dict
import Effect exposing (Effect)
import Element exposing (..)
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
    { greeting : Greeting }


type Msg
    = ReceivedGreeting Greeting
    | Navigate Path


init : () -> ( Model, Effect Msg )
init _ =
    ( { greeting = Api.Greeting.Awaiting }
    , Effect.sendCmd <| Api.Greeting.request ReceivedGreeting
    )


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ReceivedGreeting greeting ->
            ( { model | greeting = greeting }, Effect.none )

        Navigate path ->
            ( model, Effect.pushRoute { path = path, query = Dict.empty, hash = Nothing } )


view : Model -> View Msg
view model =
    { title = "Elm on Shuttle"
    , attributes = []
    , element =
        el [ centerX, centerY ] <|
            column []
                [ viewGreeting model.greeting
                , MyElements.button [ centerX ] "Sign-In" (Navigate Route.Path.SignIn)
                ]
    }


viewGreeting : Greeting -> Element msg
viewGreeting greeting =
    case greeting of
        Api.Greeting.Awaiting ->
            text "<wait...>"

        Api.Greeting.Got message ->
            text message

        Api.Greeting.Failure errMessage ->
            text <| "<" ++ errMessage ++ ">"

module Pages.Home_ exposing (Model, Msg, page)

import Api.Greeting
import Dict
import Effect exposing (Effect)
import Element exposing (..)
import MyElements
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path exposing (Path)
import Shared
import ToString
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared _ =
    Page.new
        { init = init shared
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view shared
        }


type alias Model =
    { githubAccessToken : Maybe String
    , greeting : WebData String
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared _ =
    let
        model =
            initModel shared
    in
    ( { model | greeting = RemoteData.Loading }
    , Effect.sendCmd <| Api.Greeting.request ReceivedGreeting
    )


initModel : Shared.Model -> Model
initModel shared =
    { githubAccessToken = shared.githubAccessToken
    , greeting = RemoteData.NotAsked
    }


type Msg
    = ReceivedGreeting (WebData String)
    | Navigate Path


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ReceivedGreeting greeting ->
            ( { model | greeting = greeting }, Effect.none )

        Navigate path ->
            ( model, Effect.pushRoute { path = path, query = Dict.empty, hash = Nothing } )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = "Elm on Shuttle"
    , attributes = []
    , element =
        el [ centerX, centerY ] <|
            column [ spacing 20 ]
                [ viewGreeting model.greeting
                , viewSignInStatus shared
                ]
    }


viewSignInStatus : Shared.Model -> Element Msg
viewSignInStatus shared =
    case shared.user of
        RemoteData.Loading ->
            text "<checking login status...>"

        RemoteData.Success user ->
            text <| "Logged in as " ++ user.name

        RemoteData.Failure errMessage ->
            column []
                [ text <| "Error getting user data: " ++ ToString.httpError errMessage
                , viewSignInButton
                ]

        RemoteData.NotAsked ->
            column []
                [ text "not logged in"
                , viewSignInButton
                ]


viewSignInButton : Element Msg
viewSignInButton =
    MyElements.button [ centerX ] "Sign-In" (Navigate Route.Path.SignIn)


viewGreeting : WebData String -> Element msg
viewGreeting greeting =
    case greeting of
        RemoteData.Loading ->
            text "<hang on...>"

        RemoteData.Success message ->
            text message

        RemoteData.Failure errMessage ->
            text <| "<" ++ ToString.httpError errMessage ++ ">"

        RemoteData.NotAsked ->
            text <| ""

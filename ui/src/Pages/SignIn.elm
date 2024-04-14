--
-- Thanks to Bill St. Clair for the Elm OAuth Middleware example:
-- https://github.com/billstclair/elm-oauth-middleware/blob/3.0.0/example/example.elm
--


module Pages.SignIn exposing (Model, Msg, page)

import Effect exposing (Effect)
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Region exposing (heading)
import GitHub
import MyElements as My
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Shared.Msg exposing (Msg(..))
import ToString
import Url exposing (Url)
import User exposing (UserData)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init shared route.url
        , subscriptions = \_ -> Sub.none
        , update = update
        , view = view
        }


type alias Model =
    { myUrl : Url
    , githubAccessToken : Maybe String
    , user : WebData UserData
    , message : Maybe String
    , receivedMsg : List Msg
    }


init : Shared.Model -> Url -> () -> ( Model, Effect Msg )
init shared url _ =
    ( initModel shared url
    , Effect.none
    )


initModel : Shared.Model -> Url -> Model
initModel shared url =
    { myUrl = url
    , githubAccessToken = shared.githubAccessToken
    , user = shared.user
    , message = Nothing
    , receivedMsg = []
    }


type Msg
    = Login
    | GetUser
    | ReceiveUser (WebData UserData)


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    let
        model =
            { m | receivedMsg = m.receivedMsg ++ [ msg ] }
    in
    case msg of
        Login ->
            ( model, Effect.loadExternalUrl <| GitHub.oAuthLoginUrl model.myUrl )

        GetUser ->
            updateRequestUser model

        ReceiveUser result ->
            updateReceiveUser model result


updateRequestUser : Model -> ( Model, Effect Msg )
updateRequestUser model =
    case model.githubAccessToken of
        Just token ->
            ( model, Effect.sendCmd <| GitHub.getUser token ReceiveUser )

        Nothing ->
            ( { model | message = Just "You must login before requesting user data." }
            , Effect.none
            )


updateReceiveUser : Model -> WebData UserData -> ( Model, Effect Msg )
updateReceiveUser model webdata =
    case webdata of
        RemoteData.Loading ->
            Debug.todo ""

        RemoteData.Failure err ->
            ( { model | message = Just <| ToString.httpError err }
            , Effect.none
            )

        RemoteData.Success user ->
            ( { model | message = Just <| "Hello " ++ user.name }
            , Effect.none
            )

        RemoteData.NotAsked ->
            ( model, Effect.none )


view : Model -> View Msg
view model =
    { title = "Elm on Shuttle"
    , attributes = [ height fill, width fill, padding 10 ]
    , element =
        column [ width fill ] <|
            viewMain
                :: viewMessage model
    }


viewMain : Element Msg
viewMain =
    column [ centerX ]
        [ el [ heading 1, Font.heavy ] <| text "OAuth Login Page"
        , column [ centerX ]
            [ My.button [ centerX ] "Login with GitHub" Login
            , My.button [ centerX ] "Get User" GetUser
            ]
        ]


viewMessage : Model -> List (Element msg)
viewMessage model =
    case model.message of
        Just msg ->
            [ el [ paddingEach { top = 10, right = 0, bottom = 0, left = 0 } ] <|
                Element.paragraph [] <|
                    [ el [ Background.color (rgb 1 0 0), Font.color (rgb 1 1 0) ] <|
                        text "Info:"
                    , el [ Font.color (rgb 1 0 0) ] <|
                        text (" " ++ msg)
                    ]
            ]

        Nothing ->
            []

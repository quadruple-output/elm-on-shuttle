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
    { greeting : String
    }


init : ( Model, Cmd Msg )
init =
    ( { greeting = "<waiting for server>" }
    , server_api_get_greeting
    )


server_api_get_greeting : Cmd Msg
server_api_get_greeting =
    Http.get { url = "/api/greet", expect = Http.expectString response_to_rcvd_greeting }


response_to_rcvd_greeting : Result Http.Error String -> Msg
response_to_rcvd_greeting result =
    ReceivedGreeting
        (case result of
            Ok greeting ->
                greeting

            Err _ ->
                "<sorry, cannot greet>"
        )



-- UPDATE


type Msg
    = NoOp
    | ReceivedGreeting String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Cmd.none
            )

        ReceivedGreeting greeting ->
            ( { model | greeting = greeting }
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
    , element = el [ centerX, centerY ] (text model.greeting)
    }

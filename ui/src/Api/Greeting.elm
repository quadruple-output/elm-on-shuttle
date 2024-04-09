module Api.Greeting exposing (Greeting(..), request)

import Http
import ToString


type Greeting
    = Awaiting
    | Got String
    | Failure String


request : (Greeting -> msg) -> Cmd msg
request greetingToMsg =
    Http.get { url = "/api/greet", expect = Http.expectString (resultToGreeting >> greetingToMsg) }


resultToGreeting : Result Http.Error String -> Greeting
resultToGreeting result =
    case result of
        Ok greeting ->
            Got greeting

        Err err ->
            Failure <| ToString.httpError err

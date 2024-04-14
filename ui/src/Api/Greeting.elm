module Api.Greeting exposing (request)

import Http
import RemoteData exposing (WebData)


request : (WebData String -> msg) -> Cmd msg
request greetingToMsg =
    Http.get
        { url = "/api/greet"
        , expect = Http.expectString (RemoteData.fromResult >> greetingToMsg)
        }

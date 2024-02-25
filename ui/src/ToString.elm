module ToString exposing (httpError)

import Http


httpError : Http.Error -> String
httpError err =
    case err of
        Http.BadUrl url ->
            "Bad URL: '" ++ url ++ "'"

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network Error"

        Http.BadStatus status ->
            "Bad HTTP status code " ++ String.fromInt status

        Http.BadBody body ->
            "Bad Body: " ++ body

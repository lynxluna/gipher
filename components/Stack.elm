module Stack where

import Json.Decode as Json exposing ( (:=) )
import Http exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Effects exposing (..)
import Task exposing (..)
import Html.Events exposing ( onClick, onMouseDown, onMouseUp )
import StackCard
import ElmFire
import Gif

type alias Model = List StackCard.Model

init: Bool -> ( Model, Effects Action )
init requestGifs =
  if requestGifs then
    ( [], fetchNewGifs )
  else
    ( [], Effects.none )

type Action = Fetch
  | NewGifs (Maybe Model)
  | StackCard StackCard.Action
  | NextCard Bool
  | Remove Gif.Model
  | NoOp

fetchNewGifs: Effects Action
fetchNewGifs =
  Http.get decodeList getUrl
    |> Task.toMaybe
    |> Task.map NewGifs
    |> Effects.task

getUrl: String
getUrl =
  Http.url
    "https://api.giphy.com/v1/gifs/trending"
    [ ( "api_key", "dc6zaTOxFJmzC" ), ( "limit", "400" ) ]

decodeList: Json.Decoder Model
decodeList =
  Json.object1 identity
    ( "data" := Json.list StackCard.decodeModel )

removeLikedGifs: List ( Gif.Model ) -> Model -> Model
removeLikedGifs likedGifs gifs =
  let idsList = List.map (\gif -> gif.id) likedGifs
      filteredList = List.filter (\item -> not (List.member item.gif.id idsList)) gifs
  in
    filteredList

update: Action
        -> Model
        -> List ( Gif.Model )
        -> { c | root : ElmFire.Location, user : Maybe { a | uid : String }, window : ( Int, Int ) }
        -> ( Model, Effects Action )
update action model likedGifs global =
  case action of
    Fetch ->
      init True

    NewGifs maybeGifs ->
      case maybeGifs of
        Just gifs ->
          let filteredGifs = removeLikedGifs likedGifs gifs
          in
            ( filteredGifs, Effects.none )

        Nothing ->
          ( init False )

    StackCard gifAction ->
      case (List.head model) of
        Just gif ->
          let ( gif, effects ) = StackCard.update gifAction gif global
          in
           ( gif :: List.drop 1 model, Effects.map StackCard effects )

        Nothing -> ( model, Effects.none )

    Remove gif ->
      let newModel = List.filter (\item -> not (item.gif.id == gif.id)) model
      in
        ( newModel, Effects.none )

    NextCard hasBeenLiked ->
      let effects = case (List.head model) of
        Just gif ->
          case global.user of
            Just user ->
              let firebaseLocation = ElmFire.sub ("likedGifs/" ++ user.uid) global.root
              in
                if hasBeenLiked then
                  ElmFire.set (Gif.encodeGif gif.gif) (ElmFire.push firebaseLocation)
                    |> Task.toMaybe
                    |> Task.map (\_ -> NoOp)
                    |> Effects.task
                else
                  Effects.none

            Nothing ->
              Effects.none
        Nothing ->
          Effects.none
      in
        ( List.drop 1 model, effects )

    NoOp -> ( model, Effects.none )


view: Signal.Address Action -> List StackCard.Model -> a -> Html
view address model global =
  let currentGif = List.head model
      tail = List.tail model
      error = div [ flexContainerStyle ] [ div [] [ text "No more gifs today" ] ]
      gifComponent = case currentGif of
        Just first ->
          case tail of
            Just tail ->
              div []
                (StackCard.view (Signal.forwardTo address StackCard) first::
                (List.reverse (List.indexedMap (\id gif -> Gif.stackView id gif.gif)
                                               (List.take 5 tail))))
            Nothing -> error

        Nothing -> error
  in
    div [ flexContainerStyle ] [ gifComponent
            , div [ buttonsContainer ]
              [ i [ class "material-icons hover-btn"
                  , crossStyle
                  , onClick address (StackCard StackCard.SwipeLeft) ] [ text "clear" ]
              , i [ class "material-icons hover-btn"
                  , tickStyle
                  , onClick address (StackCard StackCard.SwipeRight) ] [ text "favorite" ] ] ]

crossStyle: Attribute
crossStyle =
  style [ ("font-size", "50px" )
        , ("color", "#FF2300" )
        , ("cursor", "pointer" )
        , ("padding", "9px 11px" )
        , ("transform", "translateX(2px)" )
        , ("border", "6px solid #BBBFBE" )
        , ("font-weight", "bold" )
        , ("border-radius", "50%" ) ]

tickStyle: Attribute
tickStyle =
  style [ ("font-size", "50px" )
        , ("color", "#00FF95" )
        , ("cursor", "pointer" )
        , ("padding", "9px 11px" )
        , ("transform", "translateX(-2px)" )
        , ("border", "6px solid #BBBFBE" )
        , ("border-radius", "50%" ) ]

buttonsContainer: Attribute
buttonsContainer =
  style [ ( "font-size", "50px" )
        , ( "display", "flex" )
        , ( "margin-top", "20px" )
        , ( "justify-content", "space-around" ) ]

flexContainerStyle: Attribute
flexContainerStyle =
  style [ ( "display", "flex" )
        , ( "flex-direction", "column" )
        , ( "align-content", "center" )
        , ( "justify-content", "center" )
        , ( "align-items", "center" )
        , ( "padding-top", "130px") ]

btnAttributes: Signal.Address Action -> List ( Attribute )
btnAttributes address =
  [ onClick address Fetch
  , style
    [ ( "font-size", "20px" )
    , ( "color", "white" )
    , ( "cursor", "pointer" )
    , ( "display", "inline-block" )
    , ( "width", "100px" )
    , ( "text-align", "center" )
    , ( "border", "1px solid white" )
    , ( "border-radius", "3px" )
    , ( "padding", "10px" )
    , ( "margin-top", "20px" ) ] ]

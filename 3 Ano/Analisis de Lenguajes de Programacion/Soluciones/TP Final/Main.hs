-- happy Parser.y & ghci Main.hs -XRankNTypes
-- runhaskell --ghc-arg=-XRankNTypes Main.hs examples/langton/langton.atm examples/langton/langton.ini

module Main where

import Types
import Matrix
import Rules
import Parser (lexer, parse)
import System.Environment (getArgs, getProgName)
import UI.NCurses -- apt install c2hs & cabal install ncurses 

parseCmd :: [String] -> (String, String, Frontier, Int, Int, Int, Int)
parseCmd (a:i:[]) = (a,i,Wrap,0,0,1,0)
parseCmd (a:i:f:[]) = (a,i,read f,0,0,1,0)
parseCmd (a:i:f:s:[]) = (a,i,read f,read s,0,1,0)
parseCmd (a:i:f:s:e:[]) = (a,i,read f,read s,read e,1,0)
parseCmd (a:i:f:s:e:k:[]) = (a,i,read f,read s,read e,read k,0)
parseCmd (a:i:f:s:e:k:t:r) = (a,i,read f,read s,read e,read k, read t)

readFiles args =
  do let (definition,initial,frontier,start,frames,skip,time) = parseCmd args
     a <- readFile definition
     s <- readFile initial
     let (states, rules) = parse $ lexer a
         m = fromString s -- Divide por salto de linea y rellana espacios
         r = toInteger $ rows m + 3 -- Filas extra para el borde y generacion
         c = toInteger $ cols m + 2 -- Columnas extra para el borde
         animation = if frames == 0 then x else take frames x
                     where x = drop start $ iterate (step $ makeTransition frontier rules) m
     return (states, r, c, animation, start, toInteger time, skip)

startCurses (states,r,c,animation,start,time,skip) =
  runCurses $ do
    colors <- sequence [newColorID c1 c2 i | ((_, _, c1, c2), i) <- zip states [1..]]
    setCursorMode CursorInvisible
    w <- newWindow r c 0 0
    play animation w start (zipWith (\(c1,c2,_,_) c -> (c1,c2,c)) states colors) time skip

main :: IO ()
main = do prog <- getProgName
          args <- getArgs
          if  (length args) < 2
          then do putStrLn $ "Error de sintaxis.\nUso correcto: " ++ prog
                              ++ " AUTOMATA INICIAL [Frontier Start Frames Skip Time]"
          else do config <- readFiles args
                  startCurses config

play :: Animation -> Window -> Int -> ColorTable -> Integer -> Int -> Curses ()
play []     w g _ s x = do updateWindow w $ do
                             moveCursor 1 1
                             drawString $ "Generacion: " ++ show g ++ ". Fin de la simulacion."
                           render
                           getEvent w Nothing
                           return ()
play (f:fs) w g t s x = do updateWindow w $ do
                             drawBorder Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
                             moveCursor 1 1
                             drawString $ "Generacion: " ++ show g
                             frame 2 f t
                           render
                           e <- getEvent w (Just 0)
                           case e of
                             (Just (EventCharacter ' ')) -> do getEvent w Nothing
                                                               play (drop x fs) w (g+x) t s x
                             _ -> do getEvent w (Just s)
                                     play (drop x fs) w (g+x) t s x

frame :: Integer -> Matrix -> ColorTable -> Update ()
frame _ []         _ = do moveCursor 0 0
frame r (row:rest) t = do moveCursor r 1
                          mapM_ drawGlyph [paint c t | c <- row]
                          frame (r+1) rest t

paint :: Char -> ColorTable -> Glyph
paint c l = let l' = filter ((==c) . fst') l
            in case l' of
               [] -> Glyph c []
               (_, c', color):ls -> Glyph c' [AttributeColor color]
            where fst' (x,_,_) = x

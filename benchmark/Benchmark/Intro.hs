{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Benchmark.Intro(main) where

import Benchmark.Args
import System.IO.Extra
import Control.Monad.Extra
import System.Time.Extra
import Data.List.Extra
import System.Directory
import Development.Shake.Command
import Development.Rattle



writeMain :: Int -> Int -> IO ()
writeMain real fake = writeFile "main.c" $ unlines
    ["#include <stdio.h>"
    ,"char* util();"
    ,"void main(){printf(\"%s" ++ replicate real ' ' ++ "\", util());}" ++ replicate fake ' ']

writeUtil :: Int -> Int -> IO ()
writeUtil real fake = writeFile "util.c" $ unlines
    ["char* util(){return \"test" ++ replicate real ' ' ++ "\";}" ++ replicate fake ' ']

main :: Args -> IO ()
main Args{..} = withTempDir $ \dir -> withCurrentDirectory dir $ do
    writeFile "gcc.sh" "sleep 1 && gcc $*"
    cmd_ "chmod +x gcc.sh"
    let commands =
            [("-o main.exe main.o util.o","main.exe: main.o util.o")
            ,("-c util.c","util.o: util.c")
            ,("-c main.c","main.o: main.c")
            ]

    writeFile "Makefile" $ unlines $ concat
        [[b,"\t./gcc.sh " ++ a] | (a,b) <- commands]
    let rattleCmds = reverse $ map ((++) "./gcc.sh " . fst) commands

    let clean = do
            whenM (doesDirectoryExist ".rattle") $
                removeDirectoryRecursive ".rattle"
            forM_ ["main.o","util.o","main.exe"] $ \x ->
                whenM (doesFileExist x) $
                    removeFile x

    forM_ (threads `orNull` [1..4]) $ \j -> do
        let make = cmd_ "make" ["-j" ++ show j] (EchoStdout False)
        let opts = rattleOptions{rattleProcesses=j, rattleUI=Just RattleQuiet, rattleNamedDirs=[]}
        let rattle = rattleRun opts $ mapM_ (cmd Shell) rattleCmds

        forM_ [("make  ",make),("rattle",rattle)] $ \(name,act) -> when (trim name `elemOrNull` step) $ do
            putStr $ name ++ " -j" ++ show j ++ ": "
            hFlush stdout
            clean
            writeMain 0 0
            writeUtil 0 0
            (t1, _) <- duration act
            (t2, _) <- duration act
            writeMain 0 1
            (t3, _) <- duration act
            writeMain 1 1
            (t4, _) <- duration act
            writeMain 2 1
            writeUtil 1 0
            (t5, _) <- duration act
            putStrLn $ unwords $ map showDuration [t1,t2,t3,t4,t5]

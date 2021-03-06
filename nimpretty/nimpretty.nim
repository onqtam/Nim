#
#
#           The Nim Compiler
#        (c) Copyright 2017 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Standard tool for pretty printing.

when not defined(nimpretty):
  {.error: "This needs to be compiled with --define:nimPretty".}

import ../compiler / [idents, msgs, syntaxes, options, pathutils, layouter]

import parseopt, strutils, os

const
  Version = "0.2"
  Usage = "nimpretty - Nim Pretty Printer Version " & Version & """

  (c) 2017 Andreas Rumpf
Usage:
  nimpretty [options] file.nim
Options:
  --out:file            set the output file (default: overwrite the input file)
  --indent:N[=0]        set the number of spaces that is used for indentation
                        --indent:0 means autodetection (default behaviour)
  --maxLineLen:N        set the desired maximum line length (default: 80)
  --version             show the version
  --help                show this help
"""

proc writeHelp() =
  stdout.write(Usage)
  stdout.flushFile()
  quit(0)

proc writeVersion() =
  stdout.write(Version & "\n")
  stdout.flushFile()
  quit(0)

type
  PrettyOptions = object
    indWidth: int
    maxLineLen: int

proc prettyPrint(infile, outfile: string, opt: PrettyOptions) =
  var conf = newConfigRef()
  let fileIdx = fileInfoIdx(conf, AbsoluteFile infile)
  let f = splitFile(outfile.expandTilde)
  conf.outFile = RelativeFile f.name & f.ext
  conf.outDir = toAbsoluteDir f.dir
  var p: TParsers
  p.parser.em.indWidth = opt.indWidth
  if setupParsers(p, fileIdx, newIdentCache(), conf):
    p.parser.em.maxLineLen = opt.maxLineLen
    discard parseAll(p)
    closeParsers(p)

proc main =
  var infile, outfile: string
  var backup = false
    # when `on`, create a backup file of input in case
    # `prettyPrint` could over-write it (note that the backup may happen even
    # if input is not actually over-written, when nimpretty is a noop).
    # --backup was un-documented (rely on git instead).
  var opt: PrettyOptions
  opt.maxLineLen = 80
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      infile = key.addFileExt(".nim")
    of cmdLongOption, cmdShortOption:
      case normalize(key)
      of "help", "h": writeHelp()
      of "version", "v": writeVersion()
      of "backup": backup = parseBool(val)
      of "output", "o", "out": outfile = val
      of "indent": opt.indWidth = parseInt(val)
      of "maxlinelen": opt.maxLineLen = parseInt(val)
      else: writeHelp()
    of cmdEnd: assert(false) # cannot happen
  if infile.len == 0:
    quit "[Error] no input file."
  if outfile.len == 0:
    outfile = infile
  if not existsFile(outfile) or not sameFile(infile, outfile):
    backup = false # no backup needed since won't be over-written
  if backup:
    let infileBackup = infile & ".backup" # works with .nim or .nims
    echo "writing backup " & infile & " > " & infileBackup
    os.copyFile(source = infile, dest = infileBackup)
  prettyPrint(infile, outfile, opt)

main()

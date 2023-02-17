include ../unreal/prelude

import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, strscans]
import ../../buildscripts/nimforueconfig




proc getHeaderFromPath(path : string) : Option[string] = 
  if fileExists(path):
    some readFile(path)
  else: none(string)

proc getIncludesFromHeader(header : string) : seq[string] = 
  let lines = header.split("\n")
  func getHeaderFromIncludeLine(line: string) : string = 
    line.multiReplace(@[
      ("#include", ""),
      ("<", ""),
      (">", ""),
      ("\"", ""),
      ("\"", ""),
    ]).strip()
    
  lines
    .filterIt(it.startsWith("#include"))
    .map(getHeaderFromIncludeLine)

func getModuleRelativePathVariations(moduleName, moduleRelativePath:string) : string = 
    var variations = @["Public"]
    if moduleName == "Engine":
      variations.add("Classes")
    
    var path = moduleRelativePath
    for variation in variations:
      path = path.replace(variation & "/", "")
    path

func isModuleRelativePathInHeaders*(moduleName, moduleRelativePath:string, headers:seq[string]) : bool = 
  let path = getModuleRelativePathVariations(moduleName, moduleRelativePath)
  headers.contains(path)

#returns the absolute path of all the include paths
proc getAllIncludePaths*() : seq[string] = getNimForUEConfig().getUEHeadersIncludePaths()



proc getHeaderIncludesFromIncludePaths(header:string, includePaths:seq[string]) : seq[string] = 
  for path in includePaths:
    let headerPath = path / header
    let header = getHeaderFromPath(headerPath)
    if header.isSome:
      return getIncludesFromHeader(header.get)
  newSeq[string]()


proc traverseAllIncludes*(entryPoint:string, includePaths:seq[string], visited:seq[string], depth=0, maxDepth=3) : seq[string] = 
  let includes = getHeaderIncludesFromIncludePaths(entryPoint, includePaths).filterIt(it notin visited)
  let newVisited = (visited & includes).deduplicate()
  if depth >= maxDepth:
    return newVisited
  includes
    .mapIt(traverseAllIncludes(it, includePaths, newVisited, depth+1))
    .flatten()


proc saveIncludesToFile*(path:string, includes:seq[string]) = 
  writeFile(path, $includes.toJson())


proc getPCHIncludes*() : seq[string] = 
  #if this takes too long can be cached into a file and
  let includePaths = getNimForUEConfig().getUEHeadersIncludePaths()
  UE_Log &"Includes found on the PCH: {includePaths.len}"
  let pchIncludes =  traverseAllIncludes("UEDeps.h", includePaths, @[]).deduplicate()
  pchIncludes
import zstd/[common, compress]

type ZstdFileWriter* = object
  file: File
  cstream: ptr ZSTD_CStream
  outBuf: seq[byte]

proc checkZstd(res: csize_t): csize_t {.discardable.} =
  if ZSTD_isError(res):
    raise newException(IOError, "zstd error: " & $ZSTD_getErrorName(res))
  res

proc openZstdFileWriter*(fileName: string, level: int = 3): ZstdFileWriter =
  result.file = open(fileName, fmWrite)
  result.cstream = ZSTD_createCStream()
  doAssert result.cstream != nil, "Failed to create zstd compression stream"
  checkZstd ZSTD_initCStream(result.cstream, level.cint)
  result.outBuf = newSeq[byte](ZSTD_CStreamOutSize())

proc drainOutBuf(writer: var ZstdFileWriter, outBuf: var ZSTD_outBuffer) =
  if outBuf.pos > 0:
    let written = writer.file.writeBuffer(addr writer.outBuf[0], outBuf.pos.int)
    doAssert written == outBuf.pos.int, "Failed to write compressed data to file"
  outBuf.pos = 0

proc newOutBuffer(writer: var ZstdFileWriter): ZSTD_outBuffer =
  ZSTD_outBuffer(dst: addr writer.outBuf[0], size: writer.outBuf.len.csize_t, pos: 0)

proc write*(writer: var ZstdFileWriter, s: string) =
  ## Compresses `s` and flushes it to disk, so the file stays decodable up to
  ## and including this write even if the process dies later.
  if s.len == 0:
    return
  var
    inBuf =
      ZSTD_inBuffer(src: cast[ptr byte](unsafeAddr s[0]), size: s.len.csize_t, pos: 0)
    outBuf = writer.newOutBuffer
  while inBuf.pos < inBuf.size:
    checkZstd ZSTD_compressStream(writer.cstream, addr outBuf, addr inBuf)
    writer.drainOutBuf(outBuf)
  while checkZstd(ZSTD_flushStream(writer.cstream, addr outBuf)) > 0:
    writer.drainOutBuf(outBuf)
  writer.drainOutBuf(outBuf)
  writer.file.flushFile

proc close*(writer: var ZstdFileWriter) =
  if writer.cstream != nil:
    var outBuf = writer.newOutBuffer
    while checkZstd(ZSTD_endStream(writer.cstream, addr outBuf)) > 0:
      writer.drainOutBuf(outBuf)
    writer.drainOutBuf(outBuf)
    discard ZSTD_freeCStream(writer.cstream)
    writer.cstream = nil
  if writer.file != nil:
    writer.file.close
    writer.file = nil

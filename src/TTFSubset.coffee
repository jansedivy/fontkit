_ = require 'lodash'
Glyph = require './Glyph'
Subset = require './Subset'
Directory = require './Directory'
Tables = require './tables'

class TTFSubset extends Subset
  _addGlyph: (gid) ->
    glyf = @font.getGlyph(gid)._decode()
    
    # get the offset to the glyph from the loca table
    stream = @font.stream
    pos = stream.pos
  
    glyfOffset = @font.directory.tables.glyf.offset
    curOffset = @font.loca.offsets[gid]
    nextOffset = @font.loca.offsets[gid + 1]
  
    # parse the glyph from the glyf table
    stream.pos = glyfOffset + curOffset
    buffer = stream.readBuffer(nextOffset - curOffset)
    stream.pos = pos
  
    # if it is a compound glyph, include its components
    if glyf.numberOfContours < 0
      for component in glyf.components
        gid = @includeGlyph component.glyphID
        buffer.writeUInt16BE gid, component.pos
        
    @glyf.push buffer
    @loca.offsets.push @offset
    
    if gid < @font.hmtx.metrics.length
      @hmtx.metrics.push @font.hmtx.metrics[gid]
    else
      @hmtx.metrics.push
        advanceWidth: @font.hmtx.metrics[@font.hmtx.metrics.length - 1].advanceWidth
        leftSideBearing: @font.hmtx.leftSideBearings[gid - @font.hmtx.metrics.length]
      
    @offset += buffer.length
    return @glyf.length - 1
          
  encode: (stream) ->      
    # tables required by PDF spec: 
    #   head, hhea, loca, maxp, cvt , prep, glyf, hmtx, fpgm
    #
    # additional tables required for standalone fonts: 
    #   name, cmap, OS/2, post
              
    @glyf = []
    @offset = 0
    @loca = 
      offsets: []
    
    @hmtx =
      metrics: []
      leftSideBearings: []
      
    # include all the glyphs
    # not using a for loop because we need to support adding more
    # glyphs to the array as we go, and CoffeeScript caches the length.
    i = 0
    while i < @glyphs.length
      @_addGlyph @glyphs[i++]
      
    maxp = _.cloneDeep @font.maxp
    maxp.numGlyphs = @glyf.length
      
    @loca.offsets.push @offset
    Tables.loca.preEncode.call @loca
    
    head = _.cloneDeep @font.head
    head.indexToLocFormat = @loca.version
    
    hhea = _.cloneDeep @font.hhea
    hhea.numberOfMetrics = @hmtx.metrics.length
        
    # map = []
    # for index in [0...256]
    #     if index < @numGlyphs
    #         map[index] = index
    #     else
    #         map[index] = 0
    # 
    # cmapTable = 
    #     version: 0
    #     length: 262
    #     language: 0
    #     codeMap: map
    # 
    # cmap = 
    #     version: 0
    #     numSubtables: 1
    #     tables: [
    #         platformID: 1
    #         encodingID: 0
    #         table: cmapTable
    #     ]
        
    # TODO: subset prep, cvt, fpgm?
    Directory.encode stream,
      tables:
        head: head
        hhea: hhea
        loca: @loca
        maxp: maxp
        'cvt ': @font['cvt ']
        prep: @font.prep
        glyf: @glyf
        hmtx: @hmtx
        fpgm: @font.fpgm
        # name: clone @font.name
        # 'OS/2': clone @font['OS/2']
        # post: clone @font.post
        # cmap: cmap
        
module.exports = TTFSubset

{readFileSync, writeFileSync} = require('fs')
path = require('path')
{SourceMapConsumer, SourceMapGenerator} = require('source-map')

exports.cat = (inputMapFiles, outJSFile, outMapFile, prepend, append) ->
    buffer = []
    generator = new SourceMapGenerator
        file: outJSFile

    lineOffset = 0
    if prepend
        buffer.push(prepend)
        lineOffset += (prepend.match(/\n/)?.length or 0) + 1

    for f in inputMapFiles
        if path.extname(f) == '.map'
            map = new SourceMapConsumer(readFileSync(f, 'utf-8'))
            srcPath = path.join(path.dirname(f), map.file)
        else
            map = null
            srcPath = f

        # concatenate the file
        src = readFileSync(srcPath, 'utf-8')
        src = src.replace(/\r?\n\/\/[@#]\ssourceMappingURL[^\r\n]*/g, '')
        buffer.push(src)

        # If we have a map, add all mappings in the file
        map?.eachMapping (mapping) ->
            origSrc = path.join(path.dirname(f), mapping.source)
            mapping =
                generated:
                    line: mapping.generatedLine + lineOffset
                    column: mapping.generatedColumn
                original:
                    line: mapping.originalLine
                    column: mapping.originalColumn
                source: path.relative(path.dirname(outMapFile), origSrc)
            generator.addMapping mapping

        # update line offset so we could start working with the next file
        lineOffset += src.split('\n').length

    if append
        buffer.push(append)

    buffer.push "//# sourceMappingURL=#{path.relative(path.dirname(outJSFile), outMapFile)}"

    writeFileSync(outJSFile, buffer.join('\n'), 'utf-8')
    writeFileSync(outMapFile, generator.toString(), 'utf-8')

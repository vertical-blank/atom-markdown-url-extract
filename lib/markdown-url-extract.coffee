requestPromise = require 'request-promise'
$              = require 'jquery'
encoding       = require 'encoding-japanese'

module.extractContent = (url, res) =>
  contentType = res.headers["content-type"]

  if contentType
    if contentType.indexOf("charset=") >= 0
      charset = contentType.substring(contentType.indexOf("charset=") + 8)
    else
      charset = 'utf-8'
  else
    charset = 'utf-8'

  body = encoding.codeToString(encoding.convert(res.body, {
    from: charset,
    to: 'unicode'
  }))
  body = body.replace(/<img[^>]*>/g,"")
  $html = $(body)

  title = $html.filter('title').text()
  site_name = $html.filter("meta[property='og:site_name']").attr("content")
  description = $html.filter("meta[property='og:description']").attr("content")

  lines = []
  if site_name
    lines.push(site_name)

  if !title
    title = url

  lines.push("[" + title + "](" + url + ")")

  if description
    description = description
      .replace(/\r\n/g, "\r")
      .replace(/\n/g, "\r")
      .replace(/\r/g, "\r> ")
    lines.push("> " + description + "\r")

  return lines.join("  \r")

module.exports =
  getOgpOfURL: ->
    editor = atom.workspace.getActivePaneItem()
    return unless editor
    return if editor.getLastSelection().isEmpty()

    selection = editor.getSelections()[0]

    rows = selection.getBufferRange().getRows()

    contentByRow = {}
    promises = []
    for l in rows
      rawLine = editor.lineTextForBufferRow(l)
      url = rawLine.trim()

      if url == ''
        contentByRow[l] = rawLine
        continue

      promises.push(requestPromise({
          uri: url,
          encoding: null,
          resolveWithFullResponse: true,
          headers: {
            'User-Agent': 'Request-Promise'
          }
        })
        .then ( ((l, url) => return (res) => contentByRow[l] = module.extractContent(url, res))(l, url) )
        .catch( ((l, url) => return (err) => console.log(err);contentByRow[l] = url)(l, url.trim()) )
      )

    Promise.all(promises).then( () =>
      editor.replaceSelectedText(null,
        (text) =>
          textAll = []
          for k,v of contentByRow
            textAll.push(v)

          return "\r" + textAll.join("  \r") + "\r"
      )

      selection.clear()
    )

  activate: (state) ->
    atom.commands.add 'atom-workspace', 'markdown-url-extract:apply': => @getOgpOfURL()

#http://thegamesdb.net/api/GetGamesList.php?name=arcane
#http://thegamesdb.net/api/GetGame.php?id=2

http = require 'http'
xml2js = require 'xml2js'
glob = require 'glob'
mongojs = require 'mongojs'
request = require 'request'
google_images = require 'google-images'

roms_base_path = '/var/roms/'
APP_PORT = 8080
db = mongojs 'emulator_browser'

mongo_memoize = (func_name, func) ->
  (args, callback) ->
    collection = "__mongo__memoize__#{func_name}"
    cache_key = JSON.stringify args
    db.collection(collection).find
      cache_key: cache_key
    , (err, docs) ->
      if err then throw err
      if docs.length>0
        cached = docs[0].value
        callback cached
      else
        func args, (result) ->
          db.collection(collection).insert
            cache_key: cache_key
            value: result
          callback result


dir2platform =
  'NES': 'Nintendo Entertainment System (NES)'
  'SNES': 'Super Nintendo (SNES)'
  'Game Boy Advance': 'Nintendo Game Boy Advance'

# get_url = (host_and_path, callback) ->
get_url = mongo_memoize 'get_url', (host_and_path, callback) ->
  [host, path] = host_and_path
  request 'http://'+host+path, (err, res, body) ->
    if err
      console.log 'ERROR WITH', host, path
      throw err
    if res.statusCode!=200
      console.log 'ERROR WITH', host, path
      throw res.statusCode
    callback res.body


get_game_matches = (search_strings, callback) ->
  [game_search_string, platform_search_string] = search_strings
  get_url ["thegamesdb.net", "/api/GetGamesList.php?name=#{game_search_string}"], (xml) ->
    xml2js.parseString xml, (err, result) ->
      if err
        console.log '------'
        console.log xml
        throw err
      if not result.Data.Game?
        matches = []
      else
        matches = ( {id: x.id[0], name:x.GameTitle[0]} for x in result.Data.Game when (x.Platform[0].indexOf platform_search_string) != -1)
  
      if matches.length==0
        # console.log "NO MATCH FOR #{platform_search_string} / #{game_search_string}"
        google_images.search platform_search_string+' '+game_search_string, (err, images) ->
          if err then throw err
          ret = {}
          ret.id = -1
          ret.platform = platform_search_string
          ret.name = game_search_string
          ret.date = null
          ret.desc = null
          ret.genre = null
          ret.numPlayers = null
          ret.art = (x.unescapedUrl for x in images)[0]
          ret.url = null
          callback ret
      else
        #console.log 'gp1', matches, game_search_string, platform_search_string
        # arbitrary: take first match. Maybe there's a better way?
        match = matches[0]
        get_url ["thegamesdb.net", "/api/GetGame.php?id=#{match.id}"], (xml) ->
          xml2js.parseString xml, (err, result) ->
            if err
              console.log '------'
              console.log xml
              throw err
            ret = {}
            ret.id = match.id
            ret.platform = platform_search_string
            ret.name = match.name
            ret.date = result.Data.Game[0].ReleaseDate?[0]
            ret.desc = result.Data.Game[0].Overview?[0]
            ret.genre = result.Data.Game[0].Genres?[0].genre[0]
            ret.numPlayers = result.Data.Game[0].Players?[0]
            if result.Data.Game[0].Images?[0].boxart?
              ret.art = result.Data.baseImgUrl[0] + (x for x in result.Data.Game[0].Images?[0].boxart when x['$'].side=='front')[0]['_']
            else
              ret.art = null
            ret.url = "http://thegamesdb.net/game/#{match.id}/"
            callback ret

for folder in glob.sync "#{roms_base_path}*", {}
  platform_dir = folder.split('/')[3]
  if dir2platform[platform_dir]
    #console.log platform_dir
    platform = dir2platform[platform_dir]
    # console.log platform
    glob2 = "#{roms_base_path}#{platform_dir}/*"
    #console.log glob2
    gamefiles = glob.sync glob2, {}
    for gamefile in gamefiles
      t = gamefile.split('/')[4].split('.')
      game = t[0 .. t.length-2].join ''
      # console.log platform, ':', game
      get_game_matches [game, platform], (result) ->
        # console.log result.platform + ' / ' + result.name
        db.collection('games').insert result

###
get_game_matches 'arcana', 'SNES', (result) ->
  console.log (JSON.stringify result, null, 2)
  process.exit()
###

#--------------------------------- Express setup --------------------------------
app = express()
server = http.createServer(app)
io = socket_io.listen(server)
server.listen APP_PORT

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.configure 'development', ->
    app.locals.pretty = true

  app.use stylus.middleware
    #debug: true
    force: true
    src: __dirname + '/public'
    compile: (str, path) ->
      stylus(str).set("filename", path).use nib()

  app.use express.cookieParser()
  app.use express.bodyParser()
  app.use express.methodOverride()

  app.use app.router
   
  app.use express.static __dirname + '/public',
    redirect : false

  app.use express.logger()

app.get "/", (req, res) ->
  res.render 'index'